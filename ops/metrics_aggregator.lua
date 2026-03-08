local Aggregator = {}

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

function Aggregator.new()
    return setmetatable({
        counters = {},
        gauges = {},
        last = {},
    }, { __index = Aggregator })
end

function Aggregator:add(name, amount)
    self.counters[name] = (self.counters[name] or 0) + (tonumber(amount) or 0)
    self.last[name] = self.counters[name]
    return self.counters[name]
end

function Aggregator:set(name, value)
    self.gauges[name] = tonumber(value) or value
    self.last[name] = self.gauges[name]
    return self.gauges[name]
end

function Aggregator:recordSection(name, value)
    self.last[name] = deepcopy(value)
    return self.last[name]
end

function Aggregator:snapshot()
    return {
        counters = deepcopy(self.counters),
        gauges = deepcopy(self.gauges),
        last = deepcopy(self.last),
    }
end

function Aggregator:controlSurface(world)
    local routing = world and world.channelRouter and world.channelRouter.latestDecision and world.channelRouter:latestDecision() or nil
    local savePlan = world and world.savePlan or {}
    local economy = world and world.economySystem or {}
    local economyControl = economy and economy.controlReport and economy:controlReport() or {}
    local pressure = world and world.pressure or {}
    local containment = world and world.containment or {}
    local liveops = world and world.liveEventController and world.liveEventController:status() or {}
    local savePolicy = world and world._policySection and world:_policySection('savePolicy') or {}
    local sessionOrchestrator = world and world.sessionOrchestrator or {}
    local runtimeIdentity = world and world.runtimeIdentity or {}
    local summary = {
        tuningPoints = {
            fieldInstancePlayerCap = world and world.worldConfig and world.worldConfig.runtime and world.worldConfig.runtime.maxPlayersPerChannel or nil,
            congestionRoutingThreshold = world and world.channelRouter and world.channelRouter.congestionThreshold or nil,
            saveBatchUrgency = savePlan.urgency,
            rollbackWindowMinutes = savePolicy.rollbackWindowMinutes,
            npcSellRate = economy.npcSellRate,
            suspiciousTransactionMesos = economy.suspiciousTransactionMesos,
        },
        routing = routing,
        economy = {
            sinkPressure = economy.sinkPressure or 0,
            sinks = economy.sinks and next(economy.sinks) ~= nil and deepcopy(economy.sinks) or {},
            faucets = economy.faucets and next(economy.faucets) ~= nil and deepcopy(economy.faucets) or {},
            mutationBoundaries = economyControl.mutationBoundaries or {},
        },
        ownership = {
            worldId = runtimeIdentity.worldId,
            channelId = runtimeIdentity.channelId,
            runtimeInstanceId = runtimeIdentity.runtimeInstanceId,
            routingOwner = 'channel_router',
            economyOwner = 'economy_system',
            authorityEntrypoints = 1,
            pendingTransfers = sessionOrchestrator.pendingTransferCount and sessionOrchestrator:pendingTransferCount() or 0,
        },
        mutationBoundaries = {
            saveBatchUrgency = savePlan.urgency,
            rollbackWindowMinutes = savePolicy.rollbackWindowMinutes,
            recentTransactionCount = economyControl.mutationBoundaries and economyControl.mutationBoundaries.recentTransactionCount or 0,
            correlatedTransactionCount = economyControl.mutationBoundaries and economyControl.mutationBoundaries.correlatedTransactionCount or 0,
            rollbackTaggedCount = economyControl.mutationBoundaries and economyControl.mutationBoundaries.rollbackTaggedCount or 0,
            latestRoutingReason = routing and routing.reason or nil,
        },
        pressure = {
            saveBacklog = pressure.saveBacklog or 0,
            duplicateRisk = pressure.duplicateRiskPressure or 0,
            ownershipConflict = pressure.ownershipConflictPressure or 0,
            rewardInflation = pressure.rewardInflationPressure or 0,
        },
        containment = deepcopy(containment),
        liveops = {
            activeKinds = liveops.activeByKind or {},
        },
    }
    self:recordSection('control_surface', summary)
    return summary
end

return Aggregator
