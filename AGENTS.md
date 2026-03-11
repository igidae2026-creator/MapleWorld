# MapleWorld Design Agents

The repository is a Codex-native autonomous architecture and operation evolution system for a MapleLand-class MMORPG running under MapleStory Worlds constraints.

Permanent rules:
- `GOAL.md` and `METAOS_CONSTITUTION.md` are top authority for repository governance.
- `docs/AUTONOMY_TARGET.md` defines the unattended execution standard for operator involvement and quality preservation.
- The repository governance skeleton is fixed to:
  - `L0  RULE_CARDS`
  - `L1  METAOS_CONSTITUTION`
  - `L2  CHECKLIST_LAYER1_목표조건`
  - `L3  CHECKLIST_LAYER2_모듈책임`
  - `L4  CHECKLIST_LAYER3_REPO매핑`
  - `L5  CHECKLIST_METHOD_패치`
  - `A1  COVERAGE_AUDIT`
  - `A2  CONFLICT_LOG`
- Evolve architecture through direct repository modification. Do not stop at static writing, commentary, or docs-only completion.
- Prefer architecture evolution over architecture description.
- If a top-level governance skeleton exists, extend it instead of creating new lower-level skeleton layers.
- Do not create parallel lightweight governance scaffolds when a higher-order scaffold is the intended target.
- Do not spend cycles on interim documentation frameworks that will be superseded by the top-level governance model.
- When governance needs to grow, push the rule upward into the highest authoritative markdown file first.
- Use MapleStory Worlds-native runtime constraints only.
- Do not introduce an external backend.
- Keep gameplay server-authoritative.
- Define explicit room, world, channel, and instance topology.
- Define explicit save, transaction, replay, and rollback boundaries.
- Define explicit economy control loops, meso velocity control, and sink/faucet pressure.
- Define explicit social density anchors and congestion-routing topology.
- Define explicit live-ops intervention topology and override planes.
- Run repeated self-critique, adversarial testing, simulation, mutation, selection, and repair.
- Reject placeholder-only completion, generic MMORPG boilerplate, and abstract fake-content output.
- Optimize the current highest-cost player-experience bottleneck before broad content expansion.
- Preserve or improve first-session player feel while optimizing architecture and operations.
- Use Python for deterministic JSON, CSV, simulation, scoring, merge, mutation, repair, and progress updates.
- Store the design graph in shard files under `data/design_graph`.
- Use `data/design_graph/index.json` to prevent duplicates and preserve repeated-run safety.
- Never rely on `jq`.

Optimization targets:
- `structure_pipeline_score`
- `asset_throughput_score`
- `live_balance_quality_score`
- `mapleland_similarity_score`
- `overall_efficiency_score`
- `architecture_score`
- `long_term_operation_score`
- `overall_architecture_quality`
- `first_10_minutes`
- `first_hour_retention`
- `day1_return_intent`

Architecture priorities:
- level band bottlenecks
- field ladder progression
- solo vs party progression split
- field competition topology
- social density anchors
- channel and congestion routing
- economy source and sink topology
- meso velocity control
- consumable burn pressure
- rare supply throttling
- boss cadence and lockout topology
- save, transaction, replay, and rollback boundaries
- server-authority event ordering
- anti-bot and anti-macro runtime layers
- live-ops intervention topology
- power curve and replacement pressure
- telemetry and feedback topology

Execution rules:
- Generator-style agents write candidate JSON only.
- Python scripts own critique, adversarial testing, simulation, constraint solving, mutation, selection, scoring, merge, and supervisor decisions.
- Favor concrete runtime topology, operational parameters, and repairable control loops over lore or presentation.
- Prefer bottleneck-first patches over broad feature-first expansion.
- Reject patches that improve structural scores while degrading player-experience gates, route variance, or canon locks.
- If a governance change can live in a top-level authority file, put it there instead of spawning a new subordinate framework.
- Reject governance work that creates replace-soon sub-skeletons beneath an intended top-level skeleton.
- Keep outputs deterministic, rerunnable, shard-safe, and score-maximizing against the repository rubrics.
