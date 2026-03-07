local SpawnSystem = {}

function SpawnSystem.new(config)
    local cfg = config or {}
    local self = {
        maps = {},
        mobs = cfg.mobs or {},
        scheduler = cfg.scheduler,
        metrics = cfg.metrics,
        logger = cfg.logger,
        rng = cfg.rng or math.random,
        nextSpawnId = 1,
        maxSpawnPerTick = cfg.maxSpawnPerTick or 4,
        callbacks = cfg.callbacks or {},
    }
    setmetatable(self, { __index = SpawnSystem })
    return self
end

function SpawnSystem:_now()
    if self.scheduler and self.scheduler.now then return self.scheduler.now end
    return os.time()
end

function SpawnSystem:_emit(name, ...)
    local fn = self.callbacks and self.callbacks[name]
    if type(fn) ~= 'function' then return end
    local ok, err = pcall(fn, ...)
    if not ok and self.metrics then
        self.metrics:increment('spawn.callback_error', 1, { callback = tostring(name) })
        self.metrics:error('spawn_callback_failed', { callback = tostring(name), error = tostring(err) })
    end
end

function SpawnSystem:registerMap(mapId, spawnGroups)
    local groups, groupIndex = {}, {}
    for _, group in ipairs(spawnGroups or {}) do
        local mobDef = self.mobs[group.mobId] or {}
        local normalized = {
            id = group.id,
            mobId = group.mobId,
            maxAlive = tonumber(group.maxAlive) or 0,
            points = group.points or {},
            respawnSec = tonumber(group.respawnSec or mobDef.respawn_sec) or 5,
            disabled = false,
        }
        groups[#groups + 1] = normalized
        groupIndex[normalized.id] = normalized
    end
    self.maps[mapId] = {
        id = mapId,
        groups = groups,
        groupIndex = groupIndex,
        groupState = {},
        active = {},
        activeByMobId = {},
        activeByGroupId = {},
    }
end

function SpawnSystem:activeCount(mapId, mobId, groupId)
    local mapState = self.maps[mapId]
    if not mapState then return 0 end
    if groupId then return mapState.activeByGroupId[groupId] or 0 end
    if mobId then return mapState.activeByMobId[mobId] or 0 end
    local total = 0
    for _, count in pairs(mapState.activeByMobId) do total = total + (tonumber(count) or 0) end
    return total
end

function SpawnSystem:_ensureGroupState(mapState, group)
    local state = mapState.groupState[group.id]
    if not state then
        state = { bootstrapped = false, nextRespawnAt = 0 }
        mapState.groupState[group.id] = state
    end
    return state
end

function SpawnSystem:_validateGroup(group)
    if group.disabled then return false end
    if not self.mobs[group.mobId] then
        group.disabled = true
        if self.metrics then self.metrics:error('spawn_group_invalid_mob', { group = tostring(group.id), mob = tostring(group.mobId) }) end
        return false
    end
    if #group.points == 0 then
        group.disabled = true
        if self.metrics then self.metrics:error('spawn_group_missing_points', { group = tostring(group.id) }) end
        return false
    end
    return true
end

function SpawnSystem:_spawnOne(mapState, group)
    if not self:_validateGroup(group) then return nil end

    local mobDef = self.mobs[group.mobId]
    local spawnId = self.nextSpawnId
    self.nextSpawnId = self.nextSpawnId + 1
    local point = group.points[((spawnId - 1) % #group.points) + 1]
    local mob = {
        spawnId = spawnId,
        mobId = group.mobId,
        mapId = mapState.id,
        x = point.x,
        y = point.y,
        hp = tonumber(mobDef.hp) or 1,
        maxHp = tonumber(mobDef.hp) or 1,
        alive = true,
        spawnedAt = self:_now(),
        template = mobDef,
        spawnGroupId = group.id,
    }
    mapState.active[spawnId] = mob
    mapState.activeByMobId[mob.mobId] = (mapState.activeByMobId[mob.mobId] or 0) + 1
    mapState.activeByGroupId[group.id] = (mapState.activeByGroupId[group.id] or 0) + 1
    if self.metrics then self.metrics:increment('spawn.mob', 1, { map = mapState.id, mob = mob.mobId }) end
    if self.logger and self.logger.info then self.logger:info('mob_spawned', { mapId = mapState.id, mobId = mob.mobId, spawnId = spawnId }) end
    self:_emit('onSpawn', mob)
    return mob
end

function SpawnSystem:_removeMob(mapState, mob, reason)
    if not mapState or not mob or not mob.alive then return nil end
    mob.alive = false
    mapState.active[mob.spawnId] = nil
    if mapState.activeByMobId[mob.mobId] and mapState.activeByMobId[mob.mobId] > 0 then
        mapState.activeByMobId[mob.mobId] = mapState.activeByMobId[mob.mobId] - 1
    end
    if mapState.activeByGroupId[mob.spawnGroupId] and mapState.activeByGroupId[mob.spawnGroupId] > 0 then
        mapState.activeByGroupId[mob.spawnGroupId] = mapState.activeByGroupId[mob.spawnGroupId] - 1
    end

    local group = mapState.groupIndex[mob.spawnGroupId]
    local state = group and self:_ensureGroupState(mapState, group) or nil
    if state and group then
        local nextAt = self:_now() + (tonumber(group.respawnSec) or 5)
        if nextAt > state.nextRespawnAt then state.nextRespawnAt = nextAt end
    end

    if self.metrics then self.metrics:increment('spawn.mob_killed', 1, { map = mapState.id, mob = mob.mobId, reason = tostring(reason or 'unknown') }) end
    if self.logger and self.logger.info then self.logger:info('mob_killed', { mapId = mapState.id, mobId = mob.mobId, spawnId = mob.spawnId }) end
    self:_emit('onKill', mob, reason)
    return mob
end

function SpawnSystem:tickMap(mapId)
    local mapState = self.maps[mapId]
    if not mapState then return end

    local now = self:_now()
    for _, group in ipairs(mapState.groups) do
        local state = self:_ensureGroupState(mapState, group)
        local current = self:activeCount(mapState.id, nil, group.id)
        if not state.bootstrapped then
            while current < group.maxAlive do
                if not self:_spawnOne(mapState, group) then break end
                current = current + 1
            end
            state.bootstrapped = true
            state.nextRespawnAt = now + group.respawnSec
        else
            local spawned = 0
            while current < group.maxAlive and now >= state.nextRespawnAt and spawned < self.maxSpawnPerTick do
                if not self:_spawnOne(mapState, group) then break end
                current = current + 1
                spawned = spawned + 1
                state.nextRespawnAt = state.nextRespawnAt + group.respawnSec
            end
            if current >= group.maxAlive and state.nextRespawnAt < now then
                state.nextRespawnAt = now + group.respawnSec
            end
        end
    end
end

function SpawnSystem:tick()
    for mapId in pairs(self.maps) do
        self:tickMap(mapId)
    end
end

function SpawnSystem:getMob(mapId, spawnId)
    local mapState = self.maps[mapId]
    return mapState and mapState.active[spawnId] or nil
end

function SpawnSystem:damageMob(mapId, spawnId, amount)
    local damage = math.floor(tonumber(amount) or 0)
    if damage <= 0 then return false, 'invalid_amount' end

    local mapState = self.maps[mapId]
    local mob = mapState and mapState.active[spawnId] or nil
    if not mob or not mob.alive then return false, 'mob_not_found' end

    mob.hp = math.max(0, mob.hp - damage)
    mob.lastDamagedAt = self:_now()
    if self.metrics then self.metrics:increment('spawn.mob_damage', damage, { map = mapId, mob = mob.mobId }) end
    if mob.hp == 0 then
        local killed = self:_removeMob(mapState, mob, 'damage')
        return true, killed, true
    end
    return true, mob, false
end

function SpawnSystem:killMob(mapId, spawnId)
    local mapState = self.maps[mapId]
    local mob = mapState and mapState.active[spawnId] or nil
    if not mob or not mob.alive then return nil end
    return self:_removeMob(mapState, mob, 'kill')
end

return SpawnSystem
