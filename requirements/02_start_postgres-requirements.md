# Start Postgres Checks Requirements

## Scope

Applies to `02_start_postgres.sh`.

R001 Statement: The script validates PostgreSQL reachability and required credentials before continuing orchestration.
Design: Resolve admin and manifold credentials, then verify connectivity to the configured PostgreSQL host/port.

R005 Statement: The script provides a usable `MANIFOLD_DATABASE_URL` for downstream steps.
Design: Build and export `MANIFOLD_DATABASE_URL` when not preconfigured and verify queryability with `psql`.
