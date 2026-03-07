package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')
local PlayerRepository = require('ops.player_repository')
local WorldRepository = require('ops.world_repository')

local currentTime = 12000
local worldRepo = WorldRepository.newMemory({})
local playerRepo = PlayerRepository.newMemory({})

local worldA = ServerBootstrap.boot('.', {
    autoPickupDrops = false,
    rng = function() return 0 end,
    time = function() return currentTime end,
    worldRepository = worldRepo,
    playerRepository = playerRepo,
})
local playerA = worldA:createPlayer('scope_picker')
worldA.scheduler:tick(5)
local spawnId = next(worldA.spawnSystem.maps['henesys_hunting_ground'].active)
assert(spawnId, 'spawn missing')
assert(worldA:attackMob(playerA, 'henesys_hunting_ground', spawnId, 999), 'mob kill failed')
local drops = worldA.dropSystem:listDrops('henesys_hunting_ground')
assert(#drops >= 1, 'drop was not created')
local drop = drops[1]
local picked = worldA:pickupDrop(playerA, 'henesys_hunting_ground', drop.dropId)
assert(picked, 'pickup failed')
assert(worldA:saveWorldState('drop_scope_recovery'), 'save failed')

local worldB = ServerBootstrap.boot('.', {
    autoPickupDrops = false,
    rng = function() return 0 end,
    time = function() return currentTime end,
    worldRepository = worldRepo,
    playerRepository = playerRepo,
})
local claimKey = string.format('%s:%s:%s:%s', worldB.runtimeIdentity.worldId, worldB.runtimeIdentity.channelId, worldB.runtimeIdentity.runtimeInstanceId, tostring(drop.dropId))
assert(worldB.recoveryInvariants.claimedDrops[claimKey] == true, 'scoped claim key was not rebuilt')

local crossRuntime = ServerBootstrap.boot('.', {
    autoPickupDrops = false,
    rng = function() return 0 end,
    time = function() return currentTime end,
    worldRepository = WorldRepository.newMemory({}),
    playerRepository = PlayerRepository.newMemory({}),
    worldConfig = {
        runtime = {
            defaultMapId = 'henesys_hunting_ground',
            runtimeInstanceId = 'runtime-other',
            autoPickupDrops = false,
        },
        combat = {},
        actionBoundaries = {},
        actionRateLimits = {},
        maps = {
            henesys_hunting_ground = { spawnPosition = { x = 0, y = 0, z = 0 }, spawnGroups = {} },
        },
        bosses = {},
        drops = {},
        quests = { npcBindings = {} },
    },
})
local playerB = crossRuntime:createPlayer('scope_picker_other')
playerB.currentMapId = 'henesys_hunting_ground'
local ok2, err2 = crossRuntime:pickupDrop(playerB, 'henesys_hunting_ground', 777, {
    dropId = 777,
    mapId = 'henesys_hunting_ground',
    itemId = 'red_potion',
    quantity = 1,
    x = 0,
    y = 0,
    z = 0,
    runtimeInstanceId = 'runtime-main',
    worldId = crossRuntime.runtimeIdentity.worldId,
    channelId = crossRuntime.runtimeIdentity.channelId,
})
assert(ok2 == false and err2 == 'runtime_instance_conflict', 'cross-runtime drop claim was not rejected')

print('drop_scope_recovery_test: ok')
