local Registry = {}

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

local themes = {
    { id = 'henesys', level = 1, tags = { 'forest', 'beginner' }, identity = 'sunlit hunting trails and crowded beginner routes', terrain = 'rolling platforms with low-risk movement', social = 'pot-heavy starter gathering point' },
    { id = 'ellinia', level = 25, tags = { 'magic', 'canopy' }, identity = 'floating canopies and mana currents', terrain = 'vertical rope lanes and fragile footing', social = 'mage clustering and scroll trading' },
    { id = 'perion', level = 45, tags = { 'rock', 'warrior' }, identity = 'harsh cliffs and dust-heavy war camps', terrain = 'wide ledges and punishing knockback space', social = 'frontliner training ground' },
    { id = 'kerning', level = 65, tags = { 'urban', 'rogue' }, identity = 'shadowy alleys and sewer ambushes', terrain = 'fast routes, drops, and corner pressure', social = 'market chatter and party forming' },
    { id = 'ludibrium', level = 90, tags = { 'clockwork', 'party' }, identity = 'clockwork towers and synchronized hazards', terrain = 'timed jumps and layered platforms', social = 'party quest and raid staging' },
    { id = 'leafre', level = 120, tags = { 'dragon', 'highlands' }, identity = 'wind-swept nests and dragon remains', terrain = 'high verticality and burst danger', social = 'endgame gearing and boss callouts' },
}

local itemArchetypes = {
    { id = 'bronze_blade', slot = 'weapon', attack = 8, defense = 0, rarity = 'common' },
    { id = 'maple_staff', slot = 'weapon', attack = 6, defense = 2, rarity = 'common' },
    { id = 'shadow_claw', slot = 'weapon', attack = 7, defense = 1, rarity = 'common' },
    { id = 'field_mail', slot = 'overall', attack = 0, defense = 6, rarity = 'common' },
    { id = 'scout_hat', slot = 'hat', attack = 0, defense = 4, rarity = 'common' },
    { id = 'traveler_gloves', slot = 'glove', attack = 1, defense = 2, rarity = 'common' },
    { id = 'wanderer_boots', slot = 'shoe', attack = 0, defense = 3, rarity = 'common' },
    { id = 'hero_charm', slot = 'accessory', attack = 2, defense = 2, rarity = 'uncommon' },
}

local consumables = {
    { id = 'red_potion', price = 25, tier = 1 },
    { id = 'orange_potion', price = 60, tier = 2 },
    { id = 'white_potion', price = 180, tier = 3 },
    { id = 'mana_elixir', price = 220, tier = 3 },
}

local jobs = {
    beginner = { track = 'explorer', primaryStat = 'str', secondaryStat = 'dex', hpGrowth = 18, mpGrowth = 8, branches = { 'warrior', 'magician', 'bowman', 'thief', 'pirate' } },
    warrior = { track = 'explorer', primaryStat = 'str', secondaryStat = 'dex', hpGrowth = 30, mpGrowth = 6, branches = { 'crusader', 'dragon_knight' } },
    magician = { track = 'explorer', primaryStat = 'int', secondaryStat = 'luk', hpGrowth = 14, mpGrowth = 24, branches = { 'cleric', 'wizard_ice', 'wizard_fire' } },
    bowman = { track = 'explorer', primaryStat = 'dex', secondaryStat = 'str', hpGrowth = 20, mpGrowth = 10, branches = { 'hunter', 'crossbowman' } },
    thief = { track = 'explorer', primaryStat = 'luk', secondaryStat = 'dex', hpGrowth = 18, mpGrowth = 10, branches = { 'assassin', 'bandit' } },
    pirate = { track = 'explorer', primaryStat = 'dex', secondaryStat = 'str', hpGrowth = 24, mpGrowth = 12, branches = { 'brawler', 'gunslinger' } },
}

