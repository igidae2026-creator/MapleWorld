local ConsistencyValidator = {}

function ConsistencyValidator.new()
    return setmetatable({}, { __index = ConsistencyValidator })
end

function ConsistencyValidator:validateWorld(world)
    local issues = {}
    for playerId, player in pairs(world.players or {}) do
        if player.currentMapId and not world.worldConfig.maps[player.currentMapId] then
            issues[#issues + 1] = 'player_map_missing:' .. tostring(playerId)
        end
    end
    return #issues == 0, issues
end

return ConsistencyValidator
