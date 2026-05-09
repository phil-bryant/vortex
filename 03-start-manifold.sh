#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/08-common.sh"

ensure_command go
ensure_command curl

ensure_manifold_database_url

mkdir -p "${ROOT_DIR}/${VORTEX_STATE_DIR}"

if [[ -f "${ROOT_DIR}/${VORTEX_MANIFOLD_PID_FILE}" ]]; then
  existing_pid="$(<"${ROOT_DIR}/${VORTEX_MANIFOLD_PID_FILE}")"
  if [[ -n "${existing_pid}" ]] && kill -0 "${existing_pid}" >/dev/null 2>&1; then
    echo "Manifold already running with pid ${existing_pid}."
    exit 0
  fi
  rm -f "${ROOT_DIR}/${VORTEX_MANIFOLD_PID_FILE}"
fi

echo "Starting Manifold from ${VORTEX_MANIFOLD_DIR}..."
(
  cd "${ROOT_DIR}/${VORTEX_MANIFOLD_DIR}"
  MANIFOLD_INGEST_KEY="${MANIFOLD_INGEST_KEY}" \
  MANIFOLD_DATABASE_URL="${MANIFOLD_DATABASE_URL}" \
  MANIFOLD_ADDR="${MANIFOLD_ADDR}" \
  go run ./cmd/manifold >>"${ROOT_DIR}/${VORTEX_MANIFOLD_LOG}" 2>&1
) &

pid=$!
echo "${pid}" >"${ROOT_DIR}/${VORTEX_MANIFOLD_PID_FILE}"

ready_url="http://127.0.0.1${MANIFOLD_ADDR}/readyz"
if ! wait_for_http "${ready_url}" 30; then
  echo "Manifold failed readiness check at ${ready_url}" >&2
  echo "Recent manifold log output:" >&2
  if [[ -f "${ROOT_DIR}/${VORTEX_MANIFOLD_LOG}" ]]; then
    python - "${ROOT_DIR}/${VORTEX_MANIFOLD_LOG}" <<'PY' >&2
from pathlib import Path
import sys

path = Path(sys.argv[1])
for line in path.read_text(errors="replace").splitlines()[-40:]:
    print(line)
PY
  fi
  exit 1
fi

echo "Manifold is ready."
