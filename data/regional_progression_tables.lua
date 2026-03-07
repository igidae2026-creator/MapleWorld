local RegionalProgression = {
    henesys = {
        tier = 'starter',
        recommendedRange = { min = 1, max = 22 },
        primaryLoop = 'quest-led hunting with potion-backed field grinding',
        maps = { 'henesys_town', 'henesys_fields', 'henesys_dungeon', 'henesys_boss' },
        milestoneRewards = {
            { level = 8, reward = 'beginner_route_cache', guidance = 'Unlock your first field loop and consumable economy.' },
            { level = 15, reward = 'henesys_class_trial', guidance = 'Transition into first-job identity and route-specific gear.' },
        },
        valuedDrops = { 'red_potion', 'henesys_bronze_blade', 'henesys_material_01' },
        socialLoop = 'party onboarding, newbie trading, and tutorial-assisted grouping',
    },
    ellinia = {
        tier = 'growth',
        recommendedRange = { min = 22, max = 48 },
        primaryLoop = 'vertical casting routes, mana sustain, and quest-chain momentum',
        maps = { 'ellinia_town', 'ellinia_fields', 'ellinia_dungeon', 'ellinia_boss' },
        milestoneRewards = {
            { level = 30, reward = 'ellinia_spell_manual', guidance = 'Commit to sustained AoE or support pressure.' },
            { level = 42, reward = 'ellinia_arcane_set', guidance = 'Start building set bonuses and dungeon loops.' },
        },
        valuedDrops = { 'mana_elixir', 'ellinia_arcane_focus', 'ellinia_material_02' },
        socialLoop = 'scroll trade, support pairing, and party quest staging',
    },
    perion = {
        tier = 'midgame',
        recommendedRange = { min = 40, max = 68 },
        primaryLoop = 'durable melee grinding, elite camps, and bruiser boss prep',
        maps = { 'perion_town', 'perion_fields', 'perion_dungeon', 'perion_boss' },
        milestoneRewards = {
            { level = 50, reward = 'perion_forge_access', guidance = 'Convert field drops into durable combat sets.' },
            { level = 60, reward = 'perion_warlord_trial', guidance = 'Push boss mechanics with tank and damage pairings.' },
        },
        valuedDrops = { 'perion_obsidian_armor', 'perion_material_03', 'white_potion' },
        socialLoop = 'guild-oriented hunting squads and bruiser gearing',
    },
    kerning = {
        tier = 'advanced',
        recommendedRange = { min = 60, max = 88 },
        primaryLoop = 'high-mobility farming, jackpot rare mobs, and price-sensitive drops',
        maps = { 'kerning_town', 'kerning_fields', 'kerning_dungeon', 'kerning_boss' },
        milestoneRewards = {
            { level = 70, reward = 'kerning_black_market_badge', guidance = 'Open higher-value trading and stealth-centric routes.' },
            { level = 82, reward = 'kerning_strike_set', guidance = 'Blend burst builds with cooperative boss play.' },
        },
        valuedDrops = { 'kerning_shadow_claw', 'kerning_material_04', 'rogue_emblem' },
        socialLoop = 'party finder adoption, market flipping, and cooperative burst clears',
    },
    ludibrium = {
        tier = 'endgame_entry',
        recommendedRange = { min = 85, max = 118 },
        primaryLoop = 'party-synced routes, raid telegraphs, and clockwork event pressure',
        maps = { 'ludibrium_town', 'ludibrium_fields', 'ludibrium_dungeon', 'ludibrium_boss' },
        milestoneRewards = {
            { level = 95, reward = 'ludibrium_clock_pass', guidance = 'Enter synchronized dungeon and raid loops.' },
            { level = 110, reward = 'clockwork_colossus_emblem', guidance = 'Anchor your first serious world-boss build.' },
        },
        valuedDrops = { 'ludibrium_clock_blade', 'ludibrium_material_05', 'party_raid_token' },
        socialLoop = 'raid prep, party queueing, and clockwork world events',
    },
    leafre = {
        tier = 'endgame',
        recommendedRange = { min = 115, max = 160 },
        primaryLoop = 'dangerous vertical maps, boss-exclusive chase items, and late-game progression loops',
        maps = { 'leafre_town', 'leafre_fields', 'leafre_dungeon', 'leafre_boss' },
        milestoneRewards = {
            { level = 125, reward = 'leafre_dragon_hunt', guidance = 'Build boss-readiness through rare spawn and elite routes.' },
            { level = 145, reward = 'sky_tyrant_sigil', guidance = 'Push optimized endgame gearing and guild boss racing.' },
        },
        valuedDrops = { 'leafre_dragon_mail', 'leafre_material_06', 'dragon_scale_core' },
        socialLoop = 'endgame boss calls, guild competition, and prestige crafting',
    },
}

return RegionalProgression
