local regions = {
    { id = 'henesys', range = { 1, 24 }, loop = 'introductory hunting, potion sustain, and first-job setup' },
    { id = 'lith_harbor', range = { 8, 28 }, loop = 'trade-heavy progression, route onboarding, and mobility practice' },
    { id = 'ellinia', range = { 18, 42 }, loop = 'vertical casting routes and support-heavy grinds' },
    { id = 'ant_tunnel', range = { 28, 48 }, loop = 'dense cave funnels and attrition-heavy material farming' },
    { id = 'perion', range = { 34, 60 }, loop = 'frontline melee pressure and bruiser gearing' },
    { id = 'sleepywood', range = { 42, 72 }, loop = 'undead control, sustain checks, and support play' },
    { id = 'kerning', range = { 48, 78 }, loop = 'tempo farming, rare-hunt routing, and market-value drops' },
    { id = 'dungeon', range = { 58, 92 }, loop = 'party routing, key-room clears, and miniboss preparation' },
    { id = 'forest', range = { 72, 108 }, loop = 'rare beast hunts, hidden grove routes, and set building' },
    { id = 'desert', range = { 90, 140 }, loop = 'late-game endurance routes, elemental bosses, and raid prep' },
}

local suffixes = { 'town', 'outskirts', 'fields', 'upper_route', 'lower_route', 'grove', 'ruins', 'tunnel', 'dungeon', 'sanctum', 'clash_zone', 'boss' }
local RegionalProgression = {}

for _, region in ipairs(regions) do
    local maps = {}
    for _, suffix in ipairs(suffixes) do
        maps[#maps + 1] = region.id .. '_' .. suffix
    end
    RegionalProgression[region.id] = {
        tier = region.range[2] >= 90 and 'late_game' or region.range[1] >= 50 and 'midgame' or 'early_game',
        recommendedRange = { min = region.range[1], max = region.range[2] },
        primaryLoop = region.loop,
        maps = maps,
        milestoneRewards = {
            { level = region.range[1] + 6, reward = region.id .. '_route_cache', guidance = 'Stabilize your local route and first gear steps.' },
            { level = region.range[1] + 14, reward = region.id .. '_dungeon_pass', guidance = 'Move from open-field farming into structured dungeon loops.' },
            { level = math.min(region.range[2], region.range[1] + 24), reward = region.id .. '_boss_writ', guidance = 'Prepare for miniboss and boss progression.' },
        },
        valuedDrops = {
            region.id .. '_material_05',
            region.id .. '_bronze_blade',
            region.id .. '_artifact_03',
        },
        socialLoop = 'Use party finder, route overlap, and regional boss calls to maintain social density.',
    }
end

return RegionalProgression
