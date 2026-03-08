package.path = package.path .. ';./?.lua;../?.lua'

local RegionalProgression = require('data.regional_progression_tables')
local RareSpawns = require('data.rare_spawn_tables')

assert(RegionalProgression.henesys ~= nil, 'henesys progression missing')
assert(RegionalProgression.desert ~= nil, 'desert progression missing')
assert(#(RegionalProgression.dungeon.milestoneRewards or {}) >= 2, 'dungeon milestones too sparse')
assert(RareSpawns.kerning_fields ~= nil, 'kerning rare spawn table missing')
assert((RareSpawns.desert_fields.baselineChance or 0) > (RareSpawns.henesys_fields.baselineChance or 0), 'endgame rare chance should exceed starter rare chance')

local previousExp = nil
for line in io.lines('data/balance/progression/level_curve.csv') do
    if not line:match('^level,') then
        local _, exp = line:match('^(%d+),(%d+)$')
        local currentExp = tonumber(exp)
        assert(currentExp ~= nil, 'invalid level curve row')
        if previousExp ~= nil then
            assert(currentExp > previousExp, 'level curve must be strictly increasing')
        end
        previousExp = currentExp
    end
end

print('regional_progression_tables_test: ok')
