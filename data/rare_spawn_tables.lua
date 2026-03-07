local regions = {
    'henesys', 'ellinia', 'perion', 'kerning', 'lith_harbor',
    'ant_tunnel', 'sleepywood', 'dungeon', 'forest', 'desert',
}

local mapSuffixes = {
    { suffix = 'fields', cadence = 'steady', bias = 'route_material' },
    { suffix = 'upper_route', cadence = 'volatile', bias = 'vertical_chase' },
    { suffix = 'clash_zone', cadence = 'scheduled', bias = 'party_upgrade' },
}

local RareSpawns = {}

for regionIndex, regionId in ipairs(regions) do
    for tableIndex, entry in ipairs(mapSuffixes) do
        local mapId = regionId .. '_' .. entry.suffix
        local base = ((regionIndex - 1) * 20) + (tableIndex * 2)
        RareSpawns[mapId] = {
            cadence = entry.cadence,
            baselineChance = 0.04 + (regionIndex * 0.003) + (tableIndex * 0.01),
            elite = {
                mobId = string.format('%s_mob_%02d', regionId, math.min(20, base + 1)),
                rewardBias = entry.bias,
                trigger = tableIndex == 3 and 'party_presence' or 'route_streak',
            },
            rares = {
                {
                    mobId = string.format('%s_mob_%02d', regionId, math.min(20, base + 2)),
                    chance = 0.03 + (tableIndex * 0.01),
                    reward = regionId .. '_material_' .. string.format('%02d', math.min(20, 10 + tableIndex + regionIndex)),
                    behavior = tableIndex == 1 and 'rushdown' or tableIndex == 2 and 'telegraph_dash' or 'anchor_push',
                },
                {
                    mobId = string.format('%s_mob_%02d', regionId, math.min(20, base + 3)),
                    chance = 0.02 + (regionIndex * 0.002),
                    reward = tableIndex == 3 and (regionId .. '_artifact_0' .. tostring(math.min(9, tableIndex + 2))) or (regionId .. '_scroll_' .. string.format('%02d', math.min(10, tableIndex + 4))),
                    behavior = tableIndex == 3 and 'captain_pressure' or 'rare_patrol',
                },
            },
        }
    end
end

return RareSpawns
