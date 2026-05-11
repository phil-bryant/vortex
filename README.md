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
bash ./01_run_e2e.sh
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

- `01_run_e2e.sh`: full orchestration entrypoint.
- `02_start_postgres.sh`: validates DB connectivity and provisions Manifold DB state if needed.
- `03_start_manifold.sh`: starts Manifold in background and waits for readiness.
- `04_start_ingest_proxy.sh`: starts local ingest proxy that adds `X-Manifold-Ingest-Key`.
- `05_verify_e2e.sh`: checks `/healthz`, `/readyz`, and (if `psql` exists) confirms ingested rows.
- `06_stop_ingest_proxy.sh`: stops local ingest proxy.
- `07_stop_manifold.sh`: stops Manifold background process.
- `08_common.sh`: shared env + helper functions sourced by shell scripts.
- `09_ingest_proxy.py`: proxy server used by `04_start_ingest_proxy.sh`.

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
  - Re-run `bash ./01_run_e2e.sh` so Fountain rebuilds first.
  - Confirm `../fountain`, `../piston`, and `../manifold` paths are correct from `vortex`.
- No separate Vortex database is required:
  - Vortex orchestrates only; Manifold stores data in its own Postgres database (`prod` by default).

## Architecture Diagram

```text
BACKEND
┌──────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  ┌────────────────────────────┐        ┌──────────────────────────────────┐  │
│  │           Valve            │        │             Manifold             │  │
│  │                            │        │                                  │  │
│  │ - runs after user sign-in  │        │ - verifies signature / credential│  │
│  │ - verifies Account A access│        │ - derives tenant_id + install_id │  │
│  │ - provisions per-tenant /  │        │   from credential                │  │
│  │   per-install credential   │        │ - stores tenant-scoped events    │  │
│  │ - rotates / revokes creds  │        │ - rejects tenant mismatches      │  │
│  └─────────────┬──────────────┘        │                                  │  │
│                │                       │  ┌───────────────────────┐       │  │
│                │                       │  │ Ingest Endpoint       │       │  │
│                │                 ┌─────┼─►│ POST /v1/events/batch │       │  │
│                │                 │     │  └───────────────────────┘       │  │
│                │                 │     │                                  │  │
│                │                 │     └──────────────────────┬───────────┘  │
│                │                 │                            │              │
└────────────────┼─────────────────┼────────────────────────────┼──────────────┘
                 │                 │                            │
                 │                 │                            │ tenant-scoped
                 │                 │                            │ events
                 │ credential      │             NOC/SOC        ▼
                 │ for Account A   │             ┌──────────────────────────┐
                 │ + Install 123   │             │          Vortex          │
                 │                 │             │                          │
                 │                 │             │ - downstream all-in-one  │
                 │                 │             │ - storage / analytics    │
                 │                 │             │ - dashboards / alerts    │
                 │                 │             │ - incident review        │
    credential   │                 │             │ - strict tenant_id reads │
    provisioned  │                 │             └──────────────────────────┘
   after sign-in │                 │
                 │                 │ HTTPS + signed batch
                 │                 │ credential proves Account A + Install 123
CUSTOMER DEVICE  ▼                 │
┌──────────────────────────────────┼─────────┐
│                                  │         │
│  ┌────────────────────┐   ┌─────────────┐  │
│  │      Fountain      │   │   Piston    │  │
│  │                    │   │             │  │
│  │ - C++ event logger │   │ - Swift     │  │
│  │ - SQLite queue     │   │   uploader  │  │
│  │ - tags events with │   │ - stores    │  │
│  │   tenant_scope     │   │   credential│  │
│  └─────────┬──────────┘   │ - claims    │  │
│            │              │   matching  │  │
│            │ Account A    │   scope     │  │
│            │ events       │ - signs     │  │
│            └─────────────►│   uploads   │  │
│                           └─────────────┘  │
│                                            │
└────────────────────────────────────────────┘
```
