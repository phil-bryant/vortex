#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${ROOT_DIR}/.env" ]]; then
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
elif [[ -f "${ROOT_DIR}/.env.example" ]]; then
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env.example"
fi

MANIFOLD_INGEST_KEY="${MANIFOLD_INGEST_KEY:-local-ingest-key}"
MANIFOLD_DATABASE_URL="${MANIFOLD_DATABASE_URL:-}"
MANIFOLD_ADDR="${MANIFOLD_ADDR:-:8080}"
MANIFOLD_DB_HOST="${MANIFOLD_DB_HOST:-localhost}"
MANIFOLD_DB_PORT="${MANIFOLD_DB_PORT:-5432}"
MANIFOLD_DB_NAME="${MANIFOLD_DB_NAME:-prod}"
MANIFOLD_DB_USER="${MANIFOLD_DB_USER:-teller}"
MANIFOLD_DB_SSLMODE="${MANIFOLD_DB_SSLMODE:-disable}"
MANIFOLD_PSA_ITEM="${MANIFOLD_PSA_ITEM:-localhost_postgres_manifold}"
MANIFOLD_PSA_FIELD="${MANIFOLD_PSA_FIELD:-password}"
POSTGRES_PSA_ITEM="${POSTGRES_PSA_ITEM:-localhost_postgres_postgres}"
POSTGRES_PSA_FIELD="${POSTGRES_PSA_FIELD:-password}"
TELLER_PSA_ITEM="${TELLER_PSA_ITEM:-localhost_postgres_manifold}"
TELLER_PSA_FIELD="${TELLER_PSA_FIELD:-password}"

VORTEX_FOUNTAIN_DIR="${VORTEX_FOUNTAIN_DIR:-../fountain}"
VORTEX_PISTON_DIR="${VORTEX_PISTON_DIR:-../piston}"
VORTEX_MANIFOLD_DIR="${VORTEX_MANIFOLD_DIR:-../manifold}"
VORTEX_FOUNTAIN_BUILD_DIR="${VORTEX_FOUNTAIN_BUILD_DIR:-../fountain/build}"

VORTEX_PROXY_ADDR="${VORTEX_PROXY_ADDR:-127.0.0.1:18080}"
VORTEX_MANIFOLD_URL="${VORTEX_MANIFOLD_URL:-http://127.0.0.1:18080/v1/events/batch}"
VORTEX_FOUNTAIN_DB_PATH="${VORTEX_FOUNTAIN_DB_PATH:-/tmp/vortex-fountain.sqlite3}"
VORTEX_E2E_EVENT_NAME="${VORTEX_E2E_EVENT_NAME:-vortex.e2e.smoketest}"

VORTEX_STATE_DIR="${VORTEX_STATE_DIR:-.vortex}"
VORTEX_MANIFOLD_LOG="${VORTEX_MANIFOLD_LOG:-.vortex/manifold.log}"
VORTEX_MANIFOLD_PID_FILE="${VORTEX_MANIFOLD_PID_FILE:-.vortex/manifold.pid}"
VORTEX_PROXY_LOG="${VORTEX_PROXY_LOG:-.vortex/ingest-proxy.log}"
VORTEX_PROXY_PID_FILE="${VORTEX_PROXY_PID_FILE:-.vortex/ingest-proxy.pid}"

ensure_command() {
  local name="$1"
  if ! command -v "${name}" >/dev/null 2>&1; then
    echo "Missing required command: ${name}" >&2
    exit 1
  fi
}

get_psa_secret() {
  local item="$1"
  local field="$2"
  if [[ "${field}" == "password" ]]; then
    1psa -p "${item}"
  else
    1psa -f "${item}" "${field}"
  fi
}

urlencode() {
  local raw="$1"
  python3 - "$raw" <<'PY'
import sys
import urllib.parse
print(urllib.parse.quote(sys.argv[1], safe=''))
PY
}

ensure_manifold_database_url() {
  if [[ -n "${MANIFOLD_DATABASE_URL}" ]]; then
    export MANIFOLD_DATABASE_URL
    return 0
  fi

  ensure_command 1psa
  ensure_command python3
  local db_password
  db_password="$(get_psa_secret "${MANIFOLD_PSA_ITEM}" "${MANIFOLD_PSA_FIELD}")"
  if [[ -z "${db_password}" ]]; then
    echo "Failed to read Postgres password from 1psa item '${MANIFOLD_PSA_ITEM}'." >&2
    exit 1
  fi

  export PGPASSWORD="${db_password}"
  db_password_encoded="$(urlencode "${db_password}")"
  export MANIFOLD_DATABASE_URL="postgres://${MANIFOLD_DB_USER}:${db_password_encoded}@${MANIFOLD_DB_HOST}:${MANIFOLD_DB_PORT}/${MANIFOLD_DB_NAME}?sslmode=${MANIFOLD_DB_SSLMODE}"
}

http_ready() {
  local url="$1"
  curl --silent --show-error --fail "${url}" >/dev/null 2>&1
}

wait_for_http() {
  local url="$1"
  local timeout_seconds="${2:-30}"
  local elapsed=0
  while (( elapsed < timeout_seconds )); do
    if http_ready "${url}"; then
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  return 1
}
