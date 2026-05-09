# Root Script Layout Test

## Purpose
Verify Vortex uses root-level numbered orchestration scripts and no active `scripts/` path references.

## Checks
- C001: Files `01_run_e2e.sh` through `09_ingest_proxy.py` exist at repo root.
- C005: `README.md` references root-level script names (no `scripts/` prefix for numbered scripts).
- C010: `01_run_e2e.sh` invokes `02`..`07` from root-relative paths.
- C015: No repository references remain to `scripts/01_` style paths.

## Runtime Verification
- Run `./01_run_e2e.sh` and confirm end-to-end success:
  - Manifold reaches ready state.
  - Harness uploads through Piston.
  - `05_verify_e2e.sh` passes.
