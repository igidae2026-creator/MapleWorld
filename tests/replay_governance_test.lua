package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')
local PlayerRepository = require('ops.player_repository')
local WorldRepository = require('ops.world_repository')

local now = 9100
local worldRepo = WorldRepository.newMemory({})
local playerRepo = PlayerRepository.newMemory({})

local worldA = ServerBootstrap.boot('.', {
    rng = function() return 0 end,
    time = function() return now end,
    worldRepository = worldRepo,
    playerRepository = playerRepo,
    autoPickupDrops = false,
})
local player = worldA:createPlayer('replay_gov_user')
worldA.scheduler:tick(5)
local spawnId = next(worldA.spawnSystem.maps['henesys_hunting_ground'].active)
assert(spawnId, 'missing spawn for replay governance test')
assert(worldA:attackMob(player, 'henesys_hunting_ground', spawnId, 999), 'mob kill failed')
assert(worldA:saveWorldState('replay_governance'), 'checkpoint save failed')

worldRepo.state.materialized_digest = 'tampered-digest'

local worldB = ServerBootstrap.boot('.', {
    rng = function() return 0 end,
    time = function() return now end,
    worldRepository = worldRepo,
    playerRepository = playerRepo,
    autoPickupDrops = false,
})
local status = worldB:getRuntimeStatus()
assert(status.recovery.divergence == true, 'replay divergence was not detected')
assert((status.recovery.divergenceCount or 0) >= 1, 'replay divergence count did not increment')
assert(status.governance.state == 'replay-only' or status.governance.state == 'degraded-safe', 'governance did not enter replay/degraded state')
assert(type(status.repairs.timeline) == 'table' and #status.repairs.timeline >= 1, 'repair timeline was not recorded')
assert(type(status.health.checkpointLineage) == 'table' and #status.health.checkpointLineage >= 1, 'checkpoint lineage missing')

print('replay_governance_test: ok')
