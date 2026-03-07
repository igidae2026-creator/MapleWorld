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

return AdminTools
