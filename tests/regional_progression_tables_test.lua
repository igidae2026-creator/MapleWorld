package.path = package.path .. ';./?.lua;../?.lua'

local RegionalProgression = require('data.regional_progression_tables')
local RareSpawns = require('data.rare_spawn_tables')

assert(RegionalProgression.henesys ~= nil, 'henesys progression missing')
assert(RegionalProgression.leafre ~= nil, 'leafre progression missing')
assert(#(RegionalProgression.ludibrium.milestoneRewards or {}) >= 2, 'ludibrium milestones too sparse')
assert(RareSpawns.kerning_fields ~= nil, 'kerning rare spawn table missing')
assert((RareSpawns.leafre_fields.baselineChance or 0) > (RareSpawns.henesys_fields.baselineChance or 0), 'endgame rare chance should exceed starter rare chance')
print('regional_progression_tables_test: ok')
