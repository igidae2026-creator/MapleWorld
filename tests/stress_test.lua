package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')
local world = ServerBootstrap.boot('.')
for i = 1, 100 do world:createPlayer('player_' .. i) end
for _ = 1, 20 do
    world.scheduler:tick(5)
    for _, player in pairs(world.players) do
        local active = world.spawnSystem.maps['henesys_hunting_ground'].active
        local spawnId = next(active)
        if spawnId then world:killMob(player, 'henesys_hunting_ground', spawnId) end
    end
end
local metrics = world.metrics:snapshot()
assert(next(metrics.counters) ~= nil, 'metrics missing under stress')
assert(world.healthcheck:run().ok, 'healthcheck failed after stress')
print('stress_test: ok')
