local ProgressionSim = {}

local function average_loop_exp(regionalProgression)
    local total = 0
    local count = 0
    for _, region in pairs(regionalProgression or {}) do
        local range = region.recommendedRange or {}
        local minLevel = tonumber(range.min) or 1
        local maxLevel = tonumber(range.max) or minLevel
        total = total + ((maxLevel - minLevel + 1) * 140)
        count = count + 1
    end
    return total / math.max(1, count)
end

function ProgressionSim.run(content)
    local baseExpPerLoop = average_loop_exp(content.regionalProgression)
    local level = 18
    local targetLevel = 30
    local currentExp = 0
    local levelsGained = 0
    local loops = 0

    while level < targetLevel do
        loops = loops + 1
        currentExp = currentExp + math.floor(baseExpPerLoop + ((loops % 3) * 45))
        local threshold = 220 + (level * 55)
        while currentExp >= threshold and level < targetLevel do
            currentExp = currentExp - threshold
            level = level + 1
            levelsGained = levelsGained + 1
            threshold = 220 + (level * 55)
        end
    end

    return {
        levels_gained = levelsGained,
        exp_per_loop = baseExpPerLoop,
        loops_to_target = loops,
    }
end

return ProgressionSim
