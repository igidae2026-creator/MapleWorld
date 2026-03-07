package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.')
local player = world:createPlayer('progression-tester')

player.level = 12
player.sp = 5
player.ap = 10

local ok = world:promoteJob(player, 'warrior')
assert(ok, 'job promotion failed')
ok = world:learnSkill(player, 'power_strike')
assert(ok, 'skill learn failed')
ok = world:allocateStat(player, 'str', 5)
assert(ok, 'stat allocation failed')
local castOk, castPayload = world:castSkill(player, 'power_strike', { defense = 5 })
assert(castOk and castPayload.amount > 0, 'skill cast failed')
world:grantItem(player, 'henesys_bronze_blade', 1)
local equipOk = world:equipItem(player, 'henesys_bronze_blade')
assert(equipOk, 'equip failed')
local enhanceOk, enhancement = world:enhanceEquipment(player, 'weapon')
assert(enhanceOk and enhancement >= 1, 'enhancement failed')
print('progression_systems_test: ok')
