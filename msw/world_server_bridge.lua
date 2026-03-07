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
    if self.bootstrapError then
        return nil, self.bootstrapError
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

    local ok, worldOrErr = pcall(ServerBootstrap.boot, {
        dataProvider = safeRequire('data.runtime_tables'),
        worldConfig = worldConfig,
        playerRepository = repository,
        runtimeAdapter = self.runtimeAdapter,
        runtimeHooks = runtimeHooks,
        autoPickupDrops = false,
        useMapleWorldsDataStorage = usePersistentStorage,
    })
    if not ok then
        self.bootstrapError = 'world_bootstrap_failed'
        self:_setComponentField('BridgeReady', false)
        self:_setComponentField('BridgeError', tostring(worldOrErr))
        return nil, self.bootstrapError
    end

    self.world = worldOrErr
    self:_setComponentField('BridgeReady', true)
    return self.world
end

function WorldServerBridge:tick(delta)
    local world = self:bootstrap()
    if not world then return false, self.bootstrapError or 'world_bootstrap_failed' end
    world.scheduler:tick(tonumber(delta) or 0)
    return true
end

function WorldServerBridge:_resolvePlayer(requestContext, requestedMapId)
    local world, bootstrapErr = self:bootstrap()
    if not world then return nil, bootstrapErr or 'world_bootstrap_failed' end
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
        return player, nil, actor
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
    return player, nil, actor
end

function WorldServerBridge:_isAllowedMapTransition(sourceMapId, destinationMapId)
    local transitions = (self.worldConfig and self.worldConfig.mapTransitions)
        or (self.worldConfig and self.worldConfig.runtime and self.worldConfig.runtime.mapTransitions)
    if type(transitions) ~= 'table' then return false end
    local source = transitions[sourceMapId]
    if type(source) ~= 'table' then return false end
    if source[destinationMapId] == true then return true end
    for _, candidate in ipairs(source) do
        if candidate == destinationMapId then return true end
    end
    return false
end

function WorldServerBridge:_validateChangeMapContext(player, actor, destinationMapId, sourceMapId)
    if not destinationMapId or destinationMapId == '' then return false, 'invalid_map' end
    if not self.worldConfig.maps or not self.worldConfig.maps[destinationMapId] then return false, 'invalid_map' end

    if not self.runtimeAdapter:isLive() then return true end
    if not player then return false, 'invalid_player' end

    local playerMapId = player.currentMapId
    local actorMapId = actor and actor.mapId or nil
    local source = sourceMapId
    if source == nil or source == '' then return false, 'missing_transition_source' end
    if playerMapId and source ~= playerMapId then return false, 'wrong_map' end
    if actorMapId and source ~= actorMapId then return false, 'wrong_map' end
    if destinationMapId == source then return true end

    if not self:_isAllowedMapTransition(source, destinationMapId) then
        return false, 'invalid_map_transition'
    end
    return true
end

function WorldServerBridge:_validateNpcActionContext(player, npcId, itemId)
    if npcId == nil or npcId == '' then return false, 'invalid_npc' end
    local npc, npcErr = self.world:_resolveNpcBinding(npcId)
    if not npc then return false, npcErr end

    local shopOk, shopErr = self.world:_validateNpcShop(npc)
    if not shopOk then return false, shopErr end

    local boundaryOk, boundaryErr = self.world:_requireActionBoundary(player, npc.mapId, npc.position, 'questNpcRange')
    if not boundaryOk then return false, boundaryErr end

    if itemId == nil or itemId == '' then return false, 'invalid_item' end
    if not self.world:_isNpcItemAllowed(npc, itemId) then return false, 'item_not_sold_by_npc' end

    return true, npc
end

function WorldServerBridge:_validateMobActionContext(player, requestedMapId, spawnId)
    if spawnId == nil then return false, 'invalid_spawn' end
    local requestedSpawnId = tonumber(spawnId)
    if not requestedSpawnId then return false, 'invalid_spawn' end
    if requestedMapId ~= nil and requestedMapId ~= '' and requestedMapId ~= player.currentMapId then
        return false, 'wrong_map'
    end
    local mapId = player.currentMapId
    local mob = self.world.spawnSystem:getMob(mapId, requestedSpawnId)
    if not mob then return false, 'mob_not_found' end
    return true, mob
end

function WorldServerBridge:_validateDropActionContext(player, requestedMapId, dropId)
    if dropId == nil then return false, 'invalid_drop' end
    local requestedDropId = tonumber(dropId)
    if not requestedDropId then return false, 'invalid_drop' end
    if requestedMapId ~= nil and requestedMapId ~= '' and requestedMapId ~= player.currentMapId then
        return false, 'wrong_map'
    end
    local drop = self.world.dropSystem:getDrop(requestedDropId)
    if not drop then return false, 'drop_not_found' end
    if drop.mapId ~= player.currentMapId then return false, 'wrong_map' end
    return true, drop
end

