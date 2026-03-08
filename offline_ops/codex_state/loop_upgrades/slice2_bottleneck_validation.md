SLICE: 2
STATUS: passed

CHANGES:
- Tightened coordinator prompt rules to reject architecture-wide refactors and repeated unchanged bottlenecks.
- Added loop-side coordinator validation in `ai_evolution_offline/codex/run_bottleneck_loop.sh` for:
  - oversized patch scope
  - directory / wildcard file scopes
  - too many top-level areas in one patch
  - fake progress when bottleneck and efficiency estimate are unchanged after a successful patch
- Added one retry path for coordinator decisions before the loop rejects the cycle.

VERIFICATION:
- `bash -n ai_evolution_offline/codex/run_bottleneck_loop.sh`
- `make test`
- Confirmed updated coordinator rules in `ai_evolution_offline/prompts/coordinator.txt`

NOTES:
- Repeated bottleneck detection is now enforced both as a stop condition and as a decision-quality signal.
- Fake progress is tracked in loop state and can stop the loop once the configured threshold is reached.
