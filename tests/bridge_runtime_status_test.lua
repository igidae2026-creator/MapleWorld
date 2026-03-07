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

local controlResp = bridge:getControlPlaneReport()
local control = bridge.runtimeAdapter:decodeData(controlResp)
assert(control and control.ok == true and control.data and control.data.runtimeStatus, 'bridge control-plane report missing')

local eventResp = bridge:getEventTruth()
local eventTruth = bridge.runtimeAdapter:decodeData(eventResp)
assert(eventTruth and eventTruth.ok == true and eventTruth.data and eventTruth.data.events ~= nil, 'bridge event truth missing')

local diagnosticsResp = bridge:getBridgeDiagnostics()
local diagnostics = bridge.runtimeAdapter:decodeData(diagnosticsResp)
assert(diagnostics and diagnostics.ok == true and diagnostics.data and diagnostics.data.metrics, 'bridge diagnostics missing')

print('bridge_runtime_status_test: ok')