function WorldServerBridge:_validateBossActionContext(player, requestedMapId, bossId)
    if requestedMapId ~= nil and requestedMapId ~= '' and requestedMapId ~= player.currentMapId then
        return false, 'wrong_map'
    end
    local encounter = self.world.bossSystem:getEncounter(player.currentMapId)
    if not encounter then return false, 'no_active_encounter' end
    if bossId ~= nil and bossId ~= '' and encounter.bossId ~= bossId then
        return false, 'boss_not_found'
    end
    return true, encounter
end

function WorldServerBridge:onUserEnter(event)
    local world, bootstrapErr = self:bootstrap()
    if not world then return false, bootstrapErr or 'world_bootstrap_failed' end
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
    local world, bootstrapErr = self:bootstrap()
    if not world then return false, bootstrapErr or 'world_bootstrap_failed' end
    local authoritative = self.runtimeAdapter:isLive()
    local actor, err = self.runtimeAdapter:resolveActorContext(event, { authoritativeOnly = authoritative })
    if not actor or not actor.userId then return false, err or 'invalid_user' end
    local ok, leaveErr = self.world:onPlayerLeave(actor.userId)
    if not ok then return false, leaveErr or 'player_save_failed' end
    self.activeSessions[actor.userId] = nil
    return true
end

function WorldServerBridge:getPlayerState(requestContext)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local snapshot = self.world:publishPlayerSnapshot(player)
    return response(self.runtimeAdapter, true, snapshot)
end

function WorldServerBridge:getMapState(requestContext, mapId)
    local world, bootstrapErr = self:bootstrap()
    if not world then return response(self.runtimeAdapter, false, nil, bootstrapErr or 'world_bootstrap_failed') end
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
    local contextOk, mobOrErr = self:_validateMobActionContext(player, mapId, spawnId)
    if not contextOk then return response(self.runtimeAdapter, false, nil, mobOrErr) end
    local ok, result, resolvedMob = self.world:attackMob(player, player.currentMapId, tonumber(spawnId), tonumber(requestedDamage), mobOrErr)
    if not ok then return response(self.runtimeAdapter, false, nil, result) end
    return response(self.runtimeAdapter, true, {
        result = result,
        map = self:_cachedMapState(player.currentMapId),
        player = self.world:publishPlayerSnapshot(player),
        mob = resolvedMob,
    })
end

function WorldServerBridge:pickupDrop(requestContext, mapId, dropId)
    local player, err = self:_resolvePlayer(requestContext, mapId)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local contextOk, dropOrErr = self:_validateDropActionContext(player, mapId, dropId)
    if not contextOk then return response(self.runtimeAdapter, false, nil, dropOrErr) end
    local ok, payload = self.world:pickupDrop(player, player.currentMapId, tonumber(dropId), dropOrErr)
    if not ok then return response(self.runtimeAdapter, false, nil, payload) end
    return response(self.runtimeAdapter, true, { drop = payload, player = self.world:publishPlayerSnapshot(player) })
end

function WorldServerBridge:damageBoss(requestContext, mapId, bossId, requestedDamage)
    local player, err = self:_resolvePlayer(requestContext, mapId)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    if requestedDamage == nil and bossId ~= nil and type(bossId) ~= 'string' then
        requestedDamage = bossId
        bossId = nil
    end
    local contextOk, encounterOrErr = self:_validateBossActionContext(player, mapId, bossId)
    if not contextOk then return response(self.runtimeAdapter, false, nil, encounterOrErr) end
    local ok, payload = self.world:damageBoss(player, player.currentMapId, bossId, tonumber(requestedDamage), encounterOrErr)
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
    local contextOk, npcOrErr = self:_validateNpcActionContext(player, npcId, itemId)
    if not contextOk then return response(self.runtimeAdapter, false, nil, npcOrErr) end
    local ok, result = self.world:buyFromNpc(player, npcId, itemId, tonumber(quantity), npcOrErr)
    if not ok then return response(self.runtimeAdapter, false, nil, result) end
    return response(self.runtimeAdapter, true, self.world:publishPlayerSnapshot(player))
end

function WorldServerBridge:sellToNpc(requestContext, npcId, itemId, quantity)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local contextOk, npcOrErr = self:_validateNpcActionContext(player, npcId, itemId)
    if not contextOk then return response(self.runtimeAdapter, false, nil, npcOrErr) end
    local ok, result = self.world:sellToNpc(player, npcId, itemId, tonumber(quantity), npcOrErr)
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
    local player, err, actor = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local contextOk, contextErr = self:_validateChangeMapContext(player, actor, mapId, sourceMapId)
    if not contextOk then return response(self.runtimeAdapter, false, nil, contextErr) end
    local ok, result = self.world:changeMap(player, mapId, sourceMapId)
    if not ok then return response(self.runtimeAdapter, false, nil, result) end
    return response(self.runtimeAdapter, true, self.world:publishPlayerSnapshot(player))
end

return WorldServerBridge
