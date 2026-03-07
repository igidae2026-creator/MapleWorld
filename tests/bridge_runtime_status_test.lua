package.path = package.path .. ';./?.lua;../?.lua'
local WorldServerBridge = require('msw.world_server_bridge')

local bridge = WorldServerBridge.new({})
assert(bridge:bootstrap(), 'bridge bootstrap failed')

local statusResp = bridge:getRuntimeStatus()
local status = bridge.runtimeAdapter:decodeData(statusResp)
assert(status and status.ok == true, 'bridge runtime status failed')
assert(status.data and status.data.governance and status.data.recovery, 'bridge runtime status missing control surfaces')

local replayResp = bridge:getReplayStatus()
local replay = bridge.runtimeAdapter:decodeData(replayResp)
assert(replay and replay.ok == true and replay.data and replay.data.recovery, 'bridge replay status missing')

local topologyResp = bridge:getOwnershipTopology()
local topology = bridge.runtimeAdapter:decodeData(topologyResp)
assert(topology and topology.ok == true and topology.data and topology.data.topology, 'bridge topology status missing')

print('bridge_runtime_status_test: ok')
