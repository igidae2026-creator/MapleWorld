local AchievementsSystem = {}

function AchievementsSystem.new()
    return setmetatable({}, { __index = AchievementsSystem })
end

function AchievementsSystem:ensurePlayer(player)
    player.achievements = player.achievements or {}
    return player
end

function AchievementsSystem:unlock(player, id)
    self:ensurePlayer(player)
    player.achievements[id] = true
    player.dirty = true
    return true
end

return AchievementsSystem
