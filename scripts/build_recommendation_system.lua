local BuildRecommendationSystem = {}

function BuildRecommendationSystem.new(config)
    local cfg = config or {}
    local self = {
        jobs = cfg.jobs or {},
        skills = cfg.skills or {},
    }
    setmetatable(self, { __index = BuildRecommendationSystem })
    return self
end

function BuildRecommendationSystem:recommend(player)
    local jobId = player.jobId or 'beginner'
    local job = self.jobs[jobId] or {}
    local skills = self.skills[jobId] or {}
    local primary = job.primaryStat or 'str'
    local build = {
        role = ({
            warrior = 'tank',
            magician = 'support',
            bowman = 'damage',
            thief = 'damage',
            pirate = 'hybrid',
        })[jobId] or 'adventurer',
        primaryStat = primary,
        suggestedStats = {},
        suggestedSkills = {},
        equipmentFocus = primary == 'int' and 'magic amplification' or 'weapon attack',
        levelingMaps = {},
        milestoneHints = {},
    }
    build.suggestedStats[primary] = 0.7
    for _, stat in ipairs({ 'str', 'dex', 'int', 'luk' }) do
        if stat ~= primary then build.suggestedStats[stat] = 0.1 end
    end
    for _, skill in ipairs(skills) do
        build.suggestedSkills[#build.suggestedSkills + 1] = skill.id
    end
    build.levelingMaps = ({
        beginner = { 'henesys_fields', 'henesys_dungeon' },
        warrior = { 'perion_fields', 'perion_dungeon' },
        magician = { 'ellinia_fields', 'ellinia_dungeon' },
        bowman = { 'henesys_fields', 'ludibrium_fields' },
        thief = { 'kerning_fields', 'kerning_dungeon' },
        pirate = { 'kerning_fields', 'leafre_fields' },
    })[jobId] or { 'henesys_fields', 'ellinia_fields' }
    build.milestoneHints = {
        'Prioritize your primary stat when spending points.',
        'Equip set pieces before chasing isolated raw attack gains.',
        'Move into party and boss content once your route guidance points to dungeon maps.',
    }
    return build
end

return BuildRecommendationSystem
