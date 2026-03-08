local TelemetryPipeline = {}

function TelemetryPipeline.new(config)
    return setmetatable({
        events = {},
        counters = {},
        maxEvents = tonumber((config or {}).maxEvents) or 256,
    }, { __index = TelemetryPipeline })
end

function TelemetryPipeline:emit(kind, payload)
    self.events[#self.events + 1] = { kind = kind, payload = payload, at = os.time() }
    self.counters[kind] = (self.counters[kind] or 0) + 1
    while #self.events > self.maxEvents do table.remove(self.events, 1) end
    return self.events[#self.events]
end

function TelemetryPipeline:snapshot()
    return { events = self.events, counters = self.counters }
end

return TelemetryPipeline
