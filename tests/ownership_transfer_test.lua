package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.', {
    autoPickupDrops = false,
    rng = function() return 0 end,
})

local player = world:createPlayer('owner_shift')
assert(player, 'player create failed')

local ok, err = world:transferOwnership('coordinator-b', world.runtimeIdentity.ownerEpoch + 1, {
    reason = 'ownership_rotation',
})
assert(ok, 'ownership transfer failed: ' .. tostring(err))
assert(world.runtimeIdentity.ownerId == 'coordinator-b', 'owner id not updated')
assert(player.runtimeScope.ownerId == 'coordinator-b', 'player owner scope not updated')
assert((world:getRuntimeStatus().artifacts.byKind.ownership_transition or {})[1] ~= nil, 'ownership artifact missing')

print('ownership_transfer_test: ok')
