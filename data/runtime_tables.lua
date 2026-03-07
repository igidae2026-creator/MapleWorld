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

return runtime
