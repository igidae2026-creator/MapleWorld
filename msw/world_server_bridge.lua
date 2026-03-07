local ServerBootstrap = require('scripts.server_bootstrap')
local RuntimeAdapter = require('ops.runtime_adapter')
local PlayerRepository = require('ops.player_repository')

local WorldServerBridge = {}
WorldServerBridge.__index = WorldServerBridge

local function safeRequire(name)
    local ok, mod = pcall(require, name)
    if ok then return mod end
    return nil
end

local function response(adapter, ok, payload, err)
    return adapter:encodeData({ ok = ok == true, data = payload, error = err })
end

local function normalizePath(path)
    if path == nil then return nil end
    local normalized = tostring(path):gsub('\\', '/')
    normalized = normalized:gsub('/+', '/')
    if normalized == '' then return nil end
    if normalized ~= '/' and normalized:sub(-1) == '/' then
        normalized = normalized:sub(1, -2)
    end
    if normalized == '' then return nil end
    if normalized:sub(1, 1) ~= '/' then
        normalized = '/' .. normalized
    end
    return normalized
end

function WorldServerBridge.new(config)
    local cfg = config or {}
    local self = {
        component = cfg.component,
        runtimeAdapter = cfg.runtimeAdapter or RuntimeAdapter.new({}),
        worldConfig = cfg.worldConfig or safeRequire('data.world_runtime'),
        world = nil,
        playerStateById = {},
        mapStateById = {},
        mobEntities = {},
        dropEntities = {},
        bossEntities = {},
        activeSessions = {},
    }
    setmetatable(self, WorldServerBridge)
    return self
end

function WorldServerBridge:attachComponent(component)
    if component ~= nil then
        self.component = component
    end
    return self.component
end

function WorldServerBridge:_setComponentField(name, value)
    if not self.component then return end
    pcall(function() self.component[name] = value end)
end

function WorldServerBridge:_cachePlayerState(playerId, snapshot)
    self.playerStateById[playerId] = snapshot
    self:_setComponentField('LastSyncUserId', tostring(playerId))
    self:_setComponentField('LastPlayerStateJson', self.runtimeAdapter:encodeData(snapshot))
end

function WorldServerBridge:_cacheMapState(mapId, state)
    if not mapId then return end
    self.mapStateById[mapId] = state
    self:_setComponentField('LastMapStateJson', self.runtimeAdapter:encodeData(state))
end

function WorldServerBridge:_invalidateMapState(mapId)
    if mapId then self.mapStateById[mapId] = nil end
end

function WorldServerBridge:_cachedMapState(mapId)
    if not mapId then return nil end
    local cached = self.mapStateById[mapId]
    if cached == nil then
        cached = self.world:getMapState(mapId)
        self:_cacheMapState(mapId, cached)
    end
    return cached
end

