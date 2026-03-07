package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.', {
    autoPickupDrops = false,
    rng = function() return 0 end,
})

local player = world:createPlayer('event_truth_user')
assert(player, 'player create failed')
world.scheduler:tick(5)
local spawnId = next(world.spawnSystem.maps['henesys_hunting_ground'].active)
assert(spawnId, 'spawn missing')
assert(world:attackMob(player, 'henesys_hunting_ground', spawnId, 999), 'mob kill failed')

local events = world.adminTools:getEventTruth(world, { truthType = 'spawn.kill', playerId = 'event_truth_user' })
assert(events and events.total >= 1, 'typed event truth query returned no events')
assert(events.events[1].payload.truth_type == 'spawn.kill', 'truth type missing from event payload')
assert(events.events[1].payload.policy_version ~= nil, 'policy version missing from event payload')

print('event_truth_test: ok')
