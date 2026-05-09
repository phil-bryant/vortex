# Verify E2E Requirements

## Scope

Applies to `05_verify_e2e.sh`.

R001 Statement: The verifier checks proxy and Manifold health endpoints.
Design: Probe proxy `/healthz` plus Manifold `/healthz` and `/readyz` using curl fail-fast checks.

R005 Statement: The verifier confirms ingest persistence when database tooling is available.
Design: If `psql` exists, query ingest rows for the harness event and fail when no matching rows are found.
