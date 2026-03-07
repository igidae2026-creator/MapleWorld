package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')
local WorldRepository = require('ops.world_repository')
local PlayerRepository = require('ops.player_repository')

local now = 5000
local worldRepo = WorldRepository.newMemory({})
local playerRepo = PlayerRepository.newMemory({})

local worldA = ServerBootstrap.boot('.', {
    rng = function() return 0 end,
    time = function() return now end,
    worldRepository = worldRepo,
    playerRepository = playerRepo,
})
local player = worldA:createPlayer('p1')
assert(player, 'player create failed')
assert(worldA:spawnBoss('mano', 'forest_edge'), 'spawn boss failed')
assert(worldA:changeMap(player, 'forest_edge', player.currentMapId), 'change map failed')
local ok = worldA:damageBoss(player, 'forest_edge', 'mano', 999)
assert(ok, 'damage boss failed')
assert(worldA:saveWorldState('genesis_test'), 'save world state failed')

local statusA = worldA:getRuntimeStatus()
assert(statusA.recovery ~= nil, 'missing runtime recovery status')
assert(statusA.policy ~= nil and statusA.policy.policyId ~= nil, 'missing policy bundle status')

local worldB = ServerBootstrap.boot('.', {
    rng = function() return 0 end,
    time = function() return now end,
    worldRepository = worldRepo,
    playerRepository = playerRepo,
})
local statusB = worldB:getRuntimeStatus()
assert(statusB.recovery.valid == true, 'recovery not valid after replay restore')
assert((statusB.recovery.checkpointRevision or 0) >= 1, 'checkpoint revision not populated')

local replaced = worldB:replacePolicyBundle({ policyId = 'test.override', policyVersion = '2' })
assert(replaced, 'policy replacement failed')
assert(worldB:getRuntimeStatus().policy.policyId == 'test.override', 'policy replacement not visible')

print('genesis_runtime_upgrade_test: ok')
