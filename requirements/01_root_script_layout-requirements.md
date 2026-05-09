# Root Script Layout Requirements

## Scope

Applies to `01_run_e2e.sh`.

R001 Statement: The orchestrator runs from the repository root and starts with prerequisite command checks.
Design: `01_run_e2e.sh` verifies required commands and executes root-level numbered scripts.

R005 Statement: The primary operator entrypoint executes the numbered start flow before verification.
Design: Start order is `02_start_postgres.sh`, `03_start_manifold.sh`, `04_start_ingest_proxy.sh`, then `05_verify_e2e.sh`.

R010 Statement: Cleanup ordering must stop proxy before Manifold.
Design: Exit trap runs `06_stop_ingest_proxy.sh` before `07_stop_manifold.sh`.

R015 Statement: Legacy `scripts/` paths are not used by the orchestration entrypoint.
Design: The orchestrator only references root-level `NN_` script names.