function WorldServerBridge:_insertCachedMob(mob)
    local cached = mob and mob.mapId and self.mapStateById[mob.mapId] or nil
    if type(cached) ~= 'table' or type(cached.mobs) ~= 'table' then return false end
    local targetId = tonumber(mob.spawnId)
    local payload = {
        spawnId = mob.spawnId,
        mobId = mob.mobId,
        hp = mob.hp,
        maxHp = mob.maxHp,
        x = mob.x,
        y = mob.y,
        groupId = mob.spawnGroupId,
    }
    for i, current in ipairs(cached.mobs) do
        if tonumber(current.spawnId) == targetId then
            cached.mobs[i] = payload
            return true
        end
    end
    cached.mobs[#cached.mobs + 1] = payload
    table.sort(cached.mobs, function(a, b) return (tonumber(a.spawnId) or 0) < (tonumber(b.spawnId) or 0) end)
    return true
end

function WorldServerBridge:_removeCachedMob(mob)
    local cached = mob and mob.mapId and self.mapStateById[mob.mapId] or nil
    if type(cached) ~= 'table' or type(cached.mobs) ~= 'table' then return false end
    local targetId = tonumber(mob.spawnId)
    for i, current in ipairs(cached.mobs) do
        if tonumber(current.spawnId) == targetId then
            table.remove(cached.mobs, i)
            return true
        end
    end
    return false
end

function WorldServerBridge:_insertCachedDrop(drop)
    local cached = drop and drop.mapId and self.mapStateById[drop.mapId] or nil
    if type(cached) ~= 'table' or type(cached.drops) ~= 'table' then return false end
    local targetId = tonumber(drop.dropId)
    for i, current in ipairs(cached.drops) do
        if tonumber(current.dropId) == targetId then
            cached.drops[i] = drop
            return true
        end
    end
    cached.drops[#cached.drops + 1] = drop
    table.sort(cached.drops, function(a, b) return (tonumber(a.dropId) or 0) < (tonumber(b.dropId) or 0) end)
    return true
end

function WorldServerBridge:_removeCachedDrop(drop)
    local cached = drop and drop.mapId and self.mapStateById[drop.mapId] or nil
    if type(cached) ~= 'table' or type(cached.drops) ~= 'table' then return false end
    local targetId = tonumber(drop.dropId)
    for i, current in ipairs(cached.drops) do
        if tonumber(current.dropId) == targetId then
            table.remove(cached.drops, i)
            return true
        end
    end
    return false
end

function WorldServerBridge:_updateCachedPopulation(mapId)
    local cached = mapId and self.mapStateById[mapId] or nil
    if type(cached) ~= 'table' then return false end
    cached.population = self.world:getMapPopulation(mapId)
    cached.now = self.runtimeAdapter:now()
    return true
end


function WorldServerBridge:_updateCachedMob(mapId, spawnId, hp)
    local cached = mapId and self.mapStateById[mapId] or nil
    local mobs = cached and cached.mobs or nil
    if type(mobs) ~= 'table' then return false end
    local targetId = tonumber(spawnId)
    for _, mob in ipairs(mobs) do
        if tonumber(mob.spawnId) == targetId then
            mob.hp = math.max(0, math.floor(tonumber(hp) or 0))
            return true
        end
    end
    return false
end

function WorldServerBridge:_updateCachedBoss(mapId, encounter)
    local cached = mapId and self.mapStateById[mapId] or nil
    if not cached or type(cached) ~= 'table' or type(cached.boss) ~= 'table' then return false end
    cached.boss.hp = math.max(0, math.floor(tonumber(encounter and encounter.hp) or 0))
    cached.boss.maxHp = math.max(1, math.floor(tonumber(encounter and encounter.maxHp) or cached.boss.maxHp or 1))
    cached.boss.phase = math.max(1, math.floor(tonumber(encounter and encounter.phase) or cached.boss.phase or 1))
    cached.boss.alive = encounter and encounter.alive == true
    cached.boss.enraged = encounter and encounter.enraged == true
    return true
end

function WorldServerBridge:_defaultMapId()
    return self.worldConfig and self.worldConfig.runtime and self.worldConfig.runtime.defaultMapId or 'henesys_hunting_ground'
end

function WorldServerBridge:_rootAttachPath()
    return normalizePath(self.worldConfig and self.worldConfig.runtime and self.worldConfig.runtime.componentAttachPath) or '/server_runtime'
end

function WorldServerBridge:_mapRuntime(mapId)
    return self.worldConfig and self.worldConfig.maps and self.worldConfig.maps[mapId] and self.worldConfig.maps[mapId].runtime or nil
end

function WorldServerBridge:_entityPath(parentPath, name)
    local parent = normalizePath(parentPath)
    if not parent or not name or name == '' then return nil end
    return parent .. '/' .. tostring(name)
end

function WorldServerBridge:_resolveParentEntity(parentPath)
    local normalizedPath = normalizePath(parentPath)
    if normalizedPath then
        local parent = self.runtimeAdapter:findEntityByPath(normalizedPath)
        if parent ~= nil then return parent end
    end

    local componentEntity = self.runtimeAdapter:getComponentEntity(self.component)
    if componentEntity ~= nil then return componentEntity end
    return nil
end

function WorldServerBridge:_spawnRuntimeEntity(modelId, name, x, y, z, parentPath)
    local entityPath = self:_entityPath(parentPath, name)
    if entityPath then
        local existing = self.runtimeAdapter:findEntityByPath(entityPath)
        if existing then
            self.runtimeAdapter:setEntityPosition(existing, { x = x, y = y, z = z or 0 })
            return existing
        end
    end

    local parent = self:_resolveParentEntity(parentPath)
    return self.runtimeAdapter:spawnModel(modelId, name, self.runtimeAdapter:makeVector3(x, y, z or 0), parent)
end

function WorldServerBridge:_spawnMobEntity(mob)
    local runtime = self:_mapRuntime(mob.mapId)
    local mobDef = self.world and self.world.mobs and self.world.mobs[mob.mobId] or nil
    local modelId = (runtime and runtime.mobModelIds and runtime.mobModelIds[mob.mobId]) or (mobDef and mobDef.assetKey) or nil
    local entity = self:_spawnRuntimeEntity(modelId, 'mob_' .. tostring(mob.spawnId), mob.x, mob.y, mob.z or 0, runtime and runtime.mobParentPath)
    if entity then self.mobEntities[mob.spawnId] = entity end
    if not self:_insertCachedMob(mob) then self:_invalidateMapState(mob.mapId) end
end

function WorldServerBridge:_destroyMobEntity(mob)
    local entity = self.mobEntities[mob.spawnId]
    if entity then self.runtimeAdapter:destroyEntity(entity) end
    self.mobEntities[mob.spawnId] = nil
    if not self:_removeCachedMob(mob) then self:_invalidateMapState(mob.mapId) end
end

function WorldServerBridge:_spawnDropEntity(drop)
    local mapRuntime = self:_mapRuntime(drop.mapId)
    local dropCfg = self.worldConfig and self.worldConfig.drops or {}
    local itemDef = self.world and self.world.items and self.world.items[drop.itemId] or nil
    local modelId = (dropCfg.modelIds and dropCfg.modelIds[drop.itemId]) or dropCfg.defaultModelId or (itemDef and itemDef.assetKey) or nil
    local entity = self:_spawnRuntimeEntity(modelId, 'drop_' .. tostring(drop.dropId), drop.x, drop.y, drop.z or 0, mapRuntime and mapRuntime.dropParentPath)
    if entity then self.dropEntities[drop.dropId] = entity end
    if not self:_insertCachedDrop(drop) then self:_invalidateMapState(drop.mapId) end
end

function WorldServerBridge:_destroyDropEntity(drop)
    local entity = self.dropEntities[drop.dropId]
    if entity then self.runtimeAdapter:destroyEntity(entity) end
    self.dropEntities[drop.dropId] = nil
    if not self:_removeCachedDrop(drop) then self:_invalidateMapState(drop.mapId) end
end

function WorldServerBridge:_spawnBossEntity(encounter)
    local mapRuntime = self:_mapRuntime(encounter.mapId)
    local bossCfg = self.worldConfig and self.worldConfig.bosses and self.worldConfig.bosses[encounter.bossId] or {}
    local bossDef = self.world and self.world.bossSystem and self.world.bossSystem.bossTable and self.world.bossSystem.bossTable[encounter.bossId] or nil
    local pos = encounter.position or bossCfg.spawnPosition or (bossDef and bossDef.position) or { x = 0, y = 0, z = 0 }
    local modelId = bossCfg.modelId or (bossDef and bossDef.modelId) or (self.world and self.world.mobs and self.world.mobs[encounter.bossId] and self.world.mobs[encounter.bossId].assetKey) or nil
    local parentPath = bossCfg.parentPath or (bossDef and bossDef.parentPath) or (mapRuntime and mapRuntime.bossParentPath) or self:_rootAttachPath()
    local entity = self:_spawnRuntimeEntity(modelId, 'boss_' .. tostring(encounter.bossId), pos.x, pos.y, pos.z, parentPath)
    if entity then self.bossEntities[encounter.mapId] = entity end
    self:_invalidateMapState(encounter.mapId)
end

function WorldServerBridge:_destroyBossEntity(encounter)
    local entity = self.bossEntities[encounter.mapId]
    if entity then self.runtimeAdapter:destroyEntity(entity) end
    self.bossEntities[encounter.mapId] = nil
    self:_invalidateMapState(encounter.mapId)
end

function WorldServerBridge:bootstrap()
    if self.world then
        self:attachComponent(self.component)
        return self.world
    end

    local worldConfig = self.worldConfig or safeRequire('data.world_runtime') or {}
    local usePersistentStorage = self.runtimeAdapter:hasDataStorage()
    local repository
    if usePersistentStorage then
        repository = PlayerRepository.newMapleWorldsDataStorage({
            runtimeAdapter = self.runtimeAdapter,
            storageName = worldConfig.runtime and worldConfig.runtime.playerStorageName,
            key = worldConfig.runtime and worldConfig.runtime.playerStorageKey,
            slotCount = worldConfig.runtime and worldConfig.runtime.playerProfileSlotCount,
        })
    else
        repository = PlayerRepository.newMemory({})
    end

    local runtimeHooks = {
        onPlayerEnter = function(world, player)
            self.activeSessions[player.id] = {
                userId = player.id,
                enteredAt = self.runtimeAdapter:now(),
                lastSeenAt = self.runtimeAdapter:now(),
            }
            self:_cachePlayerState(player.id, world:publishPlayerSnapshot(player))
            if not self:_updateCachedPopulation(player.currentMapId) then self:_invalidateMapState(player.currentMapId) end
        end,
        onPlayerLeave = function(world, player)
            self.playerStateById[player.id] = nil
            self.activeSessions[player.id] = nil
        end,
        onPlayerSnapshot = function(world, player, snapshot)
            if self.activeSessions[player.id] then
                self.activeSessions[player.id].lastSeenAt = self.runtimeAdapter:now()
            end
            self:_cachePlayerState(player.id, snapshot)
        end,
        onPlayerMapChanged = function(world, player, mapId)
            if not self:_updateCachedPopulation(mapId) then self:_invalidateMapState(mapId) end
        end,
        onMobSpawned = function(world, mob)
            self:_spawnMobEntity(mob)
        end,
        onMobRemoved = function(world, mob)
            self:_destroyMobEntity(mob)
        end,
        onMobDamaged = function(world, player, mob)
            if not self:_updateCachedMob(mob.mapId, mob.spawnId, mob.hp) then
                self:_invalidateMapState(mob.mapId)
            end
        end,
        onDropSpawned = function(world, drop)
            self:_spawnDropEntity(drop)
        end,
        onDropPicked = function(world, drop)
            self:_destroyDropEntity(drop)
        end,
        onDropExpired = function(world, drop)
            self:_destroyDropEntity(drop)
        end,
        onBossSpawned = function(world, encounter)
            self:_spawnBossEntity(encounter)
        end,
        onBossDamaged = function(world, encounter)
            if not self:_updateCachedBoss(encounter.mapId, encounter) then
                self:_invalidateMapState(encounter.mapId)
            end
        end,
        onBossKilled = function(world, encounter)
            self:_destroyBossEntity(encounter)
        end,
    }

    self.world = ServerBootstrap.boot({
        dataProvider = safeRequire('data.runtime_tables'),
        worldConfig = worldConfig,
        playerRepository = repository,
        runtimeAdapter = self.runtimeAdapter,
        runtimeHooks = runtimeHooks,
        autoPickupDrops = false,
        useMapleWorldsDataStorage = usePersistentStorage,
    })
    self:_setComponentField('BridgeReady', true)
    return self.world
end

function WorldServerBridge:tick(delta)
    self:bootstrap()
    self.world.scheduler:tick(tonumber(delta) or 0)
end

function WorldServerBridge:_resolvePlayer(requestContext, requestedMapId)
    self:bootstrap()
    local authoritative = self.runtimeAdapter:isLive()

    if authoritative then
        local actor, err = self.runtimeAdapter:resolveActorContext(requestContext, {
            authoritativeOnly = true,
        })
        if not actor or not actor.userId then return nil, err or 'invalid_user' end

        local session = self.activeSessions[actor.userId]
        local player = self.world.players[actor.userId]
        if not session or not player then return nil, 'player_not_active' end

        if requestedMapId and actor.mapId and tostring(requestedMapId) ~= tostring(actor.mapId) then
            return nil, 'map_mismatch'
        end

        local mapId = actor.mapId or player.currentMapId or requestedMapId or self:_defaultMapId()
        local ok, updateErr = self.world:updatePlayerRuntimeState(player, mapId, actor.position, true)
        if not ok then return nil, updateErr end
        session.lastSeenAt = self.runtimeAdapter:now()
        return player
    end

    local actor, err = self.runtimeAdapter:resolveActorContext(requestContext, { authoritativeOnly = false })
    if not actor or not actor.userId then return nil, err or 'invalid_user' end
    local player = self.world.players[actor.userId]
    if not player then
        local created, createErr = self.world:createPlayer(actor.userId)
        if not created then return nil, createErr or 'player_load_failed' end
        player = created
    end
    local mapId = actor.mapId or player.currentMapId or requestedMapId or self:_defaultMapId()
    local ok, updateErr = self.world:updatePlayerRuntimeState(player, mapId, actor.position, false)
    if not ok then return nil, updateErr end
    return player
end

function WorldServerBridge:onUserEnter(event)
    self:bootstrap()
    local authoritative = self.runtimeAdapter:isLive()
    local actor, err = self.runtimeAdapter:resolveActorContext(event, { authoritativeOnly = authoritative })
    if not actor or not actor.userId then return false, err or 'invalid_user' end
    local mapId = actor.mapId or self:_defaultMapId()
    local player, enterErr = self.world:onPlayerEnter(actor.userId, mapId, actor.position)
    if not player then return false, enterErr or 'player_load_failed' end
    self.activeSessions[actor.userId] = {
        userId = actor.userId,
        enteredAt = self.runtimeAdapter:now(),
        lastSeenAt = self.runtimeAdapter:now(),
    }
    return true
end

function WorldServerBridge:onUserLeave(event)
    self:bootstrap()
    local authoritative = self.runtimeAdapter:isLive()
    local actor, err = self.runtimeAdapter:resolveActorContext(event, { authoritativeOnly = authoritative })
    if not actor or not actor.userId then return false, err or 'invalid_user' end
    self.activeSessions[actor.userId] = nil
    self.world:onPlayerLeave(actor.userId)
    return true
end

function WorldServerBridge:getPlayerState(requestContext)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local snapshot = self.world:publishPlayerSnapshot(player)
    return response(self.runtimeAdapter, true, snapshot)
end

function WorldServerBridge:getMapState(requestContext, mapId)
    self:bootstrap()
    local targetMapId = mapId

    if mapId == nil and type(requestContext) == 'string' then
        targetMapId = requestContext
        requestContext = nil
    end

    if (targetMapId == nil or targetMapId == '') and self.runtimeAdapter:isLive() then
        local player, err = self:_resolvePlayer(requestContext, nil)
        if not player then return response(self.runtimeAdapter, false, nil, err) end
        targetMapId = player.currentMapId
    end
    targetMapId = targetMapId or self:_defaultMapId()
    local cached = self:_cachedMapState(targetMapId)
    return response(self.runtimeAdapter, true, cached)
end

function WorldServerBridge:attackMob(requestContext, mapId, spawnId, requestedDamage)
    local player, err = self:_resolvePlayer(requestContext, mapId)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local ok, result, mobOrErr = self.world:attackMob(player, player.currentMapId, tonumber(spawnId), tonumber(requestedDamage))
    if not ok then return response(self.runtimeAdapter, false, nil, result) end
    return response(self.runtimeAdapter, true, {
        result = result,
        map = self:_cachedMapState(player.currentMapId),
        player = self.world:publishPlayerSnapshot(player),
        mob = mobOrErr,
    })
end

function WorldServerBridge:pickupDrop(requestContext, mapId, dropId)
    local player, err = self:_resolvePlayer(requestContext, mapId)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local ok, payload = self.world:pickupDrop(player, player.currentMapId, tonumber(dropId))
    if not ok then return response(self.runtimeAdapter, false, nil, payload) end
    return response(self.runtimeAdapter, true, { drop = payload, player = self.world:publishPlayerSnapshot(player) })
end

function WorldServerBridge:damageBoss(requestContext, mapId, requestedDamage)
    local player, err = self:_resolvePlayer(requestContext, mapId)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local ok, payload = self.world:damageBoss(player, player.currentMapId, tonumber(requestedDamage))
    if not ok then return response(self.runtimeAdapter, false, nil, payload) end
    return response(self.runtimeAdapter, true, { result = payload, map = self:_cachedMapState(player.currentMapId), player = self.world:publishPlayerSnapshot(player) })
end

function WorldServerBridge:acceptQuest(requestContext, questId)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local ok, result = self.world:acceptQuest(player, questId)
    if not ok then return response(self.runtimeAdapter, false, nil, result) end
    return response(self.runtimeAdapter, true, self.world:publishPlayerSnapshot(player))
end

function WorldServerBridge:turnInQuest(requestContext, questId)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local ok, result = self.world:turnInQuest(player, questId)
    if not ok then return response(self.runtimeAdapter, false, nil, result) end
    return response(self.runtimeAdapter, true, self.world:publishPlayerSnapshot(player))
end

function WorldServerBridge:buyFromNpc(requestContext, npcId, itemId, quantity)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local ok, result = self.world:buyFromNpc(player, npcId, itemId, tonumber(quantity))
    if not ok then return response(self.runtimeAdapter, false, nil, result) end
    return response(self.runtimeAdapter, true, self.world:publishPlayerSnapshot(player))
end

function WorldServerBridge:sellToNpc(requestContext, npcId, itemId, quantity)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local ok, result = self.world:sellToNpc(player, npcId, itemId, tonumber(quantity))
    if not ok then return response(self.runtimeAdapter, false, nil, result) end
    return response(self.runtimeAdapter, true, self.world:publishPlayerSnapshot(player))
end

function WorldServerBridge:equipItem(requestContext, itemId, instanceId)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local ok, result = self.world:equipItem(player, itemId, instanceId)
    if not ok then return response(self.runtimeAdapter, false, nil, result) end
    return response(self.runtimeAdapter, true, self.world:publishPlayerSnapshot(player))
end

function WorldServerBridge:unequipItem(requestContext, slot)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local ok, result = self.world:unequipItem(player, slot)
    if not ok then return response(self.runtimeAdapter, false, nil, result) end
    return response(self.runtimeAdapter, true, self.world:publishPlayerSnapshot(player))
end

function WorldServerBridge:changeMap(requestContext, mapId, sourceMapId)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local ok, result = self.world:changeMap(player, mapId, sourceMapId)
    if not ok then return response(self.runtimeAdapter, false, nil, result) end
    return response(self.runtimeAdapter, true, self.world:publishPlayerSnapshot(player))
end

return WorldServerBridge
