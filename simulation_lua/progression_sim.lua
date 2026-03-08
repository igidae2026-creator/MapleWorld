local ProgressionSim = {}
local LEVEL_CURVE_PATH = 'data/balance/progression/level_curve.csv'

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

local function load_level_curve()
    local curve = {}
    local handle = assert(io.open(LEVEL_CURVE_PATH, 'r'))
    local firstLine = true
    for line in handle:lines() do
        if firstLine then
            firstLine = false
        else
            local level, expRequired = line:match('^(%d+),(%d+)$')
            if level and expRequired then
                curve[tonumber(level)] = tonumber(expRequired)
            end
        end
    end
    handle:close()
    return curve
end

local function threshold_for_level(level, curve)
    local expRequired = curve[level]
    if expRequired then
        -- Normalize the balance-table curve into the compact offline proxy scale.
        return math.max(1, math.floor((expRequired / 4) + 0.5))
    end
    return 220 + (level * 55)
end

function ProgressionSim.run(content)
    local baseExpPerLoop = average_loop_exp(content.regionalProgression)
    local levelCurve = load_level_curve()
    local level = 18
    local targetLevel = 30
    local currentExp = 0
    local levelsGained = 0
    local loops = 0

    while level < targetLevel do
        loops = loops + 1
        currentExp = currentExp + math.floor(baseExpPerLoop + ((loops % 3) * 45))
        local threshold = threshold_for_level(level, levelCurve)
        while currentExp >= threshold and level < targetLevel do
            currentExp = currentExp - threshold
            level = level + 1
            levelsGained = levelsGained + 1
            threshold = threshold_for_level(level, levelCurve)
        end
    end

    return {
        levels_gained = levelsGained,
        exp_per_loop = baseExpPerLoop,
        loops_to_target = loops,
    }
end

return ProgressionSim
