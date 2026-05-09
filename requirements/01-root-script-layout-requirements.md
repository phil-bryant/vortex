# Root Script Layout Requirements

R001 Statement: Vortex orchestration scripts must live in the repository root and not in a `scripts/` directory.
Design: The executable and helper files are named with `NN-name` ordering at root:
- `01-run-e2e.sh`
- `02-start-postgres.sh`
- `03-start-manifold.sh`
- `04-start-ingest-proxy.sh`
- `05-verify-e2e.sh`
- `06-stop-ingest-proxy.sh`
- `07-stop-manifold.sh`
- `08-common.sh`
- `09-ingest-proxy.py`

R005 Statement: The primary operator entrypoint is `01-run-e2e.sh`.
Design: README and internal script references point at root-level paths with no `scripts/` prefix.

R010 Statement: Numbered ordering reflects execution order.
Design:
- Start path: `01` -> `02` -> `03` -> `04` -> `05`
- Cleanup path: `06` then `07`
- Shared helpers: `08`
- Proxy implementation: `09`

R015 Statement: The legacy `scripts/` directory must be removed from active use.
Design: No file in repository references `scripts/NN-...` paths.
