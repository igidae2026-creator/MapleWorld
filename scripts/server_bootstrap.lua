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
local RuntimePolicyBundle = require('ops.runtime_policy_bundle')

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
            persistedDropsPerMap = 120,
            persistedJournalEntries = 2000,
            journalMaxEntries = 5000,
            journalMaxPayloadBytes = 2048,
            ledgerMaxEntries = 20000,
            worldStateSaveDebounceSec = 5,
            worldStateMaxPendingReasons = 200,
            worldRevisionRetention = 32,
            worldCommitRetention = 64,
            playerRevisionRetention = 16,
            worldWriterLeaseSec = 30,
            worldWriterOwnerId = 'default',
            worldWriterEpoch = 0,
            coordinatorEpoch = 0,
            worldId = 'world-1',
            channelId = 'channel-1',
            runtimeInstanceId = 'runtime-main',
            policyBundleId = 'genesis.default',
            policyBundleVersion = '1.0.0',
            pressureDensityThreshold = 0.85,
            pressureSaveBacklogThreshold = 50,
            pressureRewardInflationThreshold = 12,
            pressureReplayThreshold = 1,
            pressureInstabilityThreshold = 3,
            pressureLowDiversityThreshold = 4,
            safeModeSeverityThreshold = 3,
            rewardQuarantineSeverityThreshold = 2,
            migrationBlockSeverityThreshold = 2,
            replayOnlySeverityThreshold = 4,
            autoPickupDrops = true,
        },
        combat = {
            minimumDamage = 1,
            mobDamageCapFactor = 6.0,
            bossDamageCapFactor = 4.0,
            bossDamageMaxHpFactor = 0.1,
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

local function tailEntries(entries, maxEntries)
    if type(entries) ~= 'table' then return {} end
    local cap = math.floor(tonumber(maxEntries) or 0)
    if cap <= 0 or #entries <= cap then return deepcopy(entries) end
    local out = {}
    local start = math.max(1, (#entries - cap) + 1)
    for i = start, #entries do out[#out + 1] = deepcopy(entries[i]) end
    return out
end

local function limitDropSnapshot(snapshot, maxPerMap)
    if type(snapshot) ~= 'table' then return { nextDropId = 1, drops = {}, dropsByMap = {} } end
    local cap = math.floor(tonumber(maxPerMap) or 0)
    local combined = {}

    local function appendRecord(record, inferredMapId)
        if type(record) ~= 'table' then return end
        local copy = deepcopy(record)
        copy.mapId = copy.mapId or inferredMapId
        if not copy.mapId then return end
        combined[#combined + 1] = copy
    end

    for _, record in ipairs(snapshot.drops or {}) do
        appendRecord(record, nil)
    end
    if type(snapshot.dropsByMap) == 'table' then
        for mapId, records in pairs(snapshot.dropsByMap) do
            if type(records) == 'table' then
                for _, record in ipairs(records) do
                    appendRecord(record, mapId)
                end
            end
        end
    end

    table.sort(combined, function(a, b)
        local aId = tonumber(a.dropId) or 0
        local bId = tonumber(b.dropId) or 0
        if aId == bId then
            return tostring(a.mapId or '') < tostring(b.mapId or '')
        end
        return aId < bId
    end)

    local deduped = {}
    local seenDropIds = {}
    for _, record in ipairs(combined) do
        local dropId = tonumber(record.dropId)
        if dropId == nil or not seenDropIds[dropId] then
            if dropId ~= nil then seenDropIds[dropId] = true end
            deduped[#deduped + 1] = record
        end
    end

    if cap <= 0 then
        local byMap = {}
        for _, record in ipairs(deduped) do
            byMap[record.mapId] = byMap[record.mapId] or {}
            byMap[record.mapId][#byMap[record.mapId] + 1] = deepcopy(record)
        end
        return {
            nextDropId = tonumber(snapshot.nextDropId) or 1,
            drops = deepcopy(deduped),
            dropsByMap = byMap,
        }
    end

    local byMap = {}
    for _, record in ipairs(deduped) do
        local mapId = record.mapId
        byMap[mapId] = byMap[mapId] or {}
        byMap[mapId][#byMap[mapId] + 1] = record
    end

    local trimmedDrops = {}
    local trimmedByMap = {}
    for mapId, records in pairs(byMap) do
        local entries = tailEntries(records, cap)
        trimmedByMap[mapId] = deepcopy(entries)
        for _, entry in ipairs(entries) do
            trimmedDrops[#trimmedDrops + 1] = entry
        end
    end

    table.sort(trimmedDrops, function(a, b)
        return (tonumber(a.dropId) or 0) < (tonumber(b.dropId) or 0)
    end)

    return {
        nextDropId = tonumber(snapshot.nextDropId) or 1,
        drops = deepcopy(trimmedDrops),
        dropsByMap = trimmedByMap,
    }
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
                maxRevisions = worldConfig.runtime and worldConfig.runtime.playerRevisionRetention,
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
                maxRevisions = worldConfig.runtime and worldConfig.runtime.worldRevisionRetention,
                writerOwnerId = worldConfig.runtime and worldConfig.runtime.worldWriterOwnerId,
                writerEpoch = worldConfig.runtime and worldConfig.runtime.worldWriterEpoch,
                writerLeaseSec = worldConfig.runtime and worldConfig.runtime.worldWriterLeaseSec,
                maxCommits = worldConfig.runtime and worldConfig.runtime.worldCommitRetention,
            })
        else
            worldRepository = WorldRepository.newMemory({ metrics = metrics, logger = logger })
        end
    end

    local rng = config.rng or math.random
    local journal = config.eventJournal or EventJournal.new({ metrics = metrics, logger = logger, time = runtimeClock, maxEntries = worldConfig.runtime and worldConfig.runtime.journalMaxEntries, maxPayloadBytes = worldConfig.runtime and worldConfig.runtime.journalMaxPayloadBytes, maxLedgerEntries = worldConfig.runtime and worldConfig.runtime.ledgerMaxEntries })
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
    local economySystem = EconomySystem.new({
        itemSystem = itemSystem,
        metrics = metrics,
        logger = logger,
        npcSellRate = config.npcSellRate,
        maxMesos = config.maxMesos,
        suspiciousTransactionMesos = worldConfig.runtime and worldConfig.runtime.suspiciousTransactionMesos,
        maxPlayerLedgerEntries = worldConfig.runtime and worldConfig.runtime.maxPlayerEconomyLedgerEntries,
    })
    local bossSystem = BossSystem.new({ bossTable = buildBoss(bossRaw, worldConfig), dropSystem = dropSystem, metrics = metrics, logger = logger, time = runtimeClock })
    local questSystem = QuestSystem.new({ quests = buildQuests(questRaw), itemSystem = itemSystem, economySystem = economySystem, expSystem = expSystem, metrics = metrics, logger = logger })
    local spawnSystem = SpawnSystem.new({ mobs = mobs, scheduler = scheduler, metrics = metrics, logger = logger, rng = rng, maxSpawnPerTick = config.maxSpawnPerTick })
    local healthcheck = Healthcheck.new({ metrics = metrics, scheduler = scheduler })
    local adminTools = AdminTools.new({ metrics = metrics, scheduler = scheduler })

    local policyBundle = RuntimePolicyBundle.new(worldConfig, config.policyBundle)
    local runtimeIdentity = {
        worldId = tostring((worldConfig.runtime and worldConfig.runtime.worldId) or 'world-1'),
        channelId = tostring((worldConfig.runtime and worldConfig.runtime.channelId) or 'channel-1'),
        runtimeInstanceId = tostring((worldConfig.runtime and worldConfig.runtime.runtimeInstanceId) or 'runtime-main'),
        ownerId = tostring((worldConfig.runtime and worldConfig.runtime.worldWriterOwnerId) or 'default'),
        ownerEpoch = math.max(0, math.floor(tonumber(worldConfig.runtime and worldConfig.runtime.worldWriterEpoch) or 0)),
        coordinatorEpoch = math.max(0, math.floor(tonumber(worldConfig.runtime and worldConfig.runtime.coordinatorEpoch) or 0)),
        schemaVersion = 2,
    }

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
        runtimeIdentity = runtimeIdentity,
        policyBundle = policyBundle,
        pressure = {
            density = 0,
            backlog = 0,
            rewardInflation = 0,
            replay = 0,
            instability = 0,
            lowDiversity = 0,
            duplicateRisk = 0,
            savePressure = 0,
        },
        containment = {
            safeMode = false,
            rewardQuarantine = false,
            saveQuarantine = false,
            migrationBlocked = false,
            replayOnly = false,
            ownershipReject = false,
        },
        escalation = {
            level = 0,
            reason = 'none',
            at = 0,
            history = {},
        },
        recovery = {
            mode = 'cold_start',
            checkpointId = nil,
            checkpointRevision = 0,
            replayBaseRevision = 0,
            replayedEntries = 0,
            divergence = false,
            valid = true,
        },
        recoveryInvariants = {
            claimedDrops = {},
            bossRewardClaims = {},
            itemInstanceIds = {},
        },
        _pendingWorldSaveReason = nil,
        _pendingWorldSaveReasons = {},
        _pendingWorldSaveCount = 0,
        _worldStateDirty = false,
        _lastWorldSaveAt = nil,
        _savingFailures = 0,
        _rewardMutationCountWindow = {},
        _lastPolicyId = nil,
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
    itemSystem.ledgerSink = function(event) return world:appendLedgerEvent(event) end
    economySystem.ledgerSink = function(event) return world:appendLedgerEvent(event) end

    if world.autoPickupDrops == nil then
        world.autoPickupDrops = worldConfig.runtime and worldConfig.runtime.autoPickupDrops ~= false
    end
    healthcheck.world = world

    economySystem.auditSink = function(entry)
        if not world or not world.journal then return end
        world.journal:append('economy_mutation', entry)
    end

    function world:_now()
        return math.floor(tonumber(self.clock()) or os.time())
    end

    function world:appendLedgerEvent(event)
        if not self.journal or type(self.journal.appendLedgerEvent) ~= 'function' then return nil end
        local appended, duplicate = self.journal:appendLedgerEvent(event)
        if duplicate then
            self.pressure.duplicateRisk = math.max(0, (self.pressure.duplicateRisk or 0) + 1)
        else
            self.pressure.rewardInflation = math.max(0, (self.pressure.rewardInflation or 0) + 1)
        end
        self:_recomputePressure()
        return appended, duplicate
    end

    function world:_eventType(name)
        return tostring(name or 'unknown')
    end

    function world:_recordRuntimeEvent(eventType, payload)
        local eventName = self:_eventType(eventType)
        local eventPayload = payload or {}
        eventPayload.runtime = {
            worldId = self.runtimeIdentity.worldId,
            channelId = self.runtimeIdentity.channelId,
            runtimeInstanceId = self.runtimeIdentity.runtimeInstanceId,
            ownerId = self.runtimeIdentity.ownerId,
            ownerEpoch = self.runtimeIdentity.ownerEpoch,
            coordinatorEpoch = self.runtimeIdentity.coordinatorEpoch,
            policyId = (self.policyBundle:snapshot() or {}).policyId,
            policyVersion = (self.policyBundle:snapshot() or {}).policyVersion,
        }
        self.journal:append(eventName, eventPayload)
    end

    function world:replacePolicyBundle(nextPolicy)
        local ok, err = self.policyBundle:replace(nextPolicy)
        if not ok then return false, err end
        local snapshot = self.policyBundle:snapshot()
        self._lastPolicyId = tostring(snapshot.policyId) .. '@' .. tostring(snapshot.policyVersion)
        self:_recordRuntimeEvent('policy_bundle_replaced', { policy = snapshot })
        self:_recomputePressure()
        return true
    end

    function world:_pressureThreshold(name)
        local policy = self.policyBundle:snapshot()
        local thresholds = policy and policy.pressureThresholds or {}
        return tonumber(thresholds[name]) or 0
    end

    function world:_applyContainmentFromEscalation(level, reason)
        local policy = self.policyBundle:snapshot()
        local containment = policy and policy.containment or {}
        if level >= (tonumber(containment.rewardQuarantineOnEscalation) or 99) then
            self.containment.rewardQuarantine = true
        end
        if level >= (tonumber(containment.migrationBlockOnEscalation) or 99) then
            self.containment.migrationBlocked = true
        end
        if level >= (tonumber(containment.safeModeOnEscalation) or 99) then
            self.containment.safeMode = true
        end
        if level >= (tonumber(containment.replayOnlyOnEscalation) or 99) then
            self.containment.replayOnly = true
            self.containment.ownershipReject = true
        end
        self:_recordRuntimeEvent('failure_containment_applied', {
            level = level,
            reason = reason,
            containment = deepcopy(self.containment),
        })
    end

    function world:_escalate(reason, detail)
        local nextLevel = math.min(5, (self.escalation.level or 0) + 1)
        self.escalation.level = nextLevel
        self.escalation.reason = tostring(reason or 'unspecified')
        self.escalation.at = self:_now()
        local history = self.escalation.history or {}
        history[#history + 1] = {
            at = self.escalation.at,
            level = nextLevel,
            reason = self.escalation.reason,
            detail = detail,
        }
        while #history > 32 do table.remove(history, 1) end
        self.escalation.history = history
        if self.metrics then
            self.metrics:gauge('world.escalation.level', nextLevel)
            self.metrics:increment('world.escalation.triggered', 1, { reason = tostring(reason) })
        end
        self:_recordRuntimeEvent('failure_escalated', {
            level = nextLevel,
            reason = reason,
            detail = detail,
        })
        self:_applyContainmentFromEscalation(nextLevel, reason)
    end

    function world:_recomputePressure()
        local runtimeCfg = self.worldConfig.runtime or {}
        local activePlayers = self:getActivePlayerCount()
        local mapCount = math.max(1, countTableKeys(self.worldConfig.maps or {}))
        local density = activePlayers / mapCount
        local backlog = tonumber(self._pendingWorldSaveCount) or 0
        local instability = tonumber(self._savingFailures or 0)

        self.pressure.density = density
        self.pressure.backlog = backlog
        self.pressure.savePressure = backlog
        self.pressure.instability = instability

        local now = self:_now()
        local window = self._rewardMutationCountWindow or {}
        window[#window + 1] = now
        while #window > 0 and (now - window[1]) > 60 do table.remove(window, 1) end
        self._rewardMutationCountWindow = window
        self.pressure.rewardInflation = #window

        local recent = self.journal:snapshot(math.max(0, self.journal.nextSeq - 25))
        local diversity = {}
        for _, entry in ipairs(recent) do diversity[tostring(entry.event)] = true end
        local kinds = countTableKeys(diversity)
        self.pressure.lowDiversity = kinds <= 2 and (3 - kinds) or 0

        local replayPressure = self.recovery and self.recovery.divergence and 2 or 0
        self.pressure.replay = replayPressure

        if self.metrics then
            self.metrics:gauge('pressure.density', density)
            self.metrics:gauge('pressure.backlog', backlog)
            self.metrics:gauge('pressure.reward_inflation', self.pressure.rewardInflation)
            self.metrics:gauge('pressure.replay', self.pressure.replay)
            self.metrics:gauge('pressure.low_diversity', self.pressure.lowDiversity)
            self.metrics:gauge('pressure.instability', instability)
            self.metrics:gauge('pressure.duplicate_risk', self.pressure.duplicateRisk or 0)
        end

        if backlog >= self:_pressureThreshold('saveBacklog') then
            self:_escalate('save_backlog_pressure', { backlog = backlog })
        end
        if self.pressure.lowDiversity >= self:_pressureThreshold('lowDiversity') then
            self:_recordRuntimeEvent('failure_plateau_exploration', { lowDiversity = self.pressure.lowDiversity })
        end
        if instability >= self:_pressureThreshold('instability') then
            self:_recordRuntimeEvent('failure_collapse_diversity_repair', { instability = instability })
            self:_escalate('world_instability_pressure', { instability = instability })
        end
    end

    function world:getRuntimeStatus()
        return {
            runtimeIdentity = deepcopy(self.runtimeIdentity),
            policy = self.policyBundle:snapshot(),
            pressure = deepcopy(self.pressure),
            containment = deepcopy(self.containment),
            escalation = deepcopy(self.escalation),
            recovery = deepcopy(self.recovery),
            pendingSave = {
                count = self._pendingWorldSaveCount,
                reason = self._pendingWorldSaveReason,
            },
            watermark = {
                journalSeq = self.journal.nextSeq - 1,
                ledgerEventId = self.journal.nextLedgerEventId - 1,
            },
        }
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
        player.runtimeScope = player.runtimeScope or {}
        player.runtimeScope.worldId = self.runtimeIdentity.worldId
        player.runtimeScope.channelId = self.runtimeIdentity.channelId
        player.runtimeScope.runtimeInstanceId = self.runtimeIdentity.runtimeInstanceId
        player.runtimeScope.ownerEpoch = self.runtimeIdentity.ownerEpoch
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

    function world:_resolveNpcBinding(npcId)
        if npcId == nil or npcId == '' then return nil, 'invalid_npc' end
        local bindings = self.worldConfig.quests and self.worldConfig.quests.npcBindings or {}
        local binding = bindings[npcId]
        if type(binding) ~= 'table' then return nil, 'npc_not_found' end
        local mapId = binding.mapId
        if not mapId or not self.worldConfig.maps or not self.worldConfig.maps[mapId] then return nil, 'invalid_map' end
        local position = self:_normalizePosition(binding) or self:_defaultMapPosition(mapId)
        return {
            npcId = npcId,
            mapId = mapId,
            position = position,
            shopId = binding.shopId,
            catalog = binding.catalog,
            items = binding.items,
        }
    end

    function world:_validateNpcShop(npc)
        if not npc then return false, 'invalid_npc' end
        if npc.shopId ~= nil and npc.shopId == '' then return false, 'invalid_npc_shop' end
        local catalog = npc.catalog or npc.items
        if type(catalog) ~= 'table' then return false, 'invalid_npc_shop' end
        return true
    end

    function world:_isNpcItemAllowed(npc, itemId)
        local catalog = npc and (npc.catalog or npc.items) or nil
        return type(catalog) == 'table' and catalog[itemId] == true
    end

    function world:_resolveValidatedNpc(npcId, validatedNpc)
        if validatedNpc ~= nil then
            if type(validatedNpc) ~= 'table' then return nil, 'invalid_npc' end
            if validatedNpc.npcId ~= npcId then return nil, 'npc_context_mismatch' end
            local mapId = validatedNpc.mapId
            if not mapId or not self.worldConfig.maps or not self.worldConfig.maps[mapId] then return nil, 'invalid_map' end
            return validatedNpc
        end
        return self:_resolveNpcBinding(npcId)
    end

    function world:_isAllowedMapTransition(sourceMapId, destinationMapId)
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

    function world:snapshotWorldState()
        local runtimeCfg = self.worldConfig.runtime or {}
        local persistedDropsPerMap = tonumber(runtimeCfg.persistedDropsPerMap) or 0
        local journalSnapshot = self.journal:serialize()
        journalSnapshot.entries = tailEntries(journalSnapshot.entries, runtimeCfg.persistedJournalEntries)
        local checkpointId = string.format('%s:%s:%s:%s', tostring(self.runtimeIdentity.worldId), tostring(self.runtimeIdentity.channelId), tostring(self.runtimeIdentity.runtimeInstanceId), tostring(self:_now()))
        return {
            version = 2,
            savedAt = self:_now(),
            checkpoint = {
                checkpoint_id = checkpointId,
                schema_version = 2,
                journal_watermark = self.journal.nextSeq - 1,
                ledger_watermark = self.journal.nextLedgerEventId - 1,
                world_owner_epoch = self.runtimeIdentity.ownerEpoch,
                coordinator_epoch = self.runtimeIdentity.coordinatorEpoch,
                created_at = self:_now(),
                replay_base_revision = self.worldRepository and self.worldRepository:lastLoadedRevision() or 0,
                runtime_scope = {
                    world_id = self.runtimeIdentity.worldId,
                    channel_id = self.runtimeIdentity.channelId,
                    runtime_instance_id = self.runtimeIdentity.runtimeInstanceId,
                    owner_id = self.runtimeIdentity.ownerId,
                },
                policy = self.policyBundle:snapshot(),
            },
            boss = self.bossSystem:snapshot(),
            drops = limitDropSnapshot(self.dropSystem:snapshot(), persistedDropsPerMap),
            journal = journalSnapshot,
            recovery = deepcopy(self.recovery),
            pressure = deepcopy(self.pressure),
            escalation = deepcopy(self.escalation),
        }
    end

    function world:saveWorldState(reason)
        if not self.worldRepository or self._restoringWorldState or self._savingWorldState then return true end
        if self.containment.saveQuarantine then return false, 'save_quarantined' end
        self._savingWorldState = true
        local now = self:_now()
        local startedAt = os.clock()
        local snapshot = self:snapshotWorldState()
        local ok, err = self.worldRepository:save(snapshot)
        self._savingWorldState = false
        local elapsedMs = math.floor((os.clock() - startedAt) * 1000)
        if ok then
            self._lastWorldSaveAt = now
            self._pendingWorldSaveReason = nil
            self._pendingWorldSaveReasons = {}
            self._pendingWorldSaveCount = 0
            self._worldStateDirty = false
            self._savingFailures = 0
            self.recovery.checkpointId = snapshot.checkpoint and snapshot.checkpoint.checkpoint_id or nil
            self.recovery.checkpointRevision = self.worldRepository:lastSavedRevision() or self.recovery.checkpointRevision
            if self.metrics then
                self.metrics:gauge('world_state.pending_events', 0)
                self.metrics:time('world_state.save.duration_ms', elapsedMs)
                self.metrics:gauge('world_state.checkpoint_revision', self.recovery.checkpointRevision or 0)
            end
            self:_recordRuntimeEvent('world_checkpoint_saved', {
                reason = reason,
                checkpoint = snapshot.checkpoint,
                duration_ms = elapsedMs,
            })
        else
            self._savingFailures = (self._savingFailures or 0) + 1
            if self.metrics then
                self.metrics:increment('world_state.save_error', 1, { reason = tostring(reason) })
                self.metrics:error('world_state_save_failed', { reason = tostring(reason), error = tostring(err) })
            end
            self:_recordRuntimeEvent('world_checkpoint_save_failed', { reason = reason, error = tostring(err) })
            self:_escalate('world_save_failed', { reason = reason, error = tostring(err), failures = self._savingFailures })
        end
        self:_recomputePressure()
        return ok, err
    end

    function world:markWorldStateDirty(reason)
        local runtimeCfg = self.worldConfig.runtime or {}
        local maxReasons = math.max(1, math.floor(tonumber(runtimeCfg.worldStateMaxPendingReasons) or 200))
        self._worldStateDirty = true
        self._pendingWorldSaveReason = reason or self._pendingWorldSaveReason or 'unspecified'
        self._pendingWorldSaveCount = (self._pendingWorldSaveCount or 0) + 1
        local reasons = self._pendingWorldSaveReasons or {}
        reasons[#reasons + 1] = tostring(reason or 'unspecified')
        while #reasons > maxReasons do table.remove(reasons, 1) end
        self._pendingWorldSaveReasons = reasons
        if self.metrics then
            self.metrics:increment('world_state.marked_dirty', 1, { reason = tostring(reason or 'unspecified') })
            self.metrics:gauge('world_state.pending_reasons', #reasons)
            self.metrics:gauge('world_state.pending_events', self._pendingWorldSaveCount)
        end
        self:_recomputePressure()
    end

    function world:requestWorldSave(reason, options)
        local opts = options or {}
        self:markWorldStateDirty(reason)
        if opts.immediate == true then
            return self:saveWorldState(reason)
        end
        if self.metrics then self.metrics:increment('world_state.save_deferred', 1, { reason = tostring(reason) }) end
        return true, 'deferred'
    end

    function world:flushPendingWorldSave(reason)
        if not self._worldStateDirty then return true, 'clean' end
        local runtimeCfg = self.worldConfig.runtime or {}
        local debounceSec = math.max(0, tonumber(runtimeCfg.worldStateSaveDebounceSec) or 0)
        local now = self:_now()
        if debounceSec > 0 and self._lastWorldSaveAt and (now - self._lastWorldSaveAt) < debounceSec then
            if self.metrics then self.metrics:increment('world_state.save_debounced', 1, { reason = tostring(reason or self._pendingWorldSaveReason) }) end
            return true, 'debounced'
        end
        return self:saveWorldState(reason or self._pendingWorldSaveReason)
    end

    function world:_rebuildRecoveryInvariants()
        self.recoveryInvariants = { claimedDrops = {}, bossRewardClaims = {}, itemInstanceIds = {} }
        local ledger = self.journal:ledgerSnapshot()
        for _, entry in ipairs(ledger) do
            if entry.event_type == 'reward_claim' and entry.idempotency_key then
                if self.recoveryInvariants.bossRewardClaims[entry.idempotency_key] then
                    return false, 'duplicate_boss_reward_claim'
                end
                self.recoveryInvariants.bossRewardClaims[entry.idempotency_key] = true
            end
            if entry.event_type == 'inventory_add' then
                local iid = entry.item_instance_id
                if iid and self.recoveryInvariants.itemInstanceIds[iid] then
                    return false, 'duplicate_item_instance'
                end
                if iid then self.recoveryInvariants.itemInstanceIds[iid] = true end
            end
            if entry.event_type == 'drop_claim' and entry.source_event_id then
                local dk = tostring(entry.source_event_id)
                if self.recoveryInvariants.claimedDrops[dk] then
                    return false, 'duplicate_drop_claim'
                end
                self.recoveryInvariants.claimedDrops[dk] = true
            end
        end
        return true
    end

    function world:restoreWorldState()
        if not self.worldRepository then return false end
        self.recovery.mode = 'loading_checkpoint'
        local startedAt = os.clock()
        local snapshot, err = self.worldRepository:load()
        if err then
            if self.metrics then
                self.metrics:increment('world_state.load_error', 1)
                self.metrics:error('world_state_load_failed', { error = tostring(err) })
            end
            self.recovery.mode = 'checkpoint_invalid'
            self.recovery.valid = false
            return false, err
        end
        if not snapshot then
            self.recovery.mode = 'cold_start'
            self.recovery.valid = true
            return false
        end
        if type(snapshot) ~= 'table' then return false, 'invalid_world_snapshot' end

        local previousJournal = self.journal:serialize()
        local previousDrops = self.dropSystem:snapshot()
        local previousBoss = self.bossSystem:snapshot()

        self._restoringWorldState = true
        local ok, restoreErr = pcall(function()
            self.journal:restore(snapshot.journal)
            self.dropSystem:restore(snapshot.drops)
            self.bossSystem:restore(snapshot.boss)
        end)
        self._restoringWorldState = false

        if not ok then
            self._restoringWorldState = true
            pcall(function()
                self.journal:restore(previousJournal)
                self.dropSystem:restore(previousDrops)
                self.bossSystem:restore(previousBoss)
            end)
            self._restoringWorldState = false
            if self.metrics then
                self.metrics:increment('world_state.restore_error', 1)
                self.metrics:error('world_state_restore_failed', { error = tostring(restoreErr) })
            end
            self.recovery.mode = 'checkpoint_restore_failed'
            self.recovery.valid = false
            self:_escalate('checkpoint_restore_failed', { error = tostring(restoreErr) })
            return false, 'restore_failed:' .. tostring(restoreErr)
        end

        local invOk, invErr = self:_rebuildRecoveryInvariants()
        if not invOk then
            self.recovery.mode = 'replay_restore_required'
            self.recovery.valid = false
            self:_escalate('replay_invariant_violation', { invariant = invErr })
            return false, invErr
        end

        local checkpoint = snapshot.checkpoint or {}
        self.recovery.mode = 'open_runtime'
        self.recovery.valid = true
        self.recovery.checkpointId = checkpoint.checkpoint_id
        self.recovery.replayBaseRevision = tonumber(checkpoint.replay_base_revision) or 0
        self.recovery.replayedEntries = #self.journal:snapshot((tonumber(checkpoint.journal_watermark) or 0) - 1)
        self.recovery.divergence = false
        self.recovery.checkpointRevision = self.worldRepository:lastLoadedRevision() or 0

        for _, drop in ipairs(self.dropSystem:listAllDrops()) do
            self:_emit('onDropSpawned', drop)
        end
        for _, encounter in pairs(self.bossSystem.encounters) do
            if encounter.alive then self:_emit('onBossSpawned', encounter) end
        end

        local elapsedMs = math.floor((os.clock() - startedAt) * 1000)
        if self.metrics then
            self.metrics:time('world_state.restore.duration_ms', elapsedMs)
            self.metrics:gauge('world_state.replay_entries', self.recovery.replayedEntries or 0)
            self.metrics:gauge('world_state.recovery_valid', self.recovery.valid and 1 or 0)
        end
        self:_recordRuntimeEvent('world_recovered', {
            checkpoint_id = self.recovery.checkpointId,
            replayed_entries = self.recovery.replayedEntries,
            duration_ms = elapsedMs,
        })
        self:_recomputePressure()
        return true
    end

    journal.onAppend = function(entry)
        if world._restoringWorldState then return end
        world:markWorldStateDirty('journal:' .. tostring(entry and entry.event))
    end

    journal.onLedgerAppend = function(entry)
        if world._restoringWorldState then return end
        world:markWorldStateDirty('ledger:' .. tostring(entry and entry.event_type))
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
        if not self.worldConfig.maps or not self.worldConfig.maps[mapId] then return false, 'invalid_map' end

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

    function world:savePlayer(player, options)
        if not player or not player.id then return false, 'invalid_player' end
        local cfg = options or {}
        local requireWorldSave = cfg.requireWorldSave == true
        local previousPersisted = nil
        if requireWorldSave and cfg.capturePrevious ~= false and self.playerRepository and self.playerRepository.load then
            local loadedPrevious, previousErr = self.playerRepository:load(player.id)
            if previousErr then
                if self.metrics then
                    self.metrics:increment('player_state.save_error', 1, { reason = 'player_preload_failed' })
                    self.metrics:error('player_state_preload_failed', { playerId = tostring(player.id), error = tostring(previousErr) })
                end
                return false, previousErr
            end
            previousPersisted = loadedPrevious
        end

        local ok, err = self.playerRepository:save(player)
        if not ok then
            if self.metrics then
                self.metrics:increment('player_state.save_error', 1)
                self.metrics:error('player_state_save_failed', { playerId = tostring(player.id), error = tostring(err) })
            end
            return false, err
        end

        if requireWorldSave then
            local worldSaved, worldErr = self:saveWorldState('player_save:' .. tostring(player.id))
            if not worldSaved then
                player.dirty = true
                local rollbackOk = true
                local rollbackErr = nil
                if previousPersisted then
                    rollbackOk, rollbackErr = self.playerRepository:save(previousPersisted)
                end
                if self.metrics then
                    self.metrics:increment('player_state.save_error', 1, { reason = 'world_state_save_failed' })
                    self.metrics:error('player_world_durability_boundary_failed', {
                        playerId = tostring(player.id),
                        worldError = tostring(worldErr),
                        rollbackError = rollbackOk and nil or tostring(rollbackErr),
                    })
                end
                if not rollbackOk then
                    return false, 'world_state_save_failed:' .. tostring(worldErr) .. ';rollback_failed:' .. tostring(rollbackErr)
                end
                return false, worldErr or 'world_state_save_failed'
            end
        end

        player.dirty = false
        player.lastSavedAt = self:_now()
        self.journal:append('player_saved', { playerId = player.id, version = player.version, at = player.lastSavedAt })
        return true
    end

    function world:flushDirtyPlayers(options)
        local cfg = options or {}
        local saved = 0
        local failed = 0
        for _, player in pairs(self.players) do
            if player.dirty then
                local ok, err = self:savePlayer(player, cfg)
                if ok then
                    saved = saved + 1
                else
                    failed = failed + 1
                    if self.metrics then
                        self.metrics:error('player_flush_save_failed', { playerId = tostring(player.id), error = tostring(err) })
                    end
                end
            end
        end
        if self.metrics then
            self.metrics:gauge('world.dirty_players_saved', saved)
            self.metrics:gauge('world.dirty_players_failed', failed)
        end
        return saved, failed
    end

    function world:createPlayer(playerId)
        if self.players[playerId] then return self.players[playerId] end
        local loaded, loadErr = self.playerRepository:load(playerId)
        if loadErr then
            if self.metrics then
                self.metrics:increment('player_state.load_error', 1)
                self.metrics:error('player_state_load_failed', { playerId = tostring(playerId), error = tostring(loadErr) })
            end
            return nil, loadErr
        end
        local player = self.itemSystem:sanitizePlayerProfile(loaded, playerId)
        player.runtimeScope = player.runtimeScope or {}
        player.currentMapId = player.currentMapId or (self.worldConfig.runtime and self.worldConfig.runtime.defaultMapId) or 'henesys_hunting_ground'
        if loaded then player.dirty = false else player.dirty = true end
        if not player.position then self:_setPlayerPosition(player, self:_defaultMapPosition(player.currentMapId), not self.strictRuntimeBoundary) end
        self.players[playerId] = player
        self.mapPlayers[player.currentMapId] = self.mapPlayers[player.currentMapId] or {}
        self.mapPlayers[player.currentMapId][playerId] = true
        self:_recordRuntimeEvent('player_loaded', { playerId = playerId, loaded = loaded ~= nil, scope = deepcopy(player.runtimeScope) })
        return player
    end

    function world:onPlayerEnter(playerId, mapId, position)
        local player, loadErr = self:createPlayer(playerId)
        if not player then return nil, loadErr or 'player_load_failed' end
        if mapId then
            local mapOk, mapErr = self:setPlayerMap(player, mapId)
            if not mapOk then return nil, mapErr end
        end
        self:updatePlayerRuntimeState(player, mapId, position, self.strictRuntimeBoundary)
        self:_emit('onPlayerEnter', player)
        self:publishPlayerSnapshot(player)
        return player
    end

    function world:onPlayerLeave(playerId)
        local player = self.players[playerId]
        if not player then return false, 'player_not_found' end
        if player.dirty then
            local saved, saveErr = self:savePlayer(player, { requireWorldSave = self.strictRuntimeBoundary })
            if not saved then return false, saveErr or 'player_save_failed' end
        end
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

    function world:_emitRewardLedger(player, eventType, payload)
        local base = payload or {}
        return self:appendLedgerEvent({
            event_type = eventType,
            actor_id = player and player.id or nil,
            player_id = player and player.id or nil,
            source_system = base.source_system or 'world_runtime',
            source_event_id = base.source_event_id,
            correlation_id = base.correlation_id,
            map_id = base.map_id,
            boss_id = base.boss_id,
            quest_id = base.quest_id,
            npc_id = base.npc_id,
            item_id = base.item_id,
            item_instance_id = base.item_instance_id,
            quantity = base.quantity,
            mesos_delta = base.mesos_delta,
            pre_state = base.pre_state,
            post_state = base.post_state,
            idempotency_key = base.idempotency_key,
            compensation_of = base.compensation_of,
            rollback_of = base.rollback_of,
            metadata = base.metadata,
        })
    end

    function world:_processDropAcquisition(player, mapId, source, rawDrops, forceAutoPickup, context)
        local autoPickup = forceAutoPickup == true or self.autoPickupDrops == true
        local ctx = context or {}
        if autoPickup then
            for _, drop in ipairs(rawDrops) do
                self.itemSystem:addItem(player, drop.itemId, drop.quantity, nil, { source = ctx.source or 'auto_drop_pickup', correlation_id = ctx.correlationId, source_event_id = ctx.sourceEventId, boss_id = ctx.bossId })
                self.questSystem:onItemAcquired(player, drop.itemId, drop.quantity)
                self:_emitRewardLedger(player, 'reward_claim', { source_system = 'drop_system', correlation_id = ctx.correlationId, source_event_id = ctx.sourceEventId, map_id = mapId, boss_id = ctx.bossId, item_id = drop.itemId, quantity = drop.quantity, idempotency_key = string.format('reward:auto:%s:%s:%s', tostring(player.id), tostring(drop.itemId), tostring(ctx.correlationId or os.time())), metadata = { mode = 'auto_pickup', reason = ctx.source } })
            end
            return rawDrops
        end

        local records = self.dropSystem:registerDrops(mapId, source, rawDrops, {
            ownerId = player.id,
            ownerWindowSec = self.worldConfig.runtime and self.worldConfig.runtime.dropOwnerWindowSec,
            now = self:_now(),
            sourceSystem = 'drop_system',
            sourceEventId = ctx.sourceEventId,
            correlationId = ctx.correlationId,
            bossId = ctx.bossId,
        })
        for _, record in ipairs(records) do self:_emit('onDropSpawned', record) end
        return records
    end

    function world:_applyMobRewards(player, mob, forceAutoPickup)
        self.expSystem:grant(player, mob.template.exp or 0)
        local correlationId = string.format('mob_reward:%s:%s:%s', tostring(player.id), tostring(mob.spawnId), tostring(self:_now()))
        self.economySystem:grantMesos(player, self:_rollMesos(mob.template.mesos_min, mob.template.mesos_max), 'mob_drop', { correlationId = correlationId, mapId = mob.mapId })
        local rawDrops = self.dropSystem:rollDrops(mob, player)
        local delivered = self:_processDropAcquisition(player, mob.mapId, mob, rawDrops, forceAutoPickup, { source = 'mob_drop', correlationId = correlationId, sourceEventId = tostring(mob.spawnId) })
        self.questSystem:onKill(player, mob.mobId, 1)
        player.killLog[mob.mobId] = (player.killLog[mob.mobId] or 0) + 1
        player.dirty = true
        self.journal:append('mob_killed', { playerId = player.id, mapId = mob.mapId, mobId = mob.mobId, spawnId = mob.spawnId })
        self:_emit('onMobKilled', player, mob, delivered)
        self:publishPlayerSnapshot(player)
        return delivered
    end

    function world:attackMob(player, mapId, spawnId, requestedDamage, validatedMob)
        if not player then return false, 'invalid_player' end
        if mapId ~= nil and mapId ~= '' and mapId ~= player.currentMapId then return false, 'wrong_map' end
        local targetMapId = player.currentMapId or mapId
        local mob = validatedMob or self.spawnSystem:getMob(targetMapId, spawnId)
        if validatedMob and (validatedMob.mapId ~= targetMapId or tonumber(validatedMob.spawnId) ~= tonumber(spawnId)) then
            return false, 'mob_context_mismatch'
        end
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

        local ok, mobOrErr, killed = self.spawnSystem:damageMob(mob.mapId, mob.spawnId, damage)
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

    function world:pickupDrop(player, mapId, dropId, validatedDrop)
        if not player then return false, 'invalid_player' end
        if mapId ~= nil and mapId ~= '' and mapId ~= player.currentMapId then return false, 'wrong_map' end
        local record = validatedDrop or self.dropSystem:getDrop(dropId)
        if validatedDrop and tonumber(validatedDrop.dropId) ~= tonumber(dropId) then return false, 'drop_context_mismatch' end
        if not record then return false, 'drop_not_found' end
        if mapId ~= nil and mapId ~= '' and record.mapId ~= mapId then return false, 'wrong_map' end
        local boundaryOk, boundaryErr = self:_requireActionBoundary(player, record.mapId, { x = record.x, y = record.y, z = record.z or 0 }, 'dropPickupRange')
        if not boundaryOk then return false, boundaryErr end
        local actionOk, actionErr = self:_checkAction(player, 'drop_pickup', 1)
        if not actionOk then return false, actionErr end
        if self.containment.rewardQuarantine then return false, 'reward_quarantined' end
        local claimKey = string.format('%s:%s:%s:%s', tostring(self.runtimeIdentity.worldId), tostring(self.runtimeIdentity.channelId), tostring(self.runtimeIdentity.runtimeInstanceId), tostring(dropId))
        if self.recoveryInvariants.claimedDrops[claimKey] then
            self:_escalate('duplicate_drop_claim_attempt', { dropId = dropId, playerId = player.id })
            return false, 'duplicate_drop_claim'
        end
        local ok, recordOrErr = self.dropSystem:pickupDrop(player, record.mapId, dropId, self.itemSystem, { now = self:_now() })
        if not ok then return false, recordOrErr end
        self.recoveryInvariants.claimedDrops[claimKey] = true
        self.questSystem:onItemAcquired(player, recordOrErr.itemId, recordOrErr.quantity)
        self.journal:append('drop_picked', { playerId = player.id, mapId = record.mapId, dropId = dropId, itemId = recordOrErr.itemId })
        self:_emitRewardLedger(player, 'reward_claim', { source_system = 'drop_system', map_id = record.mapId, item_id = recordOrErr.itemId, quantity = recordOrErr.quantity, source_event_id = tostring(dropId), correlation_id = recordOrErr.correlationId, idempotency_key = string.format('reward:pickup:%s:%s', tostring(player.id), tostring(dropId)), metadata = { mode = 'manual_pickup' } })
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
            self:_recordRuntimeEvent('boss_spawned', { bossId = bossId, mapId = targetMapId, scope = deepcopy(self.runtimeIdentity) })
            self:_emit('onBossSpawned', encounter)
        end
        return encounter, err, remaining
    end

    function world:_applyBossRewards(player, encounter, rawDrops)
        local bossDef = self.mobs[encounter.bossId] or {}
        self.expSystem:grant(player, bossDef.exp or 0)
        local correlationId = string.format('boss_reward:%s:%s:%s', tostring(player.id), tostring(encounter.bossId), tostring(self:_now()))
        self.economySystem:grantMesos(player, self:_rollMesos(bossDef.mesos_min, bossDef.mesos_max), 'boss_drop', { bossId = encounter.bossId, mapId = encounter.mapId, correlationId = correlationId })
        local position = self:_bossPosition(encounter)
        local delivered = self:_processDropAcquisition(player, encounter.mapId, position, rawDrops, self.autoPickupDrops == true, { source = 'boss_drop', correlationId = correlationId, bossId = encounter.bossId, sourceEventId = tostring(encounter.bossId) })
        local claimKey = string.format('boss_claim:%s:%s:%s:%s:%s', tostring(self.runtimeIdentity.worldId), tostring(self.runtimeIdentity.channelId), tostring(self.runtimeIdentity.runtimeInstanceId), tostring(player.id), tostring(encounter.bossId))
        if self.recoveryInvariants.bossRewardClaims[claimKey] then
            self:_escalate('duplicate_boss_reward_attempt', { playerId = player.id, bossId = encounter.bossId })
            return false, 'duplicate_boss_reward'
        end
        self.recoveryInvariants.bossRewardClaims[claimKey] = true
        self:_emitRewardLedger(player, 'reward_claim', { source_system = 'boss_system', correlation_id = correlationId, map_id = encounter.mapId, boss_id = encounter.bossId, idempotency_key = claimKey, metadata = { reward_kind = 'boss_clear' } })
        self.questSystem:onKill(player, encounter.bossId, 1)
        player.killLog[encounter.bossId] = (player.killLog[encounter.bossId] or 0) + 1
        player.dirty = true
        self.journal:append('boss_killed', { playerId = player.id, mapId = encounter.mapId, bossId = encounter.bossId })
        self:_emit('onBossKilled', encounter, player, delivered)
        self:publishPlayerSnapshot(player)
        return delivered
    end

    function world:damageBoss(player, mapId, bossId, amount, validatedEncounter)
        if not player then return false, 'invalid_player' end
        if amount == nil and bossId ~= nil and type(bossId) ~= 'string' then
            amount = bossId
            bossId = nil
        end
        if mapId ~= nil and mapId ~= '' and mapId ~= player.currentMapId then return false, 'wrong_map' end
        local targetMapId = player.currentMapId or mapId
        if self.containment.rewardQuarantine then return false, 'reward_quarantined' end
        local encounter = validatedEncounter or self.bossSystem:getEncounter(targetMapId)
        if validatedEncounter and (validatedEncounter.mapId ~= targetMapId or (bossId ~= nil and bossId ~= '' and validatedEncounter.bossId ~= bossId)) then return false, 'boss_context_mismatch' end
        if not encounter and mapId and mapId ~= targetMapId and self.bossSystem:getEncounter(mapId) then
            return false, 'wrong_map'
        end
        if not encounter then return false, 'no_active_encounter' end
        if bossId ~= nil and bossId ~= '' and encounter.bossId ~= bossId then return false, 'boss_not_found' end

        local boundaryOk, boundaryErr = self:_requireActionBoundary(player, encounter.mapId, self:_bossPosition(encounter), 'bossAttackRange')
        if not boundaryOk then return false, boundaryErr end
        local actionOk, actionErr = self:_checkAction(player, 'boss_attack', 1)
        if not actionOk then return false, actionErr end
        local damage, damageErr = self:_capDamage(player, 'boss', amount)
        if not damage then return false, damageErr end
        local combatCfg = self.worldConfig.combat or {}
        local hpCapFactor = tonumber(combatCfg.bossDamageMaxHpFactor) or 0.1
        local hpCap = math.max(1, math.floor((tonumber(encounter.maxHp) or 1) * hpCapFactor))
        damage = math.min(damage, hpCap)

        local ok, dropsOrError, resolvedEncounter = self.bossSystem:damage(encounter.mapId, player, damage)
        if not ok then return false, dropsOrError end
        if not dropsOrError then
            self:_emit('onBossDamaged', resolvedEncounter, player, damage)
            self:saveWorldState('boss_damage')
            return true, nil
        end

        local rewards, rewardErr = self:_applyBossRewards(player, resolvedEncounter, dropsOrError)
        if rewards == false then return false, rewardErr end
        return true, rewards
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
                    self:_recordRuntimeEvent('boss_spawned', { bossId = encounter.bossId, mapId = mapId, automated = true, scope = deepcopy(self.runtimeIdentity) })
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
        local corr = string.format('grant_item:%s:%s:%s', tostring(player and player.id), tostring(itemId), tostring(self:_now()))
        local ok, err = self.itemSystem:addItem(player, itemId, quantity, metadata, { source = reason or 'grant_item', correlation_id = corr })
        if not ok then return false, err end
        self.questSystem:onItemAcquired(player, itemId, quantity)
        self.journal:append('item_granted', { playerId = player.id, itemId = itemId, quantity = quantity, reason = reason })
        self:publishPlayerSnapshot(player)
        return true
    end

    function world:buyFromNpc(player, npcId, itemId, quantity, validatedNpc)
        if not player then return false, 'invalid_player' end
        local npc, npcErr = self:_resolveValidatedNpc(npcId, validatedNpc)
        if not npc then return false, npcErr end
        local shopOk, shopErr = self:_validateNpcShop(npc)
        if not shopOk then return false, shopErr end
        local boundaryOk, boundaryErr = self:_requireActionBoundary(player, npc.mapId, npc.position, 'questNpcRange')
        if not boundaryOk then return false, boundaryErr end
        if not self:_isNpcItemAllowed(npc, itemId) then return false, 'item_not_sold_by_npc' end
        local actionOk, actionErr = self:_checkAction(player, 'shop', 1)
        if not actionOk then return false, actionErr end
        local correlationId = string.format('shop_buy:%s:%s:%s', tostring(player.id), tostring(itemId), tostring(self:_now()))
        local ok, err = self.economySystem:buyFromNpc(player, itemId, quantity, { npcId = npcId, correlationId = correlationId })
        if not ok then return false, err end
        self.questSystem:onItemAcquired(player, itemId, quantity)
        self.journal:append('npc_buy', { playerId = player.id, npcId = npcId, itemId = itemId, quantity = quantity })
        self:publishPlayerSnapshot(player)
        return true
    end

    function world:sellToNpc(player, npcId, itemId, quantity, validatedNpc)
        if not player then return false, 'invalid_player' end
        local npc, npcErr = self:_resolveValidatedNpc(npcId, validatedNpc)
        if not npc then return false, npcErr end
        local shopOk, shopErr = self:_validateNpcShop(npc)
        if not shopOk then return false, shopErr end
        local boundaryOk, boundaryErr = self:_requireActionBoundary(player, npc.mapId, npc.position, 'questNpcRange')
        if not boundaryOk then return false, boundaryErr end
        if not self:_isNpcItemAllowed(npc, itemId) then return false, 'item_not_sold_by_npc' end
        local actionOk, actionErr = self:_checkAction(player, 'shop', 1)
        if not actionOk then return false, actionErr end
        local correlationId = string.format('shop_sell:%s:%s:%s', tostring(player.id), tostring(itemId), tostring(self:_now()))
        local ok, err = self.economySystem:sellToNpc(player, itemId, quantity, { npcId = npcId, correlationId = correlationId })
        if not ok then return false, err end
        self.questSystem:onItemRemoved(player, itemId, quantity)
        self.journal:append('npc_sell', { playerId = player.id, npcId = npcId, itemId = itemId, quantity = quantity })
        self:publishPlayerSnapshot(player)
        return true
    end

    function world:equipItem(player, itemId, instanceId)
        if not player then return false, 'invalid_player' end
        local actionOk, actionErr = self:_checkAction(player, 'equip', 1)
        if not actionOk then return false, actionErr end
        local ok, err = self.itemSystem:equip(player, itemId, instanceId, { correlation_id = string.format('equip:%s:%s:%s', tostring(player.id), tostring(itemId), tostring(self:_now())) })
        if not ok then return false, err end
        self.journal:append('item_equipped', { playerId = player.id, itemId = itemId })
        self:publishPlayerSnapshot(player)
        return true
    end

    function world:unequipItem(player, slot)
        if not player then return false, 'invalid_player' end
        local actionOk, actionErr = self:_checkAction(player, 'equip', 1)
        if not actionOk then return false, actionErr end
        local ok, err = self.itemSystem:unequip(player, slot, { correlation_id = string.format('unequip:%s:%s:%s', tostring(player.id), tostring(slot), tostring(self:_now())) })
        if not ok then return false, err end
        self.journal:append('item_unequipped', { playerId = player.id, slot = slot })
        self:publishPlayerSnapshot(player)
        return true
    end

    function world:changeMap(player, mapId, sourceMapId)
        if not player then return false, 'invalid_player' end
        if self.containment.migrationBlocked then return false, 'migration_blocked' end
        if not mapId or mapId == '' or not self.worldConfig.maps or not self.worldConfig.maps[mapId] then return false, 'invalid_map' end
        if sourceMapId ~= nil and sourceMapId ~= '' and player.currentMapId ~= sourceMapId then return false, 'wrong_map' end
        local source = sourceMapId
        if source == nil or source == '' then source = player.currentMapId end
        if source ~= mapId and not self:_isAllowedMapTransition(source, mapId) then return false, 'invalid_map_transition' end
        local actionOk, actionErr = self:_checkAction(player, 'map_change', 1)
        if not actionOk then return false, actionErr end
        local ok, err = self:setPlayerMap(player, mapId)
        if not ok then return false, err end
        self:_recordRuntimeEvent('player_runtime_migrated', { playerId = player.id, fromMapId = source, toMapId = mapId, scope = deepcopy(player.runtimeScope) })
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

    local restoredWorldState, restoreErr = world:restoreWorldState()
    if restoreErr and config.allowWorldStateRestoreFailure ~= true then
        error('world_state_restore_failed:' .. tostring(restoreErr))
    end

    local runtimeCfg = worldConfig.runtime or {}
    scheduler:every('spawn_tick', tonumber(runtimeCfg.spawnTickSec) or 5, function() spawnSystem:tick() end)
    scheduler:every('boss_tick', tonumber(runtimeCfg.bossTickSec) or 15, function() world:tickBosses() end)
    scheduler:every('autosave_tick', tonumber(runtimeCfg.autosaveTickSec) or 30, function() world:flushDirtyPlayers({ requireWorldSave = world.strictRuntimeBoundary }) end)
    scheduler:every('world_state_autosave_tick', tonumber(runtimeCfg.worldStateAutosaveTickSec) or 15, function() world:flushPendingWorldSave(world._pendingWorldSaveReason or 'periodic') end)
    scheduler:every('health_tick', tonumber(runtimeCfg.healthTickSec) or 30, function() healthcheck:run() end)
    scheduler:every('drop_expire_tick', tonumber(runtimeCfg.dropExpireTickSec) or 5, function() world:expireDrops() end)

    return world
end

return ServerBootstrap
