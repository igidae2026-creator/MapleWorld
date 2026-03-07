package.path = package.path .. ';./?.lua;../?.lua'
require('msw.world_server_entry')

local component = {
    Name = 'ServerRuntime',
    Entity = {
        Name = 'server_runtime',
    },
}

assert(type(OnBeginPlay) == 'function', 'entry OnBeginPlay is missing')
assert(type(GetMapState) == 'function', 'entry GetMapState is missing')
assert(type(GetStateDelta) == 'function', 'entry GetStateDelta is missing')
assert(type(GetBridgeDiagnostics) == 'function', 'entry GetBridgeDiagnostics is missing')
assert(type(ReconcileRuntimeState) == 'function', 'entry ReconcileRuntimeState is missing')
assert(type(OnEndPlay) == 'function', 'entry OnEndPlay is missing')

local okNoComponent = pcall(function() OnBeginPlay() end)
assert(not okNoComponent, 'entry unexpectedly bootstrapped without explicit component')

OnBeginPlay(component)
assert(component.serverBridge ~= nil or component.__worldServerBridge ~= nil, 'entry did not create an explicit bridge instance')
OnUpdate(0, component)

local bridge = component.serverBridge or component.__worldServerBridge
assert(bridge ~= nil, 'bridge was not retained on the component instance')

local mapState = bridge.runtimeAdapter:decodeData(GetMapState('henesys_hunting_ground', nil, component))
assert(mapState.ok, 'entry GetMapState failed')

local diagnostics = bridge.runtimeAdapter:decodeData(GetBridgeDiagnostics(component))
assert(diagnostics.ok, 'entry GetBridgeDiagnostics failed')

local shutdown = bridge.runtimeAdapter:decodeData(OnEndPlay(component))
assert(shutdown.ok, 'entry OnEndPlay failed')

print('component_entry_test: ok')
