package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.')
local player = world:createPlayer('class-progression')

player.level = 12
player.sp = 4
player.ap = 8

local ok, profile = world.playerClassSystem:promote(player, 'warrior')
assert(ok, 'promotion failed')
assert(profile.archetype == 'warrior', 'class profile not refreshed')
assert(world:allocateStat(player, 'str', 4), 'stat allocation failed')
assert(world:learnSkill(player, 'power_strike'), 'skill learn failed')
local snapshot = world:publishPlayerSnapshot(player)
assert(snapshot.classProfile.archetype == 'warrior', 'snapshot class profile missing')
print('player_class_progression_test: ok')
