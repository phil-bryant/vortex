#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/08_common.sh"

ensure_command curl

#R001: Verify proxy and Manifold health/readiness endpoints for the end-to-end path.
ensure_manifold_database_url

proxy_health_url="http://${VORTEX_PROXY_ADDR}/healthz"
health_url="http://127.0.0.1${MANIFOLD_ADDR}/healthz"
ready_url="http://127.0.0.1${MANIFOLD_ADDR}/readyz"

echo "Checking ${proxy_health_url}..."
curl --silent --show-error --fail "${proxy_health_url}" >/dev/null

echo "Checking ${health_url}..."
curl --silent --show-error --fail "${health_url}" >/dev/null

echo "Checking ${ready_url}..."
curl --silent --show-error --fail "${ready_url}" >/dev/null

if command -v psql >/dev/null 2>&1; then
  #R005: Confirm at least one ingested harness row exists when database tools are available.
  echo "Verifying ingested events in PostgreSQL..."
  event_count_raw="$(psql "${MANIFOLD_DATABASE_URL}" -t -A -c \
    "select count(*) from ingest_events where event_name = '${VORTEX_E2E_EVENT_NAME}' and component = 'vortex.harness';")"
  event_count="${event_count_raw//[[:space:]]/}"
  if [[ "${event_count}" -lt 1 ]]; then
    echo "No ingested rows found for event '${VORTEX_E2E_EVENT_NAME}'." >&2
    exit 1
  fi
  echo "Found ${event_count} ingested event row(s)."
else
  echo "psql not found; skipped DB-level ingest verification."
fi

echo "E2E verification passed."
