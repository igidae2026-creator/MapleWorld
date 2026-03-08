local RuntimeKernel = {}

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

function RuntimeKernel.severityName(level)
    if level >= 4 then return 'replay_restore' end
    if level >= 3 then return 'safe_mode' end
    if level >= 2 then return 'quarantine' end
    if level >= 1 then return 'repair' end
    return 'warning'
end

function RuntimeKernel.ownershipScope(identity, mapId, extra)
    local scope = {
        worldId = identity and identity.worldId or 'world-1',
        channelId = identity and identity.channelId or 'channel-1',
        runtimeInstanceId = identity and identity.runtimeInstanceId or 'runtime-main',
        mapInstanceId = tostring(mapId or 'global') .. '@' .. tostring(identity and identity.runtimeInstanceId or 'runtime-main'),
        ownerId = identity and identity.ownerId or 'default',
        ownerEpoch = identity and identity.ownerEpoch or 0,
        runtimeEpoch = identity and identity.runtimeEpoch or 0,
        coordinatorEpoch = identity and identity.coordinatorEpoch or 0,
    }
    for k, v in pairs(extra or {}) do scope[k] = deepcopy(v) end
    return scope
end

function RuntimeKernel.determineGovernanceState(policy, containment, pressure, instability)
    local governancePolicy = policy and policy.governance or {}
    local replayThreshold = tonumber(governancePolicy.repairReplayThreshold) or math.huge
    local anomalyThreshold = tonumber(governancePolicy.quarantineAnomalyThreshold) or math.huge
    local adaptiveThreshold = tonumber(governancePolicy.adaptiveOwnershipConflictThreshold) or math.huge
    local explorationThreshold = tonumber(governancePolicy.explorationLowDiversityThreshold) or math.huge

    if containment and containment.replayOnly then
        return 'replay-only', 'replay_only_containment'
    end
    if (pressure and pressure.replayPressure or 0) >= replayThreshold then
        return 'replay-only', 'replay_pressure'
    end
    if containment and containment.safeMode then
        return 'degraded-safe', 'safe_mode_containment'
    end
    if tonumber(instability or 0) > 0 then
        return 'degraded-safe', 'instability_pressure'
    end
    if containment and containment.rewardQuarantine then
        return 'quarantine', 'reward_quarantine'
    end
    if (pressure and pressure.duplicateRiskPressure or 0) >= anomalyThreshold then
        return 'quarantine', 'anomaly_pressure'
    end
    if (pressure and pressure.ownershipConflictPressure or 0) >= adaptiveThreshold then
        return 'adaptive', 'ownership_conflict_pressure'
    end
    if (pressure and math.max(tonumber(pressure.lowDiversity or 0), tonumber(pressure.farmRepetitionPressure or 0))) >= explorationThreshold then
        return 'exploration', 'diversity_pressure'
    end
    if containment and containment.persistenceQuarantine then
        return 'repair', 'persistence_quarantine'
    end
    return 'normal', 'pressure_normalized'
end

function RuntimeKernel.computeSavePlan(args)
    local policy = (args and args.policy) or {}
    local pressure = (args and args.pressure) or {}
    local containment = (args and args.containment) or {}
    local pendingCount = math.max(0, math.floor(tonumber(args and args.pendingCount) or 0))
    local mutationDensity = math.max(0, math.floor(tonumber(args and args.mutationDensity) or pendingCount))
    local replayUrgency = math.max(0, math.floor(tonumber(pressure.replayPressure) or 0))
    local backlogThreshold = tonumber(policy.backlogImmediateThreshold) or math.huge
    local mutationThreshold = tonumber(policy.mutationDensityThreshold) or math.huge
    local integrityThreshold = tonumber(policy.integrityCheckpointThreshold) or math.huge
    local replayAnchorThreshold = tonumber(policy.replayAnchorThreshold) or math.huge

    local checkpointClass = 'lightweight_runtime_checkpoint'
    local urgency = 'deferred'
    local reasons = {}

    if containment.persistenceQuarantine or containment.saveQuarantine then
        urgency = 'blocked'
        reasons[#reasons + 1] = 'persistence_quarantine'
    elseif containment.replayOnly or replayUrgency >= replayAnchorThreshold or (policy.immediateWhenReplayPressure == true and replayUrgency > 0) then
        urgency = 'immediate'
        checkpointClass = 'replay_anchor'
        reasons[#reasons + 1] = 'replay_pressure'
    elseif policy.immediateWhenOwnershipConflict == true and (pressure.ownershipConflictPressure or 0) > 0 then
        urgency = 'immediate'
        checkpointClass = 'integrity_checkpoint'
        reasons[#reasons + 1] = 'ownership_conflict'
    elseif pendingCount >= backlogThreshold then
        urgency = 'immediate'
        checkpointClass = 'integrity_checkpoint'
        reasons[#reasons + 1] = 'save_backlog'
    elseif mutationDensity >= mutationThreshold then
        urgency = 'immediate'
        checkpointClass = 'integrity_checkpoint'
        reasons[#reasons + 1] = 'mutation_density'
    elseif mutationDensity >= integrityThreshold then
        checkpointClass = 'integrity_checkpoint'
        reasons[#reasons + 1] = 'integrity_threshold'
    else
        reasons[#reasons + 1] = 'debounce_window'
    end

    local healthScore = 100
    if urgency == 'blocked' then healthScore = healthScore - 60 end
    if checkpointClass == 'integrity_checkpoint' then healthScore = healthScore - 10 end
    if checkpointClass == 'replay_anchor' then healthScore = healthScore - 20 end
    healthScore = healthScore - math.min(30, pendingCount)
    healthScore = healthScore - math.min(10, replayUrgency * 5)

    return {
        urgency = urgency,
        checkpointClass = checkpointClass,
        reasons = reasons,
        healthScore = math.max(0, healthScore),
        mutationDensity = mutationDensity,
        replayUrgency = replayUrgency,
        pendingCount = pendingCount,
    }
end

return RuntimeKernel
