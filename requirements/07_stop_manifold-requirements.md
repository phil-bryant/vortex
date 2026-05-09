# Stop Manifold Requirements

## Scope

Applies to `07_stop_manifold.sh`.

R001 Statement: The script stops an active Manifold process tracked by pid file.
Design: Read the Manifold pid file and signal the process when it is running.

R005 Statement: The script clears Manifold pid state after stop handling.
Design: Remove the Manifold pid file after stop attempts to prevent stale runtime state.
