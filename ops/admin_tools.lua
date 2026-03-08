local AdminTools = {}

function AdminTools.new(config)
    local self = { metrics = (config or {}).metrics, scheduler = (config or {}).scheduler }
    setmetatable(self, { __index = AdminTools })
    return self
end

function AdminTools:broadcast(message)
    if self.metrics then self.metrics:info('admin_broadcast', { message = message }) end
end

function AdminTools:forceSpawn(world, mapId)
    if world and world.spawnSystem then
        if mapId then world.spawnSystem:tickMap(mapId) else world.spawnSystem:tick() end
    end
    if self.metrics then self.metrics:increment('admin.force_spawn', 1, { map = mapId or 'all' }) end
end

function AdminTools:grantItem(world, playerId, itemId, quantity)
    local player = world and world.players and world.players[playerId] or nil
    if not player then return false, 'player_not_found' end
    local ok, err = world.itemSystem:addItem(player, itemId, quantity)
    if ok and self.metrics then self.metrics:increment('admin.grant_item', quantity, { item = itemId }) end
    return ok, err
end

function AdminTools:grantMesos(world, playerId, amount)
    local player = world and world.players and world.players[playerId] or nil
    if not player then return false, 'player_not_found' end
    return world.economySystem:grantMesos(player, amount, 'admin')
end


function AdminTools:getRuntimeStatus(world)
    if not world or type(world.getRuntimeStatus) ~= 'function' then return nil, 'world_status_unavailable' end
    local status = world:getRuntimeStatus()
    if self.metrics then self.metrics:info('admin_runtime_status', { escalation = status.escalation and status.escalation.level or 0 }) end
    return status
end

function AdminTools:getStatusSnapshot(world, prepared)
    local status = prepared and prepared.runtimeStatus or nil
    local err = nil
    if not status then
        status, err = self:getRuntimeStatus(world)
    end
    if not status then return nil, err end
    return {
        runtimeStatus = status,
        replay = {
            recovery = status.recovery,
            health = status.health,
            watermark = status.watermark,
            savePlan = status.savePlan,
        },
        ownership = {
            ownership = status.ownership,
            topology = status.topology,
        },
        repairs = {
            repairs = status.repairs,
            escalation = status.escalation,
            governance = status.governance,
        },
        policies = {
            active = status.policy,
            version = status.policyVersion,
            history = status.policyHistory,
        },
        checkpointLineage = {
            checkpointLineage = status.health and status.health.checkpointLineage or {},
            replay = status.recovery,
            savePlan = status.savePlan,
        },
        pressure = {
            pressure = status.pressure,
            governance = status.governance,
            containment = status.containment,
        },
        health = {
            runtimeIdentity = status.runtimeIdentity,
            health = status.health,
            governance = status.governance,
            escalation = status.escalation,
            pendingSave = status.pendingSave,
        },
    }
end

function AdminTools:getOperatorSnapshot(world, prepared)
    local status, err = self:getRuntimeStatus(world)
    if not status then return nil, err end
    local stability = prepared and prepared.stability or (world and world.getStabilityReport and world:getStabilityReport() or nil)
    local anomalyScore = prepared and prepared.anomalyScore or 0
    if world and world.anomalyScoring and world.pressure and world.exploitMonitor and anomalyScore == 0 then
        anomalyScore = world.anomalyScoring:score({
            duplicateRisk = world.pressure.duplicateRiskPressure or 0,
            replay = world.pressure.replayPressure or 0,
            exploit = #(world.exploitMonitor.incidents or {}),
        })
    end
    local routing = world and world.channelRouter and world.channelRouter.latestDecision and world.channelRouter:latestDecision() or nil
    local policy = prepared and prepared.policy
    if policy == nil and world and world.policyEngine and world.economySystem then
        policy = world.policyEngine:evaluate({
            anomalyScore = anomalyScore,
            channelLoad = world.getActivePlayerCount and world:getActivePlayerCount() or 0,
            pressure = world.pressure,
            containment = world.containment,
            savePlan = world.savePlan,
            economy = world.economySystem:controlReport().observability,
            routing = routing,
        })
    end
    local snapshot = self:getStatusSnapshot(world, { runtimeStatus = status })
    if not snapshot then return nil, 'world_status_unavailable' end
    return {
        runtimeStatus = status,
        stability = stability,
        anomalyScore = anomalyScore,
        policy = policy,
        snapshot = snapshot,
    }
end

function AdminTools:getReplayStatus(world)
    local snapshot, err = self:getStatusSnapshot(world)
    if not snapshot then return nil, err end
    return snapshot.replay
end

function AdminTools:getOwnershipTopology(world)
    local snapshot, err = self:getStatusSnapshot(world)
    if not snapshot then return nil, err end
    return snapshot.ownership
