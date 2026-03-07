package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.')
local player = world:createPlayer('inventory-check')
world:grantItem(player, 'henesys_bronze_blade', 2)
assert(world.itemSystem:validatePlayerItemTopology(player))
assert(world:equipItem(player, 'henesys_bronze_blade'))
assert(world.itemSystem:validatePlayerItemTopology(player))
assert(player.setBonuses == nil or type(player.setBonuses) == 'table')
print('inventory_integrity_extended_test: ok')
