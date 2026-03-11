# Architecture

MapleWorld is organized as five connected planes with a small canonical documentation set.

System intent lives primarily in:

- `docs/reference/GAME_DESIGN.md`
- `docs/reference/EXECUTION_LOOP.md`
- `docs/reference/QUALITY_GATES.md`

## 1. Content Plane

`content_build/content_registry.lua` generates the canonical content graph.

`content_build/content_loader.lua` attaches validation, indexes, balance tables, and generation seeds.

`data/runtime_tables.lua` remains a consumer-facing table surface, but world runtime ownership no longer lives inside the gameplay boundary.

## 2. Gameplay Plane

`msw_runtime/` is the target gameplay root.

Live gameplay authority stays here:

- event handlers
- player state mutation
- combat resolution
- drops, quests, jobs, and progression entrypoints
- server-authoritative reward mutation

The previous `server_bootstrap` integration spine was removed, so MSW ownership is not routed through a standalone MMO bootstrap.

## 3. Shared Rules Plane

`shared_rules/` contains pure or nearly pure logic that should stay portable across runtime and offline validation:

- formulas
- progression rules
- boss mechanic logic
- balance calculations

This plane should keep growing as gameplay logic is extracted out of temporary runtime-coupled scripts.

## 4. Offline Evaluation Plane

`ai_evolution_offline/`, `simulation_py/`, `simulation_lua/`, and `metrics_engine/` own:

- candidate generation
- simulation
- scoring
- mutation
- selection
- bottleneck evaluation

This plane exists to find and repair the current highest-cost player-experience bottleneck without breaching runtime authority boundaries.

## 5. Authority and Operations Plane

`offline_ops/` owns persistence tooling, replay, codex state, audit summaries, telemetry, and report outputs outside the MSW runtime.

Generated reports inform the loop, but they are not canonical design authority by themselves.

## Architectural Rule

The architecture is not feature-first. It is bottleneck-first.

If a new subsystem, content pass, or refactor does not clearly improve or protect the gates in `docs/reference/QUALITY_GATES.md`, it should not outrank a smaller patch that does.
