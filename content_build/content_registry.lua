local RegionalProgression = require('data.regional_progression_tables')
local RareSpawnTables = require('data.rare_spawn_tables')

local function clone(value, seen)
    if type(value) ~= 'table' then return value end
    local visited = seen or {}
    if visited[value] then return visited[value] end
    local copy = {}
    visited[value] = copy
    for k, v in pairs(value) do
        copy[clone(k, visited)] = clone(v, visited)
    end
    return copy
end

local function title(id)
    return (tostring(id):gsub('_(%l)', function(c) return ' ' .. string.upper(c) end):gsub('^%l', string.upper))
end

local regionProfiles = {
    { id = 'henesys', level = 1, tags = { 'forest', 'starter' }, identity = 'sunlit forest roads, beginner traffic, and comfortable route loops', terrain = 'gentle verticality and forgiving platform spacing', social = 'starter parties and potion chatter' },
    { id = 'ellinia', level = 18, tags = { 'magic', 'canopy' }, identity = 'floating canopy lanes and mana-soaked hunting routes', terrain = 'rope-heavy vertical mobility and caster sightlines', social = 'support grouping and scroll trading' },
    { id = 'perion', level = 34, tags = { 'rock', 'warrior' }, identity = 'dusty war-paths, cliffs, and brute-force training grounds', terrain = 'stomp lanes, long knockback ledges, and heavy choke points', social = 'frontliner duos and guild drills' },
    { id = 'kerning', level = 48, tags = { 'urban', 'rogue' }, identity = 'back alleys, sewer ambushes, and high-tempo farming loops', terrain = 'tight vertical cuts and mobility-favored flanks', social = 'market flipping and party finder usage' },
    { id = 'lith_harbor', level = 8, tags = { 'coast', 'trade' }, identity = 'trade docks, pirate landings, and route-connecting ferry hubs', terrain = 'pier jumps and split-level cargo lanes', social = 'trade interaction and onboarding' },
    { id = 'ant_tunnel', level = 28, tags = { 'cave', 'underground' }, identity = 'packed tunnel funnels and pressure-heavy spawn rooms', terrain = 'narrow caverns and layered tunnel branches', social = 'shared grinding and cave boss calls' },
    { id = 'sleepywood', level = 42, tags = { 'undead', 'swamp' }, identity = 'misty ruins, undead pressure, and attrition-heavy hunting', terrain = 'sticky lower routes and elevated safe islands', social = 'support-dependent grinds and quest groups' },
    { id = 'dungeon', level = 58, tags = { 'dungeon', 'ruin' }, identity = 'trap-heavy vaults and progression-gated elite wings', terrain = 'hazard rooms, split pulls, and layered control routes', social = 'structured party routing and miniboss farming' },
    { id = 'forest', level = 72, tags = { 'wildwood', 'beast' }, identity = 'dense wild routes, beast packs, and hidden grove farming', terrain = 'wide foliage platforms and ambush chokepoints', social = 'rare-hunt groups and route racing' },
    { id = 'desert', level = 90, tags = { 'desert', 'elemental' }, identity = 'storm-blasted dunes, elemental ruins, and long-form farm routes', terrain = 'wind lanes, elevation swings, and boss-prep zones', social = 'late-game grouping and high-value chase routes' },
}

local mapTemplates = {
    { suffix = 'town', levelOffset = 0, layer = 'town', role = 'hub', hooks = { 'daily_board', 'shop_services' }, routes = { 'market loop', 'quest board circle', 'storage sprint' }, vertical = { 'street', 'roof', 'lookout' }, choke = { 'front gate', 'storage bridge' }, mobility = { 'roof ladder', 'side stair' } },
    { suffix = 'outskirts', levelOffset = 2, layer = 'field', role = 'starter route', hooks = { 'route_warmup', 'ambient_spawns' }, routes = { 'entry sweep', 'side path loop', 'safe ladder reset' }, vertical = { 'low lane', 'branch lane', 'upper shelf' }, choke = { 'entry ramp', 'branch split' }, mobility = { 'upper branch', 'rope perch' } },
    { suffix = 'fields', levelOffset = 4, layer = 'field', role = 'core grind', hooks = { 'ambient_spawns', 'route_bonus' }, routes = { 'clockwise sweep', 'counter sweep', 'drop recovery lane' }, vertical = { 'ground', 'mid platform', 'high branch' }, choke = { 'center fork', 'rope landing' }, mobility = { 'ranged overlook', 'upper branch' } },
    { suffix = 'upper_route', levelOffset = 7, layer = 'vertical', role = 'vertical burst route', hooks = { 'rare_patrol', 'route_bonus' }, routes = { 'rope chain sprint', 'top loop', 'elite intercept' }, vertical = { 'lower rope', 'middle perch', 'top ledge', 'far platform' }, choke = { 'top bridge', 'rope mouth' }, mobility = { 'top ledge', 'far platform' } },
    { suffix = 'lower_route', levelOffset = 6, layer = 'field_low', role = 'ground pressure route', hooks = { 'dense_pull', 'loot_rush' }, routes = { 'ground drag', 'pit clear', 'return tunnel' }, vertical = { 'ground trench', 'mid step', 'return ramp' }, choke = { 'pit entry', 'ground bend' }, mobility = { 'return ramp', 'side root' } },
    { suffix = 'grove', levelOffset = 9, layer = 'hidden', role = 'rare hunt', hooks = { 'hidden_encounter', 'rare_spawn' }, routes = { 'hidden circuit', 'elite shelf jump', 'rare reset line' }, vertical = { 'grove floor', 'canopy shelf', 'secret overlook' }, choke = { 'grove gate', 'shelf cut' }, mobility = { 'secret overlook', 'vine jump' } },
    { suffix = 'ruins', levelOffset = 11, layer = 'ruin', role = 'elite farm', hooks = { 'elite_rotation', 'quest_pulse' }, routes = { 'ruin sweep', 'altar pull', 'drop beam return' }, vertical = { 'broken floor', 'altar ring', 'wall top' }, choke = { 'altar stairs', 'collapsed hall' }, mobility = { 'wall top', 'altar ring' } },
    { suffix = 'tunnel', levelOffset = 12, layer = 'cave', role = 'dense funnel', hooks = { 'funnel_pressure', 'mini_event' }, routes = { 'left bore', 'right bore', 'center collapse loop' }, vertical = { 'lower tunnel', 'mid shelf', 'collapse ridge' }, choke = { 'tunnel mouth', 'collapse ridge' }, mobility = { 'collapse ridge', 'shelf skip' } },
    { suffix = 'dungeon', levelOffset = 15, layer = 'dungeon', role = 'party dungeon', hooks = { 'elite_rotation', 'party_hunt' }, routes = { 'hall clear', 'key room cycle', 'escort return' }, vertical = { 'entry floor', 'mid cell', 'warden perch' }, choke = { 'cell block', 'warden stairs' }, mobility = { 'warden perch', 'cell top' } },
    { suffix = 'sanctum', levelOffset = 18, layer = 'sanctum', role = 'boss prep', hooks = { 'boss_signal', 'crafting_pulse' }, routes = { 'prep circuit', 'elite warmup', 'boss gate hold' }, vertical = { 'sanctum floor', 'side balcony', 'ritual crown' }, choke = { 'boss gate', 'ritual steps' }, mobility = { 'balcony arc', 'ritual crown' } },
    { suffix = 'clash_zone', levelOffset = 20, layer = 'clash', role = 'shared farming zone', hooks = { 'invasion_route', 'world_notice', 'party_hunt' }, routes = { 'defense sweep', 'boss intercept lane', 'loot beacon return' }, vertical = { 'frontline', 'mid barricade', 'rear high ground' }, choke = { 'front gate', 'mid barricade' }, mobility = { 'rear high ground', 'signal tower' } },
    { suffix = 'boss', levelOffset = 24, layer = 'boss', role = 'boss arena', hooks = { 'boss_mechanics', 'world_notice' }, routes = { 'arena ring', 'safe ledge reset', 'burst window rotate' }, vertical = { 'arena floor', 'hazard rim', 'safe ledge' }, choke = { 'arena center', 'hazard rim' }, mobility = { 'safe ledge', 'reset lane' } },
}

