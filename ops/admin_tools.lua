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

function AdminTools:getReplayStatus(world)
    local status, err = self:getRuntimeStatus(world)
    if not status then return nil, err end
    return {
        recovery = status.recovery,
        health = status.health,
        watermark = status.watermark,
        savePlan = status.savePlan,
    }
end

function AdminTools:getOwnershipTopology(world)
    local status, err = self:getRuntimeStatus(world)
    if not status then return nil, err end
    return {
        ownership = status.ownership,
        topology = status.topology,
    }
end

function AdminTools:getRepairHistory(world)
    local status, err = self:getRuntimeStatus(world)
    if not status then return nil, err end
    return {
        repairs = status.repairs,
        escalation = status.escalation,
        governance = status.governance,
    }
end

function AdminTools:getPolicyVersions(world)
    local status, err = self:getRuntimeStatus(world)
    if not status then return nil, err end
    return {
        active = status.policy,
        version = status.policyVersion,
        history = status.policyHistory,
    }
end

function AdminTools:getCheckpointLineage(world)
    local status, err = self:getRuntimeStatus(world)
    if not status then return nil, err end
    return {
        checkpointLineage = status.health and status.health.checkpointLineage or {},
        replay = status.recovery,
        savePlan = status.savePlan,
    }
end

function AdminTools:getPressureMatrix(world)
    local status, err = self:getRuntimeStatus(world)
    if not status then return nil, err end
    return {
        pressure = status.pressure,
        governance = status.governance,
        containment = status.containment,
    }
end

function AdminTools:getRuntimeHealthSummary(world)
    local status, err = self:getRuntimeStatus(world)
    if not status then return nil, err end
    return {
        runtimeIdentity = status.runtimeIdentity,
        health = status.health,
        governance = status.governance,
        escalation = status.escalation,
        pendingSave = status.pendingSave,
    }
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

function AdminTools:getControlPlaneReport(world)
    local status, err = self:getRuntimeStatus(world)
    if not status then return nil, err end
    return {
        replay = self:getReplayStatus(world),
        checkpointLineage = self:getCheckpointLineage(world),
        ownership = self:getOwnershipTopology(world),
        pressure = self:getPressureMatrix(world),
        policies = self:getPolicyVersions(world),
        repairs = self:getRepairHistory(world),
        artifacts = self:getArtifactLineage(world),
        eventHistory = self:getEventTruth(world, {}),
        health = self:getRuntimeHealthSummary(world),
        runtimeStatus = status,
    }
end

return AdminTools
