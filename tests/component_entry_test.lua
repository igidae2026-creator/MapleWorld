package.path = package.path .. ';./?.lua;../?.lua'
require('msw.world_server_entry')

local previousSelf = rawget(_G, 'self')
local component = {
    Name = 'ServerRuntime',
    Entity = {
        Name = 'server_runtime',
    },
}

_G.self = component
assert(type(OnBeginPlay) == 'function', 'entry OnBeginPlay is missing')
assert(type(GetMapState) == 'function', 'entry GetMapState is missing')

OnBeginPlay()
assert(component.serverBridge ~= nil or component.__worldServerBridge ~= nil, 'entry did not create an explicit bridge instance')
OnUpdate(0)

local bridge = component.serverBridge or component.__worldServerBridge
assert(bridge ~= nil, 'bridge was not retained on the component instance')

local mapState = bridge.runtimeAdapter:decodeData(GetMapState('henesys_hunting_ground'))
assert(mapState.ok, 'entry GetMapState failed')

_G.self = previousSelf
print('component_entry_test: ok')
