local RuntimeProfiler = {}

function RuntimeProfiler.new()
    return setmetatable({ samples = {}, timings = {} }, { __index = RuntimeProfiler })
end

function RuntimeProfiler:sample(name, value)
    local current = self.samples[name] or { last = nil, peak = nil }
    current.last = value
    current.peak = current.peak and math.max(current.peak, tonumber(value) or 0) or value
    self.samples[name] = current
    return value
end

function RuntimeProfiler:snapshot()
    local out = {}
    for key, value in pairs(self.samples) do out[key] = value end
    for key, value in pairs(self.timings) do out['timing:' .. tostring(key)] = value end
    return out
end

function RuntimeProfiler:time(name, durationMs)
    local current = self.timings[name] or { last = 0, peak = 0 }
    local normalized = math.max(0, tonumber(durationMs) or 0)
    current.last = normalized
    current.peak = math.max(current.peak or 0, normalized)
    self.timings[name] = current
    return normalized
end

return RuntimeProfiler
