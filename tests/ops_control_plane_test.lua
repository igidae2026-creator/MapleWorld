package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.')
world:createPlayer('ops-a')
world:createPlayer('ops-b')
local status = world:adminStatus()
assert(status.consistent == true, 'world consistency failed')
assert(status.replay.ok == true, 'replay determinism failed')
local control = world:getControlPlaneReport()
assert(control.cluster.worldId == world.runtimeIdentity.worldId, 'cluster mismatch')
assert(control.shards['shard-main'] ~= nil, 'missing shard')
print('ops_control_plane_test: ok')
