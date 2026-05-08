#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

ensure_command python3
ensure_command curl

mkdir -p "${ROOT_DIR}/${VORTEX_STATE_DIR}"

if [[ -f "${ROOT_DIR}/${VORTEX_PROXY_PID_FILE}" ]]; then
  existing_pid="$(<"${ROOT_DIR}/${VORTEX_PROXY_PID_FILE}")"
  if [[ -n "${existing_pid}" ]] && kill -0 "${existing_pid}" >/dev/null 2>&1; then
    echo "Ingest proxy already running with pid ${existing_pid}."
    exit 0
  fi
  rm -f "${ROOT_DIR}/${VORTEX_PROXY_PID_FILE}"
fi

target_url="http://127.0.0.1${MANIFOLD_ADDR}"
(
  cd "${ROOT_DIR}"
  python3 "${ROOT_DIR}/scripts/ingest_proxy.py" \
    --bind "${VORTEX_PROXY_ADDR}" \
    --target "${target_url}" \
    --ingest-key "${MANIFOLD_INGEST_KEY}" >>"${ROOT_DIR}/${VORTEX_PROXY_LOG}" 2>&1
) &

pid=$!
echo "${pid}" >"${ROOT_DIR}/${VORTEX_PROXY_PID_FILE}"

if ! wait_for_http "http://${VORTEX_PROXY_ADDR}/healthz" 10; then
  echo "Ingest proxy failed startup on ${VORTEX_PROXY_ADDR}" >&2
  exit 1
fi

echo "Ingest proxy is ready on ${VORTEX_PROXY_ADDR}."
