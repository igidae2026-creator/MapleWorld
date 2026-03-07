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
    local topBranch, topScore = 'generalist', -1
    for skillId, row in pairs(player.skills or {}) do
        local branch = row.branch or ((profile.buildFocus.branches and next(profile.buildFocus.branches)) or 'general')
        local score = tonumber(row.level) or 0
        if score > topScore then
            topBranch, topScore = branch, score
        end
        if score == 0 and topScore < 0 then topBranch = branch end
    end
    profile.specialization = topBranch
    return profile
end

function PlayerClassSystem:promote(player, jobId)
    local ok, err = self.jobSystem:promote(player, jobId)
    if not ok then return false, err end
    return true, self:refresh(player)
end

return PlayerClassSystem
