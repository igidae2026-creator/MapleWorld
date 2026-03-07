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

function AdminTools:replacePolicyBundle(world, bundle)
    if not world or type(world.replacePolicyBundle) ~= 'function' then return false, 'policy_replace_unavailable' end
    local ok, err = world:replacePolicyBundle(bundle)
    if self.metrics then
        if ok then self.metrics:increment('admin.policy_replace', 1) else self.metrics:error('admin_policy_replace_failed', { error = tostring(err) }) end
    end
    return ok, err
end

return AdminTools
