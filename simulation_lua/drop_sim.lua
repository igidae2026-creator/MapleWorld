local DropSim = {}

function DropSim.run(content)
    local totalDrops = 0
    local totalRareDrops = 0
    local totalKills = 0

    for _, entry in pairs(content.rareSpawns or {}) do
        local baselineChance = tonumber(entry.baselineChance) or 0
        totalKills = totalKills + 20
        totalDrops = totalDrops + math.floor((baselineChance * 20) + 0.5)
        for rareIndex, rare in ipairs(entry.rares or {}) do
            local chance = tonumber(rare.chance) or 0
            local deterministicRoll = (baselineChance * 1000) + (rareIndex * 9)
            if deterministicRoll >= (chance * 1000) then
                totalRareDrops = totalRareDrops + 1
                totalDrops = totalDrops + 1
            end
        end
    end

    return {
        avg_drops_per_kill = totalDrops / math.max(1, totalKills),
        rare_drop_rate_observed = totalRareDrops / math.max(1, totalKills),
    }
end

return DropSim
