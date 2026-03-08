local ServerBootstrap = require('scripts.server_bootstrap')
local RuntimeAdapter = require('ops.runtime_adapter')
local PlayerRepository = require('ops.player_repository')

local WorldServerBridge = {}
WorldServerBridge.__index = WorldServerBridge
local arrayUnpack = table.unpack or unpack

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

local function deepCopy(value, depth)
    local level = depth or 0
    if type(value) ~= 'table' or level > 6 then return value end
    local out = {}
    for key, current in pairs(value) do
        out[key] = deepCopy(current, level + 1)
    end
    return out
end

local function clamp(value, minValue, maxValue)
    local numeric = tonumber(value) or 0
    if numeric < minValue then return minValue end
    if numeric > maxValue then return maxValue end
    return numeric
end

local function arrayCount(value)
    if type(value) ~= 'table' then return 0 end
    return #value
end

local function isArray(value)
    if type(value) ~= 'table' then return false end
    local count = 0
    for key, _ in pairs(value) do
        if type(key) ~= 'number' or key <= 0 or key ~= math.floor(key) then
            return false
        end
        count = count + 1
    end
    return count == #value
end

local gatewayRoutes = {
    get_player_state = 'getPlayerState',
    get_map_state = 'getMapState',
    get_state_delta = 'getStateDelta',
    get_bridge_diagnostics = 'getBridgeDiagnostics',
    reconcile_runtime_state = 'reconcileRuntimeState',
    dispatch_runtime_event = 'dispatchRuntimeEvent',
    route_player_action = 'routePlayerAction',
    get_event_stream = 'getEventStream',
    attack_mob = 'attackMob',
    pickup_drop = 'pickupDrop',
    damage_boss = 'damageBoss',
    accept_quest = 'acceptQuest',
    turn_in_quest = 'turnInQuest',
    buy_from_npc = 'buyFromNpc',
    sell_to_npc = 'sellToNpc',
    equip_item = 'equipItem',
    unequip_item = 'unequipItem',
    change_map = 'changeMap',
    allocate_stat = 'allocateStat',
    promote_job = 'promoteJob',
    learn_skill = 'learnSkill',
    cast_skill = 'castSkill',
    enhance_equipment = 'enhanceEquipment',
    create_party = 'createParty',
    create_guild = 'createGuild',
    add_friend = 'addFriend',
    trade_mesos = 'tradeMesos',
    list_auction = 'listAuction',
    craft_item = 'craftItem',
    open_dialogue = 'openDialogue',
    channel_transfer = 'channelTransfer',
    get_runtime_status = 'getRuntimeStatus',
    get_replay_status = 'getReplayStatus',
    get_ownership_topology = 'getOwnershipTopology',
    get_control_plane_report = 'getControlPlaneReport',
    get_event_truth = 'getEventTruth',
    get_economy_report = 'getEconomyReport',
    admin_status = 'adminStatus',
    get_build_recommendation = 'getBuildRecommendation',
    get_tutorial_state = 'getTutorialState',
    list_party_finder = 'listPartyFinder',
    create_raid = 'createRaid',
}

local gatewayProtocol = {
    name = 'mapleworld_gateway',
    currentVersion = 1,
    supportedVersions = { 1 },
    requestPacketType = 'request',
    responsePacketType = 'response',
}

local gatewayRouteSpecs = {
    get_player_state = { minArgs = 1, maxArgs = 1, exposure = 'session' },
    get_map_state = { minArgs = 1, maxArgs = 2, exposure = 'session' },
    get_state_delta = { minArgs = 1, maxArgs = 3, exposure = 'session' },
    get_bridge_diagnostics = { minArgs = 0, maxArgs = 0, exposure = 'internal' },
    reconcile_runtime_state = { minArgs = 0, maxArgs = 2, exposure = 'internal' },
    dispatch_runtime_event = { minArgs = 1, maxArgs = 2, exposure = 'internal' },
    route_player_action = { minArgs = 2, maxArgs = 3, exposure = 'session' },
    get_event_stream = { minArgs = 0, maxArgs = 1, exposure = 'internal' },
    attack_mob = { minArgs = 4, maxArgs = 4, exposure = 'session' },
    pickup_drop = { minArgs = 3, maxArgs = 3, exposure = 'session' },
    damage_boss = { minArgs = 3, maxArgs = 4, exposure = 'session' },
    accept_quest = { minArgs = 2, maxArgs = 2, exposure = 'session' },
    turn_in_quest = { minArgs = 2, maxArgs = 2, exposure = 'session' },
    buy_from_npc = { minArgs = 4, maxArgs = 4, exposure = 'session' },
    sell_to_npc = { minArgs = 4, maxArgs = 4, exposure = 'session' },
    equip_item = { minArgs = 3, maxArgs = 3, exposure = 'session' },
    unequip_item = { minArgs = 2, maxArgs = 2, exposure = 'session' },
    change_map = { minArgs = 2, maxArgs = 3, exposure = 'session' },
    allocate_stat = { minArgs = 3, maxArgs = 3, exposure = 'session' },
    promote_job = { minArgs = 2, maxArgs = 2, exposure = 'session' },
    learn_skill = { minArgs = 2, maxArgs = 2, exposure = 'session' },
    cast_skill = { minArgs = 2, maxArgs = 3, exposure = 'session' },
    enhance_equipment = { minArgs = 2, maxArgs = 2, exposure = 'session' },
    create_party = { minArgs = 1, maxArgs = 1, exposure = 'session' },
    create_guild = { minArgs = 2, maxArgs = 2, exposure = 'session' },
    add_friend = { minArgs = 2, maxArgs = 2, exposure = 'session' },
    trade_mesos = { minArgs = 3, maxArgs = 3, exposure = 'session' },
    list_auction = { minArgs = 3, maxArgs = 3, exposure = 'session' },
    craft_item = { minArgs = 3, maxArgs = 3, exposure = 'session' },
    open_dialogue = { minArgs = 2, maxArgs = 2, exposure = 'public' },
    channel_transfer = { minArgs = 2, maxArgs = 2, exposure = 'session' },
    get_runtime_status = { minArgs = 0, maxArgs = 1, exposure = 'internal' },
    get_replay_status = { minArgs = 0, maxArgs = 0, exposure = 'internal' },
    get_ownership_topology = { minArgs = 0, maxArgs = 0, exposure = 'internal' },
    get_control_plane_report = { minArgs = 0, maxArgs = 0, exposure = 'internal' },
    get_event_truth = { minArgs = 0, maxArgs = 1, exposure = 'internal' },
    get_economy_report = { minArgs = 0, maxArgs = 0, exposure = 'internal' },
    admin_status = { minArgs = 0, maxArgs = 0, exposure = 'internal' },
    get_build_recommendation = { minArgs = 1, maxArgs = 1, exposure = 'session' },
    get_tutorial_state = { minArgs = 1, maxArgs = 1, exposure = 'session' },
    list_party_finder = { minArgs = 0, maxArgs = 1, exposure = 'public' },
    create_raid = { minArgs = 2, maxArgs = 2, exposure = 'session' },
}

local gatewayExposedByDefault = false

local function gatewayRouteSpec(operation)
    return gatewayRouteSpecs[operation] or {}
end

local function gatewayRouteExposure(operation)
    local exposure = gatewayRouteSpec(operation).exposure
    if exposure == nil or exposure == '' then
        return gatewayExposedByDefault and 'public' or 'internal'
    end
    return exposure
end

local function isGatewayOperationExposed(operation)
    local exposure = gatewayRouteExposure(operation)
    return exposure == 'public' or exposure == 'session'
end

local function buildGatewayCatalog()
    local operations = {}
    for operation, route in pairs(gatewayRoutes) do
        if isGatewayOperationExposed(operation) then
            local spec = gatewayRouteSpec(operation)
            operations[#operations + 1] = {
                operation = operation,
                route = route,
                minArgs = tonumber(spec.minArgs) or 0,
                maxArgs = tonumber(spec.maxArgs)
                    or tonumber(spec.minArgs)
                    or 0,
                exposure = gatewayRouteExposure(operation),
            }
        end
    end
    table.sort(operations, function(left, right)
        return tostring(left.operation) < tostring(right.operation)
    end)
    return operations
end

local function buildGatewayProtocolDescriptor(version)
    return {
        name = gatewayProtocol.name,
        version = tonumber(version) or gatewayProtocol.currentVersion,
        supportedVersions = deepCopy(gatewayProtocol.supportedVersions),
        packetType = gatewayProtocol.responsePacketType,
    }
end

