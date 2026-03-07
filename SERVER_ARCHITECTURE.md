# Server Architecture

MapleWorld runs as a single-server, single-world MMO runtime.

Core loop:

1. `scripts/server_bootstrap.lua` assembles content, gameplay systems, persistence, metrics, and operator surfaces.
2. Scheduler ticks spawns, bosses, autosave, health, drop expiry, and world-ops batching.
3. Player state, world state, snapshots, replay validation, and event batching stay inside one authoritative runtime.
4. `msw/` exposes the authoritative runtime bridge for in-world server methods.

Robustness inside the single-server model comes from snapshots, replay validation, entity indexing, event batching, and performance counters rather than multi-server expansion.
