# Start Ingest Proxy Requirements

## Scope

Applies to `04_start_ingest_proxy.sh`.

R001 Statement: The script starts the local ingest proxy with header injection configuration.
Design: Run `09_ingest_proxy.py` with configured bind address, target URL, and ingest key.

R005 Statement: The script confirms proxy health before returning success.
Design: Wait for `http://${VORTEX_PROXY_ADDR}/healthz` and fail startup when health does not become ready.
