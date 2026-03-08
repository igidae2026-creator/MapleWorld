local PerformanceCounters = {}

function PerformanceCounters.new()
    return setmetatable({ counters = {} }, { __index = PerformanceCounters })
end

function PerformanceCounters:record(name, value)
    self.counters[name] = value
    return value
end

function PerformanceCounters:snapshot()
    local out = {}
    for k, v in pairs(self.counters) do out[k] = v end
    return out
end

return PerformanceCounters
