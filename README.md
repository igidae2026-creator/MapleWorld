# MapleWorld

MapleWorld is being refactored into a strict dual-boundary architecture:

- `msw_runtime/`: MapleStory Worlds runtime-facing gameplay only.
- `shared_rules/`: pure rules, formulas, and balance logic.
- `content_build/`: content compilation and validation outside the live runtime.
- `ai_evolution_offline/`: Codex/GPT-driven generation, mutation, scoring, and selection.
- `offline_ops/`: replay, audit, telemetry, reports, and Codex execution state.

Current policy:

- MSW inside: gameplay only.
- MSW outside: control plane, replay, clustering, architecture evolution, audit, and simulation.
- `server_bootstrap` and the giant bridge are removed rather than preserved.

Run the remaining focused verification with:

```bash
for f in tests/*_test.lua; do lua "$f"; done
```
