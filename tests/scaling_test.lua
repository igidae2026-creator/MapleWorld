package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')
local world = ServerBootstrap.boot('.')

for i = 1, 40 do
    world.spawnSystem:registerMap('scale_map_' .. i, {
        { id='snail_' .. i, mobId='snail', maxAlive=12, points={{x=1,y=0},{x=2,y=0},{x=3,y=0}} },
        { id='mush_' .. i, mobId='orange_mushroom', maxAlive=8, points={{x=4,y=0},{x=5,y=0}} },
    })
end

for i = 1, 250 do world:createPlayer('scale_player_' .. i) end

for _ = 1, 10 do
    world.scheduler:tick(5)
    for _, player in pairs(world.players) do
        local active = world.spawnSystem.maps['henesys_hunting_ground'].active
        local spawnId = next(active)
        if spawnId then world:killMob(player, 'henesys_hunting_ground', spawnId) end
    end
end

assert(world.healthcheck:run().ok, 'healthcheck failed under scaling test')
assert(world.spawnSystem:activeCount('scale_map_1', 'snail') <= 12, 'spawn count drifted under scale')
assert(next(world.metrics.counters) ~= nil, 'metrics missing under scale')
print('scaling_test: ok')
