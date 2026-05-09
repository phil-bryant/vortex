#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/08_common.sh"

pid_file="${ROOT_DIR}/${VORTEX_PROXY_PID_FILE}"
if [[ ! -f "${pid_file}" ]]; then
  exit 0
fi

#R001: Stop the running ingest proxy process identified by the stored pid.
pid="$(<"${pid_file}")"
if [[ -n "${pid}" ]] && kill -0 "${pid}" >/dev/null 2>&1; then
  kill "${pid}" >/dev/null 2>&1 || true
  for _ in {1..10}; do
    if ! kill -0 "${pid}" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi

#R005: Remove the proxy pid file once the process stop attempt completes.
rm -f "${pid_file}"