local skillsByJob = {
    beginner = {
        { id = 'shell_throw', type = 'damage', ratio = 1.05, mpCost = 3, cooldown = 0, target = 'mob', unlock = 1, role = 'damage', visual = 'shell_arc', aoeCount = 1 },
        { id = 'second_wind', type = 'buff', stat = 'attack', amount = 4, duration = 20, mpCost = 6, cooldown = 25, unlock = 5, role = 'support', visual = 'wind_aura' },
    },
    warrior = {
        { id = 'power_strike', type = 'damage', ratio = 1.65, mpCost = 8, cooldown = 0, target = 'mob', unlock = 10, role = 'tank', visual = 'heavy_slash', aoeCount = 2, statusEffect = 'armor_break' },
        { id = 'guard_up', type = 'buff', stat = 'defense', amount = 18, duration = 30, mpCost = 10, cooldown = 35, unlock = 12, role = 'tank', visual = 'shield_bloom' },
    },
    magician = {
        { id = 'arcane_bolt', type = 'damage', ratio = 1.85, mpCost = 12, cooldown = 0, target = 'mob', unlock = 10, role = 'support', visual = 'arcane_burst', aoeCount = 3, statusEffect = 'slow' },
        { id = 'mana_barrier', type = 'buff', stat = 'damageReduction', amount = 0.12, duration = 30, mpCost = 16, cooldown = 45, unlock = 14, role = 'support', visual = 'mana_shell' },
    },
    bowman = {
        { id = 'double_shot', type = 'damage', ratio = 1.55, mpCost = 8, cooldown = 0, target = 'mob', unlock = 10, role = 'damage', visual = 'arrow_fan', aoeCount = 2 },
        { id = 'focus', type = 'buff', stat = 'critRate', amount = 0.1, duration = 35, mpCost = 12, cooldown = 40, unlock = 12, role = 'damage', visual = 'focus_ring' },
    },
    thief = {
        { id = 'lucky_seven', type = 'damage', ratio = 1.7, mpCost = 9, cooldown = 0, target = 'mob', unlock = 10, role = 'damage', visual = 'shadow_fork', aoeCount = 2, statusEffect = 'bleed' },
        { id = 'smoke_dash', type = 'buff', stat = 'evasion', amount = 0.15, duration = 20, mpCost = 14, cooldown = 40, unlock = 12, role = 'damage', visual = 'smoke_trail' },
    },
    pirate = {
        { id = 'knuckle_burst', type = 'damage', ratio = 1.6, mpCost = 9, cooldown = 0, target = 'mob', unlock = 10, role = 'hybrid', visual = 'cannon_knuckle', aoeCount = 2, statusEffect = 'stun' },
        { id = 'deck_swab', type = 'buff', stat = 'attackSpeed', amount = 1, duration = 18, mpCost = 12, cooldown = 36, unlock = 12, role = 'hybrid', visual = 'tempo_boost' },
    },
}

local registry = {
    maps = {},
    mobs = {},
    bosses = {},
    items = {},
    quests = {},
    npcs = {},
    jobs = clone(jobs),
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
        daily = {
            monster_cleanup = { cadence = 'daily', rewardPoints = 120 },
            patrol_rotation = { cadence = 'daily', rewardPoints = 180 },
        },
        weekly = {
            boss_rush = { cadence = 'weekly', rewardPoints = 900 },
            guild_supply = { cadence = 'weekly', rewardPoints = 750 },
        },
    },
}

for jobId, skillDefs in pairs(skillsByJob) do
    registry.skills[jobId] = clone(skillDefs)
end

for _, consumable in ipairs(consumables) do
    registry.items[consumable.id] = {
        item_id = consumable.id,
        name = consumable.id:gsub('_', ' '),
        type = 'consumable',
        required_level = 1,
        attack = 0,
        defense = 0,
        stackable = true,
        npc_price = consumable.price,
        rarity = consumable.tier >= 3 and 'uncommon' or 'common',
        asset_key = 'item/' .. consumable.id,
    }
end

