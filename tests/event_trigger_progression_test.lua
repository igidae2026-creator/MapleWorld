package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.')
local player = world:createPlayer('event-runner')
world:activateWorldEvent('weekly', 'boss_rush')
assert(player.rotations.weekly['event:boss_rush'] == true, 'weekly event rotation not marked')
local region = world.worldEventSystem:regional('henesys_fields')
assert(region.bossPressure >= 1, 'event did not affect regional boss pressure')
print('event_trigger_progression_test: ok')
