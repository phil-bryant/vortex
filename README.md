# Vortex

`Vortex` is a host-native local orchestration repo that wires the flow:

1. `fountain` logs events into a SQLite queue.
2. `piston` claims upload batches from Fountain and POSTs JSON.
3. `manifold` ingests those batches and persists to Postgres.

## Prerequisites

- macOS with:
  - `go` (for Manifold)
  - `swift` (for harness + Piston)
  - `cmake` (for Fountain build)
  - `curl`
  - `psql` and `pg_isready`
- Local Postgres reachable from `MANIFOLD_DATABASE_URL`.

## Configure Environment

Copy defaults and adjust if needed:

```bash
cp .env.example .env
```

Key values:

- `MANIFOLD_INGEST_KEY`: required by Manifold ingest auth.
- `MANIFOLD_DATABASE_URL`: optional explicit Postgres DSN override.
- `MANIFOLD_PSA_ITEM` / `MANIFOLD_PSA_FIELD`: 1psa source for DB password (defaults to `localhost_postgres_manifold` / `password`).
- `MANIFOLD_ADDR`: Manifold bind address (default `:8080`).
- `VORTEX_MANIFOLD_URL`: endpoint used by Piston (`http://127.0.0.1:18080/v1/events/batch` by default).
- `VORTEX_PROXY_ADDR`: local header-injecting proxy bind (`127.0.0.1:18080` by default).

## Run End-to-End

```bash
bash ./01-run-e2e.sh
```

What this command does:

- Resolves Postgres credentials from `1psa` (`localhost_postgres_manifold` by default).
- Checks Postgres reachability and creates the `manifold` database when missing.
- Builds Fountain static library.
- Starts Manifold and waits for `/readyz`.
- Starts a local ingest proxy that injects `X-Manifold-Ingest-Key` for Piston uploads.
- Runs a Swift harness that:
  - configures Fountain DB path,
  - logs one deterministic event (`VORTEX_E2E_EVENT_NAME`),
  - calls `PistonUploader.flushNow()`.
- Verifies health endpoints and Postgres ingest rows.

## Script Reference

- `01-run-e2e.sh`: full orchestration entrypoint.
- `02-start-postgres.sh`: validates DB connectivity and provisions Manifold DB state if needed.
- `03-start-manifold.sh`: starts Manifold in background and waits for readiness.
- `04-start-ingest-proxy.sh`: starts local ingest proxy that adds `X-Manifold-Ingest-Key`.
- `05-verify-e2e.sh`: checks `/healthz`, `/readyz`, and (if `psql` exists) confirms ingested rows.
- `06-stop-ingest-proxy.sh`: stops local ingest proxy.
- `07-stop-manifold.sh`: stops Manifold background process.
- `08-common.sh`: shared env + helper functions sourced by shell scripts.
- `09-ingest-proxy.py`: proxy server used by `04-start-ingest-proxy.sh`.

## Troubleshooting

- `401 unauthorized` from ingest:
  - Ensure `MANIFOLD_INGEST_KEY` in `.env` matches Manifold startup env.
  - Ensure proxy is running on `VORTEX_PROXY_ADDR`.
- `415 invalid_content_type`:
  - Piston sends `application/json`; if you changed proxy behavior, keep the content type preserved.
- `422 invalid_schema` / `too_many_events`:
  - Validate event shape against Manifold contract; this harness emits schema version `1`.
- `503 storage_unavailable` / `/readyz` fails:
  - Verify Postgres is running and that `1psa -p localhost_postgres_manifold` returns the correct password (or set `MANIFOLD_DATABASE_URL` explicitly).
- Build/link failures in harness:
  - Re-run `bash ./01-run-e2e.sh` so Fountain rebuilds first.
  - Confirm `../fountain`, `../piston`, and `../manifold` paths are correct from `vortex`.
- No separate Vortex database is required:
  - Vortex orchestrates only; Manifold stores data in its own Postgres database (`prod` by default).
