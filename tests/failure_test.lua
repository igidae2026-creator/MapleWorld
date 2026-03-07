package.path = package.path .. ';./?.lua;../?.lua'
local Metrics = require('ops.metrics')
local Scheduler = require('ops.event_scheduler')
local PlayerRepository = require('ops.player_repository')
local ServerBootstrap = require('scripts.server_bootstrap')

local metrics = Metrics.new()
local scheduler = Scheduler.new({ metrics = metrics, maxRunsPerTick = 2 })
local stableRuns = 0
local unstableRuns = 0

scheduler:every('unstable', 1, function()
    unstableRuns = unstableRuns + 1
    if unstableRuns == 1 then error('boom') end
end)
scheduler:every('stable', 1, function() stableRuns = stableRuns + 1 end)

scheduler:tick(1)
scheduler:tick(1)
assert(stableRuns >= 2, 'scheduler stopped after script failure')
assert(unstableRuns >= 2, 'failed job did not continue ticking')
assert(#metrics.logs >= 1, 'scheduler failure was not logged')

local repo = PlayerRepository.newMemory({})
local world = ServerBootstrap.boot('.', { playerRepository = repo })
local player = world:createPlayer('persisted')
assert(world.economySystem:grantMesos(player, 50, 'seed'), 'grant mesos failed')
assert(world:flushDirtyPlayers() >= 1, 'autosave flush failed')

local worldReloaded = ServerBootstrap.boot('.', { playerRepository = repo })
local loaded = worldReloaded:createPlayer('persisted')
assert(loaded.mesos == 50, 'player load after restart failed')

print('failure_test: ok')
