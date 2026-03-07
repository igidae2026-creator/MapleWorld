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
    player.achievementRewards = player.achievementRewards or {}
    player.achievementRewards[id] = player.achievementRewards[id] or {
        title = id,
        prestige = id == 'raid_clear' and 2 or 1,
    }
    player.dirty = true
    return true
end

return AchievementsSystem
