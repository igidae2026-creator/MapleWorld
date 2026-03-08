SLICE: 1
STATUS: passed

CHANGES:
- Added `make test` as the unified regression entrypoint.
- Added `scripts/run_tests.sh` as the direct shell fallback for the same test set.
- Upgraded `ai_evolution_offline/codex/run_bottleneck_loop.sh` with:
  - pre-patch test precheck
  - repository snapshot/restore on patch verification failure
  - failure and regression counters
  - repeated bottleneck stop condition
  - failure logging and persisted loop state

VERIFICATION:
- `bash -n ai_evolution_offline/codex/run_bottleneck_loop.sh`
- `make test`
- `bash scripts/run_tests.sh`

NOTES:
- Rollback currently restores the repository from a pre-patch tar snapshot.
- Failure handling now follows `FAIL -> rollback -> record failure -> continue`, unless configured stop thresholds are reached.
