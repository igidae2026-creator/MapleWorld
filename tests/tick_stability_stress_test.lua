package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.')
for i = 1, 36 do
    world:createPlayer('tick-stress-' .. tostring(i))
end

for step = 1, 18 do
    world.scheduler:tick(5)
    if step % 2 == 0 then
        local active = world.spawnSystem.maps['henesys_hunting_ground'].active
        for _, player in pairs(world.players) do
            local spawnId = next(active)
            if spawnId then world:killMob(player, 'henesys_hunting_ground', spawnId) end
        end
    end
end

world.scheduler:tick(10)

local perf = world.performanceCounters:snapshot()
local profiler = world.runtimeProfiler:snapshot()
local stability = world:getStabilityReport()

assert(perf.scheduler_jobs ~= nil, 'tick stress missing scheduler job metric')
assert(perf.exploit_incidents ~= nil, 'tick stress missing exploit incident metric')
assert(profiler['timing:world_ops_tick_ms'] ~= nil, 'tick stress missing world ops timing')
assert(world.eventBatcher.totalFlushed >= 0, 'tick stress missing batch flush accounting')
assert(stability.memory.state ~= nil, 'tick stress missing memory guard state')
assert(stability.deterministicReplay.ok == true, 'tick stress replay determinism failed')
print('tick_stability_stress_test: ok')
