SLICE: 3
STATUS: passed

CHANGES:
- Removed direct `content_build` import from `msw_runtime/state/gameplay_runtime.lua`.
- Switched runtime content assembly to the repository's `data/*/catalog.lua` surfaces.
- Added `tests/msw_runtime_boundary_test.lua` to fail if `msw_runtime` directly imports:
  - `content_build`
  - `offline_ops`
  - `ai_evolution_offline`
- Added manifest and README assertions so the runtime must remain explicitly gameplay-only.
- Extended the unified test entrypoint to include the new boundary guard.

VERIFICATION:
- `lua tests/msw_runtime_boundary_test.lua`
- `make test`
- `bash -n ai_evolution_offline/codex/run_bottleneck_loop.sh`

NOTES:
- The loop now enforces boundary validation through the standard test command.
- No bridge/bootstrap ownership was reintroduced.
