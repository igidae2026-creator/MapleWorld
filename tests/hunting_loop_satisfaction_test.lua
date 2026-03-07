package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.')
local player = world:createPlayer('hunt-loop')
assert(world:changeMap(player, 'henesys_fields', 'henesys_town'))
world.scheduler:tick(5)
local mapState = world:getMapState('henesys_fields')
assert(mapState.huntPreview.routeCount >= 2, 'route density missing')
assert(mapState.huntPreview.verticality >= 2, 'vertical density missing')
local spawnId = next(world.spawnSystem.maps['henesys_fields'].active)
assert(spawnId, 'no mobs spawned')
world:killMob(player, 'henesys_fields', spawnId)
assert(player.huntingLoop.streak >= 1, 'hunting streak not updated')
assert(player.lastLootFeedback ~= nil, 'loot anticipation missing')
print('hunting_loop_satisfaction_test: ok')