local function tableCount(value)
    if type(value) ~= 'table' then return 0 end
    local total = 0
    for _, _ in pairs(value) do
        total = total + 1
    end
    return total
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
        playerVersions = {},
        mapVersions = {},
        entityVersions = {},
        deltaSequence = 0,
        syncHistoryLimit = 256,
        deltaQueue = {},
        eventSequence = 0,
        eventHistory = {},
        lifecycleHistory = {},
        metrics = {
            bridgeTicks = 0,
            syncPushes = 0,
            playerSyncs = 0,
            mapSyncs = 0,
            entitySpawns = 0,
            entityDestroys = 0,
            entityUpdates = 0,
            desyncCorrections = 0,
            reconciliationRuns = 0,
            latencySamples = 0,
            totalLatencyMs = 0,
            maxLatencyMs = 0,
            throughputEvents = 0,
            routedPlayerActions = 0,
            gatewayRequests = 0,
            gatewaySucceeded = 0,
            gatewayRejected = 0,
            mobBehaviorTicks = 0,
            combatTicks = 0,
            eventQueueDepth = 0,
        },
        latency = {
            byPlayerId = {},
            byMapId = {},
            lastDeltaFlushAt = 0,
            rateLimitSeconds = 1,
        },
        frameState = {
            tickId = 0,
            lastTickAt = 0,
            schedulerLagMs = 0,
            schedulerBudgetMs = 75,
        },
        desyncIncidents = {},
        orphanEntities = {
            mob = {},
            drop = {},
            boss = {},
        },
        eventRouters = {},
        gatewayRoutes = gatewayRoutes,
        gatewayState = {
            lastRequest = nil,
            lastResponse = nil,
            requestCount = 0,
        },
    }
    setmetatable(self, WorldServerBridge)
    self.eventRouters = {
        runtime = function(bridge, eventName, payload)
            return bridge:_recordEvent('runtime', eventName, payload)
        end,
        entity = function(bridge, eventName, payload)
            return bridge:_recordEvent('entity', eventName, payload)
        end,
        world = function(bridge, eventName, payload)
            return bridge:_recordEvent('world', eventName, payload)
        end,
        player_action = function(bridge, eventName, payload)
            bridge.metrics.routedPlayerActions = bridge.metrics.routedPlayerActions + 1
            return bridge:_recordEvent('player_action', eventName, payload)
        end,
    }
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

function WorldServerBridge:_setEncodedComponentField(name, value)
    self:_setComponentField(name, self.runtimeAdapter:encodeData(value))
end

function WorldServerBridge:_nextVersion(store, key)
    local current = tonumber(store[key] or 0) or 0
    current = current + 1
    store[key] = current
    return current
end

function WorldServerBridge:_nextDeltaSequence()
    self.deltaSequence = self.deltaSequence + 1
    return self.deltaSequence
end

function WorldServerBridge:_nextEventSequence()
    self.eventSequence = self.eventSequence + 1
    return self.eventSequence
end

function WorldServerBridge:_recordMetric(name, amount)
    if self.metrics[name] == nil then
        self.metrics[name] = 0
    end
    self.metrics[name] = self.metrics[name] + (tonumber(amount) or 1)
end

