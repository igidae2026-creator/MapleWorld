# Server Architecture

MapleWorld runs as a single-server, single-world MMO runtime.

Core loop:

1. `scripts/server_bootstrap.lua` assembles content, gameplay systems, persistence, metrics, and operator surfaces.
2. Scheduler ticks spawns, bosses, autosave, health, drop expiry, and world-ops batching.
3. Player state, world state, snapshots, replay validation, and event batching stay inside one authoritative runtime.
4. `msw/` exposes the authoritative runtime bridge for in-world server methods.

Robustness inside the single-server model comes from snapshots, replay validation, entity indexing, event batching, and performance counters rather than multi-server expansion.

Key runtime-connected support layers:

- `data/world_runtime.lua` materializes regional progression metadata, rare-spawn tables, map routes, and runtime attach points.
- `ops/memory_guard.lua`, `ops/duplication_guard.lua`, and `ops/inflation_guard.lua` feed live stability reporting rather than static diagnostics only.
- `ops/live_event_controller.lua` and `scripts/world_event_system.lua` drive seasonal, invasion, and world-boss state through one authoritative world tick surface.
