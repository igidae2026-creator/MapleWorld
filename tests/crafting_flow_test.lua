package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.')
local player = world:createPlayer('crafter')
world:grantItem(player, 'henesys_material_01', 4)
local ok, crafted = world:craftItem(player, 'bronze_reforge')
assert(ok, 'craft failed')
assert(crafted.level ~= nil and crafted.mastery ~= nil, 'crafting progression missing')
assert(player.craftingProfile ~= nil and player.craftingProfile.discoveries['henesys_bronze_blade'] == true, 'crafting discoveries missing')
print('crafting_flow_test: ok')
