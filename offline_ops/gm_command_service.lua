local GMCommandService = {}

function GMCommandService.new(config)
    local self = { world = (config or {}).world }
    setmetatable(self, { __index = GMCommandService })
    return self
end

function GMCommandService:grant(player, itemId, quantity)
    return self.world:grantItem(player, itemId, quantity, nil, 'gm_grant')
end

function GMCommandService:grantMesos(player, amount)
    return self.world.economySystem:grantMesos(player, amount, 'gm_grant')
end

function GMCommandService:activateEvent(kind, eventId)
    return self.world.liveEventController:activate(kind, eventId)
end

return GMCommandService
