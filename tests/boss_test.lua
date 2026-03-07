package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')
local world = ServerBootstrap.boot('.')
local player = world:createPlayer('raider')
local encounter = world.bossSystem:spawnEncounter('mano', 'forest_edge')
assert(encounter.alive, 'boss not alive')
local killed = false
for _ = 1, 20 do
    local ok, drops = world.bossSystem:damage('forest_edge', player, 300)
    assert(ok, 'damage failed')
    if drops then killed = true; assert(#drops >= 1, 'boss should drop loot'); break end
end
assert(killed, 'boss never died')
print('boss_test: ok')
