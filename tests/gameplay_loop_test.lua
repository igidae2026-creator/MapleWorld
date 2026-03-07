package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')
local world = ServerBootstrap.boot('.')
local player = world:createPlayer('looper')

world.scheduler:tick(5)
local active = world.spawnSystem.maps['henesys_hunting_ground'].active
local spawnId = next(active)
assert(spawnId, 'no mob to hunt')
local drops = world:killMob(player, 'henesys_hunting_ground', spawnId)
assert(type(drops) == 'table', 'hunt did not produce drops table')

player.level = 20
assert(world:changeMap(player, 'forest_edge'), 'boss map change failed')
local encounter = world:spawnBoss('mano')
assert(type(encounter) == 'table' and encounter.alive, 'boss spawn failed')
local bossDrops = nil
for _ = 1, 20 do
    local ok, maybeDrops = world:damageBoss(player, 'forest_edge', 300)
    assert(ok, 'boss damage failed')
    if maybeDrops then bossDrops = maybeDrops break end
end
assert(bossDrops and #bossDrops >= 1, 'boss rare drop loop failed')
assert(player.mesos > 0, 'economy loop did not award mesos')
assert(player.killLog['mano'] == 1, 'boss kill was not recorded')

print('gameplay_loop_test: ok')
