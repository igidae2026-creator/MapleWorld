# Architecture

MapleWorld is organized as four connected planes.

1. Content plane
   `data/content_registry.lua` generates the canonical content graph. `data/content_loader.lua` attaches validation, indexes, balance tables, and generation seeds. `data/runtime_tables.lua` and `data/world_runtime.lua` project that content graph into runtime-consumable tables and map topology.

2. Gameplay plane
   `scripts/server_bootstrap.lua` is the integration spine. It builds the world, attaches legacy systems, and now wires stat, job, skill, buff, progression, inventory, party, guild, market, crafting, dialogue, event, loot, and anti-abuse services onto the live runtime.

3. Authority and operations plane
   `ops/` handles persistence, replay, control-plane state, cluster routing, sessions, failover, telemetry, audit, exploit scoring, distributed rate limits, and policy evaluation. These modules are reachable from the live world object and surface through admin status and control-plane reports.

4. Runtime binding plane
   `msw/` exposes the authoritative server bridge. The manifest now declares runtime contracts, lifecycle hooks, and the expanded server method surface for gameplay and operations.
