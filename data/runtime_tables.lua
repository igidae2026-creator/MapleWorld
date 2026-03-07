local ContentLoader = require('data.content_loader')

local loaded = ContentLoader.load()
local content = loaded.content

local runtime = {
    mobs = {},
    items = {},
    drops = {},
    exp_curve = {},
    boss = {},
    quests = {},
}

for _, mob in pairs(content.mobs or {}) do
    runtime.mobs[#runtime.mobs + 1] = {
        mob_id = mob.mob_id,
        name = mob.name,
        level = tostring(mob.level),
        hp = tostring(mob.hp),
        exp = tostring(mob.exp),
        mesos_min = tostring(mob.mesos_min),
        mesos_max = tostring(mob.mesos_max),
        map_pool = mob.map_pool,
        respawn_sec = tostring(mob.respawn_sec),
        asset_key = mob.asset_key,
    }
end
table.sort(runtime.mobs, function(a, b) return a.mob_id < b.mob_id end)

for _, item in pairs(content.items or {}) do
    runtime.items[#runtime.items + 1] = {
        item_id = item.item_id,
        name = item.name,
        type = item.type,
        required_level = tostring(item.required_level),
        attack = tostring(item.attack),
        defense = tostring(item.defense),
        stackable = item.stackable and 'true' or 'false',
        npc_price = tostring(item.npc_price),
        rarity = item.rarity,
        asset_key = item.asset_key,
        progression_tier = tostring(item.progression_tier or item.required_level or 1),
        desirability = item.desirability,
        upgrade_path = item.upgrade_path,
        excitement = item.excitement,
    }
end
table.sort(runtime.items, function(a, b) return a.item_id < b.item_id end)

for ownerId, rows in pairs(content.drop_tables or {}) do
    for _, row in ipairs(rows) do
        runtime.drops[#runtime.drops + 1] = {
            mob_id = ownerId,
            item_id = row.item_id,
            chance = tostring(row.chance),
            min_qty = tostring(row.min_qty),
            max_qty = tostring(row.max_qty),
            rarity = row.rarity,
            bind_on_pickup = row.bind_on_pickup and 'true' or 'false',
            anticipation = row.anticipation,
        }
    end
end
table.sort(runtime.drops, function(a, b)
    if a.mob_id == b.mob_id then return a.item_id < b.item_id end
    return a.mob_id < b.mob_id
end)

for level = 1, 220 do
    local base = math.floor((level * level * level * 0.4) + (level * 24) + 15)
    runtime.exp_curve[#runtime.exp_curve + 1] = {
        level = tostring(level),
        exp_to_next = tostring(base),
    }
end

for _, boss in pairs(content.bosses or {}) do
    runtime.boss[#runtime.boss + 1] = {
        boss_id = boss.boss_id,
        name = boss.name,
        map_id = boss.map_id,
        hp = tostring(boss.hp),
        trigger = boss.trigger,
        cooldown_sec = tostring(boss.cooldown_sec),
        rare_drop_group = boss.rare_drop_group,
        asset_key = boss.asset_key,
    }
end
table.sort(runtime.boss, function(a, b) return a.boss_id < b.boss_id end)

