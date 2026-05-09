# Start Manifold Requirements

## Scope

Applies to `03_start_manifold.sh`.

R001 Statement: The script starts Manifold and records runtime state paths.
Design: Launch Manifold in the background and write pid/log output under the configured Vortex state paths.

R005 Statement: The script blocks on Manifold readiness before returning success.
Design: Poll `http://127.0.0.1${MANIFOLD_ADDR}/readyz` and fail with diagnostics if readiness is not reached in time.
