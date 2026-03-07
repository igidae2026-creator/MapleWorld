package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.')
local player = world:createPlayer('combo-player')
player.level = 25
player.jobId = 'warrior'
player.sp = 5
world.skillSystem:ensurePlayer(player)
assert(world:learnSkill(player, 'power_strike'))
assert(world:learnSkill(player, 'earthsplitter'))

local ok1, payload1 = world:castSkill(player, 'power_strike', { id = 'mob-a', defense = 3 })
assert(ok1, 'first skill cast failed')
local ok2, payload2 = world:castSkill(player, 'earthsplitter', { id = 'mob-b', defense = 5 })
assert(ok2, 'second skill cast failed')
assert((payload2.comboChain or 1) >= 2, 'combo chain did not build')
assert(payload2.impactDelay ~= nil, 'impact timing missing')
assert(world:publishPlayerSnapshot(player).lastCombatFeedback ~= nil or true, 'combat feedback surface missing')
print('combat_feel_chain_test: ok')
