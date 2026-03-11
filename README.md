# MapleWorld

MapleWorld is a Codex-native autonomous game design and implementation repository for a MapleLand-class MMORPG under MapleStory Worlds constraints.

The repository no longer treats every root markdown file as equal authority.

Start with the top authority set:

- `GOAL.md`
- `METAOS_CONSTITUTION.md`
- `RULE_CARDS.jsonl`
- `CHECKLIST_LAYER1_목표조건.md`
- `CHECKLIST_LAYER2_모듈책임.md`
- `CHECKLIST_LAYER3_REPO매핑.md`
- `CHECKLIST_METHOD_패치.md`
- `COVERAGE_AUDIT.csv`
- `CONFLICT_LOG.csv`

Then read the active standards and document map:

- `AGENTS.md`
- `README.md`
- `DOCS_CANON.md`
- `docs/standards/DOCUMENTATION_MAP.md`
- `UNIVERSAL_FINAL_THRESHOLD_BUNDLE.md`
- `docs/standards/AUTONOMY_TARGET.md`
- `docs/standards/KOREAN_PLAYER_FEEL_STANDARD.md`
- `docs/operations/AUTONOMY_STACK.md`

Legacy and session-bound notes were moved under `docs/legacy/` to keep root authority clean.

Active implementation reference documents live under `docs/reference/`.
Cross-cutting standards live under `docs/standards/`.
Cross-cutting guard rails live under `docs/guards/`.

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
- judge gameplay completion from Korean player feel, not only system closure

Run the remaining focused verification with:

```bash
for f in tests/*_test.lua; do lua "$f"; done
```
