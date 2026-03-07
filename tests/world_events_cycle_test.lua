package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.')
local daily = world:activateWorldEvent('daily', 'monster_cleanup')
assert(daily ~= nil, 'daily event missing')
local invasion = world:activateWorldEvent('invasion', 'shadow_breach')
assert(invasion ~= nil, 'invasion event missing')
local regional = world:getMapState('henesys_fields').regionalEvent
assert(regional.lootMultiplier >= 1.0, 'regional loot multiplier missing')
assert(regional.invasionPressure >= 1, 'regional invasion pressure missing')
print('world_events_cycle_test: ok')
