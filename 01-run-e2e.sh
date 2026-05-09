#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/08-common.sh"

ensure_command go
ensure_command swift
ensure_command cmake
ensure_command curl

./02-start-postgres.sh

echo "Building Fountain static library..."
cmake -S "${ROOT_DIR}/${VORTEX_FOUNTAIN_DIR}" -B "${ROOT_DIR}/${VORTEX_FOUNTAIN_BUILD_DIR}"
cmake --build "${ROOT_DIR}/${VORTEX_FOUNTAIN_BUILD_DIR}" --target fountain

cleanup() {
  ./06-stop-ingest-proxy.sh || true
  ./07-stop-manifold.sh || true
}
trap cleanup EXIT

./03-start-manifold.sh
./04-start-ingest-proxy.sh

echo "Running Swift harness..."
fountain_build_dir="${ROOT_DIR}/${VORTEX_FOUNTAIN_BUILD_DIR}"
fountain_build_src_dir="${fountain_build_dir}/src"
MANIFOLD_INGEST_KEY="${MANIFOLD_INGEST_KEY}" \
VORTEX_MANIFOLD_URL="${VORTEX_MANIFOLD_URL}" \
VORTEX_FOUNTAIN_DB_PATH="${VORTEX_FOUNTAIN_DB_PATH}" \
VORTEX_E2E_EVENT_NAME="${VORTEX_E2E_EVENT_NAME}" \
swift run \
  --package-path "${ROOT_DIR}/harness" \
  -Xlinker "-L${fountain_build_dir}" \
  -Xlinker "-L${fountain_build_src_dir}" \
  -Xlinker "-lfountain" \
  -Xlinker "-lsqlite3" \
  -Xlinker "-lc++" \
  VortexHarness

./05-verify-e2e.sh

echo "Completed end-to-end diagnostics flow."
