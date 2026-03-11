# MapleWorld

MapleWorld is a Codex-native autonomous game design and implementation repository for a MapleLand-class MMORPG under MapleStory Worlds constraints.

The repository now treats a small set of markdown files as canonical authority. Start with:

- `AGENTS.md`
- `README.md`
- `ARCHITECTURE.md`
- `GAME_DESIGN.md`
- `EXECUTION_LOOP.md`
- `QUALITY_GATES.md`
- `TEST_STRATEGY.md`
- `SECURITY_MODEL.md`
- `DOCS_CANON.md`

MapleWorld is organized around a strict boundary split:

- `msw_runtime/`: MapleStory Worlds runtime-facing gameplay only.
- `shared_rules/`: pure rules, formulas, and balance logic.
- `content_build/`: content compilation and validation outside the live runtime.
- `ai_evolution_offline/`: Codex/GPT-driven generation, mutation, scoring, and selection.
- `offline_ops/`: replay, audit, telemetry, reports, and Codex execution state.

Current policy:

- MSW inside: gameplay only.
- MSW outside: control plane, replay, clustering, architecture evolution, audit, and simulation.
- `server_bootstrap` and the giant bridge are removed rather than preserved.

Current development bias:

- improve the first 10 minutes before broadening content
- remove the current highest-cost player-experience bottleneck before adding new systems
- preserve canon locks, route variance, and economy stability while raising player feel
- treat reports as evidence, not design authority

Run the remaining focused verification with:

```bash
for f in tests/*_test.lua; do lua "$f"; done
```
