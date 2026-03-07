package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.')
local player = world:createPlayer('skill-tester')
player.level = 25
player.jobId = 'magician'
player.sp = 6
world.skillSystem:ensurePlayer(player)

assert(world:learnSkill(player, 'arcane_bolt'))
assert(world:learnSkill(player, 'comet_grid'))
local ok1, one = world:castSkill(player, 'arcane_bolt', { id = 'mob-1', defense = 4 })
assert(ok1 and one.amount > 0, 'arcane_bolt failed')
local ok2, two = world:castSkill(player, 'comet_grid', { id = 'mob-2', defense = 6 })
assert(ok2 and two.comboChain >= 2, 'skill chain did not build')
assert(two.area == true and two.impactDelay ~= nil, 'aoe skill metadata missing')
print('skill_interactions_test: ok')
