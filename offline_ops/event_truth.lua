local EventTruth = {}

local function deepcopy(value, seen)
    if type(value) ~= 'table' then return value end
    local visited = seen or {}
    if visited[value] then return visited[value] end
    local copy = {}
    visited[value] = copy
    for k, v in pairs(value) do
        copy[deepcopy(k, visited)] = deepcopy(v, visited)
    end
    return copy
end

function EventTruth.enrich(eventType, payload, context)
    local ctx = context or {}
    local eventPayload = deepcopy(payload or {})
    eventPayload.truth_type = tostring(ctx.truthType or eventType)
    eventPayload.actor_id = eventPayload.actor_id or ctx.actorId
    eventPayload.player_id = eventPayload.player_id or ctx.playerId
    eventPayload.map_id = eventPayload.map_id or ctx.mapId
    eventPayload.boss_id = eventPayload.boss_id or ctx.bossId
    eventPayload.drop_id = eventPayload.drop_id or ctx.dropId
    eventPayload.spawn_id = eventPayload.spawn_id or ctx.spawnId
    eventPayload.quest_id = eventPayload.quest_id or ctx.questId
    eventPayload.item_id = eventPayload.item_id or ctx.itemId
    eventPayload.npc_id = eventPayload.npc_id or ctx.npcId
    eventPayload.correlation_id = eventPayload.correlation_id or ctx.correlationId
    eventPayload.policy_id = eventPayload.policy_id or ctx.policyId
    eventPayload.policy_version = eventPayload.policy_version or ctx.policyVersion
    eventPayload.lineage_reference = eventPayload.lineage_reference or ctx.lineageReference
    eventPayload.stage_link = eventPayload.stage_link or ctx.stageLink
    eventPayload.runtime_scope = eventPayload.runtime_scope or deepcopy(ctx.runtimeScope)
    eventPayload.owner_scope = eventPayload.owner_scope or deepcopy(ctx.ownerScope)
    return eventPayload
end

function EventTruth.query(entries, filter)
    local out = {}
    local cfg = filter or {}
    for _, entry in ipairs(entries or {}) do
        local payload = entry.payload or {}
        local truthType = tostring(payload.truth_type or entry.event or '')
        local matches = true
        if cfg.event and tostring(entry.event) ~= tostring(cfg.event) then matches = false end
        if cfg.truthType and truthType ~= tostring(cfg.truthType) then matches = false end
        if cfg.playerId and tostring(payload.player_id or payload.playerId or '') ~= tostring(cfg.playerId) then matches = false end
        if cfg.correlationId and tostring(payload.correlation_id or '') ~= tostring(cfg.correlationId) then matches = false end
        if matches then out[#out + 1] = deepcopy(entry) end
    end
    return out
end

return EventTruth
