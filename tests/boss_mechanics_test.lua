package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.')
local player = world:createPlayer('boss-runner')
world:changeMap(player, 'henesys_boss', 'henesys_town')
local encounter = assert(world:spawnBoss('henesys_overseer', 'henesys_boss'))
assert(encounter.phase == 1, 'initial phase invalid')
local ok, _, resolved = world.bossSystem:damage('henesys_boss', player, math.floor(encounter.maxHp * 0.4))
assert(ok and resolved.phase >= 2, 'boss phase did not advance')
assert(resolved.currentMechanic ~= nil, 'boss mechanic missing')
print('boss_mechanics_test: ok')
