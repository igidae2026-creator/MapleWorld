package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.')
local player = world:createPlayer('combat-spec')
player.level = 14
player.sp = 6
assert(world:promoteJob(player, 'warrior'))
assert(world:learnSkill(player, 'power_strike'))
local ok, payload = world:castSkill(player, 'power_strike', { id = 'dummy', defense = 4 })
assert(ok, 'skill cast failed')
assert(payload.hits and #payload.hits >= 1, 'expected combat hits')
assert(player.lastCombatFeedback and player.lastCombatFeedback.skillId == 'power_strike', 'missing feedback')
print('combat_logic_test: ok')
