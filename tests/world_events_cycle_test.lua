package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.')
local daily = world:activateWorldEvent('daily', 'monster_cleanup')
assert(daily ~= nil, 'daily event missing')
local regional = world:getMapState('henesys_fields').regionalEvent
assert(regional.lootMultiplier >= 1.0, 'regional loot multiplier missing')
print('world_events_cycle_test: ok')
