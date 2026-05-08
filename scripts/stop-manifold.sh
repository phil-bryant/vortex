#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

pid_file="${ROOT_DIR}/${VORTEX_MANIFOLD_PID_FILE}"
if [[ ! -f "${pid_file}" ]]; then
  exit 0
fi

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

rm -f "${pid_file}"
