# Root Script Layout Test

## Purpose
Verify Vortex uses root-level numbered orchestration scripts and no active `scripts/` path references.

## Checks
- C001: Files `01-run-e2e.sh` through `09-ingest-proxy.py` exist at repo root.
- C005: `README.md` references root-level script names (no `scripts/` prefix for numbered scripts).
- C010: `01-run-e2e.sh` invokes `02`..`07` from root-relative paths.
- C015: No repository references remain to `scripts/01-` style paths.

## Runtime Verification
- Run `./01-run-e2e.sh` and confirm end-to-end success:
  - Manifold reaches ready state.
  - Harness uploads through Piston.
  - `05-verify-e2e.sh` passes.
