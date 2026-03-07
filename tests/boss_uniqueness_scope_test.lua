package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.', {
    autoPickupDrops = false,
    rng = function() return 0 end,
})

world.pressure.ownershipConflictPressure = 99
local encounter, err = world:spawnBoss('mano')
assert(type(encounter) == 'table' and err == nil, 'channel-unique boss should not be throttled by world-unique pressure gate')

print('boss_uniqueness_scope_test: ok')