for _, quest in pairs(content.quests or {}) do
    local objectives = {}
    for _, objective in ipairs(quest.objectives or {}) do
        objectives[#objectives + 1] = string.format('%s:%s:%s', tostring(objective.type), tostring(objective.targetId), tostring(objective.required))
    end
    local rewardItems = {}
    for _, reward in ipairs(quest.reward_items or {}) do
        rewardItems[#rewardItems + 1] = string.format('%s:%s', tostring(reward.itemId), tostring(reward.quantity))
    end
    runtime.quests[#runtime.quests + 1] = {
        quest_id = quest.quest_id,
        name = quest.name,
        required_level = tostring(quest.required_level),
        objectives = table.concat(objectives, '|'),
        reward_exp = tostring(quest.reward_exp),
        reward_mesos = tostring(quest.reward_mesos),
        reward_items = table.concat(rewardItems, '|'),
        start_npc = quest.start_npc,
        end_npc = quest.end_npc,
        narrative = quest.narrative,
        reward_summary = quest.reward_summary,
        guidance = quest.guidance,
    }
end
table.sort(runtime.quests, function(a, b) return a.quest_id < b.quest_id end)

runtime.region_level_ranges = {
    starter_fields = { min = 1, max = 18, hub = 'starter_fields_town_01', entry = 'forest_edge' },
    henesys_plains = { min = 6, max = 28, hub = 'henesys_town', entry = 'henesys_hunting_ground' },
    ellinia_forest = { min = 18, max = 42, hub = 'ellinia_forest_town_01', entry = 'ellinia_forest_combat_01' },
    perion_rocklands = { min = 28, max = 56, hub = 'perion_rocklands_town_01', entry = 'perion_rocky' },
    sleepywood_depths = { min = 35, max = 68, hub = 'sleepywood_depths_town_01', entry = 'ant_tunnel_1' },
    kerning_city_shadow = { min = 32, max = 70, hub = 'kerning_city_shadow_town_01', entry = 'kerning_city_shadow_combat_01' },
    orbis_skyrealm = { min = 48, max = 82, hub = 'orbis_skyrealm_town_01', entry = 'orbis_skyrealm_combat_01' },
    ludibrium_clockwork = { min = 55, max = 92, hub = 'ludibrium_clockwork_town_01', entry = 'ludibrium_clockwork_combat_01' },
    elnath_snowfield = { min = 68, max = 106, hub = 'elnath_snowfield_town_01', entry = 'elnath_snowfield_combat_01' },
    minar_mountain = { min = 78, max = 118, hub = 'minar_mountain_town_01', entry = 'minar_mountain_combat_01' },
    coastal_harbors = { min = 22, max = 60, hub = 'coastal_harbors_town_01', entry = 'coastal_harbors_combat_01' },
    ancient_hidden_domains = { min = 88, max = 132, hub = 'ancient_hidden_domains_town_01', entry = 'ancient_hidden_domains_combat_01' },
}

runtime.drop_probability_tables = {
    field = { common = 0.48, support = 0.26, regional = 0.18, rare = 0.04, chase = 0.03 },
    dungeon = { common = 0.39, support = 0.22, regional = 0.22, rare = 0.09, chase = 0.05 },
    hidden = { common = 0.30, support = 0.15, regional = 0.24, rare = 0.12, chase = 0.08 },
    boss = { signature = 0.70, armor = 0.62, accessory = 0.55, crafting = 1.00, trophy = 1.00 },
}

runtime.rarity_weights = {
    common = 100,
    uncommon = 56,
    rare = 21,
    epic = 7,
    legendary = 2,
}

runtime.boss_respawn_groups = {
    starter_rotation = { 'mano', 'dbexp_starter_fields_boss_001', 'dbexp_starter_fields_boss_002' },
    frontier_rotation = { 'stumpy', 'dbexp_henesys_plains_boss_001', 'dbexp_perion_rocklands_boss_001', 'dbexp_coastal_harbors_boss_001' },
    dungeon_rotation = { 'dbexp_sleepywood_depths_boss_001', 'dbexp_kerning_city_shadow_boss_003', 'dbexp_ludibrium_clockwork_boss_003', 'dbexp_ancient_hidden_domains_boss_003' },
    apex_rotation = { 'dbexp_orbis_skyrealm_boss_005', 'dbexp_elnath_snowfield_boss_005', 'dbexp_minar_mountain_boss_005', 'dbexp_ancient_hidden_domains_boss_005' },
}

runtime.quest_difficulty_scaling = {
    beginner_cleanup = { objective = 1.0, reward = 1.0, travel = 0.8 },
    collection = { objective = 1.1, reward = 1.05, travel = 0.9 },
    hunt_elimination = { objective = 1.2, reward = 1.15, travel = 1.0 },
    delivery_travel = { objective = 0.9, reward = 1.1, travel = 1.25 },
    npc_story_chain = { objective = 1.0, reward = 1.2, travel = 1.1 },
    boss_intro = { objective = 1.5, reward = 1.6, travel = 1.0 },
    repeatable = { objective = 1.15, reward = 0.95, travel = 0.95 },
    hidden_trigger = { objective = 1.65, reward = 1.75, travel = 1.35 },
}

runtime.region_equipment_weights = {
    starter_fields = { weapon = 1.25, armor = 1.1, accessory = 0.8, consumable = 1.3 },
    henesys_plains = { weapon = 1.3, armor = 1.15, accessory = 0.85, consumable = 1.25 },
    ellinia_forest = { weapon = 1.05, armor = 1.0, accessory = 1.2, consumable = 1.1 },
    perion_rocklands = { weapon = 1.35, armor = 1.25, accessory = 0.75, consumable = 1.0 },
    sleepywood_depths = { weapon = 1.2, armor = 1.3, accessory = 0.9, consumable = 1.15 },
    kerning_city_shadow = { weapon = 1.15, armor = 0.95, accessory = 1.1, consumable = 1.05 },
    orbis_skyrealm = { weapon = 1.1, armor = 1.0, accessory = 1.25, consumable = 1.0 },
    ludibrium_clockwork = { weapon = 1.2, armor = 1.15, accessory = 1.05, consumable = 1.0 },
    elnath_snowfield = { weapon = 1.25, armor = 1.3, accessory = 0.95, consumable = 1.1 },
    minar_mountain = { weapon = 1.35, armor = 1.2, accessory = 1.0, consumable = 1.05 },
    coastal_harbors = { weapon = 1.1, armor = 1.0, accessory = 1.15, consumable = 1.2 },
    ancient_hidden_domains = { weapon = 1.3, armor = 1.25, accessory = 1.35, consumable = 0.95 },
}

return runtime
