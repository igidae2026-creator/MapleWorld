local WorldServerBridge = require('msw.world_server_bridge')

local Component = {}
local bridgeField = '__worldServerBridge'
local moduleBridge = nil

local function resolveComponent(explicit)
    if explicit ~= nil then return explicit end
    local ambient = rawget(_G, 'self')
    if ambient ~= nil then return ambient end
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

    if moduleBridge == nil then
        moduleBridge = WorldServerBridge.new({})
    end
    return moduleBridge, nil
end

function Component.dispatch(component, methodName, ...)
    local bridge = Component.ensureBridge(component)
    local fn = bridge and bridge[methodName] or nil
    assert(type(fn) == 'function', 'unknown_bridge_method_' .. tostring(methodName))
    return fn(bridge, ...)
end

return Component
