package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')
local WorldConfig = require('data.world_runtime')

local customConfig = {
    runtime = WorldConfig.runtime,
    combat = WorldConfig.combat,
    maps = WorldConfig.maps,
    bosses = WorldConfig.bosses,
    drops = WorldConfig.drops,
    actionRateLimits = {
        mob_attack = { tokens = 2, recharge = 0 },
    },
}

local world = ServerBootstrap.boot('.', {
    worldConfig = customConfig,
    autoPickupDrops = false,
})
local player = world:createPlayer('rate_limited')

world.scheduler:tick(5)
local spawnId = next(world.spawnSystem.maps['henesys_hunting_ground'].active)
assert(spawnId, 'no mob available for action guard test')

assert(world:attackMob(player, 'henesys_hunting_ground', spawnId, 1), 'first guarded attack failed')
assert(world:attackMob(player, 'henesys_hunting_ground', spawnId, 1), 'second guarded attack failed')
local ok, err = world:attackMob(player, 'henesys_hunting_ground', spawnId, 1)
assert(not ok and err == 'rate_limited', 'action guard did not block repeated mob attack')

print('action_guard_test: ok')