for themeIndex, theme in ipairs(themes) do
    local townId = theme.id .. '_town'
    local fields = theme.id .. '_fields'
    local dungeon = theme.id .. '_dungeon'
    local bossMap = theme.id .. '_boss'

    registry.maps[townId] = {
        map_id = townId,
        name = theme.id:gsub('^%l', string.upper) .. ' Town',
        recommended_level = theme.level,
        tags = clone(theme.tags),
        transitions = { [fields] = true },
        spawnPosition = { x = 24, y = 0, z = 0 },
        channels = 12,
        layer = 'town',
        eventHooks = { 'daily_board', 'npc_services' },
        huntingRole = 'hub',
        terrainStrategy = 'safe resupply, route planning, and social regrouping',
        verticalLayers = { 'street', 'market loft', 'lookout roof' },
        movementRoutes = { 'market loop', 'quest board circle', 'field gate shortcut' },
        socialHotspots = { 'storage corner', 'shop lane', 'party board' },
        lore = theme.identity,
    }

    registry.maps[fields] = {
        map_id = fields,
        name = theme.id:gsub('^%l', string.upper) .. ' Fields',
        recommended_level = theme.level + 4,
        tags = { theme.tags[1], 'hunt' },
        transitions = { [townId] = true, [dungeon] = true },
        spawnPosition = { x = 48, y = 0, z = 0 },
        channels = 18,
        layer = 'field',
        eventHooks = { 'map_blessing', 'ambient_spawns' },
        huntingRole = 'grind',
        terrainStrategy = theme.terrain,
        verticalLayers = { 'ground path', 'mid platform', 'upper branch' },
        movementRoutes = { 'clockwise sweep', 'vertical rope loop', 'drop recovery lane' },
        socialHotspots = { 'safe rope', 'elite corner' },
        lore = 'Hunters rotate through ' .. theme.identity .. '.',
    }

    registry.maps[dungeon] = {
        map_id = dungeon,
        name = theme.id:gsub('^%l', string.upper) .. ' Dungeon',
        recommended_level = theme.level + 12,
        tags = { theme.tags[1], 'elite' },
        transitions = { [fields] = true, [bossMap] = true },
        spawnPosition = { x = 72, y = 0, z = 0 },
        channels = 10,
        layer = 'dungeon',
        eventHooks = { 'elite_rotation', 'quest_pulse' },
        huntingRole = 'elite grind',
        terrainStrategy = 'tight spacing and layered pulls reward clean movement and party control',
        verticalLayers = { 'entry floor', 'hazard shelf', 'upper nest' },
        movementRoutes = { 'pull-and-drop loop', 'upper platform chain' },
        socialHotspots = { 'elite spawn pocket', 'quest turn-in path' },
        lore = 'The dungeon shows the harsher side of ' .. theme.identity .. '.',
    }

    registry.maps[bossMap] = {
        map_id = bossMap,
        name = theme.id:gsub('^%l', string.upper) .. ' Boss Lair',
        recommended_level = theme.level + 20,
        tags = { theme.tags[1], 'boss' },
        transitions = { [dungeon] = true },
        spawnPosition = { x = 96, y = 0, z = 0 },
        channels = 6,
        layer = 'boss',
        eventHooks = { 'boss_mechanics', 'world_notice' },
        huntingRole = 'boss',
        terrainStrategy = 'raid positioning and mechanic reads matter more than raw uptime',
        verticalLayers = { 'arena floor', 'hazard rim', 'safe ledge' },
        movementRoutes = { 'clock face rotation', 'burst window reposition' },
        socialHotspots = { 'entrance prep zone', 'loot beam center' },
        lore = 'This lair anchors the region story and its highest-pressure fights.',
    }

    registry.npcs[theme.id .. '_guide'] = {
        npc_id = theme.id .. '_guide',
        name = theme.id:gsub('^%l', string.upper) .. ' Guide',
        map_id = townId,
        x = 24,
        y = 0,
        z = 0,
        shopId = theme.id .. '_general_store',
        dialogue_id = theme.id .. '_guide_dialogue',
        catalog = {},
        services = { 'shop', 'quest', 'travel', 'daily' },
    }
    registry.dialogues[theme.id .. '_guide_dialogue'] = {
        npc_id = theme.id .. '_guide',
        greeting = 'The frontier shifts every channel cycle. Stay supplied and keep moving.',
        nodes = {
            start = {
                text = 'Our patrols need hunters, crafters, and scouts. Pick a route.',
                options = {
                    { id = 'quests', label = 'Quests', next = 'quests' },
                    { id = 'store', label = 'Store', next = 'store' },
                    { id = 'travel', label = 'Travel', next = 'travel' },
                },
            },
            quests = { text = 'Field boards refresh on daily and weekly cadence. Clear them for progression points.' },
            store = { text = 'Consumables and local materials stay in rotation. Premium gear comes through crafting and bosses.' },
            travel = { text = 'Town routes are stable. Dungeon and boss routes open once your quest line advances.' },
        },
    }

    for _, consumable in ipairs(consumables) do
        registry.npcs[theme.id .. '_guide'].catalog[consumable.id] = true
    end

    for variant = 1, 4 do
        local mobId = string.format('%s_mob_%02d', theme.id, variant)
        local level = theme.level + ((variant - 1) * 4)
        registry.mobs[mobId] = {
            mob_id = mobId,
        name = string.format('%s Vanguard %d', theme.id:gsub('^%l', string.upper), variant),
        identity = ({
            'quick swarmers that teach route efficiency',
            'anchored bruisers that punish standing still',
            'elite casters that pressure upper platforms',
            'mini-commanders that force burst timing',
        })[variant],
        hitReaction = variant >= 3 and 'heavy_stagger' or 'light_flinch',
        level = level,
            hp = 40 + (themeIndex * 60) + (variant * 45),
            exp = 14 + (themeIndex * 18) + (variant * 12),
            mesos_min = 4 + (themeIndex * 8) + variant,
            mesos_max = 10 + (themeIndex * 12) + (variant * 3),
            map_pool = variant <= 2 and fields or dungeon,
            respawn_sec = 4 + variant,
            asset_key = 'mob/' .. mobId,
            family = theme.id,
            role = variant <= 2 and 'swarm' or 'elite',
        }

        local materialId = string.format('%s_material_%02d', theme.id, variant)
        registry.items[materialId] = {
            item_id = materialId,
            name = string.format('%s Core %d', theme.id:gsub('^%l', string.upper), variant),
            type = 'material',
            required_level = math.max(1, level - 3),
            attack = 0,
            defense = 0,
            stackable = true,
            npc_price = 8 + (themeIndex * 4) + variant,
            rarity = variant >= 3 and 'uncommon' or 'common',
            asset_key = 'item/' .. materialId,
            progression_tier = variant,
            excitement = variant >= 3 and 'crafting_breakpoint' or 'steady income',
        }

        registry.drop_tables[mobId] = {
            { item_id = materialId, chance = 0.58, min_qty = 1, max_qty = 3, rarity = variant >= 3 and 'uncommon' or 'common', bind_on_pickup = false, anticipation = variant >= 3 and 'notable' or 'steady' },
            { item_id = consumables[math.min(#consumables, math.max(1, math.ceil(variant / 2)))].id, chance = 0.22, min_qty = 1, max_qty = 2, rarity = 'common', bind_on_pickup = false, anticipation = 'support' },
        }
    end

    for archetypeIndex, archetype in ipairs(itemArchetypes) do
        local itemId = string.format('%s_%s', theme.id, archetype.id)
        registry.items[itemId] = {
            item_id = itemId,
            name = string.format('%s %s', theme.id:gsub('^%l', string.upper), archetype.id:gsub('_', ' ')),
            type = archetype.slot,
            required_level = theme.level + (archetypeIndex * 2),
            attack = archetype.attack + (themeIndex * (archetype.slot == 'weapon' and 5 or 1)),
            defense = archetype.defense + themeIndex,
            stackable = false,
            npc_price = 160 + (themeIndex * 140) + (archetypeIndex * 40),
            rarity = themeIndex >= 5 and 'rare' or archetype.rarity,
            asset_key = 'item/' .. itemId,
            progression_tier = themeIndex + archetypeIndex,
            upgrade_path = theme.id .. '_reforge',
            desirability = archetype.slot == 'weapon' and 'power spike' or 'set completion',
        }
    end

    local bossId = theme.id .. '_overseer'
    registry.bosses[bossId] = {
        boss_id = bossId,
        name = theme.id:gsub('^%l', string.upper) .. ' Overseer',
        map_id = bossMap,
        hp = 2500 + (themeIndex * 3200),
        trigger = themeIndex % 2 == 0 and 'scheduled_window' or 'channel_presence',
        cooldown_sec = 900 + (themeIndex * 240),
        rare_drop_group = bossId .. '_rares',
        asset_key = 'boss/' .. bossId,
        uniqueness = themeIndex >= 5 and 'world_unique' or 'channel_unique',
        raid = themeIndex >= 4,
        mechanics = {
            [1] = { pattern = 'pressure_lane', hazard = 'slam', text = 'The boss controls space and forces movement.' },
            [2] = { pattern = 'summon_ring', hazard = 'orbital_shards', text = 'Adds and hazards overlap; support matters.' },
            [3] = { pattern = 'berserk_cycle', hazard = 'arena_burst', text = 'Final burn phase with lethal damage windows.' },
        },
    }
    registry.drop_tables[bossId] = {
        { item_id = string.format('%s_%s', theme.id, itemArchetypes[1].id), chance = 0.4, min_qty = 1, max_qty = 1, rarity = 'rare', bind_on_pickup = false, anticipation = 'jackpot' },
        { item_id = string.format('%s_%s', theme.id, itemArchetypes[8].id), chance = 1.0, min_qty = 1, max_qty = 1, rarity = 'epic', bind_on_pickup = false, anticipation = 'boss_signature' },
        { item_id = string.format('%s_material_%02d', theme.id, 4), chance = 1.0, min_qty = 3, max_qty = 6, rarity = 'rare', bind_on_pickup = false, anticipation = 'crafting_cache' },
    }

    for questIndex = 1, 4 do
        local questId = string.format('%s_story_%02d', theme.id, questIndex)
        local killTarget = string.format('%s_mob_%02d', theme.id, math.min(4, questIndex))
        local collectItem = string.format('%s_material_%02d', theme.id, math.min(4, questIndex))
        registry.quests[questId] = {
            quest_id = questId,
            name = string.format('%s Campaign %d', theme.id:gsub('^%l', string.upper), questIndex),
            required_level = theme.level + ((questIndex - 1) * 5),
            objectives = {
                { type = 'kill', targetId = killTarget, required = 6 + (questIndex * 2) },
                { type = 'collect', targetId = collectItem, required = 3 + questIndex },
            },
            reward_exp = 120 + (themeIndex * 80) + (questIndex * 40),
            reward_mesos = 240 + (themeIndex * 120) + (questIndex * 70),
            reward_items = {
                { itemId = string.format('%s_%s', theme.id, itemArchetypes[((questIndex - 1) % #itemArchetypes) + 1].id), quantity = 1 },
            },
            start_npc = theme.id .. '_guide',
            end_npc = theme.id .. '_guide',
            arc = theme.id,
            narrative = string.format('The %s frontier is destabilizing. Campaign step %d pushes the player deeper into the regional threat.', theme.id, questIndex),
            reward_summary = 'story gear + region materials + route unlock pressure',
            guidance = questIndex == 1 and 'Start in the field loop, then step into the dungeon once potion flow stabilizes.' or 'Push the harder route and prepare for the boss map.',
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
        terrainStrategy = mapId == 'forest_edge' and 'edge platforms reward careful pulls' or 'straight route with simple monster cycling',
        verticalLayers = { 'base path', 'branch lane' },
        movementRoutes = { 'legacy sweep', 'return rope' },
        socialHotspots = { 'npc stop', 'entry rope' },
        lore = map.name .. ' remains as a nostalgia route inside the broader world.',
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
    registry.items[itemId] = {
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
    }
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
        name = mobId:gsub('_', ' '),
        level = mob.level,
        hp = mob.hp,
        exp = mob.exp,
        mesos_min = mob.mesos_min,
        mesos_max = mob.mesos_max,
        map_pool = mob.map_pool,
        respawn_sec = mob.respawn_sec,
        asset_key = 'mob/' .. mobId,
        role = 'compatibility',
        identity = 'legacy mob used to preserve early route familiarity',
        hitReaction = 'light_flinch',
    }
end

registry.bosses.mano = { boss_id = 'mano', name = 'Mano', map_id = 'forest_edge', hp = 5000, trigger = 'channel_presence', cooldown_sec = 1800, rare_drop_group = 'mano_rares', asset_key = 'boss/mano', uniqueness = 'channel_unique', mechanics = { [1] = { pattern = 'shell_wave' }, [2] = { pattern = 'slam' }, [3] = { pattern = 'rage_burst' } } }
registry.bosses.stumpy = { boss_id = 'stumpy', name = 'Stumpy', map_id = 'perion_rocky', hp = 12000, trigger = 'scheduled_window', cooldown_sec = 2700, rare_drop_group = 'stumpy_rares', asset_key = 'boss/stumpy', uniqueness = 'channel_unique', mechanics = { [1] = { pattern = 'axe_sweep' }, [2] = { pattern = 'stomp' }, [3] = { pattern = 'stone_fall' } } }

registry.drop_tables.snail = {
    { item_id = 'snail_shell', chance = 0.65, min_qty = 1, max_qty = 2, rarity = 'common', bind_on_pickup = false },
    { item_id = 'red_potion', chance = 0.15, min_qty = 1, max_qty = 1, rarity = 'common', bind_on_pickup = false },
}
registry.drop_tables.orange_mushroom = {
    { item_id = 'mushroom_spore', chance = 0.55, min_qty = 1, max_qty = 2, rarity = 'common', bind_on_pickup = false },
    { item_id = 'mushcap_hat', chance = 0.06, min_qty = 1, max_qty = 1, rarity = 'uncommon', bind_on_pickup = false },
}
registry.drop_tables.horny_mushroom = {
    { item_id = 'wooden_armor', chance = 0.08, min_qty = 1, max_qty = 1, rarity = 'common', bind_on_pickup = false },
    { item_id = 'red_potion', chance = 0.45, min_qty = 1, max_qty = 3, rarity = 'common', bind_on_pickup = false },
}
registry.drop_tables.zombie_mushroom = {
    { item_id = 'zombie_glove', chance = 0.04, min_qty = 1, max_qty = 1, rarity = 'rare', bind_on_pickup = false },
    { item_id = 'hp_potion', chance = 0.35, min_qty = 1, max_qty = 2, rarity = 'common', bind_on_pickup = false },
}
registry.drop_tables.mano = {
    { item_id = 'mano_shell', chance = 1.0, min_qty = 1, max_qty = 1, rarity = 'rare', bind_on_pickup = false },
    { item_id = 'sword_bronze', chance = 0.25, min_qty = 1, max_qty = 1, rarity = 'uncommon', bind_on_pickup = false },
}
registry.drop_tables.stumpy = {
    { item_id = 'stumpy_axe', chance = 1.0, min_qty = 1, max_qty = 1, rarity = 'epic', bind_on_pickup = false },
    { item_id = 'wooden_armor', chance = 0.2, min_qty = 1, max_qty = 1, rarity = 'common', bind_on_pickup = false },
}

registry.npcs.Rina = { npc_id = 'Rina', name = 'Rina', map_id = 'henesys_hunting_ground', x = 20, y = 0, z = 0, shopId = 'henesys_general', dialogue_id = 'Rina_dialogue', catalog = { hp_potion = true, red_potion = true, snail_shell = true, mushroom_spore = true }, services = { 'shop', 'quest' } }
registry.npcs.Sera = { npc_id = 'Sera', name = 'Sera', map_id = 'henesys_hunting_ground', x = 20, y = 0, z = 0, shopId = 'henesys_general', dialogue_id = 'Sera_dialogue', catalog = { hp_potion = true, red_potion = true, snail_shell = true, mushroom_spore = true }, services = { 'shop', 'quest' } }
registry.npcs.Chief_Stan = { npc_id = 'Chief_Stan', name = 'Chief Stan', map_id = 'forest_edge', x = 80, y = 0, z = 0, shopId = 'forest_trade', dialogue_id = 'Chief_Stan_dialogue', catalog = { hp_potion = true, red_potion = true, mano_shell = true }, services = { 'shop', 'quest' } }

registry.dialogues.Rina_dialogue = { npc_id = 'Rina', greeting = 'Start with snails. Learn the rhythm of combat first.', personality = 'warm field captain', nodes = { start = { text = 'Clear snails, gather drops, then come back stronger. If the shells stop dropping, move one platform over and keep the loop alive.' } } }
registry.dialogues.Sera_dialogue = { npc_id = 'Sera', greeting = 'Spores and potions keep the early route moving.', personality = 'precise herbalist', nodes = { start = { text = 'Collect what the mushrooms leave behind. The spores pay for your next stretch of hunting.' } } }
registry.dialogues.Chief_Stan_dialogue = { npc_id = 'Chief_Stan', greeting = 'Field bosses shape the frontier.', personality = 'tired veteran', nodes = { start = { text = 'Push the edge, then challenge Mano. The whole route feels different once that shell drops.' } } }

registry.quests.q_snail_cleanup = {
    quest_id = 'q_snail_cleanup', name = 'Snail Cleanup', required_level = 1,
    objectives = { { type = 'kill', targetId = 'snail', required = 5 } },
    reward_exp = 40, reward_mesos = 100, reward_items = { { itemId = 'red_potion', quantity = 5 } },
    start_npc = 'Rina', end_npc = 'Rina', arc = 'legacy',
    narrative = 'Rina wants the beginner route made safe so new hunters stop burning all their potions on snails.',
    reward_summary = 'starter sustain package',
    guidance = 'Stay on the lower path until five kills are secured, then return to town.',
}
registry.quests.q_spore_collection = {
    quest_id = 'q_spore_collection', name = 'Spore Collection', required_level = 8,
    objectives = { { type = 'collect', targetId = 'mushroom_spore', required = 4 } },
    reward_exp = 120, reward_mesos = 260, reward_items = { { itemId = 'hp_potion', quantity = 3 } },
    start_npc = 'Sera', end_npc = 'Sera', arc = 'legacy',
    narrative = 'Sera is rebuilding potion stock from mushroom spores after the local supply line fell behind.',
    reward_summary = 'consumables and mesos for the next hunt route',
    guidance = 'Farm orange mushrooms until the potion loop feels self-sustaining.',
}
registry.quests.q_mano_hunt = {
    quest_id = 'q_mano_hunt', name = 'Mano Suppression', required_level = 18,
    objectives = { { type = 'kill', targetId = 'mano', required = 1 } },
    reward_exp = 800, reward_mesos = 1200, reward_items = { { itemId = 'mano_shell', quantity = 1 } },
    start_npc = 'Chief_Stan', end_npc = 'Chief_Stan', arc = 'legacy',
    narrative = 'Chief Stan needs proof that Mano’s pressure over the forest edge has been broken.',
    reward_summary = 'boss trophy and meaningful equipment pivot',
    guidance = 'Bring support items, clear the route, then burst the boss during safe windows.',
}

function Registry.load()
    return clone(registry)
end

return Registry
