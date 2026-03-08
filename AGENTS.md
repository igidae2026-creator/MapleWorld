# MapleWorld Design Agents

The repository is a Codex-native autonomous architecture and operation evolution system for a MapleLand-class MMORPG running under MapleStory Worlds constraints.

Permanent rules:
- Evolve architecture through direct repository modification. Do not stop at static writing, commentary, or docs-only completion.
- Prefer architecture evolution over architecture description.
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
- Keep outputs deterministic, rerunnable, shard-safe, and score-maximizing against the repository rubrics.
