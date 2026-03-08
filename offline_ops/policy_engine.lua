local PolicyEngine = {}

local function deepcopy(value, seen)
    if type(value) ~= 'table' then return value end
    local visited = seen or {}
    if visited[value] then return visited[value] end
    local copy = {}
    visited[value] = copy
    for k, v in pairs(value) do
        copy[deepcopy(k, visited)] = deepcopy(v, visited)
    end
    return copy
end

function PolicyEngine.new(config)
    local cfg = config or {}
    local self = {
        thresholds = cfg.thresholds or {},
    }
    setmetatable(self, { __index = PolicyEngine })
    return self
end

function PolicyEngine:evaluate(metrics)
    local pressure = metrics and metrics.pressure or {}
    local containment = metrics and metrics.containment or {}
    local savePlan = metrics and metrics.savePlan or {}
    local economy = metrics and metrics.economy or {}
    local routing = metrics and metrics.routing or {}

    local anomalyScore = tonumber(metrics and metrics.anomalyScore) or 0
    local channelLoad = tonumber(metrics and metrics.channelLoad) or 0
    local duplicateRisk = tonumber(pressure.duplicateRiskPressure or pressure.duplicateRisk or 0)
    local rewardInflation = tonumber(pressure.rewardInflationPressure or pressure.rewardInflation or 0)
    local saveBacklog = tonumber(pressure.saveBacklog or pressure.backlog or 0)
    local sinkPressure = tonumber(economy.sinkPressure or 0)
    local routingReason = routing and routing.reason or nil

    local advisories = {}
    if savePlan.urgency == 'immediate' then advisories[#advisories + 1] = 'flush_world_save' end
    if duplicateRisk >= (self.thresholds.duplicateRisk or 2) then advisories[#advisories + 1] = 'audit_duplicate_claims' end
    if rewardInflation >= (self.thresholds.rewardInflation or 8) then advisories[#advisories + 1] = 'tighten_reward_flow' end
    if routingReason == 'least_congested_over_threshold' then advisories[#advisories + 1] = 'rebalance_channel_load' end
    if sinkPressure <= (self.thresholds.lowSinkPressure or 0) then advisories[#advisories + 1] = 'increase_economy_sinks' end

    local weakestPressure = 'stable'
    local pressureCandidates = {
        anomalyScore = anomalyScore,
        duplicateRisk = duplicateRisk,
        rewardInflation = rewardInflation,
        saveBacklog = saveBacklog,
        channelLoad = channelLoad,
    }
    local highestName, highestValue = weakestPressure, -1
    for name, value in pairs(pressureCandidates) do
        if tonumber(value) > highestValue then
            highestName, highestValue = name, tonumber(value)
        end
    end

    return {
        safeMode = containment.safeMode == true or anomalyScore >= (self.thresholds.safeMode or 10),
        throttle = channelLoad >= (self.thresholds.channelLoad or 100) or routingReason == 'least_congested_over_threshold',
        freezeTransfers = containment.migrationBlocked == true or duplicateRisk >= (self.thresholds.freezeTransfers or 3),
        freezeRewards = containment.rewardQuarantine == true or rewardInflation >= (self.thresholds.freezeRewards or 12),
        weakestPressure = highestName,
        advisoryActions = advisories,
        snapshot = deepcopy({
            savePlan = savePlan,
            routing = routing,
            economy = { sinkPressure = sinkPressure },
            pressure = pressure,
        }),
    }
end

return PolicyEngine
