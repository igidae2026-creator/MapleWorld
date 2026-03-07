local WorldServerBridge = require('msw.world_server_bridge')

local Component = {}
local bridgeField = '__worldServerBridge'
local function resolveComponent(explicit)
    if explicit ~= nil then return explicit end
    return nil
end

function Component.ensureBridge(component)
    local target = resolveComponent(component)
    if target ~= nil then
        local bridge = rawget(target, bridgeField) or rawget(target, 'serverBridge')
        if bridge == nil then
            bridge = WorldServerBridge.new({ component = target })
            rawset(target, bridgeField, bridge)
            pcall(function() target.serverBridge = bridge end)
        end
        bridge:attachComponent(target)
        return bridge, target
    end

    return nil, nil
end

function Component.dispatch(component, methodName, ...)
    local bridge = Component.ensureBridge(component)
    assert(bridge ~= nil, 'bridge_component_unavailable')
    local fn = bridge and bridge[methodName] or nil
    assert(type(fn) == 'function', 'unknown_bridge_method_' .. tostring(methodName))
    return fn(bridge, ...)
end

return Component
