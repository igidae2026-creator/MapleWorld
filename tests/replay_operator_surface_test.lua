package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')
local PlayerRepository = require('ops.player_repository')
local WorldRepository = require('ops.world_repository')

local now = 15000
local worldRepo = WorldRepository.newMemory({})
local playerRepo = PlayerRepository.newMemory({})

local worldA = ServerBootstrap.boot('.', {
    rng = function() return 0 end,
    time = function() return now end,
    worldRepository = worldRepo,
    playerRepository = playerRepo,
    autoPickupDrops = false,
})
local player = worldA:onPlayerEnter('replay_surface_user', 'forest_edge', { x = 80, y = 0, z = 0 })
assert(player, 'player enter failed')
assert(worldA:saveWorldState('operator_surface'), 'save failed')

local worldB = ServerBootstrap.boot('.', {
    rng = function() return 0 end,
    time = function() return now end,
    worldRepository = worldRepo,
    playerRepository = playerRepo,
    autoPickupDrops = false,
})

local restored = worldB.players.replay_surface_user
assert(restored ~= nil, 'active player checkpoint was not restored')

local status = worldB.adminTools:getRuntimeHealthSummary(worldB)
assert(status.health.recoverySource.source == 'checkpoint_restore', 'recovery source missing')
assert((status.health.replayConfidence or 0) >= 1, 'replay confidence missing')
assert(type(status.health.verificationSummary) == 'table', 'verification summary missing')
assert(type(worldB.adminTools:getCheckpointLineage(worldB).checkpointLineage) == 'table', 'checkpoint lineage missing')
assert(type(worldB.adminTools:getPressureMatrix(worldB).pressure) == 'table', 'pressure matrix missing')

print('replay_operator_surface_test: ok')
