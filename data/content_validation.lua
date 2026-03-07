local ContentValidation = {}

local RegionalProgression = require('data.regional_progression_tables')
local RareSpawnTables = require('data.rare_spawn_tables')

function ContentValidation.validate(content)
    local errors, warnings = {}, {}
    local function err(message) errors[#errors + 1] = message end
    local function warn(message) warnings[#warnings + 1] = message end

    local maps = content.maps or {}
    local items = content.items or {}
    local mobs = content.mobs or {}
    local bosses = content.bosses or {}
    local npcs = content.npcs or {}

    for mapId, map in pairs(maps) do
        for transitionId in pairs(map.transitions or {}) do
            if not maps[transitionId] then
                err('missing_map_transition:' .. tostring(mapId) .. '->' .. tostring(transitionId))
            end
        end
        if type(map.verticalLayers) ~= 'table' or #map.verticalLayers < 2 then
            warn('map_verticality_sparse:' .. tostring(mapId))
        end
        if type(map.movementRoutes) ~= 'table' or #map.movementRoutes < 2 then
            warn('map_routes_sparse:' .. tostring(mapId))
        end
    end

    for mobId, mob in pairs(mobs) do
        if not maps[mob.map_pool] then err('mob_map_missing:' .. tostring(mobId)) end
        if tonumber(mob.level) <= 0 then err('mob_level_invalid:' .. tostring(mobId)) end
    end

    for bossId, boss in pairs(bosses) do
        if not maps[boss.map_id] then err('boss_map_missing:' .. tostring(bossId)) end
        if tonumber(boss.hp) <= 0 then err('boss_hp_invalid:' .. tostring(bossId)) end
    end

    for itemId, item in pairs(items) do
        if item.stackable ~= true and item.stackable ~= false then
            err('item_stackable_invalid:' .. tostring(itemId))
        end
        if tonumber(item.npc_price) < 0 then err('item_price_invalid:' .. tostring(itemId)) end
    end

    for npcId, npc in pairs(npcs) do
        if not maps[npc.map_id] then err('npc_map_missing:' .. tostring(npcId)) end
        for itemId in pairs(npc.catalog or {}) do
            if not items[itemId] then err('npc_catalog_item_missing:' .. tostring(npcId) .. ':' .. tostring(itemId)) end
        end
    end

    for questId, quest in pairs(content.quests or {}) do
        if not npcs[quest.start_npc] then err('quest_start_npc_missing:' .. tostring(questId)) end
        if not npcs[quest.end_npc] then err('quest_end_npc_missing:' .. tostring(questId)) end
        for _, objective in ipairs(quest.objectives or {}) do
            if objective.type == 'kill' and not (mobs[objective.targetId] or bosses[objective.targetId]) then
                err('quest_kill_target_missing:' .. tostring(questId) .. ':' .. tostring(objective.targetId))
            elseif objective.type == 'collect' and not items[objective.targetId] then
                err('quest_collect_item_missing:' .. tostring(questId) .. ':' .. tostring(objective.targetId))
            elseif objective.type ~= 'kill' and objective.type ~= 'collect' then
                warn('quest_objective_unknown:' .. tostring(questId) .. ':' .. tostring(objective.type))
            end
        end
        for _, reward in ipairs(quest.reward_items or {}) do
            if not items[reward.itemId] then err('quest_reward_item_missing:' .. tostring(questId) .. ':' .. tostring(reward.itemId)) end
        end
    end

    for mobId, rows in pairs(content.drop_tables or {}) do
        if not (mobs[mobId] or bosses[mobId]) then err('drop_owner_missing:' .. tostring(mobId)) end
        local totalChance = 0
        for _, row in ipairs(rows) do
            if not items[row.item_id] then err('drop_item_missing:' .. tostring(mobId) .. ':' .. tostring(row.item_id)) end
            totalChance = totalChance + (tonumber(row.chance) or 0)
        end
        if totalChance < 0.2 then warn('drop_table_sparse:' .. tostring(mobId)) end
    end

    for regionId, region in pairs(RegionalProgression) do
        for _, mapId in ipairs(region.maps or {}) do
            if not maps[mapId] then err('regional_map_missing:' .. tostring(regionId) .. ':' .. tostring(mapId)) end
        end
        if type(region.milestoneRewards) ~= 'table' or #region.milestoneRewards < 2 then
            warn('regional_milestones_sparse:' .. tostring(regionId))
        end
    end

    for mapId, rareTable in pairs(RareSpawnTables) do
        if not maps[mapId] then err('rare_spawn_map_missing:' .. tostring(mapId)) end
        if not (rareTable.elite and mobs[rareTable.elite.mobId]) then
            err('rare_spawn_elite_missing:' .. tostring(mapId))
        end
        for _, rare in ipairs(rareTable.rares or {}) do
            if not mobs[rare.mobId] then err('rare_spawn_mob_missing:' .. tostring(mapId) .. ':' .. tostring(rare.mobId)) end
            if not items[rare.reward] then err('rare_spawn_reward_missing:' .. tostring(mapId) .. ':' .. tostring(rare.reward)) end
        end
    end

    local regionCount = 0
    for _ in pairs(RegionalProgression) do regionCount = regionCount + 1 end
    local rareSpawnMapCount = 0
    for _ in pairs(RareSpawnTables) do rareSpawnMapCount = rareSpawnMapCount + 1 end

    return {
        ok = #errors == 0,
        errors = errors,
        warnings = warnings,
        summary = {
            errors = #errors,
            warnings = #warnings,
            regions = regionCount,
            rareSpawnMaps = rareSpawnMapCount,
        },
    }
end

return ContentValidation
