package.path = package.path .. ';./?.lua;../?.lua'
local WorldServerBridge = require('msw.world_server_bridge')

local bridge = WorldServerBridge.new({})
assert(bridge:bootstrap(), 'bridge bootstrap failed')
assert(bridge:onUserEnter({ userId = 'event_user', CurrentMapName = 'henesys_hunting_ground' }), 'event user enter failed')

local runtimeEvent = bridge.runtimeAdapter:decodeData(bridge:dispatchRuntimeEvent('loot_boost_started', {
    regionId = 'henesys_region',
    boost = 15,
}))
assert(runtimeEvent and runtimeEvent.ok == true, 'dispatchRuntimeEvent failed')

local actionEvent = bridge.runtimeAdapter:decodeData(bridge:routePlayerAction('event_user', 'manual_ready_check', {
    bossId = 'mano',
}))
assert(actionEvent and actionEvent.ok == true, 'routePlayerAction failed')

local stream = bridge.runtimeAdapter:decodeData(bridge:getEventStream(8))
assert(stream and stream.ok == true, 'getEventStream failed')
assert(type(stream.data.events) == 'table' and #stream.data.events >= 2, 'event stream missing routed events')

local diagnostics = bridge.runtimeAdapter:decodeData(bridge:getBridgeDiagnostics())
assert(diagnostics and diagnostics.ok == true, 'getBridgeDiagnostics failed')
assert(diagnostics.data and diagnostics.data.metrics and diagnostics.data.metrics.routedPlayerActions >= 1, 'diagnostics missing routed player actions')

print('msw_event_routing_test: ok')
