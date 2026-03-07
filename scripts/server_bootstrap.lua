local SpawnSystem = require('scripts.spawn_system')
local DropSystem = require('scripts.drop_system')
local ExpSystem = require('scripts.exp_system')
local ItemSystem = require('scripts.item_system')
local BossSystem = require('scripts.boss_system')
local QuestSystem = require('scripts.quest_system')
local EconomySystem = require('scripts.economy_system')
local Metrics = require('ops.metrics')
local Scheduler = require('ops.event_scheduler')
local AdminTools = require('ops.admin_tools')
local Healthcheck = require('ops.healthcheck')
local PlayerRepository = require('ops.player_repository')
local WorldRepository = require('ops.world_repository')
local EventJournal = require('ops.event_journal')
local ActionGuard = require('ops.action_guard')
local RuntimeAdapter = require('ops.runtime_adapter')

local ServerBootstrap = {}

local function safeRequire(name)
    local ok, mod = pcall(require, name)
    if ok then return mod end
    return nil
end

local function cloneRows(rows)
    local out = {}
    for i, row in ipairs(rows or {}) do
        local copy = {}
        for k, v in pairs(row) do copy[k] = v end
        out[i] = copy
    end
    return out
end

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

local function parseCsv(path)
    local rows, header = {}, nil
    local file = assert(io.open(path, 'r'))
    for line in file:lines() do
        if line ~= '' then
            local cols = {}
            for value in string.gmatch(line .. ',', '(.-),') do cols[#cols + 1] = value end
            if not header then
                header = cols
            else
                local row = {}
                for i, key in ipairs(header) do row[key] = cols[i] end
                rows[#rows + 1] = row
            end
        end
    end
    file:close()
    return rows
end

local function indexBy(rows, key)
    local indexed = {}
    for _, row in ipairs(rows) do indexed[row[key]] = row end
    return indexed
end

local function buildDrops(rows)
    local out = {}
    for _, row in ipairs(rows) do
        out[row.mob_id] = out[row.mob_id] or {}
        out[row.mob_id][#out[row.mob_id] + 1] = {
            itemId = row.item_id,
            chance = tonumber(row.chance),
            minQty = tonumber(row.min_qty),
            maxQty = tonumber(row.max_qty),
            rarity = row.rarity,
            bindOnPickup = row.bind_on_pickup == 'true',
        }
    end
    return out
end

local function buildExpCurve(rows)
    local out = {}
    for _, row in ipairs(rows) do out[tonumber(row.level)] = tonumber(row.exp_to_next) end
    return out
end

local function buildBoss(rows, worldConfig)
    local out = {}
    for _, row in ipairs(rows) do
        local runtimeBoss = worldConfig and worldConfig.bosses and worldConfig.bosses[row.boss_id] or {}
        out[row.boss_id] = {
            id = row.boss_id,
            mapId = row.map_id,
            hp = tonumber(row.hp),
            trigger = row.trigger,
            cooldownSec = tonumber(row.cooldown_sec),
            rareDropGroup = row.rare_drop_group,
            assetKey = row.asset_key,
            modelId = runtimeBoss and runtimeBoss.modelId or row.asset_key,
            parentPath = runtimeBoss and runtimeBoss.parentPath or nil,
            position = runtimeBoss and deepcopy(runtimeBoss.spawnPosition) or nil,
        }
    end
    return out
end

local function buildQuests(rows)
    local out = {}
    for _, row in ipairs(rows) do
        local objectives = {}
        for objective in string.gmatch(row.objectives or '', '[^|]+') do
            local t, target, required = objective:match('([^:]+):([^:]+):([^:]+)')
            objectives[#objectives + 1] = { type=t, targetId=target, required=tonumber(required) }
        end
        local rewardItems = {}
        if row.reward_items ~= '' then
            for reward in string.gmatch(row.reward_items, '[^|]+') do
                local itemId, quantity = reward:match('([^:]+):([^:]+)')
                rewardItems[#rewardItems + 1] = { itemId=itemId, quantity=tonumber(quantity) }
            end
        end
        out[row.quest_id] = {
            id = row.quest_id,
            name = row.name,
            requiredLevel = tonumber(row.required_level),
            objectives = objectives,
            rewardExp = tonumber(row.reward_exp),
            rewardMesos = tonumber(row.reward_mesos),
            rewardItems = rewardItems,
            startNpc = row.start_npc,
            endNpc = row.end_npc,
        }
    end
    return out
end

local function requireRuntimeTables()
    return safeRequire('data.runtime_tables')
end

local function requireWorldConfig()
    return safeRequire('data.world_runtime') or {
        runtime = {
            defaultMapId = 'henesys_hunting_ground',
            componentAttachPath = '/server_runtime',
            spawnTickSec = 5,
            bossTickSec = 15,
            autosaveTickSec = 30,
            worldStateAutosaveTickSec = 15,
            healthTickSec = 30,
            dropExpireTickSec = 5,
            dropExpireSec = 90,
            dropOwnerWindowSec = 2,
            maxWorldDropsPerMap = 250,
            playerStorageName = 'GenesisPlayerState',
            playerStorageKey = 'profile',
            playerProfileSlotCount = 2,
            worldStorageName = 'GenesisWorldState',
            worldStorageKey = 'state',
            worldStateSlotCount = 3,
            journalMaxEntries = 0,
            autoPickupDrops = true,
        },
        combat = {
            minimumDamage = 1,
            mobDamageCapFactor = 6.0,
            bossDamageCapFactor = 4.0,
            mobDamageMinCap = 12,
            bossDamageMinCap = 0,
            mobDamageFloorPerLevel = 4,
            bossDamageFloorPerLevel = 8,
        },
        actionBoundaries = {
            mobAttackRange = 48,
            bossAttackRange = 64,
            dropPickupRange = 32,
            questNpcRange = 28,
        },
        actionRateLimits = {},
        maps = {
            henesys_hunting_ground = {
                spawnPosition = { x = 20, y = 0, z = 0 },
                spawnGroups = {
                    { id='group_snail', mobId='snail', maxAlive=12, points={{x=10,y=0},{x=35,y=0},{x=60,y=0}} },
                    { id='group_mushroom', mobId='orange_mushroom', maxAlive=8, points={{x=120,y=0},{x=145,y=0}} },
                },
            },
            ant_tunnel_1 = {
                spawnPosition = { x = 28, y = 0, z = 0 },
                spawnGroups = {
                    { id='group_horny', mobId='horny_mushroom', maxAlive=10, points={{x=20,y=0},{x=90,y=0}} },
                    { id='group_zombie', mobId='zombie_mushroom', maxAlive=6, points={{x=130,y=0},{x=190,y=0}} },
                },
            },
            forest_edge = { spawnPosition = { x = 80, y = 0, z = 0 }, spawnGroups = {} },
            perion_rocky = { spawnPosition = { x = 110, y = 0, z = 0 }, spawnGroups = {} },
        },
        bosses = {
            mano = { modelId = 'boss/mano', parentPath = '/server_runtime/forest_edge/bosses', spawnPosition = { x = 80, y = 0, z = 0 } },
            stumpy = { modelId = 'boss/stumpy', parentPath = '/server_runtime/perion_rocky/bosses', spawnPosition = { x = 110, y = 0, z = 0 } },
        },
        drops = {
            defaultModelId = 'item/red_potion',
            modelIds = {},
        },
        quests = {
            npcBindings = {
                Rina = { mapId = 'henesys_hunting_ground', x = 20, y = 0, z = 0 },
                Sera = { mapId = 'henesys_hunting_ground', x = 20, y = 0, z = 0 },
                Chief_Stan = { mapId = 'forest_edge', x = 80, y = 0, z = 0 },
            },
        },
    }
end

local function loadRows(basePath, relativePath, providerKey, dataProvider, warnings, dataSources)
    if basePath and io and io.open then
        local ok, rows = pcall(parseCsv, basePath .. '/' .. relativePath)
        if ok then
            dataSources[providerKey] = 'csv'
            return rows
        end
        warnings[#warnings + 1] = 'csv_fallback:' .. relativePath
    end

    if dataProvider and dataProvider[providerKey] then
        dataSources[providerKey] = 'runtime_tables'
        return cloneRows(dataProvider[providerKey])
    end

    error('Missing data source for ' .. tostring(providerKey))
end

local function randomInt(rng, minValue, maxValue)
    local minAmount = math.floor(tonumber(minValue) or 0)
    local maxAmount = math.floor(tonumber(maxValue) or minAmount)
    if maxAmount <= minAmount then return minAmount end
    local roll = tonumber(rng()) or 0
    local span = maxAmount - minAmount + 1
    local value = minAmount + math.floor(roll * span)
    if value > maxAmount then value = maxAmount end
    return value
end

local function summarizeDataSources(dataSources)
    local hasCsv, hasRuntime = false, false
    for _, source in pairs(dataSources) do
        if source == 'csv' then hasCsv = true end
        if source == 'runtime_tables' then hasRuntime = true end
    end
    if hasCsv and hasRuntime then return 'mixed' end
    if hasRuntime then return 'runtime_tables' end
    return 'csv'
end

local function countTableKeys(value)
    local count = 0
    for _ in pairs(value or {}) do count = count + 1 end
    return count
end

function ServerBootstrap.boot(basePath, config)
    if type(basePath) == 'table' and config == nil then
        config = basePath
        basePath = config.basePath
    end
    config = config or {}

    local metrics = config.metrics or Metrics.new()
    local scheduler = config.scheduler or Scheduler.new({ metrics = metrics, maxRunsPerTick = config.maxRunsPerTick or 5 })
    local logger = config.logger or metrics
    local dataProvider = config.dataProvider or requireRuntimeTables()
    local worldConfig = config.worldConfig or requireWorldConfig()
    local warnings, dataSources = {}, {}
    local runtimeAdapter = config.runtimeAdapter or RuntimeAdapter.new({ metrics = metrics, logger = logger })
    local runtimeClock = config.time or function() return runtimeAdapter:now() end

    local mobsRaw = loadRows(basePath, 'data/mobs.csv', 'mobs', dataProvider, warnings, dataSources)
    local itemsRaw = loadRows(basePath, 'data/items.csv', 'items', dataProvider, warnings, dataSources)
    local dropsRaw = loadRows(basePath, 'data/drops.csv', 'drops', dataProvider, warnings, dataSources)
    local expRaw = loadRows(basePath, 'data/exp_curve.csv', 'exp_curve', dataProvider, warnings, dataSources)
    local bossRaw = loadRows(basePath, 'data/boss.csv', 'boss', dataProvider, warnings, dataSources)
    local questRaw = loadRows(basePath, 'data/quests.csv', 'quests', dataProvider, warnings, dataSources)

    local mobs = indexBy(mobsRaw, 'mob_id')
    for _, mob in pairs(mobs) do
        mob.level = tonumber(mob.level)
        mob.hp = tonumber(mob.hp)
        mob.exp = tonumber(mob.exp)
        mob.mesos_min = tonumber(mob.mesos_min)
        mob.mesos_max = tonumber(mob.mesos_max)
        mob.respawn_sec = tonumber(mob.respawn_sec)
        mob.assetKey = mob.asset_key
    end

    local items = indexBy(itemsRaw, 'item_id')
    for _, item in pairs(items) do
        item.requiredLevel = tonumber(item.required_level)
        item.attack = tonumber(item.attack)
        item.defense = tonumber(item.defense)
        item.stackable = item.stackable == 'true'
        item.npcPrice = tonumber(item.npc_price)
        item.assetKey = item.asset_key
    end

    local playerRepository = config.playerRepository
    if not playerRepository then
        if config.useMapleWorldsDataStorage ~= false and runtimeAdapter:hasDataStorage() then
            playerRepository = PlayerRepository.newMapleWorldsDataStorage({
                runtimeAdapter = runtimeAdapter,
                metrics = metrics,
                logger = logger,
                storageName = worldConfig.runtime and worldConfig.runtime.playerStorageName,
                key = worldConfig.runtime and worldConfig.runtime.playerStorageKey,
                slotCount = worldConfig.runtime and worldConfig.runtime.playerProfileSlotCount,
            })
        else
            playerRepository = PlayerRepository.newMemory({ metrics = metrics, logger = logger })
        end
    end

    local worldRepository = config.worldRepository
    if not worldRepository then
        if config.useMapleWorldsDataStorage ~= false and runtimeAdapter:hasDataStorage() then
            worldRepository = WorldRepository.newMapleWorldsDataStorage({
                runtimeAdapter = runtimeAdapter,
                metrics = metrics,
                logger = logger,
                storageName = worldConfig.runtime and worldConfig.runtime.worldStorageName,
                key = worldConfig.runtime and worldConfig.runtime.worldStorageKey,
                slotCount = worldConfig.runtime and worldConfig.runtime.worldStateSlotCount,
            })
        else
            worldRepository = WorldRepository.newMemory({ metrics = metrics, logger = logger })
        end
    end

    local rng = config.rng or math.random
    local journal = config.eventJournal or EventJournal.new({ metrics = metrics, logger = logger, time = runtimeClock, maxEntries = worldConfig.runtime and worldConfig.runtime.journalMaxEntries })
    local actionGuard = config.actionGuard or ActionGuard.new({
        limits = worldConfig.actionRateLimits,
        time = runtimeClock,
        metrics = metrics,
        logger = logger,
        bucketTtlSec = worldConfig.runtime and worldConfig.runtime.actionBucketTtlSec,
        maxBuckets = worldConfig.runtime and worldConfig.runtime.maxActionBuckets,
    })

    local itemSystem = ItemSystem.new({ items = items, metrics = metrics, logger = logger })
    local dropSystem = DropSystem.new({
        dropTable = buildDrops(dropsRaw),
        items = items,
        metrics = metrics,
        logger = logger,
        rng = rng,
        time = runtimeClock,
        dropExpireSec = worldConfig.runtime and worldConfig.runtime.dropExpireSec,
        ownerWindowSec = worldConfig.runtime and worldConfig.runtime.dropOwnerWindowSec,
        maxActivePerMap = worldConfig.runtime and worldConfig.runtime.maxWorldDropsPerMap,
    })
    local expSystem = ExpSystem.new({ curve = buildExpCurve(expRaw), metrics = metrics, logger = logger })
    local economySystem = EconomySystem.new({ itemSystem = itemSystem, metrics = metrics, logger = logger, npcSellRate = config.npcSellRate, maxMesos = config.maxMesos })
    local bossSystem = BossSystem.new({ bossTable = buildBoss(bossRaw, worldConfig), dropSystem = dropSystem, metrics = metrics, logger = logger, time = runtimeClock })
    local questSystem = QuestSystem.new({ quests = buildQuests(questRaw), itemSystem = itemSystem, economySystem = economySystem, expSystem = expSystem, metrics = metrics, logger = logger })
    local spawnSystem = SpawnSystem.new({ mobs = mobs, scheduler = scheduler, metrics = metrics, logger = logger, rng = rng, maxSpawnPerTick = config.maxSpawnPerTick })
    local healthcheck = Healthcheck.new({ metrics = metrics, scheduler = scheduler })
    local adminTools = AdminTools.new({ metrics = metrics, scheduler = scheduler })

    local world = {
        metrics = metrics,
        scheduler = scheduler,
        spawnSystem = spawnSystem,
        dropSystem = dropSystem,
        expSystem = expSystem,
        itemSystem = itemSystem,
        bossSystem = bossSystem,
        questSystem = questSystem,
        economySystem = economySystem,
        adminTools = adminTools,
        healthcheck = healthcheck,
        players = {},
        mapPlayers = {},
        mobs = mobs,
        items = items,
        playerRepository = playerRepository,
        worldRepository = worldRepository,
        runtimeAdapter = runtimeAdapter,
        runtimeHooks = config.runtimeHooks or {},
        worldConfig = worldConfig,
        actionGuard = actionGuard,
        journal = journal,
        rng = rng,
        clock = runtimeClock,
        strictRuntimeBoundary = runtimeAdapter:isLive(),
        autoPickupDrops = config.autoPickupDrops,
        bootReport = {
            dataSource = summarizeDataSources(dataSources),
            dataSources = dataSources,
            warnings = warnings,
        },
    }
    if world.autoPickupDrops == nil then
        world.autoPickupDrops = worldConfig.runtime and worldConfig.runtime.autoPickupDrops ~= false
    end
    healthcheck.world = world

    function world:_now()
        return math.floor(tonumber(self.clock()) or os.time())
    end

    function world:_emit(hookName, ...)
        local fn = self.runtimeHooks and self.runtimeHooks[hookName]
        if type(fn) ~= 'function' then return end
        local ok, err = pcall(fn, self, ...)
        if not ok and self.metrics then
            self.metrics:increment('world.runtime_hook_error', 1, { hook = tostring(hookName) })
            self.metrics:error('runtime_hook_failed', { hook = tostring(hookName), error = tostring(err) })
        end
    end

    function world:_normalizePosition(position)
        return self.runtimeAdapter:normalizePosition(position)
    end

    function world:_defaultMapPosition(mapId)
        local mapCfg = self.worldConfig.maps and self.worldConfig.maps[mapId] or nil
        local position = mapCfg and self:_normalizePosition(mapCfg.spawnPosition) or nil
        if position then return position end
        if mapCfg and type(mapCfg.spawnGroups) == 'table' then
            local group = mapCfg.spawnGroups[1]
            local point = group and group.points and group.points[1] or nil
            position = self:_normalizePosition(point)
            if position then return position end
        end
        return { x = 0, y = 0, z = 0 }
    end

    function world:_bossPosition(encounter)
        local position = encounter and self:_normalizePosition(encounter.position) or nil
        if position then return position end
        local bossCfg = encounter and self.worldConfig.bosses and self.worldConfig.bosses[encounter.bossId] or nil
        return self:_normalizePosition(bossCfg and bossCfg.spawnPosition) or self:_defaultMapPosition(encounter and encounter.mapId)
    end

    function world:_setPlayerPosition(player, position, authoritative)
        if not player then return end
        local normalized = self:_normalizePosition(position) or self:_defaultMapPosition(player.currentMapId)
        player.position = normalized
        if authoritative ~= nil then player.positionAuthoritative = authoritative == true end
        if authoritative == true then player.lastRuntimeSyncAt = self:_now() end
    end

    function world:updatePlayerRuntimeState(player, mapId, position, authoritative)
        if not player then return false, 'invalid_player' end
        if mapId and mapId ~= '' and mapId ~= player.currentMapId then
            local ok, err = self:setPlayerMap(player, mapId)
            if not ok then return false, err end
        elseif not player.currentMapId then
            player.currentMapId = mapId or (self.worldConfig.runtime and self.worldConfig.runtime.defaultMapId) or 'henesys_hunting_ground'
        end

        if position then
            self:_setPlayerPosition(player, position, authoritative)
        elseif not player.position then
            self:_setPlayerPosition(player, self:_defaultMapPosition(player.currentMapId), not self.strictRuntimeBoundary)
        end
        return true
    end

    function world:_playerPosition(player)
        local position = player and self:_normalizePosition(player.position) or nil
        if position then return position end
        if self.strictRuntimeBoundary then return nil end
        return self:_defaultMapPosition(player and player.currentMapId)
    end

    function world:_requireActionBoundary(player, targetMapId, targetPosition, radiusKey)
        if not player then return false, 'invalid_player' end
        if not targetMapId or targetMapId == '' then return false, 'invalid_map' end
        if player.currentMapId ~= targetMapId then return false, 'wrong_map' end

        local radius = tonumber(self.worldConfig.actionBoundaries and self.worldConfig.actionBoundaries[radiusKey]) or 0
        if radius <= 0 or targetPosition == nil then return true end

        local playerPosition = self:_playerPosition(player)
        if not playerPosition then return false, 'position_unavailable' end
        local distanceSq = self.runtimeAdapter:distanceSquared(playerPosition, targetPosition)
        if distanceSq == nil then return false, 'position_unavailable' end
        if distanceSq > (radius * radius) then return false, 'out_of_range' end
        return true
    end

    function world:_questBinding(quest, mode)
        local npcName = mode == 'turn_in' and quest.endNpc or quest.startNpc
        local bindings = self.worldConfig.quests and self.worldConfig.quests.npcBindings or {}
        local binding = bindings[npcName] or {}
        local mapId = binding.mapId or self.worldConfig.runtime.defaultMapId
        local position = self:_normalizePosition(binding) or self:_defaultMapPosition(mapId)
        return {
            npc = npcName,
            mapId = mapId,
            position = position,
        }
    end

    function world:snapshotWorldState()
        return {
            version = 1,
            savedAt = self:_now(),
            boss = self.bossSystem:snapshot(),
            drops = self.dropSystem:snapshot(),
            journal = self.journal:serialize(),
        }
    end

    function world:saveWorldState(reason)
        if not self.worldRepository or self._restoringWorldState or self._savingWorldState then return true end
        self._savingWorldState = true
        local ok, err = self.worldRepository:save(self:snapshotWorldState())
        self._savingWorldState = false
        if not ok and self.metrics then
            self.metrics:increment('world_state.save_error', 1, { reason = tostring(reason) })
            self.metrics:error('world_state_save_failed', { reason = tostring(reason), error = tostring(err) })
        end
        return ok, err
    end

    function world:restoreWorldState()
        if not self.worldRepository then return false end
        local snapshot, err = self.worldRepository:load()
        if not snapshot then return false, err end

        self._restoringWorldState = true
        self.journal:restore(snapshot.journal)
        self.dropSystem:restore(snapshot.drops)
        self.bossSystem:restore(snapshot.boss)
        self._restoringWorldState = false

        for _, drop in ipairs(self.dropSystem:listAllDrops()) do
            self:_emit('onDropSpawned', drop)
        end
        for _, encounter in pairs(self.bossSystem.encounters) do
            if encounter.alive then self:_emit('onBossSpawned', encounter) end
        end
        return true
    end

    journal.onAppend = function(entry)
        if world._restoringWorldState then return end
        world:saveWorldState('journal:' .. tostring(entry and entry.event))
    end

    spawnSystem.callbacks = {
        onSpawn = function(mob)
            world.journal:append('mob_spawned', { mapId = mob.mapId, mobId = mob.mobId, spawnId = mob.spawnId })
            world:_emit('onMobSpawned', mob)
        end,
        onKill = function(mob)
            world:_emit('onMobRemoved', mob)
        end,
    }

    function world:_rollMesos(minMesos, maxMesos)
        return randomInt(self.rng, minMesos, maxMesos)
    end

    function world:getActivePlayerCount()
        return countTableKeys(self.players)
    end

    function world:getMapPopulation(mapId)
        return countTableKeys(self.mapPlayers[mapId] or {})
    end

    function world:_removePlayerFromMap(playerId, mapId)
        local mapPlayers = self.mapPlayers[mapId]
        if mapPlayers then mapPlayers[playerId] = nil end
    end

    function world:setPlayerMap(player, mapId)
        if not player then return false, 'invalid_player' end
        if not mapId or mapId == '' then return false, 'invalid_map' end

        if player.currentMapId == mapId then
            if not player.position then self:_setPlayerPosition(player, self:_defaultMapPosition(mapId), not self.strictRuntimeBoundary) end
            return true
        end
        if player.currentMapId then self:_removePlayerFromMap(player.id, player.currentMapId) end
        self.mapPlayers[mapId] = self.mapPlayers[mapId] or {}
        self.mapPlayers[mapId][player.id] = true
        player.currentMapId = mapId
        player.lastMapChangeAt = self:_now()
        player.dirty = true
        self:_setPlayerPosition(player, self:_defaultMapPosition(mapId), not self.strictRuntimeBoundary)
        self.journal:append('player_map_changed', { playerId = player.id, mapId = mapId })
        self:_emit('onPlayerMapChanged', player, mapId)
        return true
    end

    function world:savePlayer(player)
        if not player or not player.id then return false, 'invalid_player' end
        local ok, err = self.playerRepository:save(player)
        if ok then
            player.dirty = false
            player.lastSavedAt = self:_now()
            self.journal:append('player_saved', { playerId = player.id, version = player.version, at = player.lastSavedAt })
        end
        return ok, err
    end

    function world:flushDirtyPlayers()
        local saved = 0
        for _, player in pairs(self.players) do
            if player.dirty then
                local ok = self:savePlayer(player)
                if ok then saved = saved + 1 end
            end
        end
        if self.metrics then self.metrics:gauge('world.dirty_players_saved', saved) end
        return saved
    end

    function world:createPlayer(playerId)
        if self.players[playerId] then return self.players[playerId] end
        local loaded = self.playerRepository:load(playerId)
        local player = self.itemSystem:sanitizePlayerProfile(loaded, playerId)
        player.currentMapId = player.currentMapId or (self.worldConfig.runtime and self.worldConfig.runtime.defaultMapId) or 'henesys_hunting_ground'
        if loaded then player.dirty = false else player.dirty = true end
        if not player.position then self:_setPlayerPosition(player, self:_defaultMapPosition(player.currentMapId), not self.strictRuntimeBoundary) end
        self.players[playerId] = player
        self.mapPlayers[player.currentMapId] = self.mapPlayers[player.currentMapId] or {}
        self.mapPlayers[player.currentMapId][playerId] = true
        self.journal:append('player_loaded', { playerId = playerId, loaded = loaded ~= nil })
        return player
    end

    function world:onPlayerEnter(playerId, mapId, position)
        local player = self:createPlayer(playerId)
        if mapId then self:setPlayerMap(player, mapId) end
        self:updatePlayerRuntimeState(player, mapId, position, self.strictRuntimeBoundary)
        self:_emit('onPlayerEnter', player)
        self:publishPlayerSnapshot(player)
        return player
    end

    function world:onPlayerLeave(playerId)
        local player = self.players[playerId]
        if not player then return false, 'player_not_found' end
        self:savePlayer(player)
        self:_emit('onPlayerLeave', player)
        self:_removePlayerFromMap(playerId, player.currentMapId)
        self.players[playerId] = nil
        self.journal:append('player_unloaded', { playerId = playerId })
        return true
    end

    function world:publishPlayerSnapshot(player)
        local snapshot = {
            playerId = player.id,
            level = player.level,
            exp = player.exp,
            expToNext = self.expSystem:requiredFor(player.level),
            mesos = player.mesos,
            power = self.itemSystem:getPower(player),
            currentMapId = player.currentMapId,
            position = deepcopy(player.position),
            stats = player.stats,
            inventory = self.itemSystem:exportInventory(player),
            equipment = player.equipment,
            quests = self.questSystem:snapshotPlayer(player),
            kills = player.killLog,
            dirty = player.dirty,
            version = player.version,
        }
        self:_emit('onPlayerSnapshot', player, snapshot)
        return snapshot
    end

    function world:getMapState(mapId)
        local mapState = self.spawnSystem.maps[mapId]
        local mobsOut = {}
        if mapState then
            for spawnId, mob in pairs(mapState.active) do
                mobsOut[#mobsOut + 1] = {
                    spawnId = spawnId,
                    mobId = mob.mobId,
                    hp = mob.hp,
                    maxHp = mob.maxHp,
                    x = mob.x,
                    y = mob.y,
                    groupId = mob.spawnGroupId,
                }
            end
            table.sort(mobsOut, function(a, b) return a.spawnId < b.spawnId end)
        end
        local encounter = self.bossSystem:getEncounter(mapId)
        local bossOut = nil
        if encounter then
            local position = self:_bossPosition(encounter)
            bossOut = {
                bossId = encounter.bossId,
                hp = encounter.hp,
                maxHp = encounter.maxHp,
                phase = encounter.phase,
                alive = encounter.alive,
                enraged = encounter.enraged,
                x = position and position.x or 0,
                y = position and position.y or 0,
                z = position and position.z or 0,
            }
        end
        return {
            mapId = mapId,
            population = self:getMapPopulation(mapId),
            mobs = mobsOut,
            drops = self.dropSystem:listDrops(mapId),
            boss = bossOut,
            now = self:_now(),
        }
    end

    function world:_checkAction(player, action, cost)
        local ok, err = self.actionGuard:check(player and player.id or nil, action, cost or 1)
        if not ok then return false, err end
        return true
    end

    function world:_capDamage(player, targetKind, requestedDamage)
        local requested = math.floor(tonumber(requestedDamage) or 0)
        if requested <= 0 then return nil, 'invalid_amount' end
        local combatCfg = self.worldConfig.combat or {}
        local minimumDamage = tonumber(combatCfg.minimumDamage) or 1
        local base = math.max(minimumDamage, self.itemSystem:getPower(player))
        local factor = targetKind == 'boss' and (tonumber(combatCfg.bossDamageCapFactor) or 4) or (tonumber(combatCfg.mobDamageCapFactor) or 6)
        local fixedFloor = targetKind == 'boss' and (tonumber(combatCfg.bossDamageMinCap) or 0) or (tonumber(combatCfg.mobDamageMinCap) or 0)
        local perLevel = targetKind == 'boss' and (tonumber(combatCfg.bossDamageFloorPerLevel) or 0) or (tonumber(combatCfg.mobDamageFloorPerLevel) or 0)
        local levelFloor = math.max(0, math.floor((tonumber(player and player.level) or 1) * perLevel))
        local cap = math.max(minimumDamage, math.floor(base * factor), math.floor(fixedFloor), levelFloor)
        if requested > cap then requested = cap end
        return requested
    end

    function world:_processDropAcquisition(player, mapId, source, rawDrops, forceAutoPickup)
        local autoPickup = forceAutoPickup == true or self.autoPickupDrops == true
        if autoPickup then
            for _, drop in ipairs(rawDrops) do
                self.itemSystem:addItem(player, drop.itemId, drop.quantity)
                self.questSystem:onItemAcquired(player, drop.itemId, drop.quantity)
            end
            return rawDrops
        end

        local records = self.dropSystem:registerDrops(mapId, source, rawDrops, {
            ownerId = player.id,
            ownerWindowSec = self.worldConfig.runtime and self.worldConfig.runtime.dropOwnerWindowSec,
            now = self:_now(),
        })
        for _, record in ipairs(records) do self:_emit('onDropSpawned', record) end
        return records
    end

    function world:_applyMobRewards(player, mob, forceAutoPickup)
        self.expSystem:grant(player, mob.template.exp or 0)
        self.economySystem:grantMesos(player, self:_rollMesos(mob.template.mesos_min, mob.template.mesos_max), 'mob_drop')
        local rawDrops = self.dropSystem:rollDrops(mob, player)
        local delivered = self:_processDropAcquisition(player, mob.mapId, mob, rawDrops, forceAutoPickup)
        self.questSystem:onKill(player, mob.mobId, 1)
        player.killLog[mob.mobId] = (player.killLog[mob.mobId] or 0) + 1
        player.dirty = true
        self.journal:append('mob_killed', { playerId = player.id, mapId = mob.mapId, mobId = mob.mobId, spawnId = mob.spawnId })
        self:_emit('onMobKilled', player, mob, delivered)
        self:publishPlayerSnapshot(player)
        return delivered
    end

    function world:attackMob(player, mapId, spawnId, requestedDamage)
        if not player then return false, 'invalid_player' end
        local targetMapId = player.currentMapId or mapId
        local mob = self.spawnSystem:getMob(targetMapId, spawnId)
        if not mob and mapId and mapId ~= targetMapId and self.spawnSystem:getMob(mapId, spawnId) then
            return false, 'wrong_map'
        end
        if not mob then return false, 'mob_not_found' end

        local boundaryOk, boundaryErr = self:_requireActionBoundary(player, mob.mapId, { x = mob.x, y = mob.y, z = mob.z or 0 }, 'mobAttackRange')
        if not boundaryOk then return false, boundaryErr end
        local actionOk, actionErr = self:_checkAction(player, 'mob_attack', 1)
        if not actionOk then return false, actionErr end
        local damage, damageErr = self:_capDamage(player, 'mob', requestedDamage)
        if not damage then return false, damageErr end

        local ok, mobOrErr, killed = self.spawnSystem:damageMob(mob.mapId, spawnId, damage)
        if not ok then return false, mobOrErr end
        if killed then
            return true, self:_applyMobRewards(player, mobOrErr, false), mobOrErr
        end
        self:_emit('onMobDamaged', player, mobOrErr)
        return true, nil, mobOrErr
    end

    function world:killMob(player, mapId, spawnId)
        if not player then return nil, 'invalid_player' end
        local mob = self.spawnSystem:killMob(mapId, spawnId)
        if not mob then return nil, 'mob_not_found' end
        return self:_applyMobRewards(player, mob, true)
    end

    function world:pickupDrop(player, mapId, dropId)
        if not player then return false, 'invalid_player' end
        local record = self.dropSystem:getDrop(dropId)
        if not record then return false, 'drop_not_found' end
        local boundaryOk, boundaryErr = self:_requireActionBoundary(player, record.mapId, { x = record.x, y = record.y, z = record.z or 0 }, 'dropPickupRange')
        if not boundaryOk then return false, boundaryErr end
        local actionOk, actionErr = self:_checkAction(player, 'drop_pickup', 1)
        if not actionOk then return false, actionErr end
        local ok, recordOrErr = self.dropSystem:pickupDrop(player, record.mapId, dropId, self.itemSystem, { now = self:_now() })
        if not ok then return false, recordOrErr end
        self.questSystem:onItemAcquired(player, recordOrErr.itemId, recordOrErr.quantity)
        self.journal:append('drop_picked', { playerId = player.id, mapId = record.mapId, dropId = dropId, itemId = recordOrErr.itemId })
        self:_emit('onDropPicked', recordOrErr, player)
        self:publishPlayerSnapshot(player)
        return true, recordOrErr
    end

    function world:spawnBoss(bossId, mapId)
        local def = self.bossSystem.bossTable[bossId]
        local targetMapId = mapId or (def and def.mapId)
        local encounter, err, remaining = self.bossSystem:spawnEncounter(bossId, targetMapId)
        if type(encounter) == 'table' then
            if not encounter.position then encounter.position = deepcopy(def and def.position) end
            self.journal:append('boss_spawned', { bossId = bossId, mapId = targetMapId })
            self:_emit('onBossSpawned', encounter)
        end
        return encounter, err, remaining
    end

    function world:_applyBossRewards(player, encounter, rawDrops)
        local bossDef = self.mobs[encounter.bossId] or {}
        self.expSystem:grant(player, bossDef.exp or 0)
        self.economySystem:grantMesos(player, self:_rollMesos(bossDef.mesos_min, bossDef.mesos_max), 'boss_drop')
        local position = self:_bossPosition(encounter)
        local delivered = self:_processDropAcquisition(player, encounter.mapId, position, rawDrops, self.autoPickupDrops == true)
        self.questSystem:onKill(player, encounter.bossId, 1)
        player.killLog[encounter.bossId] = (player.killLog[encounter.bossId] or 0) + 1
        player.dirty = true
        self.journal:append('boss_killed', { playerId = player.id, mapId = encounter.mapId, bossId = encounter.bossId })
        self:_emit('onBossKilled', encounter, player, delivered)
        self:publishPlayerSnapshot(player)
        return delivered
    end

    function world:damageBoss(player, mapId, amount)
        if not player then return false, 'invalid_player' end
        local targetMapId = player.currentMapId or mapId
        local encounter = self.bossSystem:getEncounter(targetMapId)
        if not encounter and mapId and mapId ~= targetMapId and self.bossSystem:getEncounter(mapId) then
            return false, 'wrong_map'
        end
        if not encounter then return false, 'no_active_encounter' end

        local boundaryOk, boundaryErr = self:_requireActionBoundary(player, encounter.mapId, self:_bossPosition(encounter), 'bossAttackRange')
        if not boundaryOk then return false, boundaryErr end
        local actionOk, actionErr = self:_checkAction(player, 'boss_attack', 1)
        if not actionOk then return false, actionErr end
        local damage, damageErr = self:_capDamage(player, 'boss', amount)
        if not damage then return false, damageErr end

        local ok, dropsOrError, resolvedEncounter = self.bossSystem:damage(encounter.mapId, player, damage)
        if not ok then return false, dropsOrError end
        if not dropsOrError then
            self:_emit('onBossDamaged', resolvedEncounter, player, damage)
            self:saveWorldState('boss_damage')
            return true, nil
        end

        return true, self:_applyBossRewards(player, resolvedEncounter, dropsOrError)
    end

    function world:tickBosses()
        if next(self.players) == nil then return 0 end
        local before = {}
        for mapId, encounter in pairs(self.bossSystem.encounters) do
            before[mapId] = encounter
        end
        local spawned = self.bossSystem:tick(self)
        if spawned > 0 then
            for mapId, encounter in pairs(self.bossSystem.encounters) do
                if before[mapId] ~= encounter and encounter and encounter.alive then
                    self.journal:append('boss_spawned', { bossId = encounter.bossId, mapId = mapId, automated = true })
                    self:_emit('onBossSpawned', encounter)
                end
            end
        end
        if self.metrics then self.metrics:gauge('boss.auto_spawned', spawned) end
        return spawned
    end

    function world:expireDrops()
        local expired = self.dropSystem:expireDrops(self:_now())
        for _, record in ipairs(expired) do self:_emit('onDropExpired', record) end
        if #expired > 0 then self:saveWorldState('drop_expire') end
        return #expired
    end

    function world:grantItem(player, itemId, quantity, metadata, reason)
        local ok, err = self.itemSystem:addItem(player, itemId, quantity, metadata)
        if not ok then return false, err end
        self.questSystem:onItemAcquired(player, itemId, quantity)
        self.journal:append('item_granted', { playerId = player.id, itemId = itemId, quantity = quantity, reason = reason })
        self:publishPlayerSnapshot(player)
        return true
    end

    function world:buyFromNpc(player, itemId, quantity)
        if not player then return false, 'invalid_player' end
        local actionOk, actionErr = self:_checkAction(player, 'shop', 1)
        if not actionOk then return false, actionErr end
        local ok, err = self.economySystem:buyFromNpc(player, itemId, quantity)
        if not ok then return false, err end
        self.questSystem:onItemAcquired(player, itemId, quantity)
        self.journal:append('npc_buy', { playerId = player.id, itemId = itemId, quantity = quantity })
        self:publishPlayerSnapshot(player)
        return true
    end

    function world:sellToNpc(player, itemId, quantity)
        if not player then return false, 'invalid_player' end
        local actionOk, actionErr = self:_checkAction(player, 'shop', 1)
        if not actionOk then return false, actionErr end
        local ok, err = self.economySystem:sellToNpc(player, itemId, quantity)
        if not ok then return false, err end
        self.questSystem:onItemRemoved(player, itemId, quantity)
        self.journal:append('npc_sell', { playerId = player.id, itemId = itemId, quantity = quantity })
        self:publishPlayerSnapshot(player)
        return true
    end

    function world:equipItem(player, itemId, instanceId)
        if not player then return false, 'invalid_player' end
        local actionOk, actionErr = self:_checkAction(player, 'equip', 1)
        if not actionOk then return false, actionErr end
        local ok, err = self.itemSystem:equip(player, itemId, instanceId)
        if not ok then return false, err end
        self.journal:append('item_equipped', { playerId = player.id, itemId = itemId })
        self:publishPlayerSnapshot(player)
        return true
    end

    function world:unequipItem(player, slot)
        if not player then return false, 'invalid_player' end
        local actionOk, actionErr = self:_checkAction(player, 'equip', 1)
        if not actionOk then return false, actionErr end
        local ok, err = self.itemSystem:unequip(player, slot)
        if not ok then return false, err end
        self.journal:append('item_unequipped', { playerId = player.id, slot = slot })
        self:publishPlayerSnapshot(player)
        return true
    end

    function world:changeMap(player, mapId)
        if not player then return false, 'invalid_player' end
        local actionOk, actionErr = self:_checkAction(player, 'map_change', 1)
        if not actionOk then return false, actionErr end
        local ok, err = self:setPlayerMap(player, mapId)
        if not ok then return false, err end
        self.journal:append('player_map_changed_manual', { playerId = player.id, mapId = mapId })
        self:publishPlayerSnapshot(player)
        return true
    end

    function world:acceptQuest(player, questId)
        if not player then return false, 'invalid_player' end
        local quest = self.questSystem.quests[questId]
        if not quest then return false, 'unknown_quest' end
        local binding = self:_questBinding(quest, 'accept')
        local boundaryOk, boundaryErr = self:_requireActionBoundary(player, binding.mapId, binding.position, 'questNpcRange')
        if not boundaryOk then return false, boundaryErr end
        local actionOk, actionErr = self:_checkAction(player, 'quest', 1)
        if not actionOk then return false, actionErr end
        local ok, err = self.questSystem:accept(player, questId)
        if not ok then return false, err end
        self.journal:append('quest_accepted', { playerId = player.id, questId = questId, npc = binding.npc, mapId = binding.mapId })
        self:publishPlayerSnapshot(player)
        return true
    end

    function world:turnInQuest(player, questId)
        if not player then return false, 'invalid_player' end
        local quest = self.questSystem.quests[questId]
        if not quest then return false, 'unknown_quest' end
        local binding = self:_questBinding(quest, 'turn_in')
        local boundaryOk, boundaryErr = self:_requireActionBoundary(player, binding.mapId, binding.position, 'questNpcRange')
        if not boundaryOk then return false, boundaryErr end
        local actionOk, actionErr = self:_checkAction(player, 'quest', 1)
        if not actionOk then return false, actionErr end
        local ok, err = self.questSystem:turnIn(player, questId)
        if not ok then return false, err end
        self.journal:append('quest_completed', { playerId = player.id, questId = questId, npc = binding.npc, mapId = binding.mapId })
        self:publishPlayerSnapshot(player)
        return true
    end

    for mapId, mapConfig in pairs(worldConfig.maps or {}) do
        spawnSystem:registerMap(mapId, mapConfig.spawnGroups or {})
    end

    world:restoreWorldState()

    local runtimeCfg = worldConfig.runtime or {}
    scheduler:every('spawn_tick', tonumber(runtimeCfg.spawnTickSec) or 5, function() spawnSystem:tick() end)
    scheduler:every('boss_tick', tonumber(runtimeCfg.bossTickSec) or 15, function() world:tickBosses() end)
    scheduler:every('autosave_tick', tonumber(runtimeCfg.autosaveTickSec) or 30, function() world:flushDirtyPlayers() end)
    scheduler:every('world_state_autosave_tick', tonumber(runtimeCfg.worldStateAutosaveTickSec) or 15, function() world:saveWorldState('periodic') end)
    scheduler:every('health_tick', tonumber(runtimeCfg.healthTickSec) or 30, function() healthcheck:run() end)
    scheduler:every('drop_expire_tick', tonumber(runtimeCfg.dropExpireTickSec) or 5, function() world:expireDrops() end)

    return world
end

return ServerBootstrap
