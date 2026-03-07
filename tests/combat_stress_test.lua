package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.')
for i = 1, 48 do
    world:createPlayer('combat-stress-' .. tostring(i))
end

for _ = 1, 12 do
    world.scheduler:tick(5)
    local active = world.spawnSystem.maps['henesys_hunting_ground'].active
    for _, player in pairs(world.players) do
        local spawnId = next(active)
        if spawnId then
            world:killMob(player, 'henesys_hunting_ground', spawnId)
        end
    end
end

world.scheduler:tick(10)

local stability = world:getStabilityReport()
local admin = world:adminStatus()
assert(stability.deterministicReplay.ok == true, 'combat stress replay determinism failed')
assert(stability.performance.entity_count ~= nil, 'combat stress missing entity count')
assert((stability.telemetry.counters.stability_tick or 0) >= 1, 'combat stress missing stability telemetry')
assert(admin.consistent == true, 'combat stress consistency failed')
print('combat_stress_test: ok')
