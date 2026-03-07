# MapleWorld

MapleWorld is a world engine, MMO server runtime, and content platform aimed at MapleStory-class progression with stronger authority, replay, and control-plane guarantees.

The repository now ships as an integrated stack:

- `data/`: generated content registry, validation, indexing, balance tables, and category catalogs for maps, mobs, bosses, items, quests, jobs, skills, NPCs, events, and economy.
- `scripts/`: gameplay runtime including combat, jobs, skills, buffs, progression, crafting, social, party, guild, trading, auctions, dialogue, map/world events, loot routing, and anti-abuse hooks.
- `ops/`: world cluster, routing, failover, replay validation, consistency checks, telemetry, profiling, audit, policy evaluation, admin surfaces, and exploit monitoring.
- `msw/`: hardened runtime bridge and component manifest for authoritative server execution.
- `tests/`: invariant-driven Lua tests covering content integrity, gameplay interactions, replay determinism, control-plane integrity, economy, and transfer flows.

Current upper-bound single-server pillars:

- layered maps with route metadata, regional progression tables, and rare spawn tables wired into runtime state
- class/job/stat/skill/equipment progression with party, guild, boss, and economy loops
- deterministic persistence, replay validation, event batching, entity indexing, and operator-visible stability reports
- content density strong enough to support town, field, dungeon, boss, invasion, seasonal, and world-boss play inside one persistent world

Run the suite with:

```bash
for f in tests/*_test.lua; do lua "$f"; done
```

Bootstrap a world in Lua with:

```lua
package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')
local world = ServerBootstrap.boot('.')
local player = world:createPlayer('hero')
```
