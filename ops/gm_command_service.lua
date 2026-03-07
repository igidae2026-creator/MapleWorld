local GMCommandService = {}

function GMCommandService.new(config)
    local self = { world = (config or {}).world }
    setmetatable(self, { __index = GMCommandService })
    return self
end

function GMCommandService:grant(player, itemId, quantity)
    return self.world:grantItem(player, itemId, quantity, nil, 'gm_grant')
end

return GMCommandService
