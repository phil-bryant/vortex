#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/08_common.sh"

ensure_command go
ensure_command swift
ensure_command cmake
ensure_command curl

#R001: The orchestrator starts by ensuring all required toolchain commands are present.
./02_start_postgres.sh

echo "Building Fountain static library..."
cmake -S "${ROOT_DIR}/${VORTEX_FOUNTAIN_DIR}" -B "${ROOT_DIR}/${VORTEX_FOUNTAIN_BUILD_DIR}"
cmake --build "${ROOT_DIR}/${VORTEX_FOUNTAIN_BUILD_DIR}" --target fountain

cleanup() {
  #R010: Cleanup path executes stop scripts in numbered order.
  ./06_stop_ingest_proxy.sh || true
  ./07_stop_manifold.sh || true
}
trap cleanup EXIT

#R005: The main operator entrypoint executes the numbered start flow before verification.
./03_start_manifold.sh
./04_start_ingest_proxy.sh

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

./05_verify_e2e.sh

#R015: The legacy scripts directory is unused; this root script coordinates all numbered root scripts.
echo "Completed end-to-end diagnostics flow."