local mapTemplatesBySuffix = {}
for _, template in ipairs(mapTemplates) do
    mapTemplatesBySuffix[template.suffix] = template
end

local regionEconomyOrder = {}
do
    local sortedRegions = clone(regionProfiles)
    table.sort(sortedRegions, function(a, b)
        if a.level == b.level then
            return a.id < b.id
        end
        return a.level < b.level
    end)
    for order, region in ipairs(sortedRegions) do
        regionEconomyOrder[region.id] = order
    end
end

local function regionMapSuffix(regionId, mapId)
    local prefix = regionId .. '_'
    if mapId:sub(1, #prefix) ~= prefix then
        return nil
    end
    return mapId:sub(#prefix + 1)
end

local npcRoles = {
    { suffix = 'guide', services = { 'quest', 'travel', 'daily' }, tone = 'guide the leveling route and region identity' },
    { suffix = 'merchant', services = { 'shop', 'economy' }, tone = 'explain pricing, local loot, and regional trade' },
    { suffix = 'smith', services = { 'crafting', 'enhancement' }, tone = 'explain gear progression and set bonuses' },
    { suffix = 'quartermaster', services = { 'quest', 'supply' }, tone = 'push players into combat loops and weekly boards' },
    { suffix = 'scout', services = { 'quest', 'warning' }, tone = 'warn about rare mobs and invasion pressure' },
    { suffix = 'scholar', services = { 'lore', 'quest' }, tone = 'provide regional lore and hidden encounter hints' },
    { suffix = 'ranger', services = { 'route', 'quest' }, tone = 'describe farming routes and mobility zones' },
    { suffix = 'captain', services = { 'party', 'boss' }, tone = 'explain party play and boss preparation' },
    { suffix = 'collector', services = { 'quest', 'crafting' }, tone = 'request materials and explain item value' },
    { suffix = 'healer', services = { 'shop', 'support' }, tone = 'reinforce sustain loops and support play' },
    { suffix = 'broker', services = { 'economy', 'auction' }, tone = 'explain auction house and rarity value' },
    { suffix = 'warden', services = { 'warning', 'quest' }, tone = 'warn about minibosses and dangerous routes' },
    { suffix = 'historian', services = { 'lore', 'exploration' }, tone = 'give exploration context and hidden route guidance' },
    { suffix = 'artisan', services = { 'crafting', 'economy' }, tone = 'connect drops, materials, and market demand' },
    { suffix = 'veteran', services = { 'boss', 'late_game' }, tone = 'teach high-pressure fights and long-term goals' },
}

local mobArchetypes = {
    { key = 'crawler', family = 'snail_variants', role = 'swarm', pattern = 'scuttle_nip', reaction = 'light_flinch' },
    { key = 'shellling', family = 'snail_variants', role = 'swarm', pattern = 'slide_bite', reaction = 'light_flinch' },
    { key = 'sporeling', family = 'mushroom_variants', role = 'swarm', pattern = 'hop_spore', reaction = 'light_flinch' },
    { key = 'fungal_guard', family = 'mushroom_variants', role = 'elite', pattern = 'spore_burst', reaction = 'heavy_stagger' },
    { key = 'twig_stalker', family = 'forest_creatures', role = 'swarm', pattern = 'ambush_slash', reaction = 'light_flinch' },
    { key = 'thorn_howler', family = 'forest_creatures', role = 'elite', pattern = 'line_roar', reaction = 'heavy_stagger' },
    { key = 'grave_sentry', family = 'undead', role = 'swarm', pattern = 'bone_throw', reaction = 'light_flinch' },
    { key = 'wraith_lancer', family = 'undead', role = 'elite', pattern = 'phase_thrust', reaction = 'heavy_recoil' },
    { key = 'sand_beast', family = 'beasts', role = 'swarm', pattern = 'rush_bite', reaction = 'light_flinch' },
    { key = 'dune_alpha', family = 'beasts', role = 'captain', pattern = 'pack_howl', reaction = 'heavy_recoil' },
    { key = 'ember_sprite', family = 'elementals', role = 'swarm', pattern = 'spark_arc', reaction = 'light_flinch' },
    { key = 'storm_wisp', family = 'elementals', role = 'elite', pattern = 'charged_lane', reaction = 'heavy_stagger' },
    { key = 'vault_golem', family = 'dungeon_monsters', role = 'elite', pattern = 'slam_wall', reaction = 'heavy_stagger' },
    { key = 'chain_keeper', family = 'dungeon_monsters', role = 'captain', pattern = 'hook_drag', reaction = 'heavy_recoil' },
    { key = 'elite_hunter', family = 'elite_variants', role = 'elite', pattern = 'route_break', reaction = 'heavy_recoil' },
    { key = 'elite_bruiser', family = 'elite_variants', role = 'elite', pattern = 'ground_crush', reaction = 'heavy_stagger' },
    { key = 'rare_marauder', family = 'rare_variants', role = 'captain', pattern = 'telegraph_dash', reaction = 'heavy_recoil' },
    { key = 'rare_oracle', family = 'rare_variants', role = 'captain', pattern = 'zone_mark', reaction = 'heavy_recoil' },
    { key = 'guardian', family = 'regional_guard', role = 'elite', pattern = 'shield_pulse', reaction = 'heavy_stagger' },
    { key = 'champion', family = 'regional_guard', role = 'captain', pattern = 'phase_burst', reaction = 'heavy_recoil' },
}

local equipmentBases = {
    { id = 'bronze_blade', type = 'weapon', attack = 10, defense = 0, rarity = 'common' },
    { id = 'maple_staff', type = 'weapon', attack = 8, defense = 1, rarity = 'common' },
    { id = 'shadow_claw', type = 'weapon', attack = 9, defense = 0, rarity = 'common' },
    { id = 'wind_bow', type = 'weapon', attack = 9, defense = 0, rarity = 'common' },
    { id = 'cannon_knuckle', type = 'weapon', attack = 10, defense = 0, rarity = 'common' },
    { id = 'field_mail', type = 'overall', attack = 0, defense = 6, rarity = 'common' },
    { id = 'scout_hat', type = 'hat', attack = 0, defense = 4, rarity = 'common' },
    { id = 'traveler_gloves', type = 'glove', attack = 1, defense = 2, rarity = 'common' },
    { id = 'wanderer_boots', type = 'shoe', attack = 0, defense = 3, rarity = 'common' },
    { id = 'hero_charm', type = 'accessory', attack = 2, defense = 2, rarity = 'uncommon' },
    { id = 'guard_shield', type = 'accessory', attack = 0, defense = 4, rarity = 'uncommon' },
    { id = 'storm_pendant', type = 'accessory', attack = 3, defense = 1, rarity = 'uncommon' },
    { id = 'warden_plate', type = 'overall', attack = 0, defense = 8, rarity = 'uncommon' },
    { id = 'ritual_cap', type = 'hat', attack = 1, defense = 5, rarity = 'uncommon' },
    { id = 'hunter_wraps', type = 'glove', attack = 2, defense = 2, rarity = 'uncommon' },
    { id = 'pathrunner_boots', type = 'shoe', attack = 0, defense = 4, rarity = 'uncommon' },
    { id = 'sentinel_blade', type = 'weapon', attack = 12, defense = 0, rarity = 'rare' },
    { id = 'oracle_orb', type = 'weapon', attack = 11, defense = 2, rarity = 'rare' },
    { id = 'captain_emblem', type = 'accessory', attack = 3, defense = 3, rarity = 'rare' },
    { id = 'region_crest', type = 'accessory', attack = 4, defense = 2, rarity = 'rare' },
}

local materialBases = {
    'material_01', 'material_02', 'material_03', 'material_04', 'material_05',
    'material_06', 'material_07', 'material_08', 'material_09', 'material_10',
    'material_11', 'material_12', 'material_13', 'material_14', 'material_15',
    'material_16', 'material_17', 'material_18', 'material_19', 'material_20',
}

local artifactBases = {
    'artifact_01', 'artifact_02', 'artifact_03', 'artifact_04', 'artifact_05',
    'artifact_06', 'artifact_07', 'artifact_08', 'artifact_09', 'artifact_10',
}

local consumableBases = {
    { id = 'potion_01', name = 'Route Potion', price = 30 },
    { id = 'potion_02', name = 'Field Potion', price = 60 },
    { id = 'potion_03', name = 'Dungeon Potion', price = 120 },
    { id = 'potion_04', name = 'Boss Potion', price = 260 },
    { id = 'elixir_01', name = 'Mana Draft', price = 90 },
    { id = 'elixir_02', name = 'Focus Draft', price = 140 },
    { id = 'elixir_03', name = 'Guard Draft', price = 200 },
    { id = 'tonic_01', name = 'Route Tonic', price = 75 },
    { id = 'tonic_02', name = 'Party Tonic', price = 150 },
    { id = 'tonic_03', name = 'Raid Tonic', price = 300 },
}

local scrollBases = {
    'scroll_01', 'scroll_02', 'scroll_03', 'scroll_04', 'scroll_05',
    'scroll_06', 'scroll_07', 'scroll_08', 'scroll_09', 'scroll_10',
}

local relicBases = {
    'relic_01', 'relic_02', 'relic_03', 'relic_04', 'relic_05',
    'relic_06', 'relic_07', 'relic_08', 'relic_09', 'relic_10',
}

local registry = {
    maps = {},
    mobs = {},
    bosses = {},
    items = {},
    quests = {},
    npcs = {},
    jobs = {
        beginner = { track = 'explorer', primaryStat = 'str', secondaryStat = 'dex', hpGrowth = 18, mpGrowth = 8, branches = { 'warrior', 'magician', 'bowman', 'thief', 'pirate' } },
        warrior = { track = 'explorer', primaryStat = 'str', secondaryStat = 'dex', hpGrowth = 30, mpGrowth = 6, branches = { 'crusader', 'dragon_knight' } },
        magician = { track = 'explorer', primaryStat = 'int', secondaryStat = 'luk', hpGrowth = 14, mpGrowth = 24, branches = { 'cleric', 'wizard_ice', 'wizard_fire' } },
        bowman = { track = 'explorer', primaryStat = 'dex', secondaryStat = 'str', hpGrowth = 20, mpGrowth = 10, branches = { 'hunter', 'crossbowman' } },
        thief = { track = 'explorer', primaryStat = 'luk', secondaryStat = 'dex', hpGrowth = 18, mpGrowth = 10, branches = { 'assassin', 'bandit' } },
        pirate = { track = 'explorer', primaryStat = 'dex', secondaryStat = 'str', hpGrowth = 24, mpGrowth = 12, branches = { 'brawler', 'gunslinger' } },
    },
    skills = {},
    dialogues = {},
    drop_tables = {},
    economy = {
        auctionFeeRate = 0.04,
        tradeTaxRate = 0.02,
        craftingFeeRate = 0.01,
        mesosSoftCaps = { daily = 25000000, weekly = 125000000 },
    },
    events = {
        daily = { patrol_rotation = { cadence = 'daily', rewardPoints = 120 }, route_cleanup = { cadence = 'daily', rewardPoints = 150 } },
        weekly = { boss_rush = { cadence = 'weekly', rewardPoints = 900 }, guild_supply = { cadence = 'weekly', rewardPoints = 750 } },
        seasonal = { lantern_festival = { cadence = 'seasonal', rewardPoints = 1400, buff = 'bonus_loot' }, harvest_storm = { cadence = 'seasonal', rewardPoints = 1600, buff = 'rare_spawn' } },
        invasion = { shadow_breach = { cadence = 'world_rotation', rewardPoints = 1800, pressure = 'elite_swarm' }, dragon_descent = { cadence = 'world_rotation', rewardPoints = 2200, pressure = 'boss_route' } },
        world_boss = { clockwork_colossus = { cadence = 'scheduled', rewardPoints = 3200, map = 'dungeon_boss' }, sky_tyrant = { cadence = 'scheduled', rewardPoints = 3600, map = 'desert_boss' } },
    },
}

registry.skills.beginner = {
    { id = 'shell_throw', type = 'damage', ratio = 1.05, mpCost = 3, cooldown = 0, target = 'mob', unlock = 1, role = 'damage', visual = 'shell_arc', aoeCount = 1, branch = 'starter', style = 'steady', impactDelay = 0.1 },
    { id = 'second_wind', type = 'buff', stat = 'attack', amount = 4, duration = 20, mpCost = 6, cooldown = 25, unlock = 5, role = 'support', visual = 'wind_aura', branch = 'starter', style = 'tempo', impactDelay = 0.18 },
    { id = 'adventurers_drive', type = 'damage', ratio = 1.24, mpCost = 5, cooldown = 8, target = 'mob', unlock = 7, role = 'hybrid', visual = 'forward_dash', aoeCount = 2, branch = 'tempo', style = 'mobility', impactDelay = 0.08 },
}
registry.skills.warrior = {
    { id = 'power_strike', type = 'damage', ratio = 1.65, mpCost = 8, cooldown = 0, target = 'mob', unlock = 10, role = 'tank', visual = 'heavy_slash', aoeCount = 2, statusEffect = 'armor_break', branch = 'vanguard', style = 'impact', impactDelay = 0.18 },
    { id = 'guard_up', type = 'buff', stat = 'defense', amount = 18, duration = 30, mpCost = 10, cooldown = 35, unlock = 12, role = 'tank', visual = 'shield_bloom', branch = 'bulwark', style = 'guard', impactDelay = 0.2 },
    { id = 'earthsplitter', type = 'damage', ratio = 1.88, mpCost = 15, cooldown = 12, target = 'mob', unlock = 18, role = 'tank', visual = 'earth_crack', aoeCount = 3, statusEffect = 'stagger', branch = 'vanguard', style = 'burst', impactDelay = 0.24 },
}
registry.skills.magician = {
    { id = 'arcane_bolt', type = 'damage', ratio = 1.85, mpCost = 12, cooldown = 0, target = 'mob', unlock = 10, role = 'support', visual = 'arcane_burst', aoeCount = 3, statusEffect = 'slow', branch = 'arcane', style = 'sustain', impactDelay = 0.16 },
    { id = 'mana_barrier', type = 'buff', stat = 'damageReduction', amount = 0.12, duration = 30, mpCost = 16, cooldown = 45, unlock = 14, role = 'support', visual = 'mana_shell', branch = 'support', style = 'guard', impactDelay = 0.18 },
    { id = 'comet_grid', type = 'damage', ratio = 2.05, mpCost = 20, cooldown = 14, target = 'mob', unlock = 20, role = 'support', visual = 'comet_grid', aoeCount = 4, statusEffect = 'slow', branch = 'arcane', style = 'zone_control', impactDelay = 0.28 },
}
registry.skills.bowman = {
    { id = 'double_shot', type = 'damage', ratio = 1.55, mpCost = 8, cooldown = 0, target = 'mob', unlock = 10, role = 'damage', visual = 'arrow_fan', aoeCount = 2, branch = 'marksman', style = 'tempo', impactDelay = 0.1 },
    { id = 'focus', type = 'buff', stat = 'critRate', amount = 0.1, duration = 35, mpCost = 12, cooldown = 40, unlock = 12, role = 'damage', visual = 'focus_ring', branch = 'marksman', style = 'setup', impactDelay = 0.12 },
    { id = 'piercing_volley', type = 'damage', ratio = 1.92, mpCost = 16, cooldown = 10, target = 'mob', unlock = 18, role = 'damage', visual = 'piercing_volley', aoeCount = 3, branch = 'ranger', style = 'lane_clear', impactDelay = 0.14 },
}
registry.skills.thief = {
    { id = 'lucky_seven', type = 'damage', ratio = 1.7, mpCost = 9, cooldown = 0, target = 'mob', unlock = 10, role = 'damage', visual = 'shadow_fork', aoeCount = 2, statusEffect = 'bleed', branch = 'assassin', style = 'burst', impactDelay = 0.09 },
    { id = 'smoke_dash', type = 'buff', stat = 'evasion', amount = 0.15, duration = 20, mpCost = 14, cooldown = 40, unlock = 12, role = 'damage', visual = 'smoke_trail', branch = 'trickster', style = 'mobility', impactDelay = 0.08 },
    { id = 'shadow_link', type = 'damage', ratio = 1.86, mpCost = 15, cooldown = 9, target = 'mob', unlock = 18, role = 'damage', visual = 'shadow_link', aoeCount = 3, statusEffect = 'bleed', branch = 'assassin', style = 'chain', impactDelay = 0.1 },
}
registry.skills.pirate = {
    { id = 'knuckle_burst', type = 'damage', ratio = 1.6, mpCost = 9, cooldown = 0, target = 'mob', unlock = 10, role = 'hybrid', visual = 'cannon_knuckle', aoeCount = 2, statusEffect = 'stun', branch = 'brawler', style = 'impact', impactDelay = 0.12 },
    { id = 'deck_swab', type = 'buff', stat = 'attackSpeed', amount = 1, duration = 18, mpCost = 12, cooldown = 36, unlock = 12, role = 'hybrid', visual = 'tempo_boost', branch = 'gunslinger', style = 'tempo', impactDelay = 0.1 },
    { id = 'broadside_step', type = 'damage', ratio = 1.82, mpCost = 15, cooldown = 11, target = 'mob', unlock = 19, role = 'hybrid', visual = 'broadside_step', aoeCount = 3, statusEffect = 'stun', branch = 'gunslinger', style = 'mobility', impactDelay = 0.11 },
}

local function addItem(item)
    registry.items[item.item_id] = item
end

local function addDialogue(npcId, greeting, tone, regionName)
    registry.dialogues[npcId .. '_dialogue'] = {
        npc_id = npcId,
        greeting = greeting,
        personality = tone,
        nodes = {
            start = {
                text = greeting,
                options = {
                    { id = 'quests', label = 'Quests', next = 'quests' },
                    { id = 'lore', label = 'Lore', next = 'lore' },
                    { id = 'routes', label = 'Routes', next = 'routes' },
                },
            },
            quests = { text = regionName .. ' progression is built from repeatable hunting, regional story chains, and boss preparation.' },
            lore = { text = regionName .. ' feels distinct because its mobs, rewards, and routes all reinforce the same regional pressure.' },
            routes = { text = 'Use the map routes, shared farming zones, and choke points to decide where solo and group play feel strongest.' },
        },
    }
end

for regionIndex, region in ipairs(regionProfiles) do
    local regionName = title(region.id)
    local progression = assert(RegionalProgression[region.id], 'missing regional progression source:' .. tostring(region.id))
    local regionLevel = assert(progression.recommendedRange and progression.recommendedRange.min, 'missing progression range:' .. tostring(region.id))
    local rewardBandIndex = assert(regionEconomyOrder[region.id], 'missing region economy order:' .. tostring(region.id))
    local mapIds = {}
    local orderedMapSuffixes = {}

    for templateIndex, mapId in ipairs(progression.maps or {}) do
        local suffix = assert(regionMapSuffix(region.id, mapId), 'progression map outside region:' .. tostring(mapId))
        local template = assert(mapTemplatesBySuffix[suffix], 'missing map template for suffix:' .. tostring(suffix))
        mapIds[template.suffix] = mapId
        orderedMapSuffixes[#orderedMapSuffixes + 1] = template.suffix
        registry.maps[mapId] = {
            map_id = mapId,
            name = regionName .. ' ' .. title(template.suffix),
            recommended_level = regionLevel + template.levelOffset,
            tags = clone(region.tags),
            transitions = {},
            spawnPosition = { x = 24 + (templateIndex * 8), y = (templateIndex % 3) * 8, z = 0 },
            channels = template.role == 'hub' and 12 or template.role == 'boss arena' and 6 or 10,
            layer = template.layer,
            eventHooks = clone(template.hooks),
            huntingRole = template.role,
            terrainStrategy = region.terrain,
            verticalLayers = clone(template.vertical),
            movementRoutes = clone(template.routes),
            socialHotspots = { 'quest board', 'party banner', 'loot beam lane' },
            chokePoints = clone(template.choke),
            mobilityAdvantageZones = clone(template.mobility),
            sharedFarmingZones = template.role == 'hub' and { mapId } or { mapId, region.id .. '_clash_zone' },
            lore = region.identity,
            environmentStory = region.identity .. ' The map layout reinforces ' .. template.role .. '.',
        }
    end

    for index, suffix in ipairs(orderedMapSuffixes) do
        local map = registry.maps[mapIds[suffix]]
        local nextSuffix = orderedMapSuffixes[index + 1]
        local prevSuffix = orderedMapSuffixes[index - 1]
        if nextSuffix then map.transitions[mapIds[nextSuffix]] = true end
        if prevSuffix then map.transitions[mapIds[prevSuffix]] = true end
        if suffix == 'town' then
            map.transitions[mapIds.fields] = true
            map.transitions[mapIds.outskirts] = true
        end
        if suffix == 'clash_zone' then
            map.transitions[mapIds.boss] = true
            map.transitions[mapIds.sanctum] = true
        end
    end

    for _, consumable in ipairs(consumableBases) do
        addItem({
            item_id = region.id .. '_' .. consumable.id,
            name = regionName .. ' ' .. consumable.name,
            type = 'consumable',
            required_level = math.max(1, regionLevel),
            attack = 0,
            defense = 0,
            stackable = true,
            npc_price = consumable.price + (regionIndex * 8),
            rarity = consumable.id == 'tonic_03' and 'rare' or 'common',
            asset_key = 'item/' .. region.id .. '_' .. consumable.id,
            progression_tier = regionIndex,
            desirability = 'sustain',
            excitement = consumable.id == 'tonic_03' and 'boss_prep' or 'steady',
            dopamineTier = consumable.id == 'tonic_03' and 'build' or 'steady',
        })
    end

    for itemIndex, base in ipairs(equipmentBases) do
        for tier = 1, 3 do
            local itemId = tier == 1 and (region.id .. '_' .. base.id) or string.format('%s_%s_t%d', region.id, base.id, tier)
            local rarity = tier == 3 and (base.rarity == 'rare' and 'legendary' or 'epic') or tier == 2 and (base.rarity == 'common' and 'uncommon' or 'rare') or base.rarity
            addItem({
                item_id = itemId,
                name = string.format('%s %s %s', regionName, title(base.id), tier == 1 and 'Mk I' or tier == 2 and 'Mk II' or 'Mk III'),
                type = base.type,
                required_level = regionLevel + (itemIndex % 6) + ((tier - 1) * 8),
                attack = base.attack + (regionIndex * (base.type == 'weapon' and 3 or 1)) + ((tier - 1) * 6),
                defense = base.defense + regionIndex + ((tier - 1) * 4),
                stackable = false,
                npc_price = 120 + (regionIndex * 90) + (itemIndex * 25) + (tier * 80),
                rarity = rarity,
                asset_key = 'item/' .. itemId,
                progression_tier = regionIndex + (tier * 2),
                desirability = base.type == 'weapon' and 'power spike' or 'set completion',
                upgrade_path = region.id .. '_reforge',
                excitement = rarity == 'legendary' and 'jackpot' or rarity == 'epic' and 'boss_signature' or 'steady',
                dopamineTier = rarity == 'legendary' and 'peak' or rarity == 'epic' and 'chase' or rarity == 'rare' and 'build' or 'steady',
                set_bonus_key = region.id .. '_set_' .. tostring((itemIndex % 4) + 1),
            })
        end
    end

    for materialIndex, suffix in ipairs(materialBases) do
        local itemId = region.id .. '_' .. suffix
        addItem({
            item_id = itemId,
            name = string.format('%s Material %02d', regionName, materialIndex),
            type = 'material',
            required_level = regionLevel + math.floor(materialIndex / 2),
            attack = 0,
            defense = 0,
            stackable = true,
            npc_price = 10 + (regionIndex * 5) + materialIndex,
            rarity = materialIndex >= 15 and 'rare' or materialIndex >= 8 and 'uncommon' or 'common',
            asset_key = 'item/' .. itemId,
            progression_tier = regionIndex + math.floor(materialIndex / 3),
            desirability = 'crafting',
            excitement = materialIndex >= 15 and 'crafting_breakpoint' or 'steady',
            dopamineTier = materialIndex >= 15 and 'build' or 'steady',
        })
    end

    for artifactIndex, suffix in ipairs(artifactBases) do
        local itemId = region.id .. '_' .. suffix
        addItem({
            item_id = itemId,
            name = string.format('%s Artifact %02d', regionName, artifactIndex),
            type = 'accessory',
            required_level = regionLevel + 6 + artifactIndex,
            attack = 2 + artifactIndex,
            defense = 2 + math.floor(artifactIndex / 2),
            stackable = false,
            npc_price = 400 + (regionIndex * 140) + (artifactIndex * 60),
            rarity = artifactIndex >= 8 and 'legendary' or artifactIndex >= 5 and 'epic' or 'rare',
            asset_key = 'item/' .. itemId,
            progression_tier = regionIndex + 8 + artifactIndex,
            desirability = 'boss-exclusive',
            excitement = artifactIndex >= 8 and 'jackpot' or 'boss_signature',
            dopamineTier = artifactIndex >= 8 and 'peak' or 'chase',
        })
    end

    for scrollIndex, suffix in ipairs(scrollBases) do
        local itemId = region.id .. '_' .. suffix
        addItem({
            item_id = itemId,
            name = string.format('%s Scroll %02d', regionName, scrollIndex),
            type = 'material',
            required_level = regionLevel + scrollIndex,
            attack = 0,
            defense = 0,
            stackable = true,
            npc_price = 80 + (regionIndex * 20) + (scrollIndex * 15),
            rarity = scrollIndex >= 8 and 'epic' or scrollIndex >= 5 and 'rare' or 'uncommon',
            asset_key = 'item/' .. itemId,
            progression_tier = regionIndex + scrollIndex,
            desirability = 'enhancement',
            excitement = scrollIndex >= 8 and 'mini_jackpot' or 'route_upgrade',
            dopamineTier = scrollIndex >= 8 and 'chase' or 'build',
        })
    end

    for relicIndex, suffix in ipairs(relicBases) do
        local itemId = region.id .. '_' .. suffix
        addItem({
            item_id = itemId,
            name = string.format('%s Relic %02d', regionName, relicIndex),
            type = 'material',
            required_level = regionLevel + relicIndex,
            attack = 0,
            defense = 0,
            stackable = true,
            npc_price = 0,
            rarity = relicIndex >= 8 and 'epic' or 'rare',
            asset_key = 'item/' .. itemId,
            progression_tier = regionIndex + relicIndex,
            desirability = 'quest',
            excitement = 'lore_find',
            dopamineTier = 'build',
        })
    end

    for npcIndex, role in ipairs(npcRoles) do
        local npcId = string.format('%s_%s_%02d', region.id, role.suffix, npcIndex)
        local mapSuffix = orderedMapSuffixes[((npcIndex - 1) % #orderedMapSuffixes) + 1]
        local catalog = {}
        catalog[region.id .. '_potion_01'] = true
        catalog[region.id .. '_potion_02'] = true
        catalog[region.id .. '_material_01'] = true
        catalog[region.id .. '_material_02'] = true
        if npcIndex % 3 == 0 then catalog[region.id .. '_scroll_01'] = true end
        registry.npcs[npcId] = {
            npc_id = npcId,
            name = string.format('%s %s %02d', regionName, title(role.suffix), npcIndex),
            map_id = mapIds[mapSuffix],
            x = 24 + (npcIndex * 3),
            y = (npcIndex % 3) * 6,
            z = 0,
            shopId = npcId .. '_shop',
            dialogue_id = npcId .. '_dialogue',
            catalog = catalog,
            services = clone(role.services),
        }
        addDialogue(npcId, string.format('%s %s knows how to %s.', regionName, title(role.suffix), role.tone), title(role.suffix) .. ' voice', regionName)
    end

    for mobIndex, archetype in ipairs(mobArchetypes) do
        local mobId = string.format('%s_mob_%02d', region.id, mobIndex)
        local earlyEconomyPressure = mobIndex <= 8
        local mapChoice = ({
            'outskirts', 'fields', 'fields', 'upper_route', 'lower_route',
            'grove', 'ruins', 'tunnel', 'tunnel', 'clash_zone',
            'fields', 'sanctum', 'dungeon', 'dungeon', 'ruins',
            'clash_zone', 'grove', 'clash_zone', 'sanctum', 'boss',
        })[mobIndex]
        registry.mobs[mobId] = {
            mob_id = mobId,
            name = string.format('%s %s', regionName, title(archetype.key)),
            level = regionLevel + mobIndex,
            hp = 24 + (regionIndex * 60) + (mobIndex * 34),
            exp = 10 + (regionIndex * 14) + (mobIndex * 8),
            mesos_min = 3 + regionIndex + mobIndex,
            mesos_max = 7 + (regionIndex * 3) + (mobIndex * 2),
            map_pool = mapIds[mapChoice],
            respawn_sec = archetype.role == 'captain' and 10 or archetype.role == 'elite' and 7 or 5,
            asset_key = 'mob/' .. mobId,
            family = archetype.family,
            role = archetype.role,
            identity = region.identity .. ' This enemy uses ' .. archetype.pattern .. '.',
            hitReaction = archetype.reaction,
            eliteBehavior = archetype.pattern,
            staggerProfile = archetype.role == 'captain' and 'bosslike' or archetype.role == 'elite' and 'heavy' or 'light',
        }
        local materialChance = earlyEconomyPressure and 0.48 or 0.62
        if region.id == 'perion' and mapChoice == 'fields' then
            materialChance = earlyEconomyPressure and 0.42 or 0.56
        end
        registry.drop_tables[mobId] = {
            { item_id = region.id .. '_' .. materialBases[((mobIndex - 1) % #materialBases) + 1], chance = materialChance, min_qty = 1, max_qty = earlyEconomyPressure and 2 or 3, rarity = mobIndex >= 15 and 'rare' or mobIndex >= 8 and 'uncommon' or 'common', bind_on_pickup = false, anticipation = mobIndex >= 15 and 'route_chase' or 'steady' },
            { item_id = region.id .. '_' .. consumableBases[((mobIndex - 1) % #consumableBases) + 1].id, chance = 0.24, min_qty = 1, max_qty = 2, rarity = 'common', bind_on_pickup = false, anticipation = 'support' },
            { item_id = (mobIndex % 3 == 0) and (region.id .. '_' .. scrollBases[((mobIndex - 1) % #scrollBases) + 1]) or (region.id .. '_' .. equipmentBases[((mobIndex - 1) % #equipmentBases) + 1].id), chance = mobIndex >= 17 and 0.08 or mobIndex >= 10 and 0.05 or 0.03, min_qty = 1, max_qty = 1, rarity = mobIndex >= 17 and 'epic' or 'rare', bind_on_pickup = false, anticipation = mobIndex >= 17 and 'mini_jackpot' or 'notable' },
        }
    end

    local function adjustedBossCooldown(baseCooldown, trigger)
        if regionIndex < 6 or trigger ~= 'scheduled_window' then
            return baseCooldown
        end
        return math.floor(baseCooldown * 0.82 + 0.5)
    end

    local bosses = {
        { id = region.id .. '_warden', name = regionName .. ' Warden', map = mapIds.clash_zone, hp = 3200 + (regionIndex * 2600), trigger = 'scheduled_window', cooldown = adjustedBossCooldown(720 + (regionIndex * 60), 'scheduled_window'), rarity = 'rare', raid = regionIndex >= 4 },
        { id = region.id .. '_overseer', name = regionName .. ' Overseer', map = mapIds.boss, hp = 5200 + (regionIndex * 4200), trigger = regionIndex % 2 == 0 and 'scheduled_window' or 'channel_presence', cooldown = adjustedBossCooldown(1100 + (regionIndex * 90), regionIndex % 2 == 0 and 'scheduled_window' or 'channel_presence'), rarity = 'epic', raid = regionIndex >= 5 },
        { id = region.id .. '_tyrant', name = regionName .. ' Tyrant', map = mapIds.sanctum, hp = 8600 + (regionIndex * 5600), trigger = 'scheduled_window', cooldown = adjustedBossCooldown(1500 + (regionIndex * 120), 'scheduled_window'), rarity = 'epic', raid = true },
        { id = region.id .. '_raid_core', name = regionName .. ' Raid Core', map = mapIds.boss, hp = 12800 + (regionIndex * 7200), trigger = 'scheduled_window', cooldown = adjustedBossCooldown(2100 + (regionIndex * 180), 'scheduled_window'), rarity = 'legendary', raid = true },
    }

    for bossIndex, boss in ipairs(bosses) do
        registry.bosses[boss.id] = {
            boss_id = boss.id,
            name = boss.name,
            map_id = boss.map,
            hp = boss.hp,
            trigger = boss.trigger,
            cooldown_sec = boss.cooldown,
            rare_drop_group = boss.id .. '_drops',
            asset_key = 'boss/' .. boss.id,
            uniqueness = bossIndex == 4 and 'world_unique' or 'channel_unique',
            raid = boss.raid,
            mechanics = {
                [1] = { pattern = 'telegraph_sweep', hazard = 'lane_break', text = 'The boss marks safe lanes before bursting forward.', punishWindow = 'medium', telegraph = 'lane_glow' },
                [2] = { pattern = 'summon_ring', hazard = 'zone_lock', text = 'Adds and hazards overlap; movement and support matter.', punishWindow = 'short', telegraph = 'ring_marker' },
                [3] = { pattern = 'berserk_cycle', hazard = 'arena_burst', text = 'Final phase opens tight burst windows after strong telegraphs.', punishWindow = 'tight', telegraph = 'arena_crack' },
            },
        }
        registry.drop_tables[boss.id] = {
            { item_id = region.id .. '_' .. equipmentBases[((bossIndex - 1) % #equipmentBases) + 1].id .. '_t3', chance = 0.6, min_qty = 1, max_qty = 1, rarity = boss.rarity, bind_on_pickup = false, anticipation = 'boss_signature' },
            { item_id = region.id .. '_' .. artifactBases[((bossIndex - 1) % #artifactBases) + 1], chance = bossIndex == 4 and 1.0 or 0.45, min_qty = 1, max_qty = 1, rarity = bossIndex == 4 and 'legendary' or 'epic', bind_on_pickup = false, anticipation = 'jackpot' },
            { item_id = region.id .. '_' .. materialBases[20 - bossIndex], chance = 1.0, min_qty = 3, max_qty = 5, rarity = 'rare', bind_on_pickup = false, anticipation = 'crafting_cache' },
        }
    end

    local questNpcs = {
        guide = string.format('%s_guide_%02d', region.id, 1),
        scout = string.format('%s_scout_%02d', region.id, 5),
        captain = string.format('%s_captain_%02d', region.id, 8),
        artisan = string.format('%s_artisan_%02d', region.id, 14),
        veteran = string.format('%s_veteran_%02d', region.id, 15),
    }

    for questIndex = 1, 30 do
        local questId = string.format('%s_story_%02d', region.id, questIndex)
        local early = questIndex <= 8
        local mid = questIndex > 8 and questIndex <= 20
        local late = questIndex > 20
        local killTarget = late and bosses[((questIndex - 21) % #bosses) + 1].id or string.format('%s_mob_%02d', region.id, ((questIndex - 1) % 20) + 1)
        local collectTarget = late and (region.id .. '_' .. artifactBases[((questIndex - 21) % #artifactBases) + 1]) or (region.id .. '_' .. materialBases[((questIndex - 1) % #materialBases) + 1])
        local objectiveKillCount = late and 1 or 5 + (questIndex % 5)
        local objectives = {
            { type = 'kill', targetId = killTarget, required = objectiveKillCount },
            { type = 'collect', targetId = collectTarget, required = late and 1 or 2 + (questIndex % 4) },
        }
        local narrative = early and (regionName .. ' opens with guided hunts and route familiarity.') or mid and (regionName .. ' escalates through dungeon routes, crafting pressure, and regional lore.') or (regionName .. ' culminates in boss, raid, and artifact loops.')
        local rewardSummary = late and 'boss progression gear + prestige drops' or mid and 'regional gear + crafting materials' or 'starter sustain + route unlock pressure'
        local guidance = late and 'Form a party, read telegraphs, and clear the boss phases before the reward window closes.' or mid and 'Rotate between route maps and dungeon maps to keep gear and quest progress aligned.' or 'Start on the lower-pressure field route, then move up once drops and quest progress stabilize.'

        if region.id == 'henesys' and questIndex <= 6 then
            local onboardingOverrides = {
                [1] = {
                    objectives = {
                        { type = 'kill', targetId = 'henesys_mob_01', required = 6 },
                    },
                    narrative = 'Henesys onboarding kill pressure step 1',
                    rewardSummary = 'starter sustain before crafting pressure',
                    guidance = 'Clear the starter lane first and turn in before adding drop-routing pressure.',
                },
                [2] = {
                    objectives = {
                        { type = 'collect', targetId = 'henesys_material_02', required = 4 },
                    },
                    narrative = 'Henesys onboarding collection step 2',
                    rewardSummary = 'material stock for potion loop',
                    guidance = 'Stay on the low-risk route and bank enough field materials to stabilize potion use.',
                },
                [3] = {
                    objectives = {
                        { type = 'kill', targetId = 'henesys_mob_03', required = 8 },
                        { type = 'collect', targetId = 'henesys_material_03', required = 5 },
                    },
                    narrative = 'Henesys mixed combat and drop step 3',
                    rewardSummary = 'combat cadence plus crafting feed',
                    guidance = 'Push one field loop until both kill pace and drop pace line up.',
                },
                [4] = {
                    objectives = {
                        { type = 'kill', targetId = 'henesys_mob_04', required = 5 },
                        { type = 'kill', targetId = 'henesys_mob_03', required = 4 },
                    },
                    narrative = 'Henesys lane rotation step 4',
                    rewardSummary = 'route rotation and spawn discipline',
                    guidance = 'Rotate between adjacent lanes instead of camping one spawn pocket.',
                },
                [5] = {
                    objectives = {
                        { type = 'collect', targetId = 'henesys_material_05', required = 2 },
                        { type = 'collect', targetId = 'henesys_material_04', required = 3 },
                    },
                    narrative = 'Henesys supply sweep step 5',
                    rewardSummary = 'crafting stock without overfarming one node',
                    guidance = 'Sweep two material routes and return once both bags are filled.',
                },
                [6] = {
                    objectives = {
                        { type = 'collect', targetId = 'henesys_material_06', required = 4 },
                        { type = 'kill', targetId = 'henesys_mob_06', required = 6 },
                    },
                    narrative = 'Henesys recovery loop step 6',
                    rewardSummary = 'drop-first then combat finish',
                    guidance = 'Secure the sustain drops first and close the route with a final combat pass.',
                },
            }
            local override = onboardingOverrides[questIndex]
            objectives = override.objectives
            narrative = override.narrative
            rewardSummary = override.rewardSummary
            guidance = override.guidance
        end

        registry.quests[questId] = {
            quest_id = questId,
            name = string.format('%s Campaign %02d', regionName, questIndex),
            required_level = regionLevel + questIndex - 1,
            objectives = objectives,
            reward_exp = 120 + (regionIndex * 60) + (questIndex * 28),
            reward_mesos = 180 + (rewardBandIndex * 90) + (questIndex * 46),
            reward_items = {
                { itemId = early and (region.id .. '_potion_03') or mid and (region.id .. '_' .. equipmentBases[((questIndex - 1) % #equipmentBases) + 1].id) or (region.id .. '_' .. artifactBases[((questIndex - 21) % #artifactBases) + 1]), quantity = 1 },
            },
            start_npc = early and questNpcs.guide or mid and questNpcs.scout or questNpcs.veteran,
            end_npc = early and questNpcs.guide or mid and questNpcs.artisan or questNpcs.captain,
            arc = region.id,
            narrative = narrative,
            reward_summary = rewardSummary,
            guidance = guidance,
        }
    end
end

local legacyMaps = {
    henesys_hunting_ground = { name = 'Henesys Hunting Ground', recommended_level = 1, transitions = { forest_edge = true, ant_tunnel_1 = true }, spawnPosition = { x = 20, y = 0, z = 0 } },
    ant_tunnel_1 = { name = 'Ant Tunnel 1', recommended_level = 20, transitions = { henesys_hunting_ground = true }, spawnPosition = { x = 28, y = 0, z = 0 } },
    forest_edge = { name = 'Forest Edge', recommended_level = 18, transitions = { henesys_hunting_ground = true, perion_rocky = true }, spawnPosition = { x = 80, y = 0, z = 0 } },
    perion_rocky = { name = 'Perion Rocky', recommended_level = 30, transitions = { forest_edge = true }, spawnPosition = { x = 110, y = 0, z = 0 } },
}

for mapId, map in pairs(legacyMaps) do
    registry.maps[mapId] = {
        map_id = mapId,
        name = map.name,
        recommended_level = map.recommended_level,
        tags = { 'legacy', 'compatibility' },
        transitions = map.transitions,
        spawnPosition = map.spawnPosition,
        channels = 6,
        layer = 'legacy',
        eventHooks = { 'compatibility' },
        huntingRole = mapId == 'henesys_hunting_ground' and 'starter grind' or 'legacy route',
        terrainStrategy = 'straight route with simple monster cycling',
        verticalLayers = { 'base path', 'branch lane' },
        movementRoutes = { 'legacy sweep', 'return rope' },
        socialHotspots = { 'npc stop', 'entry rope' },
        chokePoints = { 'legacy bridge' },
        mobilityAdvantageZones = { 'branch lane' },
        sharedFarmingZones = { mapId },
        lore = map.name .. ' remains as a nostalgia route inside the broader world.',
        environmentStory = 'The older route shape stays intact as a readable training ground.',
    }
end

local legacyItems = {
    sword_bronze = { name = 'Bronze Sword', type = 'weapon', required_level = 5, attack = 12, defense = 0, price = 180, rarity = 'common' },
    wooden_armor = { name = 'Wooden Armor', type = 'overall', required_level = 3, attack = 0, defense = 8, price = 140, rarity = 'common' },
    hp_potion = { name = 'HP Potion', type = 'consumable', required_level = 1, attack = 0, defense = 0, price = 20, rarity = 'common', stackable = true },
    mushcap_hat = { name = 'Mushcap Hat', type = 'hat', required_level = 10, attack = 0, defense = 6, price = 220, rarity = 'uncommon' },
    zombie_glove = { name = 'Zombie Glove', type = 'glove', required_level = 20, attack = 4, defense = 3, price = 560, rarity = 'rare' },
    mano_shell = { name = 'Mano Shell', type = 'accessory', required_level = 15, attack = 2, defense = 2, price = 1000, rarity = 'rare' },
    stumpy_axe = { name = 'Stumpy Axe', type = 'weapon', required_level = 30, attack = 38, defense = 0, price = 2400, rarity = 'epic' },
    snail_shell = { name = 'Snail Shell', type = 'material', required_level = 1, attack = 0, defense = 0, price = 5, rarity = 'common', stackable = true },
    mushroom_spore = { name = 'Mushroom Spore', type = 'material', required_level = 1, attack = 0, defense = 0, price = 12, rarity = 'common', stackable = true },
}

for itemId, item in pairs(legacyItems) do
    addItem({
        item_id = itemId,
        name = item.name,
        type = item.type,
        required_level = item.required_level,
        attack = item.attack,
        defense = item.defense,
        stackable = item.stackable == true,
        npc_price = item.price,
        rarity = item.rarity,
        asset_key = 'item/' .. itemId,
        progression_tier = item.required_level,
        desirability = item.rarity == 'epic' and 'legacy chase' or 'legacy progression',
        excitement = item.rarity == 'epic' and 'jackpot' or 'steady',
        dopamineTier = item.rarity == 'epic' and 'peak' or 'steady',
    })
end

local legacyMobs = {
    snail = { level = 1, hp = 12, exp = 8, mesos_min = 1, mesos_max = 3, map_pool = 'henesys_hunting_ground', respawn_sec = 5 },
    orange_mushroom = { level = 8, hp = 80, exp = 18, mesos_min = 6, mesos_max = 12, map_pool = 'henesys_hunting_ground', respawn_sec = 7 },
    horny_mushroom = { level = 22, hp = 260, exp = 52, mesos_min = 24, mesos_max = 35, map_pool = 'ant_tunnel_1', respawn_sec = 9 },
    zombie_mushroom = { level = 24, hp = 340, exp = 70, mesos_min = 28, mesos_max = 40, map_pool = 'ant_tunnel_1', respawn_sec = 10 },
}

for mobId, mob in pairs(legacyMobs) do
    registry.mobs[mobId] = {
        mob_id = mobId,
        name = title(mobId),
        level = mob.level,
        hp = mob.hp,
        exp = mob.exp,
        mesos_min = mob.mesos_min,
        mesos_max = mob.mesos_max,
        map_pool = mob.map_pool,
        respawn_sec = mob.respawn_sec,
        asset_key = 'mob/' .. mobId,
        role = 'compatibility',
        family = 'legacy',
        identity = 'legacy mob used to preserve early route familiarity',
        hitReaction = 'light_flinch',
        eliteBehavior = 'legacy pacing',
        staggerProfile = 'light',
    }
end

registry.bosses.mano = { boss_id = 'mano', name = 'Mano', map_id = 'forest_edge', hp = 5000, trigger = 'channel_presence', cooldown_sec = 1800, rare_drop_group = 'mano_rares', asset_key = 'boss/mano', uniqueness = 'channel_unique', mechanics = { [1] = { pattern = 'shell_wave', text = 'Watch the shell pattern.' }, [2] = { pattern = 'slam', text = 'Move after the slam.' }, [3] = { pattern = 'rage_burst', text = 'Burst after the rage tell.' } } }
registry.bosses.stumpy = { boss_id = 'stumpy', name = 'Stumpy', map_id = 'perion_rocky', hp = 12000, trigger = 'scheduled_window', cooldown_sec = 2700, rare_drop_group = 'stumpy_rares', asset_key = 'boss/stumpy', uniqueness = 'channel_unique', mechanics = { [1] = { pattern = 'axe_sweep', text = 'Sweep telegraph on the floor.' }, [2] = { pattern = 'stomp', text = 'Jump or move for the stomp.' }, [3] = { pattern = 'stone_fall', text = 'Bait then reposition.' } } }

registry.drop_tables.snail = {
    { item_id = 'snail_shell', chance = 0.65, min_qty = 1, max_qty = 2, rarity = 'common', bind_on_pickup = false, anticipation = 'steady' },
    { item_id = 'hp_potion', chance = 0.15, min_qty = 1, max_qty = 1, rarity = 'common', bind_on_pickup = false, anticipation = 'support' },
}
registry.drop_tables.orange_mushroom = {
    { item_id = 'mushroom_spore', chance = 0.55, min_qty = 1, max_qty = 2, rarity = 'common', bind_on_pickup = false, anticipation = 'steady' },
    { item_id = 'mushcap_hat', chance = 0.06, min_qty = 1, max_qty = 1, rarity = 'uncommon', bind_on_pickup = false, anticipation = 'notable' },
}
registry.drop_tables.horny_mushroom = {
    { item_id = 'wooden_armor', chance = 0.08, min_qty = 1, max_qty = 1, rarity = 'common', bind_on_pickup = false, anticipation = 'steady' },
    { item_id = 'hp_potion', chance = 0.45, min_qty = 1, max_qty = 3, rarity = 'common', bind_on_pickup = false, anticipation = 'support' },
}
registry.drop_tables.zombie_mushroom = {
    { item_id = 'zombie_glove', chance = 0.04, min_qty = 1, max_qty = 1, rarity = 'rare', bind_on_pickup = false, anticipation = 'jackpot' },
    { item_id = 'hp_potion', chance = 0.35, min_qty = 1, max_qty = 2, rarity = 'common', bind_on_pickup = false, anticipation = 'support' },
}
registry.drop_tables.mano = {
    { item_id = 'mano_shell', chance = 1.0, min_qty = 1, max_qty = 1, rarity = 'rare', bind_on_pickup = false, anticipation = 'boss_signature' },
    { item_id = 'sword_bronze', chance = 0.25, min_qty = 1, max_qty = 1, rarity = 'uncommon', bind_on_pickup = false, anticipation = 'notable' },
}
registry.drop_tables.stumpy = {
    { item_id = 'stumpy_axe', chance = 1.0, min_qty = 1, max_qty = 1, rarity = 'epic', bind_on_pickup = false, anticipation = 'jackpot' },
    { item_id = 'wooden_armor', chance = 0.2, min_qty = 1, max_qty = 1, rarity = 'common', bind_on_pickup = false, anticipation = 'steady' },
}

registry.npcs.Rina = { npc_id = 'Rina', name = 'Rina', map_id = 'henesys_hunting_ground', x = 20, y = 0, z = 0, shopId = 'henesys_general', dialogue_id = 'Rina_dialogue', catalog = { hp_potion = true, snail_shell = true, mushroom_spore = true }, services = { 'shop', 'quest' } }
registry.npcs.Sera = { npc_id = 'Sera', name = 'Sera', map_id = 'henesys_hunting_ground', x = 20, y = 0, z = 0, shopId = 'henesys_general', dialogue_id = 'Sera_dialogue', catalog = { hp_potion = true, snail_shell = true, mushroom_spore = true }, services = { 'shop', 'quest' } }
registry.npcs.Chief_Stan = { npc_id = 'Chief_Stan', name = 'Chief Stan', map_id = 'forest_edge', x = 80, y = 0, z = 0, shopId = 'forest_trade', dialogue_id = 'Chief_Stan_dialogue', catalog = { hp_potion = true, mano_shell = true }, services = { 'shop', 'quest' } }

registry.dialogues.Rina_dialogue = { npc_id = 'Rina', greeting = 'Start with snails. Learn the rhythm of combat first.', personality = 'warm field captain', nodes = { start = { text = 'Clear snails, gather drops, then come back stronger.' } } }
registry.dialogues.Sera_dialogue = { npc_id = 'Sera', greeting = 'Spores and potions keep the early route moving.', personality = 'precise herbalist', nodes = { start = { text = 'Collect what the mushrooms leave behind.' } } }
registry.dialogues.Chief_Stan_dialogue = { npc_id = 'Chief_Stan', greeting = 'Field bosses shape the frontier.', personality = 'tired veteran', nodes = { start = { text = 'Push the edge, then challenge Mano.' } } }

registry.quests.q_snail_cleanup = {
    quest_id = 'q_snail_cleanup', name = 'Snail Cleanup', required_level = 1,
    objectives = { { type = 'kill', targetId = 'snail', required = 5 } },
    reward_exp = 40, reward_mesos = 100, reward_items = { { itemId = 'hp_potion', quantity = 5 } },
    start_npc = 'Rina', end_npc = 'Rina', arc = 'legacy',
    narrative = 'Rina wants the beginner route made safe.', reward_summary = 'starter sustain package',
    guidance = 'Stay on the lower path until five kills are secured, then return to town.',
}
registry.quests.q_spore_collection = {
    quest_id = 'q_spore_collection', name = 'Spore Collection', required_level = 8,
    objectives = { { type = 'collect', targetId = 'mushroom_spore', required = 4 } },
    reward_exp = 120, reward_mesos = 260, reward_items = { { itemId = 'hp_potion', quantity = 3 } },
    start_npc = 'Sera', end_npc = 'Sera', arc = 'legacy',
    narrative = 'Sera is rebuilding potion stock from mushroom spores.', reward_summary = 'consumables and mesos',
    guidance = 'Farm orange mushrooms until the potion loop feels self-sustaining.',
}
registry.quests.q_mano_hunt = {
    quest_id = 'q_mano_hunt', name = 'Mano Suppression', required_level = 18,
    objectives = { { type = 'kill', targetId = 'mano', required = 1 } },
    reward_exp = 800, reward_mesos = 1200, reward_items = { { itemId = 'mano_shell', quantity = 1 } },
    start_npc = 'Chief_Stan', end_npc = 'Chief_Stan', arc = 'legacy',
    narrative = 'Chief Stan needs proof that Mano has been broken.', reward_summary = 'boss trophy and equipment pivot',
    guidance = 'Bring support items, clear the route, then burst the boss during safe windows.',
}

for mapId in pairs(RareSpawnTables) do
    assert(registry.maps[mapId] ~= nil, 'rare spawn map missing from registry source alignment:' .. tostring(mapId))
end

function registry.load()
    return clone(registry)
end

return registry
