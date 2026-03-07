package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')
local PlayerRepository = require('ops.player_repository')
local WorldRepository = require('ops.world_repository')

local now = 16000
local worldRepo = WorldRepository.newMemory({})
local playerRepo = PlayerRepository.newMemory({})

local worldA = ServerBootstrap.boot('.', {
    rng = function() return 0 end,
    time = function() return now end,
    worldRepository = worldRepo,
    playerRepository = playerRepo,
    autoPickupDrops = false,
})
assert(worldA:saveWorldState('replay_invariant_failure'), 'save failed')

worldRepo.state.checkpoint.commit_state.finalized = false

local worldB = ServerBootstrap.boot('.', {
    rng = function() return 0 end,
    time = function() return now end,
    worldRepository = worldRepo,
    playerRepository = playerRepo,
    autoPickupDrops = false,
    allowWorldStateRestoreFailure = true,
})
local status = worldB:getRuntimeStatus()
assert(status.recovery.valid == false, 'replay invariant failure did not fail closed')
assert(status.governance.state == 'replay-only' or status.containment.replayOnly == true, 'replay invariant failure did not enter replay-only containment')

print('replay_invariant_failure_test: ok')
