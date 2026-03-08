local Metrics = {}

function Metrics.new()
    local self = { counters = {}, logs = {}, gauges = {}, timers = {} }
    setmetatable(self, { __index = Metrics })
    return self
end

function Metrics:_key(name, tags)
    if not tags then return name end
    local pairsOut = {}
    for k, v in pairs(tags) do pairsOut[#pairsOut + 1] = k .. '=' .. tostring(v) end
    table.sort(pairsOut)
    return name .. '|' .. table.concat(pairsOut, ',')
end

function Metrics:increment(name, value, tags)
    local key = self:_key(name, tags)
    self.counters[key] = (self.counters[key] or 0) + (value or 1)
end

function Metrics:gauge(name, value, tags)
    self.gauges[self:_key(name, tags)] = value
end

function Metrics:time(name, durationMs, tags)
    local key = self:_key(name, tags)
    self.timers[key] = self.timers[key] or {}
    table.insert(self.timers[key], durationMs)
end

function Metrics:info(event, payload)
    table.insert(self.logs, { level = 'info', event = event, payload = payload, at = os.time() })
end

function Metrics:error(event, payload)
    table.insert(self.logs, { level = 'error', event = event, payload = payload, at = os.time() })
end

function Metrics:snapshot()
    return { counters = self.counters, gauges = self.gauges, timers = self.timers, logs = self.logs }
end

return Metrics