function WorldServerBridge:_appendLimited(list, value, limit)
    list[#list + 1] = value
    local maxItems = tonumber(limit) or self.syncHistoryLimit
    while #list > maxItems do
        table.remove(list, 1)
    end
end

function WorldServerBridge:_recordEvent(router, eventName, payload)
    local item = {
        sequence = self:_nextEventSequence(),
        router = router,
        event = eventName,
        at = self.runtimeAdapter:now(),
        payload = deepCopy(payload),
    }
    self:_appendLimited(self.eventHistory, item, self.syncHistoryLimit)
    self:_recordMetric('throughputEvents', 1)
    self:_setEncodedComponentField('LastRuntimeEventJson', item)
    return item
end

function WorldServerBridge:_recordLifecycle(stage, payload)
    local item = {
        stage = stage,
        at = self.runtimeAdapter:now(),
        payload = deepCopy(payload),
    }
    self:_appendLimited(self.lifecycleHistory, item, 64)
    self:_setEncodedComponentField('LastLifecycleJson', item)
    return item
end

function WorldServerBridge:_recordDesync(kind, id, payload)
    local key = tostring(kind) .. ':' .. tostring(id)
    local current = self.desyncIncidents[key] or {
        kind = kind,
        id = id,
        count = 0,
        lastAt = 0,
        payload = nil,
    }
    current.count = current.count + 1
    current.lastAt = self.runtimeAdapter:now()
    current.payload = deepCopy(payload)
    self.desyncIncidents[key] = current
    self:_recordMetric('desyncCorrections', 1)
    self:_recordEvent('runtime', 'desync_detected', current)
end

function WorldServerBridge:_touchLatency(playerId, mapId)
    local now = self.runtimeAdapter:now()
    if playerId then
        local sample = self.latency.byPlayerId[playerId] or { last = now, observed = 0 }
        local latencyMs = math.max(0, (now - (sample.last or now)) * 1000)
        sample.last = now
        sample.observed = latencyMs
        self.latency.byPlayerId[playerId] = sample
        self:_recordMetric('latencySamples', 1)
        self.metrics.totalLatencyMs = self.metrics.totalLatencyMs + latencyMs
        self.metrics.maxLatencyMs = math.max(self.metrics.maxLatencyMs, latencyMs)
    end
    if mapId then
        self.latency.byMapId[mapId] = now
    end
end

function WorldServerBridge:_queueDelta(scopeKind, scopeId, deltaKind, payload, version)
    if not scopeId then return nil end
    local item = {
        sequence = self:_nextDeltaSequence(),
        scopeKind = scopeKind,
        scopeId = tostring(scopeId),
        deltaKind = deltaKind,
        version = version or 0,
        at = self.runtimeAdapter:now(),
        payload = deepCopy(payload),
    }
    self:_appendLimited(self.deltaQueue, item, self.syncHistoryLimit)
    self.metrics.eventQueueDepth = #self.deltaQueue
    self:_recordMetric('syncPushes', 1)
    self:_setEncodedComponentField('LastDeltaJson', item)
    return item
end

function WorldServerBridge:_flushDeltaQueue(limit)
    local maxItems = clamp(limit or 32, 1, self.syncHistoryLimit)
    local out = {}
    local index = math.max(1, #self.deltaQueue - maxItems + 1)
    for i = index, #self.deltaQueue do
        out[#out + 1] = deepCopy(self.deltaQueue[i])
    end
    self.latency.lastDeltaFlushAt = self.runtimeAdapter:now()
    return out
end

function WorldServerBridge:_entityVersionKey(kind, id)
    return tostring(kind) .. ':' .. tostring(id)
end

function WorldServerBridge:_cachePlayerState(playerId, snapshot, reason)
    local version = self:_nextVersion(self.playerVersions, playerId)
    local copied = deepCopy(snapshot)
    copied.syncVersion = version
    copied.syncReason = reason or 'player_sync'
    self.playerStateById[playerId] = copied
    self:_queueDelta('player', playerId, 'player_state', copied, version)
    self:_touchLatency(playerId, copied.currentMapId)
    self:_recordMetric('playerSyncs', 1)
    self:_setComponentField('LastSyncUserId', tostring(playerId))
    self:_setEncodedComponentField('LastPlayerStateJson', copied)
end

function WorldServerBridge:_cacheMapState(mapId, state, reason)
    if not mapId then return end
    local version = self:_nextVersion(self.mapVersions, mapId)
    local copied = deepCopy(state)
    copied.syncVersion = version
    copied.syncReason = reason or 'map_sync'
    copied.bridgeMeta = copied.bridgeMeta or {}
    copied.bridgeMeta.mapId = mapId
    copied.bridgeMeta.population = copied.population
    copied.bridgeMeta.deltaSequence = self.deltaSequence
    self.mapStateById[mapId] = copied
    self:_queueDelta('map', mapId, 'map_state', copied, version)
    self:_touchLatency(nil, mapId)
    self:_recordMetric('mapSyncs', 1)
    self:_setEncodedComponentField('LastMapStateJson', copied)
end

function WorldServerBridge:_invalidateMapState(mapId)
    if mapId then self.mapStateById[mapId] = nil end
end

function WorldServerBridge:_cachedMapState(mapId)
    if not mapId then return nil end
    local cached = self.mapStateById[mapId]
    if cached == nil then
        cached = self.world:getMapState(mapId)
        self:_cacheMapState(mapId, cached, 'map_fetch')
    end
    return cached
end

function WorldServerBridge:_queueEntityDelta(kind, id, mapId, action, payload)
    local key = self:_entityVersionKey(kind, id)
    local version = self:_nextVersion(self.entityVersions, key)
    local data = deepCopy(payload) or {}
    data.entityId = id
    data.mapId = mapId
    data.action = action
    data.version = version
    self:_queueDelta('entity', key, action, data, version)
    return version
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
        z = mob.z or 0,
        groupId = mob.spawnGroupId,
        aiPattern = mob.aiPattern,
        elite = mob.elite == true,
        rare = mob.rare == true,
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
    local payload = deepCopy(drop)
    for i, current in ipairs(cached.drops) do
        if tonumber(current.dropId) == targetId then
            cached.drops[i] = payload
            return true
        end
    end
    cached.drops[#cached.drops + 1] = payload
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
    cached.bridgeMeta = cached.bridgeMeta or {}
    cached.bridgeMeta.population = cached.population
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
    cached.boss.telegraph = encounter and encounter.telegraph or cached.boss.telegraph
    return true
end

function WorldServerBridge:_defaultMapId()
    return self.worldConfig and self.worldConfig.runtime and self.worldConfig.runtime.defaultMapId or 'henesys_hunting_ground'
end

function WorldServerBridge:_actorScope(actor)
    actor = actor or {}
    local runtimeIdentity = self.world and self.world.runtimeIdentity or {}
    return {
        worldId = actor.worldId or runtimeIdentity.worldId,
        channelId = actor.channelId or runtimeIdentity.channelId,
        runtimeInstanceId = actor.runtimeInstanceId or runtimeIdentity.runtimeInstanceId,
    }
end

function WorldServerBridge:_buildAuthoritySyncDescriptor(player, mapId)
    local runtimeIdentity = self.world and self.world.runtimeIdentity or {}
    local targetMapId = mapId or (player and player.currentMapId) or self:_defaultMapId()
    return {
        playerId = player and player.id or nil,
        mapId = targetMapId,
        worldId = runtimeIdentity.worldId,
        channelId = runtimeIdentity.channelId,
        runtimeInstanceId = runtimeIdentity.runtimeInstanceId,
        latestDeltaSequence = self.deltaSequence,
        playerSyncVersion = player and self.playerVersions[player.id] or nil,
        mapSyncVersion = targetMapId and self.mapVersions[targetMapId] or nil,
    }
end

function WorldServerBridge:_validateSyncScopeRequest(player, scopeId)
    if not player then return nil, 'invalid_player' end
    if scopeId == nil or scopeId == '' then
        return {
            scopeId = tostring(player.currentMapId or player.id),
            scopeKind = 'map',
            mapId = player.currentMapId,
        }
    end

    local normalized = tostring(scopeId)
    if normalized == tostring(player.id) then
        return {
            scopeId = normalized,
            scopeKind = 'player',
            mapId = player.currentMapId,
        }
    end

    local currentMapId = tostring(player.currentMapId or '')
    if normalized == currentMapId or normalized == self:_entityVersionKey('boss', currentMapId) then
        return {
            scopeId = normalized,
            scopeKind = normalized == currentMapId and 'map' or 'boss',
            mapId = player.currentMapId,
        }
    end

    return nil, 'scope_not_authoritative'
end

function WorldServerBridge:_validateActorScope(player, actor)
    if not player then return false, 'invalid_player' end
    local scope = self:_actorScope(actor)
    local ps = player.runtimeScope or {}
    if ps.worldId and scope.worldId and tostring(ps.worldId) ~= tostring(scope.worldId) then
        if self.world and self.world._recordRuntimeEvent then
            self.world:_recordRuntimeEvent('runtime_scope_conflict', { playerId = player.id, field = 'worldId', expected = ps.worldId, actual = scope.worldId })
        end
        if self.world and self.world._recordOwnershipConflict then
            self.world:_recordOwnershipConflict('runtime_world_conflict', { playerId = player.id, expected = ps.worldId, actual = scope.worldId })
        end
        self:_recordDesync('player_scope', player.id, { field = 'worldId', expected = ps.worldId, actual = scope.worldId })
        return false, 'runtime_world_conflict'
    end
    if ps.channelId and scope.channelId and tostring(ps.channelId) ~= tostring(scope.channelId) then
        if self.world and self.world._recordRuntimeEvent then
            self.world:_recordRuntimeEvent('runtime_scope_conflict', { playerId = player.id, field = 'channelId', expected = ps.channelId, actual = scope.channelId })
        end
        if self.world and self.world._recordOwnershipConflict then
            self.world:_recordOwnershipConflict('runtime_channel_conflict', { playerId = player.id, expected = ps.channelId, actual = scope.channelId })
        end
        self:_recordDesync('player_scope', player.id, { field = 'channelId', expected = ps.channelId, actual = scope.channelId })
        return false, 'runtime_channel_conflict'
    end
    if ps.runtimeInstanceId and scope.runtimeInstanceId and tostring(ps.runtimeInstanceId) ~= tostring(scope.runtimeInstanceId) then
        if self.world and self.world._recordRuntimeEvent then
            self.world:_recordRuntimeEvent('runtime_scope_conflict', { playerId = player.id, field = 'runtimeInstanceId', expected = ps.runtimeInstanceId, actual = scope.runtimeInstanceId })
        end
        if self.world and self.world._recordOwnershipConflict then
            self.world:_recordOwnershipConflict('runtime_instance_conflict', { playerId = player.id, expected = ps.runtimeInstanceId, actual = scope.runtimeInstanceId })
        end
        self:_recordDesync('player_scope', player.id, { field = 'runtimeInstanceId', expected = ps.runtimeInstanceId, actual = scope.runtimeInstanceId })
        return false, 'runtime_instance_conflict'
    end
    return true
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
            return existing, true, entityPath
        end
    end

    local parent = self:_resolveParentEntity(parentPath)
    local entity = self.runtimeAdapter:spawnModel(modelId, name, self.runtimeAdapter:makeVector3(x, y, z or 0), parent)
    return entity, false, entityPath
end

function WorldServerBridge:_trackEntity(kind, id, mapId, entity, entityPath)
    local target
    if kind == 'mob' then
        target = self.mobEntities
    elseif kind == 'drop' then
        target = self.dropEntities
    else
        target = self.bossEntities
    end
    target[id] = {
        entity = entity,
        mapId = mapId,
        path = entityPath,
        trackedAt = self.runtimeAdapter:now(),
        kind = kind,
        id = id,
    }
end

function WorldServerBridge:_entityEntry(kind, id)
    if kind == 'mob' then return self.mobEntities[id] end
    if kind == 'drop' then return self.dropEntities[id] end
    return self.bossEntities[id]
end

function WorldServerBridge:_clearEntityEntry(kind, id)
    if kind == 'mob' then self.mobEntities[id] = nil return end
    if kind == 'drop' then self.dropEntities[id] = nil return end
    self.bossEntities[id] = nil
end

function WorldServerBridge:_spawnMobEntity(mob)
    local runtime = self:_mapRuntime(mob.mapId)
    local mobDef = self.world and self.world.mobs and self.world.mobs[mob.mobId] or nil
    local modelId = (runtime and runtime.mobModelIds and runtime.mobModelIds[mob.mobId]) or (mobDef and mobDef.assetKey) or nil
    local entity, reused, entityPath = self:_spawnRuntimeEntity(modelId, 'mob_' .. tostring(mob.spawnId), mob.x, mob.y, mob.z or 0, runtime and runtime.mobParentPath)
    if entity then
        self:_trackEntity('mob', mob.spawnId, mob.mapId, entity, entityPath)
        self:_recordMetric(reused and 'entityUpdates' or 'entitySpawns', 1)
    else
        self.orphanEntities.mob[mob.spawnId] = { mapId = mob.mapId, expectedPath = entityPath, lastSeenAt = self.runtimeAdapter:now() }
    end
    self:_queueEntityDelta('mob', mob.spawnId, mob.mapId, reused and 'upsert' or 'spawn', {
        mobId = mob.mobId,
        hp = mob.hp,
        maxHp = mob.maxHp,
        position = { x = mob.x, y = mob.y, z = mob.z or 0 },
    })
    self:_recordEvent('entity', 'mob_spawn', { mapId = mob.mapId, spawnId = mob.spawnId, mobId = mob.mobId, reused = reused == true })
    if not self:_insertCachedMob(mob) then
        self:_invalidateMapState(mob.mapId)
    else
        self:_queueDelta('map', mob.mapId, 'mob_delta', { action = 'upsert', spawnId = mob.spawnId, hp = mob.hp }, self.mapVersions[mob.mapId] or 0)
    end
end

function WorldServerBridge:_destroyMobEntity(mob)
    local entry = self.mobEntities[mob.spawnId]
    if entry and entry.entity then
        self.runtimeAdapter:destroyEntity(entry.entity)
        self:_recordMetric('entityDestroys', 1)
    end
    self:_clearEntityEntry('mob', mob.spawnId)
    self:_queueEntityDelta('mob', mob.spawnId, mob.mapId, 'destroy', { spawnId = mob.spawnId })
    self:_recordEvent('entity', 'mob_destroy', { mapId = mob.mapId, spawnId = mob.spawnId })
    if not self:_removeCachedMob(mob) then
        self:_invalidateMapState(mob.mapId)
    else
        self:_queueDelta('map', mob.mapId, 'mob_delta', { action = 'destroy', spawnId = mob.spawnId }, self.mapVersions[mob.mapId] or 0)
    end
end

function WorldServerBridge:_spawnDropEntity(drop)
    local mapRuntime = self:_mapRuntime(drop.mapId)
    local dropCfg = self.worldConfig and self.worldConfig.drops or {}
    local itemDef = self.world and self.world.items and self.world.items[drop.itemId] or nil
    local modelId = (dropCfg.modelIds and dropCfg.modelIds[drop.itemId]) or dropCfg.defaultModelId or (itemDef and itemDef.assetKey) or nil
    local entity, reused, entityPath = self:_spawnRuntimeEntity(modelId, 'drop_' .. tostring(drop.dropId), drop.x, drop.y, drop.z or 0, mapRuntime and mapRuntime.dropParentPath)
    if entity then
        self:_trackEntity('drop', drop.dropId, drop.mapId, entity, entityPath)
        self:_recordMetric(reused and 'entityUpdates' or 'entitySpawns', 1)
    else
        self.orphanEntities.drop[drop.dropId] = { mapId = drop.mapId, expectedPath = entityPath, lastSeenAt = self.runtimeAdapter:now() }
    end
    self:_queueEntityDelta('drop', drop.dropId, drop.mapId, reused and 'upsert' or 'spawn', deepCopy(drop))
    self:_recordEvent('entity', 'drop_spawn', { mapId = drop.mapId, dropId = drop.dropId, itemId = drop.itemId })
    if not self:_insertCachedDrop(drop) then
        self:_invalidateMapState(drop.mapId)
    else
        self:_queueDelta('map', drop.mapId, 'drop_delta', { action = 'upsert', dropId = drop.dropId }, self.mapVersions[drop.mapId] or 0)
    end
end

function WorldServerBridge:_destroyDropEntity(drop)
    local entry = self.dropEntities[drop.dropId]
    if entry and entry.entity then
        self.runtimeAdapter:destroyEntity(entry.entity)
        self:_recordMetric('entityDestroys', 1)
    end
    self:_clearEntityEntry('drop', drop.dropId)
    self:_queueEntityDelta('drop', drop.dropId, drop.mapId, 'destroy', { dropId = drop.dropId, itemId = drop.itemId })
    self:_recordEvent('entity', 'drop_destroy', { mapId = drop.mapId, dropId = drop.dropId, itemId = drop.itemId })
    if not self:_removeCachedDrop(drop) then
        self:_invalidateMapState(drop.mapId)
    else
        self:_queueDelta('map', drop.mapId, 'drop_delta', { action = 'destroy', dropId = drop.dropId }, self.mapVersions[drop.mapId] or 0)
    end
end

function WorldServerBridge:_spawnBossEntity(encounter)
    local mapRuntime = self:_mapRuntime(encounter.mapId)
    local bossCfg = self.worldConfig and self.worldConfig.bosses and self.worldConfig.bosses[encounter.bossId] or {}
    local bossDef = self.world and self.world.bossSystem and self.world.bossSystem.bossTable and self.world.bossSystem.bossTable[encounter.bossId] or nil
    local pos = encounter.position or bossCfg.spawnPosition or (bossDef and bossDef.position) or { x = 0, y = 0, z = 0 }
    local modelId = bossCfg.modelId or (bossDef and bossDef.modelId) or (self.world and self.world.mobs and self.world.mobs[encounter.bossId] and self.world.mobs[encounter.bossId].assetKey) or nil
    local parentPath = bossCfg.parentPath or (bossDef and bossDef.parentPath) or (mapRuntime and mapRuntime.bossParentPath) or self:_rootAttachPath()
    local entity, reused, entityPath = self:_spawnRuntimeEntity(modelId, 'boss_' .. tostring(encounter.bossId), pos.x, pos.y, pos.z, parentPath)
    if entity then
        self:_trackEntity('boss', encounter.mapId, encounter.mapId, entity, entityPath)
        self:_recordMetric(reused and 'entityUpdates' or 'entitySpawns', 1)
    else
        self.orphanEntities.boss[encounter.mapId] = { mapId = encounter.mapId, expectedPath = entityPath, lastSeenAt = self.runtimeAdapter:now() }
    end
    self:_queueEntityDelta('boss', encounter.mapId, encounter.mapId, reused and 'upsert' or 'spawn', {
        bossId = encounter.bossId,
        hp = encounter.hp,
        maxHp = encounter.maxHp,
        phase = encounter.phase,
        enraged = encounter.enraged == true,
        telegraph = encounter.telegraph,
    })
    self:_recordEvent('entity', 'boss_spawn', { mapId = encounter.mapId, bossId = encounter.bossId, phase = encounter.phase })
    self:_invalidateMapState(encounter.mapId)
end

function WorldServerBridge:_destroyBossEntity(encounter)
    local entry = self.bossEntities[encounter.mapId]
    if entry and entry.entity then
        self.runtimeAdapter:destroyEntity(entry.entity)
        self:_recordMetric('entityDestroys', 1)
    end
    self:_clearEntityEntry('boss', encounter.mapId)
    self:_queueEntityDelta('boss', encounter.mapId, encounter.mapId, 'destroy', { bossId = encounter.bossId, mapId = encounter.mapId })
    self:_recordEvent('entity', 'boss_destroy', { mapId = encounter.mapId, bossId = encounter.bossId })
    self:_invalidateMapState(encounter.mapId)
end

function WorldServerBridge:_reconcileEntityTable(kind, expectedIds)
    local source
    if kind == 'mob' then
        source = self.mobEntities
    elseif kind == 'drop' then
        source = self.dropEntities
    else
        source = self.bossEntities
    end

    local expected = {}
    for _, id in ipairs(expectedIds or {}) do
        expected[tostring(id)] = true
    end

    for key, entry in pairs(source) do
        local compareKey = tostring(kind == 'boss' and (entry.mapId or key) or key)
        if not expected[compareKey] then
            self.orphanEntities[kind][key] = {
                mapId = entry.mapId,
                expectedPath = entry.path,
                lastSeenAt = self.runtimeAdapter:now(),
            }
            if entry.entity then
                self.runtimeAdapter:destroyEntity(entry.entity)
            end
            source[key] = nil
            self:_recordDesync(kind, key, { reason = 'orphan_cleanup', mapId = entry.mapId })
        end
    end
end

function WorldServerBridge:_reconcileMapState(mapId)
    local state = self.world:getMapState(mapId)
    self:_cacheMapState(mapId, state, 'reconcile')
    local expectedMobs = {}
    for _, mob in ipairs(state.mobs or {}) do
        expectedMobs[#expectedMobs + 1] = mob.spawnId
    end
    local expectedDrops = {}
    for _, drop in ipairs(state.drops or {}) do
        expectedDrops[#expectedDrops + 1] = drop.dropId
    end
    local expectedBosses = {}
    if state.boss and state.boss.alive ~= false then
        expectedBosses[#expectedBosses + 1] = mapId
    end
    self:_reconcileEntityTable('mob', expectedMobs)
    self:_reconcileEntityTable('drop', expectedDrops)
    self:_reconcileEntityTable('boss', expectedBosses)
    self:_recordMetric('reconciliationRuns', 1)
    return state
end

function WorldServerBridge:_cleanupOrphans()
    for kind, entries in pairs(self.orphanEntities) do
        for key, entry in pairs(entries) do
            local now = self.runtimeAdapter:now()
            if now - (entry.lastSeenAt or now) >= 0 then
                local tracked = self:_entityEntry(kind, key)
                if tracked and tracked.entity then
                    self.runtimeAdapter:destroyEntity(tracked.entity)
                    self:_clearEntityEntry(kind, key)
                end
                entries[key] = nil
            end
        end
    end
end

function WorldServerBridge:_updateMapDelta(mapId, reason)
    local state = self.world:getMapState(mapId)
    self:_cacheMapState(mapId, state, reason or 'map_refresh')
    return state
end

function WorldServerBridge:_resolveMapSpawnPoint(mapId)
    local mapConfig = self.worldConfig and self.worldConfig.maps and self.worldConfig.maps[mapId] or nil
    local runtime = mapConfig and mapConfig.runtime or {}
    local spawn = runtime.spawnPosition or mapConfig.spawnPosition or runtime.defaultSpawn or { x = 0, y = 0, z = 0 }
    return {
        x = tonumber(spawn.x) or 0,
        y = tonumber(spawn.y) or 0,
        z = tonumber(spawn.z) or 0,
    }
end

function WorldServerBridge:_validateSpawnPoint(mapId, point)
    if not mapId or not self.worldConfig.maps or not self.worldConfig.maps[mapId] then
        return false, 'invalid_map'
    end
    local pos = point or self:_resolveMapSpawnPoint(mapId)
    if type(pos) ~= 'table' then return false, 'invalid_spawn_point' end
    if tonumber(pos.x) == nil or tonumber(pos.y) == nil then return false, 'invalid_spawn_point' end
    return true, {
        x = tonumber(pos.x) or 0,
        y = tonumber(pos.y) or 0,
        z = tonumber(pos.z) or 0,
    }
end

function WorldServerBridge:_buildMapTransitionPayload(player, sourceMapId, destinationMapId)
    local okSpawn, spawnOrErr = self:_validateSpawnPoint(destinationMapId)
    if not okSpawn then return nil, spawnOrErr end
    return {
        playerId = player and player.id or nil,
        sourceMapId = sourceMapId,
        destinationMapId = destinationMapId,
        spawn = spawnOrErr,
        normalizedPath = normalizePath('/maps/' .. tostring(destinationMapId)),
    }
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

    self:_recordLifecycle('bootstrap_begin', { persistent = usePersistentStorage == true })
    local runtimeHooks = {
        onPlayerEnter = function(world, player)
            local now = self.runtimeAdapter:now()
            self.activeSessions[player.id] = {
                userId = player.id,
                enteredAt = now,
                lastSeenAt = now,
            }
            self:_cachePlayerState(player.id, world:publishPlayerSnapshot(player), 'player_enter')
            if not self:_updateCachedPopulation(player.currentMapId) then
                self:_invalidateMapState(player.currentMapId)
            else
                self:_queueDelta('map', player.currentMapId, 'population', { population = world:getMapPopulation(player.currentMapId) }, self.mapVersions[player.currentMapId] or 0)
            end
            self:_recordLifecycle('player_enter', { playerId = player.id, mapId = player.currentMapId })
        end,
        onPlayerLeave = function(world, player)
            self.playerStateById[player.id] = nil
            self.activeSessions[player.id] = nil
            self:_queueDelta('player', player.id, 'player_leave', { playerId = player.id }, self.playerVersions[player.id] or 0)
            self:_recordLifecycle('player_leave', { playerId = player.id })
        end,
        onPlayerSnapshot = function(world, player, snapshot)
            if self.activeSessions[player.id] then
                self.activeSessions[player.id].lastSeenAt = self.runtimeAdapter:now()
            end
            self:_cachePlayerState(player.id, snapshot, 'snapshot')
        end,
        onPlayerMapChanged = function(world, player, mapId)
            if not self:_updateCachedPopulation(mapId) then
                self:_invalidateMapState(mapId)
            end
            self:_updateMapDelta(mapId, 'map_changed')
            self:_recordLifecycle('map_load', { playerId = player.id, mapId = mapId })
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
            else
                self:_queueEntityDelta('mob', mob.spawnId, mob.mapId, 'damage', { hp = mob.hp, actorId = player and player.id or nil })
                self:_queueDelta('map', mob.mapId, 'mob_delta', { action = 'damage', spawnId = mob.spawnId, hp = mob.hp }, self.mapVersions[mob.mapId] or 0)
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
            else
                self:_queueEntityDelta('boss', encounter.mapId, encounter.mapId, 'damage', {
                    bossId = encounter.bossId,
                    hp = encounter.hp,
                    maxHp = encounter.maxHp,
                    phase = encounter.phase,
                    telegraph = encounter.telegraph,
                })
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
        self:_recordLifecycle('bootstrap_failed', { error = tostring(worldOrErr) })
        return nil, self.bootstrapError
    end

    self.world = worldOrErr
    self:_setComponentField('BridgeReady', true)
    self:_recordLifecycle('bootstrap_ready', { defaultMapId = self:_defaultMapId() })
    return self.world
end

function WorldServerBridge:_frameTick(delta)
    self.frameState.tickId = self.frameState.tickId + 1
    self.frameState.lastTickAt = self.runtimeAdapter:now()
    self.frameState.delta = tonumber(delta) or 0
    self:_recordMetric('bridgeTicks', 1)
    return self.frameState
end

function WorldServerBridge:_entityUpdateScheduler()
    local activeEntities = 0
    for _, _ in pairs(self.mobEntities) do activeEntities = activeEntities + 1 end
    for _, _ in pairs(self.dropEntities) do activeEntities = activeEntities + 1 end
    for _, _ in pairs(self.bossEntities) do activeEntities = activeEntities + 1 end
    self.frameState.activeEntities = activeEntities
    self.metrics.activeEntities = activeEntities
    return activeEntities
end

function WorldServerBridge:_mobBehaviorTick()
    self:_recordMetric('mobBehaviorTicks', 1)
end

function WorldServerBridge:_combatTickManager()
    self:_recordMetric('combatTicks', 1)
end

function WorldServerBridge:_memoryGuard()
    local total = arrayCount(self.deltaQueue) + arrayCount(self.eventHistory)
    if total > self.syncHistoryLimit * 2 then
        while #self.deltaQueue > self.syncHistoryLimit do
            table.remove(self.deltaQueue, 1)
        end
        while #self.eventHistory > self.syncHistoryLimit do
            table.remove(self.eventHistory, 1)
        end
        self.metrics.eventQueueDepth = #self.deltaQueue
        self:_recordEvent('runtime', 'memory_guard_trim', { retained = self.syncHistoryLimit })
    end
end

function WorldServerBridge:tick(delta)
    local world = self:bootstrap()
    if not world then return false, self.bootstrapError or 'world_bootstrap_failed' end
    local numericDelta = tonumber(delta) or 0
    local frame = self:_frameTick(numericDelta)
    local tickStartedAt = self.runtimeAdapter:now()
    world.scheduler:tick(numericDelta)
    self:_entityUpdateScheduler()
    self:_mobBehaviorTick()
    self:_combatTickManager()
    self:_cleanupOrphans()
    self:_memoryGuard()
    local tickFinishedAt = self.runtimeAdapter:now()
    frame.tickDurationMs = math.max(0, (tickFinishedAt - tickStartedAt) * 1000)
    frame.schedulerLagMs = math.max(0, frame.tickDurationMs - frame.schedulerBudgetMs)
    self.frameState.schedulerLagMs = frame.schedulerLagMs
    self:_setEncodedComponentField('LastFrameTickJson', frame)
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
        local scopeOk, scopeErr = self:_validateActorScope(player, actor)
        if not scopeOk then return nil, scopeErr end
        self:_touchLatency(player.id, mapId)
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
    local scopeOk, scopeErr = self:_validateActorScope(player, actor)
    if not scopeOk then return nil, scopeErr end
    self:_touchLatency(player.id, mapId)
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

    if not self.runtimeAdapter:isLive() then return self:_validateSpawnPoint(destinationMapId) end
    if not player then return false, 'invalid_player' end

    local playerMapId = player.currentMapId
    local actorMapId = actor and actor.mapId or nil
    local source = sourceMapId
    if source == nil or source == '' then return false, 'missing_transition_source' end
    if playerMapId and source ~= playerMapId then return false, 'wrong_map' end
    if actorMapId and source ~= actorMapId then return false, 'wrong_map' end
    if destinationMapId == source then
        return self:_validateSpawnPoint(destinationMapId)
    end

    if not self:_isAllowedMapTransition(source, destinationMapId) then
        return false, 'invalid_map_transition'
    end
    return self:_validateSpawnPoint(destinationMapId)
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

function WorldServerBridge:_routeEvent(routerName, eventName, payload)
    local router = self.eventRouters[routerName]
    if not router then
        return nil, 'invalid_router'
    end
    return router(self, eventName, payload)
end

function WorldServerBridge:_decodeGatewayEnvelope(requestEnvelope)
    local envelope = requestEnvelope
    if type(requestEnvelope) == 'string' then
        envelope = self.runtimeAdapter:decodeData(requestEnvelope)
    end
    if type(envelope) ~= 'table' then
        return nil, 'invalid_gateway_request'
    end
    local protocolVersion = envelope.protocolVersion
    if protocolVersion == nil then
        protocolVersion = envelope.version
    end
    if protocolVersion == nil then
        protocolVersion = gatewayProtocol.currentVersion
    end
    protocolVersion = tonumber(protocolVersion)
    if protocolVersion == nil or protocolVersion ~= math.floor(protocolVersion) or protocolVersion < 1 then
        return nil, 'invalid_gateway_protocol_version'
    end
    local protocolSupported = false
    for _, supportedVersion in ipairs(gatewayProtocol.supportedVersions) do
        if protocolVersion == supportedVersion then
            protocolSupported = true
            break
        end
    end
    if not protocolSupported then
        return nil, 'unsupported_gateway_protocol_version'
    end
    local packetType = envelope.packetType
    if packetType == nil then
        packetType = gatewayProtocol.requestPacketType
    end
    if type(packetType) ~= 'string' or packetType ~= gatewayProtocol.requestPacketType then
        return nil, 'invalid_gateway_packet_type'
    end
    local operation = envelope.operation or envelope.method
    if type(operation) ~= 'string' or operation == '' then
        return nil, 'missing_gateway_operation'
    end
    local args = envelope.args
    if args == nil then
        args = {}
    elseif not isArray(args) then
        return nil, 'invalid_gateway_args'
    end
    local requestId = envelope.requestId
    if requestId ~= nil then
        requestId = tostring(requestId)
    end
    return {
        requestId = requestId,
        protocolVersion = protocolVersion,
        packetType = packetType,
        operation = operation,
        args = deepCopy(args),
    }
end

function WorldServerBridge:_gatewayFailure(requestId, operation, err, protocolVersion)
    self:_recordMetric('gatewayRejected', 1)
    local payload = {
        ok = false,
        data = nil,
        error = err,
        requestId = requestId,
        operation = operation,
        protocol = buildGatewayProtocolDescriptor(protocolVersion),
        gateway = {
            handledAt = self.runtimeAdapter:now(),
            route = nil,
            status = 'rejected',
        },
    }
    self.gatewayState.lastResponse = deepCopy(payload)
    self:_setEncodedComponentField('LastGatewayResponseJson', payload)
    return self.runtimeAdapter:encodeData(payload)
end

function WorldServerBridge:_validateGatewayArgs(operation, args)
    local spec = gatewayRouteSpecs[operation]
    if spec == nil then return true end
    local count = arrayCount(args)
    local minArgs = tonumber(spec.minArgs) or 0
    local maxArgs = tonumber(spec.maxArgs) or minArgs
    if count < minArgs or count > maxArgs then
        return false, 'invalid_gateway_arg_count'
    end
    return true
end

function WorldServerBridge:_validateGatewayExposure(operation)
    if not isGatewayOperationExposed(operation) then
        return false, 'gateway_operation_not_exposed'
    end
    return true
end

function WorldServerBridge:handleGatewayRequest(requestEnvelope)
    self:_recordMetric('gatewayRequests', 1)
    local envelope, err = self:_decodeGatewayEnvelope(requestEnvelope)
    if not envelope then
        self.gatewayState.requestCount = self.gatewayState.requestCount + 1
        self.gatewayState.lastRequest = {
            handledAt = self.runtimeAdapter:now(),
            status = 'rejected',
            decodeError = err,
        }
        self:_setEncodedComponentField('LastGatewayRequestJson', self.gatewayState.lastRequest)
        return self:_gatewayFailure(nil, nil, err, nil)
    end

    self.gatewayState.requestCount = self.gatewayState.requestCount + 1
    self.gatewayState.lastRequest = {
        requestId = envelope.requestId,
        protocolVersion = envelope.protocolVersion,
        packetType = envelope.packetType,
        operation = envelope.operation,
        argsCount = arrayCount(envelope.args),
        handledAt = self.runtimeAdapter:now(),
        status = 'pending',
    }
    self:_setEncodedComponentField('LastGatewayRequestJson', self.gatewayState.lastRequest)

    local methodName = self.gatewayRoutes[envelope.operation]
    if methodName == nil then
        self.gatewayState.lastRequest.status = 'rejected'
        self.gatewayState.lastRequest.routeError = 'unknown_gateway_operation'
        self:_setEncodedComponentField('LastGatewayRequestJson', self.gatewayState.lastRequest)
        return self:_gatewayFailure(envelope.requestId, envelope.operation, 'unknown_gateway_operation', envelope.protocolVersion)
    end

    local exposureOk, exposureErr = self:_validateGatewayExposure(envelope.operation)
    if not exposureOk then
        self.gatewayState.lastRequest.status = 'rejected'
        self.gatewayState.lastRequest.route = methodName
        self.gatewayState.lastRequest.routeError = exposureErr
        self:_setEncodedComponentField('LastGatewayRequestJson', self.gatewayState.lastRequest)
        return self:_gatewayFailure(envelope.requestId, envelope.operation, exposureErr, envelope.protocolVersion)
    end

    local argsOk, argsErr = self:_validateGatewayArgs(envelope.operation, envelope.args)
    if not argsOk then
        self.gatewayState.lastRequest.status = 'rejected'
        self.gatewayState.lastRequest.route = methodName
        self.gatewayState.lastRequest.routeError = argsErr
        self:_setEncodedComponentField('LastGatewayRequestJson', self.gatewayState.lastRequest)
        return self:_gatewayFailure(envelope.requestId, envelope.operation, argsErr, envelope.protocolVersion)
    end

    local method = self[methodName]
    if type(method) ~= 'function' then
        self.gatewayState.lastRequest.status = 'rejected'
        self.gatewayState.lastRequest.routeError = 'invalid_gateway_route'
        self:_setEncodedComponentField('LastGatewayRequestJson', self.gatewayState.lastRequest)
        return self:_gatewayFailure(envelope.requestId, envelope.operation, 'invalid_gateway_route', envelope.protocolVersion)
    end

    local ok, encoded = pcall(method, self, arrayUnpack(envelope.args))
    if not ok then
        self.gatewayState.lastRequest.status = 'rejected'
        self.gatewayState.lastRequest.routeError = 'gateway_dispatch_failed'
        self:_setEncodedComponentField('LastGatewayRequestJson', self.gatewayState.lastRequest)
        return self:_gatewayFailure(envelope.requestId, envelope.operation, 'gateway_dispatch_failed', envelope.protocolVersion)
    end

    local decoded = self.runtimeAdapter:decodeData(encoded)
    if type(decoded) ~= 'table' then
        self.gatewayState.lastRequest.status = 'rejected'
        self.gatewayState.lastRequest.routeError = 'invalid_gateway_response'
        self:_setEncodedComponentField('LastGatewayRequestJson', self.gatewayState.lastRequest)
        return self:_gatewayFailure(envelope.requestId, envelope.operation, 'invalid_gateway_response', envelope.protocolVersion)
    end

    local payload = deepCopy(decoded)
    payload.requestId = envelope.requestId
    payload.operation = envelope.operation
    payload.protocol = buildGatewayProtocolDescriptor(envelope.protocolVersion)
    payload.gateway = {
        handledAt = self.runtimeAdapter:now(),
        route = methodName,
        status = payload.ok == true and 'ok' or 'error',
    }
    self.gatewayState.lastRequest.status = payload.gateway.status
    self.gatewayState.lastResponse = deepCopy(payload)
    self:_setEncodedComponentField('LastGatewayRequestJson', self.gatewayState.lastRequest)
    self:_setEncodedComponentField('LastGatewayResponseJson', payload)
    if payload.ok == true then
        self:_recordMetric('gatewaySucceeded', 1)
    else
        self:_recordMetric('gatewayRejected', 1)
    end
    return self.runtimeAdapter:encodeData(payload)
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
    self:_routeEvent('runtime', 'user_enter', { playerId = actor.userId, mapId = mapId })
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
    self:_routeEvent('runtime', 'user_leave', { playerId = actor.userId })
    return true
end

function WorldServerBridge:getPlayerState(requestContext)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local snapshot = self.world:publishPlayerSnapshot(player)
    self:_cachePlayerState(player.id, snapshot, 'get_player_state')
    snapshot.authority = self:_buildAuthoritySyncDescriptor(player, player.currentMapId)
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
    local cached = deepCopy(self:_cachedMapState(targetMapId))
    cached.bridgeMeta = cached.bridgeMeta or {}
    cached.bridgeMeta.authority = self:_buildAuthoritySyncDescriptor(nil, targetMapId)
    return response(self.runtimeAdapter, true, cached)
end

function WorldServerBridge:getStateDelta(requestContext, scopeId, sinceVersion)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local scope, scopeErr = self:_validateSyncScopeRequest(player, scopeId or player.currentMapId or player.id)
    if not scope then return response(self.runtimeAdapter, false, nil, scopeErr) end
    local targetScopeId = scope.scopeId
    local minimumVersion = tonumber(sinceVersion) or 0
    local deltas = {}
    for _, item in ipairs(self.deltaQueue) do
        if item.version > minimumVersion and (item.scopeId == tostring(targetScopeId) or item.scopeId == tostring(player.id) or item.scopeId == self:_entityVersionKey('boss', targetScopeId)) then
            deltas[#deltas + 1] = deepCopy(item)
        end
    end
    return response(self.runtimeAdapter, true, {
        playerId = player.id,
        scopeId = tostring(targetScopeId),
        scopeKind = scope.scopeKind,
        authority = self:_buildAuthoritySyncDescriptor(player, scope.mapId),
        sinceVersion = minimumVersion,
        latestSequence = self.deltaSequence,
        deltas = deltas,
    })
end

function WorldServerBridge:getBridgeDiagnostics()
    if not self.world then
        local world, err = self:bootstrap()
        if not world then return response(self.runtimeAdapter, false, nil, err or 'bootstrap_failed') end
    end
    local averageLatencyMs = 0
    if self.metrics.latencySamples > 0 then
        averageLatencyMs = math.floor(self.metrics.totalLatencyMs / self.metrics.latencySamples)
    end
    local gatewayDiagnostics = deepCopy(self.gatewayState)
    gatewayDiagnostics.protocol = buildGatewayProtocolDescriptor(gatewayProtocol.currentVersion)
    gatewayDiagnostics.supportedOperations = buildGatewayCatalog()
    gatewayDiagnostics.routeCount = #gatewayDiagnostics.supportedOperations
    gatewayDiagnostics.rejectionCount = tonumber(self.metrics.gatewayRejected) or 0
    gatewayDiagnostics.successCount = tonumber(self.metrics.gatewaySucceeded) or 0
    return response(self.runtimeAdapter, true, {
        metrics = deepCopy(self.metrics),
        frameState = deepCopy(self.frameState),
        queueDepth = #self.deltaQueue,
        eventDepth = #self.eventHistory,
        averageLatencyMs = averageLatencyMs,
        maxLatencyMs = self.metrics.maxLatencyMs,
        desyncIncidents = deepCopy(self.desyncIncidents),
        lifecycle = deepCopy(self.lifecycleHistory),
        recentEvents = self:_flushDeltaQueue(16),
        gateway = gatewayDiagnostics,
    })
end

function WorldServerBridge:getEventStream(limit)
    return response(self.runtimeAdapter, true, {
        events = deepCopy(self.eventHistory),
        deltas = self:_flushDeltaQueue(limit or 32),
    })
end

function WorldServerBridge:reconcileRuntimeState(requestContext, mapId)
    if not self.world then
        local world, err = self:bootstrap()
        if not world then return response(self.runtimeAdapter, false, nil, err or 'bootstrap_failed') end
    end
    local targetMapId = mapId
    local player = nil
    if targetMapId == nil and requestContext ~= nil then
        player, err = self:_resolvePlayer(requestContext, nil)
        if not player then return response(self.runtimeAdapter, false, nil, err) end
        targetMapId = player.currentMapId
    elseif requestContext ~= nil then
        player, err = self:_resolvePlayer(requestContext, nil)
        if not player then return response(self.runtimeAdapter, false, nil, err) end
        local scope, scopeErr = self:_validateSyncScopeRequest(player, targetMapId)
        if not scope then return response(self.runtimeAdapter, false, nil, scopeErr) end
        targetMapId = scope.mapId
    end
    targetMapId = targetMapId or self:_defaultMapId()
    local state = self:_reconcileMapState(targetMapId)
    self:_recordEvent('runtime', 'reconcile_runtime_state', { mapId = targetMapId })
    return response(self.runtimeAdapter, true, {
        mapId = targetMapId,
        state = state,
        authority = self:_buildAuthoritySyncDescriptor(player, targetMapId),
        diagnostics = {
            desyncIncidents = deepCopy(self.desyncIncidents),
            orphanEntities = deepCopy(self.orphanEntities),
        },
    })
end

function WorldServerBridge:dispatchRuntimeEvent(eventName, payload)
    local event = self:_routeEvent('runtime', eventName, payload)
    if not event then return response(self.runtimeAdapter, false, nil, 'invalid_router') end
    return response(self.runtimeAdapter, true, event)
end

function WorldServerBridge:routePlayerAction(requestContext, actionName, payload)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local event = self:_routeEvent('player_action', actionName, {
        playerId = player.id,
        mapId = player.currentMapId,
        payload = payload,
    })
    return response(self.runtimeAdapter, true, event)
end

function WorldServerBridge:attackMob(requestContext, mapId, spawnId, requestedDamage)
    local player, err = self:_resolvePlayer(requestContext, mapId)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    self:_routeEvent('player_action', 'attack_mob', { playerId = player.id, mapId = mapId or player.currentMapId, spawnId = spawnId })
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
    self:_routeEvent('player_action', 'pickup_drop', { playerId = player.id, mapId = mapId or player.currentMapId, dropId = dropId })
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
    self:_routeEvent('player_action', 'damage_boss', { playerId = player.id, mapId = mapId or player.currentMapId, bossId = bossId })
    local contextOk, encounterOrErr = self:_validateBossActionContext(player, mapId, bossId)
    if not contextOk then return response(self.runtimeAdapter, false, nil, encounterOrErr) end
    local ok, payload = self.world:damageBoss(player, player.currentMapId, bossId, tonumber(requestedDamage), encounterOrErr)
    if not ok then return response(self.runtimeAdapter, false, nil, payload) end
    return response(self.runtimeAdapter, true, { result = payload, map = self:_cachedMapState(player.currentMapId), player = self.world:publishPlayerSnapshot(player) })
end

function WorldServerBridge:acceptQuest(requestContext, questId)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    self:_routeEvent('player_action', 'accept_quest', { playerId = player.id, questId = questId })
    local ok, result = self.world:acceptQuest(player, questId)
    if not ok then return response(self.runtimeAdapter, false, nil, result) end
    return response(self.runtimeAdapter, true, self.world:publishPlayerSnapshot(player))
end

function WorldServerBridge:turnInQuest(requestContext, questId)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    self:_routeEvent('player_action', 'turn_in_quest', { playerId = player.id, questId = questId })
    local ok, result = self.world:turnInQuest(player, questId)
    if not ok then return response(self.runtimeAdapter, false, nil, result) end
    return response(self.runtimeAdapter, true, self.world:publishPlayerSnapshot(player))
end

function WorldServerBridge:buyFromNpc(requestContext, npcId, itemId, quantity)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    self:_routeEvent('player_action', 'buy_from_npc', { playerId = player.id, npcId = npcId, itemId = itemId, quantity = quantity })
    local contextOk, npcOrErr = self:_validateNpcActionContext(player, npcId, itemId)
    if not contextOk then return response(self.runtimeAdapter, false, nil, npcOrErr) end
    local ok, result = self.world:buyFromNpc(player, npcId, itemId, tonumber(quantity), npcOrErr)
    if not ok then return response(self.runtimeAdapter, false, nil, result) end
    return response(self.runtimeAdapter, true, self.world:publishPlayerSnapshot(player))
end

function WorldServerBridge:sellToNpc(requestContext, npcId, itemId, quantity)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    self:_routeEvent('player_action', 'sell_to_npc', { playerId = player.id, npcId = npcId, itemId = itemId, quantity = quantity })
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
    local contextOk, contextPayloadOrErr = self:_validateChangeMapContext(player, actor, mapId, sourceMapId)
    if not contextOk then return response(self.runtimeAdapter, false, nil, contextPayloadOrErr) end
    if self.world and self.world.containment and self.world.containment.migrationBlocked then
        return response(self.runtimeAdapter, false, nil, 'migration_blocked')
    end
    local transitionPayload, transitionErr = self:_buildMapTransitionPayload(player, sourceMapId, mapId)
    if not transitionPayload then return response(self.runtimeAdapter, false, nil, transitionErr) end
    local ok, result = self.world:changeMap(player, mapId, sourceMapId)
    if not ok then return response(self.runtimeAdapter, false, nil, result) end
    self:_routeEvent('world', 'map_transition', transitionPayload)
    self:_updateMapDelta(mapId, 'transition')
    return response(self.runtimeAdapter, true, self.world:publishPlayerSnapshot(player))
end

function WorldServerBridge:allocateStat(requestContext, stat, amount)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local ok, result = self.world:allocateStat(player, stat, tonumber(amount))
    if not ok then return response(self.runtimeAdapter, false, nil, result) end
    return response(self.runtimeAdapter, true, result)
end

function WorldServerBridge:promoteJob(requestContext, jobId)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local ok, result = self.world:promoteJob(player, jobId)
    if not ok then return response(self.runtimeAdapter, false, nil, result) end
    return response(self.runtimeAdapter, true, result)
end

function WorldServerBridge:learnSkill(requestContext, skillId)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local ok, result = self.world:learnSkill(player, skillId)
    if not ok then return response(self.runtimeAdapter, false, nil, result) end
    return response(self.runtimeAdapter, true, result)
end

function WorldServerBridge:castSkill(requestContext, skillId, target)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    self:_routeEvent('player_action', 'cast_skill', { playerId = player.id, skillId = skillId, target = target })
    local ok, result = self.world:castSkill(player, skillId, target)
    if not ok then return response(self.runtimeAdapter, false, nil, result) end
    return response(self.runtimeAdapter, true, { result = result, player = self.world:publishPlayerSnapshot(player) })
end

function WorldServerBridge:enhanceEquipment(requestContext, slot)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local ok, result = self.world:enhanceEquipment(player, slot)
    if not ok then return response(self.runtimeAdapter, false, nil, result) end
    return response(self.runtimeAdapter, true, { enhancement = result, player = self.world:publishPlayerSnapshot(player) })
end

function WorldServerBridge:createParty(requestContext)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local payload = self.world:createParty(player)
    self:_routeEvent('world', 'party_created', { playerId = player.id, mapId = player.currentMapId })
    return response(self.runtimeAdapter, true, payload)
end

function WorldServerBridge:createGuild(requestContext, name)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local payload = self.world:createGuild(player, name)
    self:_routeEvent('world', 'guild_created', { playerId = player.id, name = name })
    return response(self.runtimeAdapter, true, payload)
end

function WorldServerBridge:addFriend(requestContext, otherId)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local ok = self.world:addFriend(player, otherId)
    return response(self.runtimeAdapter, ok, self.world:publishPlayerSnapshot(player), ok and nil or 'friend_add_failed')
end

function WorldServerBridge:tradeMesos(requestContext, targetPlayerId, amount)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local target = self.world:createPlayer(targetPlayerId)
    local ok, result = self.world:tradeMesos(player, target, tonumber(amount))
    if not ok then return response(self.runtimeAdapter, false, nil, result) end
    self:_routeEvent('player_action', 'trade_mesos', { playerId = player.id, targetPlayerId = targetPlayerId, amount = amount })
    return response(self.runtimeAdapter, true, { player = self.world:publishPlayerSnapshot(player), target = self.world:publishPlayerSnapshot(target) })
end

function WorldServerBridge:listAuction(requestContext, itemId, quantity, price)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local ok, listing = self.world:listAuction(player, itemId, tonumber(quantity), tonumber(price))
    if ok then
        self:_routeEvent('world', 'auction_listing', { playerId = player.id, itemId = itemId, quantity = quantity, price = price })
    end
    return response(self.runtimeAdapter, ok, listing, ok and nil or 'auction_list_failed')
end

function WorldServerBridge:craftItem(requestContext, recipeId)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local ok, result = self.world:craftItem(player, recipeId)
    if not ok then return response(self.runtimeAdapter, false, nil, result) end
    return response(self.runtimeAdapter, true, self.world:publishPlayerSnapshot(player))
end

function WorldServerBridge:openDialogue(npcId)
    if not self.world then
        local world, err = self:bootstrap()
        if not world then return response(self.runtimeAdapter, false, nil, err or 'bootstrap_failed') end
    end
    return response(self.runtimeAdapter, true, self.world:openDialogue(npcId))
end

function WorldServerBridge:channelTransfer(requestContext, mapId)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local ok, result = self.world:channelTransfer(player, mapId)
    return response(self.runtimeAdapter, ok, result, ok and nil or result)
end

function WorldServerBridge:getRuntimeStatus()
    if not self.world then
        local world, err = self:bootstrap()
        if not world then return response(self.runtimeAdapter, false, nil, err or 'bootstrap_failed') end
    end
    local status = self.world:getRuntimeStatus()
    local diagnostics = self.runtimeAdapter:decodeData(self:getBridgeDiagnostics())
    status.bridge = diagnostics and diagnostics.data or nil
    return response(self.runtimeAdapter, true, status)
end

function WorldServerBridge:getReplayStatus()
    if not self.world then
        local world, err = self:bootstrap()
        if not world then return response(self.runtimeAdapter, false, nil, err or 'bootstrap_failed') end
    end
    return response(self.runtimeAdapter, true, self.world.adminTools:getReplayStatus(self.world))
end

function WorldServerBridge:getOwnershipTopology()
    if not self.world then
        local world, err = self:bootstrap()
        if not world then return response(self.runtimeAdapter, false, nil, err or 'bootstrap_failed') end
    end
    local payload = self.world.adminTools:getOwnershipTopology(self.world)
    payload.bridge = {
        activeSessions = deepCopy(self.activeSessions),
        trackedMobEntities = tableCount(self.mobEntities),
        trackedDropEntities = tableCount(self.dropEntities),
        trackedBossEntities = tableCount(self.bossEntities),
    }
    return response(self.runtimeAdapter, true, payload)
end

function WorldServerBridge:getControlPlaneReport()
    if not self.world then
        local world, err = self:bootstrap()
        if not world then return response(self.runtimeAdapter, false, nil, err or 'bootstrap_failed') end
    end
    local payload = self.world:getControlPlaneReport()
    payload.bridgeDiagnostics = self.runtimeAdapter:decodeData(self:getBridgeDiagnostics()).data
    return response(self.runtimeAdapter, true, payload)
end

function WorldServerBridge:getEventTruth()
    if not self.world then
        local world, err = self:bootstrap()
        if not world then return response(self.runtimeAdapter, false, nil, err or 'bootstrap_failed') end
    end
    local payload = self.world.adminTools:getEventTruth(self.world, {})
    payload.bridgeEventHistory = deepCopy(self.eventHistory)
    return response(self.runtimeAdapter, true, payload)
end

function WorldServerBridge:getEconomyReport()
    if not self.world then
        local world, err = self:bootstrap()
        if not world then return response(self.runtimeAdapter, false, nil, err or 'bootstrap_failed') end
    end
    local payload = self.world:getEconomyReport()
    payload.marketSync = {
        latestDeltaSequence = self.deltaSequence,
        queueDepth = #self.deltaQueue,
    }
    return response(self.runtimeAdapter, true, payload)
end

function WorldServerBridge:adminStatus()
    if not self.world then
        local world, err = self:bootstrap()
        if not world then return response(self.runtimeAdapter, false, nil, err or 'bootstrap_failed') end
    end
    local payload = self.world:adminStatus()
    payload.bridge = self.runtimeAdapter:decodeData(self:getBridgeDiagnostics()).data
    return response(self.runtimeAdapter, true, payload)
end

function WorldServerBridge:getBuildRecommendation(requestContext)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    return response(self.runtimeAdapter, true, self.world.buildRecommendationSystem:recommend(player))
end

function WorldServerBridge:getTutorialState(requestContext)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    return response(self.runtimeAdapter, true, { tutorial = player.tutorial, current = self.world.tutorialSystem:getCurrent(player) })
end

function WorldServerBridge:listPartyFinder(requestContext)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    return response(self.runtimeAdapter, true, self.world:findParties({ mapId = player.currentMapId }))
end

function WorldServerBridge:createRaid(requestContext, bossId)
    local player, err = self:_resolvePlayer(requestContext, nil)
    if not player then return response(self.runtimeAdapter, false, nil, err) end
    local payload = self.world:createRaid(player, bossId)
    self:_routeEvent('world', 'raid_created', { playerId = player.id, bossId = bossId, mapId = player.currentMapId })
    return response(self.runtimeAdapter, true, payload)
end

function WorldServerBridge:shutdown()
    if self.world and self.world.onShutdown then
        pcall(function() self.world:onShutdown() end)
    end
    self:_recordLifecycle('shutdown', {
        activeSessions = deepCopy(self.activeSessions),
        queueDepth = #self.deltaQueue,
    })
    return response(self.runtimeAdapter, true, { shutdown = true, lifecycle = deepCopy(self.lifecycleHistory) })
end

return WorldServerBridge
