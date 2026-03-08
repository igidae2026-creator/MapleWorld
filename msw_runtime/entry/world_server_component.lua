local Runtime = require('msw_runtime.state.gameplay_runtime')

local Component = {}

local function ensureRuntime(component)
    component = component or {}
    local runtime = rawget(component, '__mapleWorldRuntimeState')
    if runtime == nil then
        runtime = Runtime:new()
        rawset(component, '__mapleWorldRuntimeState', runtime)
    end
    return component, runtime
end

local function invoke(component, methodName, ...)
    component, runtime = ensureRuntime(component)
    local method = runtime[methodName]
    assert(type(method) == 'function', 'unknown_runtime_method_' .. tostring(methodName))
    return method(runtime, ...)
end

function Component.dispatch(component, methodName, ...)
    return invoke(component, methodName, ...)
end

return Component