end

function AdminTools:getRepairHistory(world)
    local snapshot, err = self:getStatusSnapshot(world)
    if not snapshot then return nil, err end
    return snapshot.repairs
end

function AdminTools:getPolicyVersions(world)
    local snapshot, err = self:getStatusSnapshot(world)
    if not snapshot then return nil, err end
    return snapshot.policies
end

function AdminTools:getCheckpointLineage(world)
    local snapshot, err = self:getStatusSnapshot(world)
    if not snapshot then return nil, err end
    return snapshot.checkpointLineage
end

function AdminTools:getPressureMatrix(world)
    local snapshot, err = self:getStatusSnapshot(world)
    if not snapshot then return nil, err end
    return snapshot.pressure
end

function AdminTools:getRuntimeHealthSummary(world)
    local snapshot, err = self:getStatusSnapshot(world)
    if not snapshot then return nil, err end
    return snapshot.health
end

function AdminTools:getEventTruth(world, filter)
    if not world or type(world.getEventHistory) ~= 'function' then return nil, 'event_history_unavailable' end
    local entries = world:getEventHistory(filter)
    return {
        total = #entries,
        events = entries,
    }
end

function AdminTools:replacePolicyBundle(world, bundle)
    if not world or type(world.replacePolicyBundle) ~= 'function' then return false, 'policy_replace_unavailable' end
    local ok, err = world:replacePolicyBundle(bundle, {
        adoptionSource = 'admin_tools',
        adoptionReason = bundle and bundle.adoptionReason or 'admin_replace',
        adoptionWindow = 'runtime',
    })
    if self.metrics then
        if ok then self.metrics:increment('admin.policy_replace', 1) else self.metrics:error('admin_policy_replace_failed', { error = tostring(err) }) end
    end
    return ok, err
end

function AdminTools:rollbackPolicyBundle(world, reason)
    if not world or type(world.rollbackPolicyBundle) ~= 'function' then return false, 'policy_rollback_unavailable' end
    return world:rollbackPolicyBundle(reason or 'admin_rollback')
end

function AdminTools:getArtifactLineage(world, kind)
    if not world or type(world.getRuntimeStatus) ~= 'function' then return nil, 'world_status_unavailable' end
    local entries = world.artifacts and world.artifacts.entries or {}
    local out = {}
    for _, artifact in ipairs(entries) do
        if kind == nil or tostring(artifact.kind) == tostring(kind) then
            out[#out + 1] = artifact
        end
    end
    return {
        artifacts = out,
        total = #out,
    }
end

function AdminTools:getControlPlaneReport(world, prepared)
    local operator = prepared and prepared.operator or nil
    local err = nil
    if not operator then
        operator, err = self:getOperatorSnapshot(world)
    end
    if not operator then return nil, err end
    local snapshot = operator.snapshot
    local operatorSurface = world and world.metricsAggregator and world.metricsAggregator.controlSurface and world.metricsAggregator:controlSurface(world) or nil
    return {
        cluster = world and world.cluster or nil,
        shards = world and world.shardRegistry and world.shardRegistry.shards or nil,
        sessions = world and world.sessionOrchestrator and world.sessionOrchestrator.snapshot and world.sessionOrchestrator:snapshot() or nil,
        failover = world and world.failover and world.failover.history or nil,
        audit = world and world.auditLog and world.auditLog.entries or nil,
        telemetry = world and world.telemetryPipeline and world.telemetryPipeline.events or nil,
        metrics = world and world.metricsAggregator and world.metricsAggregator.snapshot and world.metricsAggregator:snapshot() or nil,
        performance = world and world.performanceCounters and world.performanceCounters.snapshot and world.performanceCounters:snapshot() or nil,
        batches = world and world.eventBatcher and { queued = #world.eventBatcher.queue, flushed = #world.eventBatcher.flushed } or nil,
        liveEvents = world and world.liveEventController and world.liveEventController.status and world.liveEventController:status() or nil,
        routing = {
            latestDecision = world and world.channelRouter and world.channelRouter.latestDecision and world.channelRouter:latestDecision() or nil,
        },
        operatorSurface = operatorSurface,
        snapshots = world and world.snapshotManager and world.snapshotManager.summary and world.snapshotManager:summary() or nil,
        stability = operator.stability,
        replay = snapshot.replay,
        checkpointLineage = snapshot.checkpointLineage,
        ownership = snapshot.ownership,
        pressure = snapshot.pressure,
        policies = snapshot.policies,
        repairs = snapshot.repairs,
        artifacts = self:getArtifactLineage(world),
        eventHistory = self:getEventTruth(world, {}),
        health = snapshot.health,
        runtimeStatus = snapshot.runtimeStatus,
    }
end

return AdminTools
