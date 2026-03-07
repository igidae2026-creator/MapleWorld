package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')
local PlayerRepository = require('ops.player_repository')
local WorldRepository = require('ops.world_repository')

local currentTime = 2000
local sharedWorldRepo = WorldRepository.newMemory({})
local sharedPlayerRepo = PlayerRepository.newMemory({})

local worldA = ServerBootstrap.boot('.', {
    autoPickupDrops = false,
    rng = function() return 0 end,
    time = function() return currentTime end,
    worldRepository = sharedWorldRepo,
    playerRepository = sharedPlayerRepo,
})
local player = worldA:createPlayer('persisted')
player.level = 25
worldA.scheduler:tick(5)

local spawnId = nil
for id, mob in pairs(worldA.spawnSystem.maps['henesys_hunting_ground'].active) do
    if mob.mobId == 'snail' then spawnId = id break end
end
assert(spawnId, 'no snail available for persistence test')
assert(worldA:attackMob(player, 'henesys_hunting_ground', spawnId, 999), 'persistence mob attack failed')
assert(worldA:changeMap(player, 'forest_edge'), 'persistence boss map change failed')
assert(type(worldA:spawnBoss('mano')) == 'table', 'persistence boss spawn failed')
assert(worldA:damageBoss(player, 'forest_edge', 300), 'persistence boss damage failed')
assert(worldA:saveWorldState('test'), 'world state save failed')

local worldB = ServerBootstrap.boot('.', {
    autoPickupDrops = false,
    rng = function() return 0 end,
    time = function() return currentTime end,
    worldRepository = sharedWorldRepo,
    playerRepository = sharedPlayerRepo,
})
assert(#worldB.dropSystem:listDrops('henesys_hunting_ground') >= 1, 'drops were not restored after restart')
local encounter = worldB.bossSystem:getEncounter('forest_edge')
assert(encounter and encounter.hp < encounter.maxHp, 'boss encounter state was not restored after restart')
local latest = worldB.journal:latest()
assert(latest and latest.event ~= nil, 'event journal was not restored after restart')

print('world_state_persistence_test: ok')
