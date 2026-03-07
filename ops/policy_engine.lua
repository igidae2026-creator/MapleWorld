local PolicyEngine = {}

function PolicyEngine.new(config)
    local self = { thresholds = (config or {}).thresholds or {} }
    setmetatable(self, { __index = PolicyEngine })
    return self
end

function PolicyEngine:evaluate(metrics)
    return {
        safeMode = (metrics and metrics.anomalyScore or 0) >= (self.thresholds.safeMode or 10),
        throttle = (metrics and metrics.channelLoad or 0) >= (self.thresholds.channelLoad or 100),
    }
end

return PolicyEngine
