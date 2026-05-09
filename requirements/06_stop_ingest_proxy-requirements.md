# Stop Ingest Proxy Requirements

## Scope

Applies to `06_stop_ingest_proxy.sh`.

R001 Statement: The script stops an active ingest proxy process tracked by pid file.
Design: Read the proxy pid file and signal the process when it is running.

R005 Statement: The script clears proxy pid state after stop handling.
Design: Remove the proxy pid file after stop attempts to prevent stale runtime state.
