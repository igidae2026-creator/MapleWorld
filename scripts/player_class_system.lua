local PlayerClassSystem = {}

function PlayerClassSystem.new(config)
    local cfg = config or {}
    local self = {
        jobSystem = cfg.jobSystem,
        statSystem = cfg.statSystem,
        buildRecommendationSystem = cfg.buildRecommendationSystem,
    }
    setmetatable(self, { __index = PlayerClassSystem })
    return self
end

function PlayerClassSystem:ensurePlayer(player)
    self.jobSystem:ensurePlayer(player)
    self.statSystem:ensurePlayer(player)
    player.classProfile = player.classProfile or {
        archetype = player.jobId or 'beginner',
        specialization = 'generalist',
        buildFocus = self.buildRecommendationSystem:recommend(player),
    }
    return player.classProfile
end

function PlayerClassSystem:refresh(player)
    local profile = self:ensurePlayer(player)
    profile.archetype = player.jobId or 'beginner'
    profile.buildFocus = self.buildRecommendationSystem:recommend(player)
    return profile
end

function PlayerClassSystem:promote(player, jobId)
    local ok, err = self.jobSystem:promote(player, jobId)
    if not ok then return false, err end
    return true, self:refresh(player)
end

return PlayerClassSystem
