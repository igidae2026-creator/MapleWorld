local RuntimeProfiler = {}

function RuntimeProfiler.new()
    return setmetatable({ samples = {} }, { __index = RuntimeProfiler })
end

function RuntimeProfiler:sample(name, value)
    self.samples[name] = value
    return value
end

return RuntimeProfiler
