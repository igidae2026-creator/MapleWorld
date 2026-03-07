local TelemetryPipeline = {}

function TelemetryPipeline.new()
    return setmetatable({ events = {} }, { __index = TelemetryPipeline })
end

function TelemetryPipeline:emit(kind, payload)
    self.events[#self.events + 1] = { kind = kind, payload = payload, at = os.time() }
    return self.events[#self.events]
end

return TelemetryPipeline
