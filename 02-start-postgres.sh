#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/08-common.sh"

ensure_command psql
ensure_command pg_isready
ensure_command zsh
ensure_command 1psa
ensure_command rg

echo "Checking PostgreSQL reachability..."
admin_password="$(get_psa_secret "${POSTGRES_PSA_ITEM}" "${POSTGRES_PSA_FIELD}")"
if [[ -z "${admin_password}" ]]; then
  echo "Failed to read admin Postgres password from 1psa item '${POSTGRES_PSA_ITEM}'." >&2
  exit 1
fi

manifold_password="$(get_psa_secret "${MANIFOLD_PSA_ITEM}" "${MANIFOLD_PSA_FIELD}")"
if [[ -z "${manifold_password}" ]]; then
  echo "Failed to read Manifold Postgres password from 1psa item '${MANIFOLD_PSA_ITEM}'." >&2
  exit 1
fi

if ! PGPASSWORD="${admin_password}" pg_isready -h "${MANIFOLD_DB_HOST}" -p "${MANIFOLD_DB_PORT}" -U postgres -d postgres >/dev/null 2>&1; then
  echo "PostgreSQL is not ready on ${MANIFOLD_DB_HOST}:${MANIFOLD_DB_PORT}." >&2
  exit 1
fi

echo "Checking existing manifold DB provisioning..."
if ! (cd "${ROOT_DIR}/${VORTEX_MANIFOLD_DIR}" && \
  TELLER_PSA_ITEM="${TELLER_PSA_ITEM}" \
  TELLER_DB_PASSWORD="${manifold_password}" \
  zsh ./04_verify_deploy_database.sh >/dev/null 2>&1); then
  manifold_sql_dir="${ROOT_DIR}/${VORTEX_MANIFOLD_DIR}/sql/postgres"
  if [[ -d "${manifold_sql_dir}" ]]; then
    echo "Manifold DB not provisioned; running manifold deploy scripts..."
    (
      cd "${ROOT_DIR}/${VORTEX_MANIFOLD_DIR}" && \
      POSTGRES_PSA_ITEM="${POSTGRES_PSA_ITEM}" \
      POSTGRES_PSA_FIELD="${POSTGRES_PSA_FIELD}" \
      TELLER_PSA_ITEM="${TELLER_PSA_ITEM}" \
      TELLER_PSA_FIELD="${TELLER_PSA_FIELD}" \
      bash ./03_deploy_database.sh && \
      TELLER_PSA_ITEM="${TELLER_PSA_ITEM}" \
      TELLER_DB_PASSWORD="${manifold_password}" \
      zsh ./04_verify_deploy_database.sh
    )
  else
    echo "Manifold deploy SQL files missing; using fallback DB bootstrap."
    sql_escaped_password="${manifold_password//\'/\'\'}"
    PGPASSWORD="${admin_password}" psql \
      -h "${MANIFOLD_DB_HOST}" \
      -p "${MANIFOLD_DB_PORT}" \
      -U postgres \
      -d postgres \
      -v ON_ERROR_STOP=1 <<SQL >/dev/null
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${MANIFOLD_DB_USER}') THEN
    EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', '${MANIFOLD_DB_USER}', '${sql_escaped_password}');
  ELSE
    EXECUTE format('ALTER ROLE %I WITH LOGIN PASSWORD %L', '${MANIFOLD_DB_USER}', '${sql_escaped_password}');
  END IF;
END
\$\$;
SQL
    if ! PGPASSWORD="${admin_password}" psql -h "${MANIFOLD_DB_HOST}" -p "${MANIFOLD_DB_PORT}" -U postgres -d postgres -t -A -c \
      "select 1 from pg_database where datname='${MANIFOLD_DB_NAME}';" | rg -q "^1$"; then
      PGPASSWORD="${admin_password}" psql -h "${MANIFOLD_DB_HOST}" -p "${MANIFOLD_DB_PORT}" -U postgres -d postgres -v ON_ERROR_STOP=1 -c \
        "create database ${MANIFOLD_DB_NAME} owner ${MANIFOLD_DB_USER};" >/dev/null
    fi
    PGPASSWORD="${admin_password}" psql -h "${MANIFOLD_DB_HOST}" -p "${MANIFOLD_DB_PORT}" -U postgres -d "${MANIFOLD_DB_NAME}" -v ON_ERROR_STOP=1 -c \
      "GRANT CONNECT, TEMPORARY ON DATABASE ${MANIFOLD_DB_NAME} TO ${MANIFOLD_DB_USER};" >/dev/null
    PGPASSWORD="${admin_password}" psql -h "${MANIFOLD_DB_HOST}" -p "${MANIFOLD_DB_PORT}" -U postgres -d "${MANIFOLD_DB_NAME}" -v ON_ERROR_STOP=1 -c \
      "GRANT USAGE, CREATE ON SCHEMA public TO ${MANIFOLD_DB_USER};" >/dev/null
  fi
else
  echo "Manifold DB already provisioned."
fi

if [[ -z "${MANIFOLD_DATABASE_URL}" ]]; then
  manifold_password_encoded="$(urlencode "${manifold_password}")"
  export MANIFOLD_DATABASE_URL="postgres://${MANIFOLD_DB_USER}:${manifold_password_encoded}@${MANIFOLD_DB_HOST}:${MANIFOLD_DB_PORT}/${MANIFOLD_DB_NAME}?sslmode=${MANIFOLD_DB_SSLMODE}"
fi

if ! psql "${MANIFOLD_DATABASE_URL}" -c "select 1;" >/dev/null 2>&1; then
  echo "Connected to PostgreSQL host, but query failed for DSN: ${MANIFOLD_DATABASE_URL}" >&2
  exit 1
fi

echo "PostgreSQL is reachable."
