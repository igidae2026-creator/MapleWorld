package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.')
for i = 1, 10 do
    world:createPlayer('ticker-' .. tostring(i))
end
for _ = 1, 3 do
    world.scheduler:tick(10)
end
local status = world:adminStatus()
assert(status.consistent == true, 'consistency failed')
assert(status.performance.entity_count ~= nil, 'entity count missing')
assert(status.batches.flushed >= 0, 'batch metrics missing')
assert(type(status.policy.advisoryActions) == 'table', 'policy advisory actions missing')
assert(status.policy.weakestPressure ~= nil, 'policy weakest pressure missing')
print('server_tick_stability_test: ok')
