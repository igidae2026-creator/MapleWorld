local SpawnSystem = require('scripts.spawn_system')
local DropSystem = require('scripts.drop_system')
local ExpSystem = require('scripts.exp_system')
local ItemSystem = require('scripts.item_system')
local BossSystem = require('scripts.boss_system')
local QuestSystem = require('scripts.quest_system')
local EconomySystem = require('scripts.economy_system')
local StatSystem = require('scripts.stat_system')
local JobSystem = require('scripts.job_system')
local BuffSystem = require('scripts.buff_debuff_system')
local PlayerClassSystem = require('scripts.player_class_system')
local CombatResolution = require('scripts.combat_resolution')
local SkillSystem = require('scripts.skill_system')
local EquipmentProgression = require('scripts.equipment_progression')
local InventoryExpansion = require('scripts.inventory_expansion')
local PartySystem = require('scripts.party_system')
local GuildSystem = require('scripts.guild_system')
local SocialSystem = require('scripts.social_system')
local TradingSystem = require('scripts.trading_system')
local AuctionHouse = require('scripts.auction_house')
local CraftingSystem = require('scripts.crafting_system')
local DialogueSystem = require('scripts.npc_dialogue_system')
local MapEventSystem = require('scripts.map_event_system')
local WorldEventSystem = require('scripts.world_event_system')
local ProgressionSystem = require('scripts.progression_system')
local DailyWeeklySystem = require('scripts.daily_weekly_system')
local AchievementsSystem = require('scripts.achievements_system')
local BossMechanicsSystem = require('scripts.boss_mechanics_system')
local LootDistribution = require('scripts.loot_distribution')
local AntiAbuseHooks = require('scripts.anti_abuse_gameplay_hooks')
local TutorialSystem = require('scripts.tutorial_system')
local BuildRecommendationSystem = require('scripts.build_recommendation_system')
local PartyFinder = require('scripts.party_finder')
local CombatFeedback = require('scripts.combat_feedback')
local RaidSystem = require('scripts.raid_system')
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
local RuntimeKernel = require('ops.runtime_kernel')
local RecoveryKernel = require('ops.recovery_kernel')
local EventTruth = require('ops.event_truth')
local ContentLoader = require('data.content_loader')
local WorldCluster = require('ops.world_cluster')
local ChannelRouter = require('ops.channel_router')
local ShardRegistry = require('ops.shard_registry')
local WorldFailover = require('ops.world_failover')
local SessionOrchestrator = require('ops.session_orchestrator')
local SnapshotManager = require('ops.snapshot_manager')
local ReplayEngine = require('ops.replay_engine')
local DeterministicReplayValidator = require('ops.deterministic_replay_validator')
local ConsistencyValidator = require('ops.consistency_validator')
local TelemetryPipeline = require('ops.telemetry_pipeline')
local MetricsAggregator = require('ops.metrics_aggregator')
local RuntimeProfiler = require('ops.runtime_profiler')
local AdminConsole = require('ops.admin_console')
local GMCommandService = require('ops.gm_command_service')
local CheatDetection = require('ops.cheat_detection')
local ExploitMonitor = require('ops.exploit_monitor')
local AnomalyScoring = require('ops.anomaly_scoring')
local DistributedRateLimit = require('ops.distributed_rate_limit')
local AuditLog = require('ops.audit_log')
local PolicyEngine = require('ops.policy_engine')
local BootstrapProfiles = require('ops.bootstrap_profiles')
local EntityIndex = require('ops.entity_index')
local EventBatcher = require('ops.event_batcher')
local PerformanceCounters = require('ops.performance_counters')
local MemoryGuard = require('ops.memory_guard')
local DuplicationGuard = require('ops.duplication_guard')
local InflationGuard = require('ops.inflation_guard')
local LiveEventController = require('ops.live_event_controller')

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
            anticipation = row.anticipation,
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
            uniqueness = runtimeBoss and runtimeBoss.uniqueness or (worldConfig and worldConfig.runtime and worldConfig.runtime.defaultBossUniquenessScope) or 'channel_unique',
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
            narrative = row.narrative,
            rewardSummary = row.reward_summary,
            guidance = row.guidance,
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
            saveReplayAnchorThreshold = 1,
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
            topologyMode = 'single_instance_compatibility',
            policyBundleId = 'genesis.default',
            policyBundleVersion = '1.0.0',
            policyBundleClass = 'stable',
            pressureDensityThreshold = 0.85,
            pressureSaveBacklogThreshold = 50,
            pressureRewardInflationThreshold = 12,
            pressureReplayThreshold = 1,
            pressureInstabilityThreshold = 3,
            pressureLowDiversityThreshold = 4,
            maxPlayersPerChannel = 100,
            maxWorldSnapshots = 8,
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
    if dataProvider and dataProvider[providerKey] then
        dataSources[providerKey] = 'runtime_tables'
        return cloneRows(dataProvider[providerKey])
    end

    if basePath and io and io.open then
        local ok, rows = pcall(parseCsv, basePath .. '/' .. relativePath)
        if ok then
            dataSources[providerKey] = 'csv'
            return rows
        end
        warnings[#warnings + 1] = 'csv_fallback:' .. relativePath
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

local function stableSerialize(value, seen)
    local valueType = type(value)
    if valueType ~= 'table' then return tostring(value) end
    local visited = seen or {}
    if visited[value] then return '<cycle>' end
    visited[value] = true
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = {'{'}
    for _, key in ipairs(keys) do
        out[#out + 1] = tostring(key)
        out[#out + 1] = '='
        out[#out + 1] = stableSerialize(value[key], visited)
        out[#out + 1] = ';'
    end
    out[#out + 1] = '}'
    visited[value] = nil
    return table.concat(out)
end

local function stringHash(value)
    local hash = 5381
    for i = 1, #value do
        hash = ((hash * 33) + string.byte(value, i)) % 4294967296
        hash = hash % 4294967296
    end
    return string.format('%08x', hash)
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
    local contentBundle = config.contentBundle or ContentLoader.load()
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
        item.progressionTier = tonumber(item.progression_tier) or item.requiredLevel or 1
        item.desirability = item.desirability
        item.upgradePath = item.upgrade_path
        item.excitement = item.excitement
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
    local statSystem = StatSystem.new({ jobs = contentBundle.content.jobs, metrics = metrics })
    local jobSystem = JobSystem.new({ jobs = contentBundle.content.jobs, metrics = metrics })
    local buffSystem = BuffSystem.new({ time = runtimeClock })
    local combatResolution = CombatResolution.new({ statSystem = statSystem, buffSystem = buffSystem, itemSystem = itemSystem })
    local skillSystem = SkillSystem.new({ skillTrees = contentBundle.content.skills, buffSystem = buffSystem, combat = combatResolution, time = runtimeClock })
    local equipmentProgression = EquipmentProgression.new({ itemSystem = itemSystem })
    local inventoryExpansion = InventoryExpansion.new()
    local partySystem = PartySystem.new()
    local guildSystem = GuildSystem.new()
    local socialSystem = SocialSystem.new()
    local tradingSystem = TradingSystem.new({ itemSystem = itemSystem, economySystem = economySystem })
    local auctionHouse = AuctionHouse.new({ economy = contentBundle.content.economy })
    local craftingSystem = CraftingSystem.new({ itemSystem = itemSystem })
    local dialogueSystem = DialogueSystem.new({ dialogues = contentBundle.content.dialogues })
    local mapEventSystem = MapEventSystem.new({ maps = contentBundle.content.maps })
    local worldEventSystem = WorldEventSystem.new({ definitions = contentBundle.content.events })
    local progressionSystem = ProgressionSystem.new({ jobSystem = jobSystem, statSystem = statSystem, inventoryExpansion = inventoryExpansion })
    local dailyWeeklySystem = DailyWeeklySystem.new()
    local achievementsSystem = AchievementsSystem.new()
    local bossMechanicsSystem = BossMechanicsSystem.new()
    local lootDistribution = LootDistribution.new()
    local antiAbuseHooks = AntiAbuseHooks.new()
    local tutorialSystem = TutorialSystem.new()
    local buildRecommendationSystem = BuildRecommendationSystem.new({ jobs = contentBundle.content.jobs, skills = contentBundle.content.skills })
    local playerClassSystem = PlayerClassSystem.new({ jobSystem = jobSystem, statSystem = statSystem, buildRecommendationSystem = buildRecommendationSystem })
    local partyFinder = PartyFinder.new()
    local combatFeedback = CombatFeedback.new()
    local raidSystem = RaidSystem.new()
    local healthcheck = Healthcheck.new({ metrics = metrics, scheduler = scheduler })
    local adminTools = AdminTools.new({ metrics = metrics, scheduler = scheduler })

    local policyBundle = RuntimePolicyBundle.new(worldConfig, config.policyBundle)
    local runtimeIdentity = {
        worldId = tostring((worldConfig.runtime and worldConfig.runtime.worldId) or 'world-1'),
        channelId = tostring((worldConfig.runtime and worldConfig.runtime.channelId) or 'channel-1'),
        runtimeInstanceId = tostring((worldConfig.runtime and worldConfig.runtime.runtimeInstanceId) or 'runtime-main'),
        ownerId = tostring((worldConfig.runtime and worldConfig.runtime.worldWriterOwnerId) or 'default'),
        runtimeEpoch = math.max(0, math.floor(tonumber(worldConfig.runtime and worldConfig.runtime.worldWriterEpoch) or 0)),
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
        statSystem = statSystem,
        jobSystem = jobSystem,
        buffSystem = buffSystem,
        skillSystem = skillSystem,
        combatResolution = combatResolution,
        equipmentProgression = equipmentProgression,
        inventoryExpansion = inventoryExpansion,
        partySystem = partySystem,
        guildSystem = guildSystem,
        socialSystem = socialSystem,
        tradingSystem = tradingSystem,
        auctionHouse = auctionHouse,
        craftingSystem = craftingSystem,
        dialogueSystem = dialogueSystem,
        mapEventSystem = mapEventSystem,
        worldEventSystem = worldEventSystem,
        progressionSystem = progressionSystem,
        dailyWeeklySystem = dailyWeeklySystem,
        achievementsSystem = achievementsSystem,
        bossMechanicsSystem = bossMechanicsSystem,
        lootDistribution = lootDistribution,
        antiAbuseHooks = antiAbuseHooks,
        tutorialSystem = tutorialSystem,
        buildRecommendationSystem = buildRecommendationSystem,
        playerClassSystem = playerClassSystem,
        partyFinder = partyFinder,
        combatFeedback = combatFeedback,
        raidSystem = raidSystem,
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
        content = contentBundle,
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
            entityDensity = 0,
            entityDensityPressure = 0,
            replayPressure = 0,
            ownershipConflictPressure = 0,
            rewardInflationPressure = 0,
            duplicateRiskPressure = 0,
            instabilityPressure = 0,
            farmRepetitionPressure = 0,
            saveBacklog = 0,
            repetitiveFarming = 0,
        },
        containment = {
            safeMode = false,
            rewardQuarantine = false,
            saveQuarantine = false,
            migrationBlocked = false,
            replayOnly = false,
            ownershipReject = false,
            persistenceQuarantine = false,
        },
        escalation = {
            level = 0,
            reason = 'none',
            at = 0,
            history = {},
            severity = 'warning',
        },
        governance = {
            state = 'normal',
            previousState = nil,
            changedAt = 0,
            reason = 'boot',
            history = {},
            decisions = {},
            outputs = {},
        },
        repairs = {
            state = 'idle',
            retries = {},
            actions = {},
            timeline = {},
            quarantines = {},
        },
        recovery = {
            mode = 'cold_start',
            checkpointId = nil,
            checkpointRevision = 0,
            replayBaseRevision = 0,
            replayedEntries = 0,
            divergence = false,
            valid = true,
            phases = {
                checkpoint_load = 'pending',
                event_hydration = 'pending',
                deterministic_reconstruction = 'pending',
                state_reconstruction = 'pending',
                invariant_verification = 'pending',
                runtime_activation = 'pending',
            },
            watermark = {
                journal = 0,
                ledger = 0,
            },
            lastReplayDurationMs = 0,
            divergenceCount = 0,
            checkpointLineage = {},
            lastReplayReportId = nil,
            recoverySource = {
                source = 'cold_start',
                checkpointId = nil,
                revision = 0,
                reportArtifactId = nil,
            },
            confidence = 100,
            verificationSummary = {
                verdict = 'cold_start',
                confidence = 100,
                reasons = { 'cold_start' },
            },
        },
        recoveryInvariants = {
            claimedDrops = {},
            bossRewardClaims = {},
            itemInstanceIds = {},
            ownershipScopes = {},
        },
        _pendingWorldSaveReason = nil,
        _pendingWorldSaveReasons = {},
        _pendingWorldSaveCount = 0,
        _worldStateDirty = false,
        _lastWorldSaveAt = nil,
        _savingFailures = 0,
        _ownershipConflicts = 0,
        _rewardMutationCountWindow = {},
        _ownershipConflictWindow = {},
        _recentFarmSignals = {},
        _lastPolicyId = nil,
        actionGuard = actionGuard,
        journal = journal,
        rng = rng,
        clock = runtimeClock,
        strictRuntimeBoundary = runtimeAdapter:isLive(),
        autoPickupDrops = config.autoPickupDrops,
        artifacts = {
            nextId = 1,
            entries = {},
            byKind = {},
        },
        topology = {
            mode = tostring((worldConfig.runtime and worldConfig.runtime.topologyMode) or 'single_instance_compatibility'),
            world = {},
            channel = {},
            runtime = {},
            mapInstances = {},
        },
        policyHistory = policyBundle:historySnapshot(),
        savePlan = {
            urgency = 'deferred',
            checkpointClass = 'lightweight_runtime_checkpoint',
            reasons = { 'boot' },
            healthScore = 100,
        },
        bootReport = {
            dataSource = summarizeDataSources(dataSources),
            dataSources = dataSources,
            warnings = warnings,
        },
        gameplay = {
            recipes = {
                bronze_reforge = {
                    ingredients = { { itemId = 'henesys_material_01', quantity = 2 } },
                    result = { itemId = 'henesys_bronze_blade', quantity = 1 },
                },
            },
        },
    }
    world.cluster = WorldCluster.new({ worldId = runtimeIdentity.worldId })
    world.cluster:registerChannel(runtimeIdentity.channelId, {})
    world.shardRegistry = ShardRegistry.new()
    world.shardRegistry:register('shard-main', { worldId = runtimeIdentity.worldId, channelId = runtimeIdentity.channelId })
    world.channelRouter = ChannelRouter.new({
        cluster = world.cluster,
        congestionThreshold = worldConfig.runtime and worldConfig.runtime.pressureDensityThreshold,
        perChannelPlayerCap = worldConfig.runtime and worldConfig.runtime.maxPlayersPerChannel,
    })
    world.failover = WorldFailover.new({ cluster = world.cluster })
    world.sessionOrchestrator = SessionOrchestrator.new({ time = runtimeClock })
    world.snapshotManager = SnapshotManager.new({ time = runtimeClock, maxSnapshots = worldConfig.runtime and worldConfig.runtime.maxWorldSnapshots })
    world.entityIndex = EntityIndex.new()
    world.eventBatcher = EventBatcher.new({ maxBatch = 24 })
    world.performanceCounters = PerformanceCounters.new()
    world.replayEngine = ReplayEngine.new()
    world.deterministicReplayValidator = DeterministicReplayValidator.new({ replayEngine = world.replayEngine })
    world.consistencyValidator = ConsistencyValidator.new()
    world.telemetryPipeline = TelemetryPipeline.new()
    world.metricsAggregator = MetricsAggregator.new()
    world.runtimeProfiler = RuntimeProfiler.new()
    world.memoryGuard = MemoryGuard.new({ softLimitKb = 196608, hardLimitKb = 262144 })
    world.duplicationGuard = DuplicationGuard.new()
    world.inflationGuard = InflationGuard.new({ ratioThreshold = 2.0 })
    world.cheatDetection = CheatDetection.new()
    world.exploitMonitor = ExploitMonitor.new({ detector = world.cheatDetection })
    world.anomalyScoring = AnomalyScoring.new()
    world.distributedRateLimit = DistributedRateLimit.new()
    world.auditLog = AuditLog.new()
    world.policyEngine = PolicyEngine.new({
        thresholds = {
            safeMode = 10,
            channelLoad = 75,
            duplicateRisk = 2,
            rewardInflation = 8,
            freezeTransfers = 3,
            freezeRewards = 12,
            lowSinkPressure = 0,
        },
    })
    world.bootstrapProfiles = BootstrapProfiles
    world.adminConsole = AdminConsole.new({ world = world, adminTools = adminTools, healthcheck = healthcheck })
    world.gmCommandService = GMCommandService.new({ world = world })
    world.liveEventController = LiveEventController.new({ world = world })
    itemSystem.ledgerSink = function(event) return world:appendLedgerEvent(event) end
    economySystem.ledgerSink = function(event) return world:appendLedgerEvent(event) end

    if world.autoPickupDrops == nil then
        world.autoPickupDrops = worldConfig.runtime and worldConfig.runtime.autoPickupDrops ~= false
    end
    healthcheck.world = world
    world.topology.world = { id = world.runtimeIdentity.worldId, scope = 'world_global' }
    world.topology.channel = { id = world.runtimeIdentity.channelId, worldId = world.runtimeIdentity.worldId, scope = 'channel_global' }
    world.topology.runtime = { id = world.runtimeIdentity.runtimeInstanceId, channelId = world.runtimeIdentity.channelId, worldId = world.runtimeIdentity.worldId, scope = 'runtime_local' }

    economySystem.auditSink = function(entry)
        if not world or not world.journal then return end
        world.journal:append('economy_mutation', entry)
    end

    function world:_now()
        return math.floor(tonumber(self.clock()) or os.time())
    end

    function world:_ensurePlayerSystems(player)
        self.statSystem:ensurePlayer(player)
        self.jobSystem:ensurePlayer(player)
        self.skillSystem:ensurePlayer(player)
        self.inventoryExpansion:ensurePlayer(player)
        self.socialSystem:ensurePlayer(player)
        self.progressionSystem:ensurePlayer(player)
        self.dailyWeeklySystem:ensurePlayer(player)
        self.achievementsSystem:ensurePlayer(player)
        self.buffSystem:ensurePlayer(player)
        self.tutorialSystem:ensurePlayer(player)
        self.playerClassSystem:ensurePlayer(player)
        self.progressionSystem:refresh(player)
        player.huntingLoop = player.huntingLoop or { streak = 0, rareSince = 0, recentDrops = {} }
        return player
    end

    function world:_nextQuestGuidance(player)
        local lowestId, lowestQuest = nil, nil
        for questId, quest in pairs(self.questSystem.quests or {}) do
            local state = player.questState[questId]
            if not state or not state.completed then
                if (quest.requiredLevel or 1) <= (player.level or 1) and (lowestQuest == nil or (quest.requiredLevel or 1) < (lowestQuest.requiredLevel or 1) or questId < lowestId) then
                    lowestId, lowestQuest = questId, quest
                end
            end
        end
        if not lowestQuest then return nil end
        return {
            questId = lowestId,
            title = lowestQuest.name,
            narrative = lowestQuest.narrative,
            guidance = lowestQuest.guidance,
            rewardSummary = lowestQuest.rewardSummary,
        }
    end

    function world:_recommendedRoute(player)
        local current = self.worldConfig.maps[player.currentMapId or self.worldConfig.runtime.defaultMapId] or {}
        local nextMapId = nil
        for candidateId in pairs((self.worldConfig.mapTransitions or {})[player.currentMapId or self.worldConfig.runtime.defaultMapId] or {}) do
            local candidate = self.worldConfig.maps[candidateId] or {}
            if not nextMapId or (candidate.recommended_level or 0) > (current.recommended_level or 0) then
                nextMapId = candidateId
            end
        end
        return {
            currentMapId = player.currentMapId,
            nextMapId = nextMapId,
            tutorial = self.tutorialSystem:getCurrent(player),
        }
    end

    function world:_playerJourneyPlan(player)
        local build = self.buildRecommendationSystem:recommend(player)
        local nextQuest = self:_nextQuestGuidance(player)
        local route = self:_recommendedRoute(player)
        local economy = self:getEconomyReport()
        local mapMeta = self.worldConfig.maps[player.currentMapId or self.worldConfig.runtime.defaultMapId] or {}
        return {
            nextObjective = nextQuest and nextQuest.title or 'Continue hunting toward the next map milestone.',
            whereToLevel = build.levelingMaps,
            gearFocus = build.equipmentFocus,
            gearTierTarget = math.max(1, math.floor((player.level or 1) / 20) + 1),
            howToJoinGroupPlay = 'Use party finder, then move into dungeon and boss routes once your level matches the map guidance.',
            howToEarnCurrency = 'Sell surplus drops, clear quests, and list high-demand rares on the auction house.',
            howToFightBosses = 'Check route progression, stock consumables, and watch telegraphed phase changes.',
            currentRegionLore = mapMeta.metadata and mapMeta.metadata.lore or nil,
            progressionHints = build.milestoneHints,
            recommendedRoute = route,
            marketFocus = {
                hottestTrackedItem = next(economy.priceHistory or {}) or nil,
                sinkPressure = economy.sinkPressure,
            },
            longTermGoals = {
                prestige = (player.progression or {}).prestige or 0,
                raidTier = (player.progression or {}).raidTier or 0,
                specialization = (player.progression or {}).specialization,
            },
        }
    end

    function world:_policy()
        return self.policyBundle:snapshot() or {}
    end

    function world:_policySection(name)
        local policy = self:_policy()
        return type(policy[name]) == 'table' and policy[name] or {}
    end

    function world:_severityName(level)
        return RuntimeKernel.severityName(level)
    end

    function world:_lineageReference(kind, subject)
        return table.concat({
            tostring(kind or 'runtime'),
            tostring(subject or 'unknown'),
            tostring(self.runtimeIdentity.worldId),
            tostring(self.runtimeIdentity.channelId),
            tostring(self.runtimeIdentity.runtimeInstanceId),
            tostring(self.runtimeIdentity.runtimeEpoch),
        }, ':')
    end

    function world:_ledgerContext(base)
        local ctx = deepcopy(base or {})
        ctx.world_id = ctx.world_id or self.runtimeIdentity.worldId
        ctx.channel_id = ctx.channel_id or self.runtimeIdentity.channelId
        ctx.runtime_instance_id = ctx.runtime_instance_id or self.runtimeIdentity.runtimeInstanceId
        ctx.owner_id = ctx.owner_id or self.runtimeIdentity.ownerId
        ctx.runtime_epoch = ctx.runtime_epoch or self.runtimeIdentity.runtimeEpoch
        ctx.coordinator_epoch = ctx.coordinator_epoch or self.runtimeIdentity.coordinatorEpoch
        ctx.lineage_reference = ctx.lineage_reference or self:_lineageReference(ctx.source_system or 'runtime', ctx.item_instance_id or ctx.item_id or ctx.boss_id or ctx.quest_id or ctx.map_id or ctx.actor_id)
        return ctx
    end

    function world:_replayPhase(phase, status, detail)
        self.recovery.phases = self.recovery.phases or {}
        self.recovery.phases[phase] = status
        self.recovery.mode = phase
        self:_recordRuntimeEvent('replay_phase_changed', {
            phase = phase,
            status = status,
            detail = detail,
        })
    end

    function world:_artifact(kind, scope, detail)
        local nextId = self.artifacts.nextId or 1
        self.artifacts.nextId = nextId + 1
        local artifact = {
            artifactId = string.format('artifact:%s:%s:%s', tostring(kind), tostring(self.runtimeIdentity.runtimeInstanceId), tostring(nextId)),
            kind = tostring(kind),
            at = self:_now(),
            scope = deepcopy(scope or self.runtimeIdentity),
            detail = deepcopy(detail or {}),
            lineage = {
                checkpointId = self.recovery and self.recovery.checkpointId or nil,
                policyId = (self:_policy().policyId or nil),
                policyVersion = (self:_policy().policyVersion or nil),
                runtimeEpoch = self.runtimeIdentity.runtimeEpoch,
                ownerEpoch = self.runtimeIdentity.ownerEpoch,
            },
        }
        self.artifacts.entries[#self.artifacts.entries + 1] = artifact
        self.artifacts.byKind[kind] = self.artifacts.byKind[kind] or {}
        self.artifacts.byKind[kind][#self.artifacts.byKind[kind] + 1] = artifact
        return artifact
    end

    function world:_ownershipScope(mapId, extra)
        return RuntimeKernel.ownershipScope(self.runtimeIdentity, mapId, extra)
    end

    function world:_activePlayerCheckpoint()
        local players = {}
        for playerId, player in pairs(self.players or {}) do
            players[playerId] = self:publishPlayerSnapshot(player)
        end
        return players
    end

    function world:_checkpointValidityHealth(snapshot)
        local score = 100
        local checkpoint = snapshot and snapshot.checkpoint or {}
        local phases = snapshot and snapshot.recovery and snapshot.recovery.phases or {}
        if checkpoint.commit_state and checkpoint.commit_state.finalized ~= true then score = score - 50 end
        if phases and phases.invariant_verification == 'failed' then score = score - 40 end
        if snapshot and snapshot.materialized_digest == nil then score = score - 20 end
        if snapshot and snapshot.activePlayers and next(snapshot.activePlayers) ~= nil then score = score - 5 end
        return math.max(0, score)
    end

    function world:_updateSavePlan(reason)
        local plan = RuntimeKernel.computeSavePlan({
            policy = self:_policySection('savePolicy'),
            pressure = self.pressure,
            containment = self.containment,
            pendingCount = self._pendingWorldSaveCount,
            mutationDensity = self._pendingWorldSaveCount,
        })
        plan.reason = tostring(reason or self._pendingWorldSaveReason or 'unspecified')
        self.savePlan = plan
        return plan
    end

    function world:_refreshRecoveryVerification()
        local summary = RecoveryKernel.verificationSummary(self.recovery, self.savePlan)
        self.recovery.confidence = summary.confidence
        self.recovery.verificationSummary = summary
        return summary
    end

    function world:_truthContext(base)
        local ctx = deepcopy(base or {})
        local policy = self:_policy()
        ctx.policyId = ctx.policyId or policy.policyId
        ctx.policyVersion = ctx.policyVersion or policy.policyVersion
        ctx.runtimeScope = ctx.runtimeScope or self:_ownershipScope(ctx.mapId, {
            bossId = ctx.bossId,
            dropId = ctx.dropId,
            spawnId = ctx.spawnId,
            questId = ctx.questId,
        })
        ctx.ownerScope = ctx.ownerScope or deepcopy(ctx.runtimeScope)
        ctx.lineageReference = ctx.lineageReference or self:_lineageReference(ctx.truthType or 'runtime', ctx.playerId or ctx.itemId or ctx.bossId or ctx.dropId or ctx.mapId or ctx.questId or ctx.npcId)
        return ctx
    end

    function world:_recordTruthEvent(eventType, payload, context)
        local ctx = self:_truthContext(context)
        local enriched = EventTruth.enrich(eventType, payload, ctx)
        if ctx.forceRecord == true then enriched.__forceRecord = true end
        return self:_recordRuntimeEvent(eventType, enriched)
    end

    function world:getEventHistory(filter)
        return EventTruth.query(self.journal:snapshot(), filter)
    end

    function world:_dropClaimKey(recordOrDropId)
        local record = type(recordOrDropId) == 'table' and recordOrDropId or nil
        local dropId = record and record.dropId or recordOrDropId
        return string.format('%s:%s:%s:%s',
            tostring((record and record.worldId) or self.runtimeIdentity.worldId),
            tostring((record and record.channelId) or self.runtimeIdentity.channelId),
            tostring((record and record.runtimeInstanceId) or self.runtimeIdentity.runtimeInstanceId),
            tostring(dropId))
    end

    function world:_bossRewardClaimKey(playerId, encounter)
        local claimScope = encounter and encounter.uniqueness == 'world_unique' and {
            self.runtimeIdentity.worldId, 'world', 'world',
        } or {
            self.runtimeIdentity.worldId,
            self.runtimeIdentity.channelId,
            self.runtimeIdentity.runtimeInstanceId,
        }
        return string.format('boss_claim:%s:%s:%s:%s:%s',
            tostring(claimScope[1]),
            tostring(claimScope[2]),
            tostring(claimScope[3]),
            tostring(playerId),
            tostring(encounter and encounter.bossId))
    end

    function world:_recordGovernanceDecision(reason, decision, detail)
        local entry = {
            at = self:_now(),
            reason = tostring(reason or 'unspecified'),
            decision = tostring(decision or 'observe'),
            detail = deepcopy(detail or {}),
            state = self.governance.state,
        }
        local decisions = self.governance.decisions or {}
        decisions[#decisions + 1] = entry
        while #decisions > 64 do table.remove(decisions, 1) end
        self.governance.decisions = decisions
        self:_artifact('governance_decision', self:_ownershipScope(detail and detail.mapId, detail and detail.scope), entry)
        self:_recordRuntimeEvent('governance_decision', entry)
        return entry
    end

    function world:_setGovernanceState(nextState, reason, outputs)
        nextState = tostring(nextState or 'normal')
        if self.governance.state == nextState then return false end
        local previous = self.governance.state
        self.governance.previousState = previous
        self.governance.state = nextState
        self.governance.reason = tostring(reason or 'unspecified')
        self.governance.changedAt = self:_now()
        self.governance.outputs = deepcopy(outputs or {})
        local history = self.governance.history or {}
        history[#history + 1] = {
            at = self.governance.changedAt,
            from = previous,
            to = nextState,
            reason = self.governance.reason,
            outputs = deepcopy(outputs or {}),
        }
        while #history > 64 do table.remove(history, 1) end
        self.governance.history = history
        self:_artifact('governance_transition', self:_ownershipScope(), history[#history])
        self:_recordRuntimeEvent('governance_transition', history[#history])
        return true
    end

    function world:_recordRepairAction(kind, scope, cause, outcome, detail)
        local retries = self.repairs.retries or {}
        retries[kind] = (retries[kind] or 0) + 1
        self.repairs.retries = retries
        self.repairs.state = tostring(kind or 'repairing')
        self.repairs.quarantines = self.repairs.quarantines or {}
        local action = {
            at = self:_now(),
            kind = tostring(kind or 'repair'),
            scope = deepcopy(scope or self:_ownershipScope()),
            cause = tostring(cause or 'unknown'),
            outcome = tostring(outcome or 'pending'),
            retry = retries[kind],
            detail = deepcopy(detail or {}),
        }
        local actions = self.repairs.actions or {}
        actions[#actions + 1] = action
        while #actions > 64 do table.remove(actions, 1) end
        self.repairs.actions = actions
        local timeline = self.repairs.timeline or {}
        timeline[#timeline + 1] = action
        while #timeline > 128 do table.remove(timeline, 1) end
        self.repairs.timeline = timeline
        local maxRetries = tonumber(self:_policySection('repair').maxAutomaticRetries) or 3
        if action.outcome == 'quarantine' or action.outcome == 'entered_replay_only' then
            self.repairs.quarantines[#self.repairs.quarantines + 1] = {
                at = action.at,
                kind = action.kind,
                scope = deepcopy(action.scope),
                cause = action.cause,
                outcome = action.outcome,
                detail = deepcopy(action.detail),
            }
        end
        if retries[kind] >= maxRetries then
            self.containment.replayOnly = self.containment.replayOnly or action.kind == 'replay_divergence'
            self.containment.migrationBlocked = true
            self:_setGovernanceState('repair', 'repair_retry_threshold', { kind = action.kind, retries = retries[kind] })
            action.operatorEscalation = true
        end
        self:_artifact('repair_action', action.scope, action)
        self:_recordRuntimeEvent('repair_action', action)
        return action
    end

    function world:_materializedDigest()
        local status = {
            drops = self.dropSystem:snapshot(),
            boss = self.bossSystem:snapshot(),
            players = self:_activePlayerCheckpoint(),
            policy = self.policyBundle:snapshot(),
            runtimeIdentity = self.runtimeIdentity,
            containment = self.containment,
            escalation = {
                level = self.escalation.level,
                severity = self.escalation.severity,
            },
        }
        return stringHash(stableSerialize(status))
    end

    function world:_recordOwnershipConflict(reason, detail, options)
        local opts = options or {}
        local now = self:_now()
        local window = self._ownershipConflictWindow or {}
        window[#window + 1] = now
        while #window > 0 and (now - window[1]) > 120 do table.remove(window, 1) end
        self._ownershipConflictWindow = window
        self.pressure.ownershipConflictPressure = #window
        if opts.recordEvent ~= false then
            self:_recordRuntimeEvent('ownership_conflict', { reason = reason, detail = detail, count = #window })
        end
        self:_artifact('ownership_conflict_report', self:_ownershipScope(detail and detail.mapId, detail and detail.scope), {
            reason = reason,
            detail = detail,
            count = #window,
        })
    end

    function world:_recordFarmSignal(player, targetId, options)
        local opts = options or {}
        local now = self:_now()
        local signals = self._recentFarmSignals or {}
        signals[#signals + 1] = { at = now, playerId = player and player.id or nil, targetId = tostring(targetId or 'unknown') }
        while #signals > 0 and (now - (signals[1].at or now)) > 120 do table.remove(signals, 1) end
        self._recentFarmSignals = signals
        self.pressure.farmRepetitionPressure = #signals
        if opts.recordArtifact ~= false then
            self:_artifact('runtime_pressure_snapshot', self:_ownershipScope(), {
                pressure = { farmRepetitionPressure = #signals },
                source = 'farm_signal',
                targetId = tostring(targetId or 'unknown'),
            })
        end
    end

    function world:_emitOpsTelemetry(kind, payload)
        self.telemetryPipeline:emit(kind, payload)
        self.eventBatcher:push({ event = kind, payload = payload, at = self:_now() })
        self.metricsAggregator:add('telemetry_events_total', 1)
        self.metricsAggregator:recordSection('last_telemetry_event', { kind = kind, payload = deepcopy(payload) })
    end

    function world:_runStabilityGuards()
        local memoryKb = collectgarbage and collectgarbage('count') or 0
        local memory = self.memoryGuard:inspect(memoryKb)
        if memory.action == 'collect' and collectgarbage then
            collectgarbage('step', 200)
        elseif memory.action == 'shed_load' then
            self:_escalate('memory_pressure', { memoryKb = memoryKb, limitKb = memory.hardLimitKb })
            self.containment.safeMode = true
        end

        local duplication = self.duplicationGuard:inspect(self)
        if not duplication.ok then
            self.exploitMonitor:flag('system', 'duplication_risk')
            self.pressure.duplicateRisk = math.max(self.pressure.duplicateRisk or 0, #duplication.issues)
            self.pressure.duplicateRiskPressure = self.pressure.duplicateRisk
        end

        local inflation = self.inflationGuard:inspect(self.economySystem, self.auctionHouse)
        if not inflation.ok then
            self.exploitMonitor:flag('economy', 'inflation_risk')
        end

        self:_emitOpsTelemetry('stability_tick', {
            memory = memory.state,
            duplicateIssues = #duplication.issues,
            inflationOk = inflation.ok,
        })
        return {
            memory = memory,
            duplication = duplication,
            inflation = inflation,
        }
    end

    function world:appendLedgerEvent(event)
        if not self.journal or type(self.journal.appendLedgerEvent) ~= 'function' then return nil end
        local enriched = self:_ledgerContext(event)
        local appended, duplicate = self.journal:appendLedgerEvent(enriched)
        if duplicate then
            self.pressure.duplicateRisk = math.max(0, (self.pressure.duplicateRisk or 0) + 1)
            self.pressure.duplicateRiskPressure = self.pressure.duplicateRisk
            self.duplicationGuard:recordClaim(enriched.idempotency_key or enriched.lineage_reference or enriched.source_event_id)
            self.exploitMonitor:flag(enriched.actor_id or enriched.player_id or 'system', 'ledger_duplicate')
        else
            self.pressure.rewardInflation = math.max(0, (self.pressure.rewardInflation or 0) + 1)
            self.pressure.rewardInflationPressure = self.pressure.rewardInflation
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
        local forceRecord = eventPayload.__forceRecord == true
        eventPayload.__forceRecord = nil
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
        if (self._restoringWorldState or self._replayingRecovery) and not forceRecord then
            return { event = eventName, payload = deepcopy(eventPayload) }
        end
        self.journal:append(eventName, eventPayload)
    end

    function world:_evaluatePolicyBundle(reason)
        local evaluation = self.policyBundle:evaluate({
            at = self:_now(),
            reason = tostring(reason or 'runtime_observe'),
            governanceState = self.governance.state,
            containment = deepcopy(self.containment),
            pressure = deepcopy(self.pressure),
            stability = math.max(0, 100 - ((self._savingFailures or 0) * 15) - ((self.escalation.level or 0) * 10)),
            replayReliability = self.recovery and self.recovery.divergence and 25 or 100,
            rewardIntegrity = math.max(0, 100 - ((self.pressure.duplicateRiskPressure or 0) * 20)),
            exploitResistance = math.max(0, 100 - ((self.pressure.rewardInflationPressure or 0) * 5) - ((self.pressure.duplicateRiskPressure or 0) * 10)),
            savePressure = math.max(0, 100 - math.min(100, (self._pendingWorldSaveCount or 0) * 2)),
            densityBalance = math.max(0, 100 - math.floor((self.pressure.entityDensityPressure or 0) * 10)),
            migrationCorrectness = self.containment.migrationBlocked and 50 or 100,
        })
        self:_artifact('policy_evaluation', self:_ownershipScope(), evaluation)
        return evaluation
    end

    function world:replacePolicyBundle(nextPolicy, metadata)
        local ok, err = self.policyBundle:replace(nextPolicy, {
            adoptedAt = self:_now(),
            adoptionSource = metadata and metadata.adoptionSource,
            adoptionReason = metadata and metadata.adoptionReason or (nextPolicy and nextPolicy.adoptionReason),
            adoptionWindow = metadata and metadata.adoptionWindow,
            mutationOf = metadata and metadata.mutationOf,
        })
        if not ok then return false, err end
        local snapshot = self.policyBundle:snapshot()
        self.policyHistory = self.policyBundle:historySnapshot()
        self._lastPolicyId = tostring(snapshot.policyId) .. '@' .. tostring(snapshot.policyVersion)
        self:_recordRuntimeEvent('policy_bundle_replaced', { policy = snapshot, policyVersion = self._lastPolicyId, metadata = metadata })
        self:_artifact('policy_bundle_version', self:_ownershipScope(), {
            policy = snapshot,
            previousPolicyId = snapshot.rollback and snapshot.rollback.previousPolicyId or nil,
            previousPolicyVersion = snapshot.rollback and snapshot.rollback.previousPolicyVersion or nil,
        })
        self:_evaluatePolicyBundle('policy_replace')
        self:_recomputePressure()
        return true
    end

    function world:rollbackPolicyBundle(reason)
        local ok, result = self.policyBundle:rollback(reason)
        if not ok then return false, result end
        self.policyHistory = self.policyBundle:historySnapshot()
        self._lastPolicyId = tostring(result.policyId) .. '@' .. tostring(result.policyVersion)
        self:_recordRuntimeEvent('policy_bundle_rollback', { policy = result, reason = tostring(reason or 'runtime_rollback') })
        self:_artifact('policy_bundle_version', self:_ownershipScope(), {
            policy = result,
            rollback = true,
            reason = tostring(reason or 'runtime_rollback'),
        })
        self:_evaluatePolicyBundle('policy_rollback')
        self:_recomputePressure()
        return true, result
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
        if level >= (tonumber(containment.persistenceQuarantineOnEscalation) or 99) then
            self.containment.persistenceQuarantine = true
            self.containment.saveQuarantine = true
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
        self.escalation.severity = self:_severityName(nextLevel)
        local history = self.escalation.history or {}
        history[#history + 1] = {
            at = self.escalation.at,
            level = nextLevel,
            reason = self.escalation.reason,
            severity = self.escalation.severity,
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
            severity = self.escalation.severity,
            reason = reason,
            detail = detail,
        })
        self:_applyContainmentFromEscalation(nextLevel, reason)
    end

    function world:_recomputePressure()
        if self._recomputingPressure then return end
        self._recomputingPressure = true
        local activePlayers = self:getActivePlayerCount()
        local mapCount = math.max(1, countTableKeys(self.worldConfig.maps or {}))
        local density = activePlayers / mapCount
        local backlog = tonumber(self._pendingWorldSaveCount) or 0
        local instability = tonumber(self._savingFailures or 0)

        self.pressure.density = density
        self.pressure.backlog = backlog
        self.pressure.savePressure = backlog
        self.pressure.instability = instability
        self.pressure.entityDensity = density
        self.pressure.entityDensityPressure = density
        self.pressure.saveBacklog = backlog
        self.pressure.replayPressure = tonumber(self.recovery and self.recovery.divergence and 2 or 0)
        self.pressure.instabilityPressure = instability

        local now = self:_now()
        local window = self._rewardMutationCountWindow or {}
        window[#window + 1] = now
        while #window > 0 and (now - window[1]) > 60 do table.remove(window, 1) end
        self._rewardMutationCountWindow = window
        self.pressure.rewardInflation = #window
        self.pressure.rewardInflationPressure = #window

        local recent = self.journal:snapshot(math.max(0, self.journal.nextSeq - 25))
        local diversity = {}
        for _, entry in ipairs(recent) do diversity[tostring(entry.event)] = true end
        local kinds = countTableKeys(diversity)
        self.pressure.lowDiversity = kinds <= 2 and (3 - kinds) or 0
        self.pressure.repetitiveFarming = self.pressure.lowDiversity

        local replayPressure = self.recovery and self.recovery.divergence and 2 or 0
        self.pressure.replay = replayPressure
        self.pressure.replayPressure = replayPressure
        self.pressure.ownershipConflictPressure = #(self._ownershipConflictWindow or {})
        self.pressure.duplicateRiskPressure = tonumber(self.pressure.duplicateRisk or 0)
        self.pressure.farmRepetitionPressure = #(self._recentFarmSignals or {})

        if self.metrics then
            self.metrics:gauge('pressure.density', density)
            self.metrics:gauge('pressure.backlog', backlog)
            self.metrics:gauge('pressure.reward_inflation', self.pressure.rewardInflation)
            self.metrics:gauge('pressure.replay', self.pressure.replay)
            self.metrics:gauge('pressure.low_diversity', self.pressure.lowDiversity)
            self.metrics:gauge('pressure.instability', instability)
            self.metrics:gauge('pressure.duplicate_risk', self.pressure.duplicateRisk or 0)
            self.metrics:gauge('pressure.ownership_conflict', self.pressure.ownershipConflictPressure or 0)
            self.metrics:gauge('pressure.farm_repetition', self.pressure.farmRepetitionPressure or 0)
            self.metrics:gauge('pressure.entity_density', self.pressure.entityDensityPressure or 0)
            self.metrics:gauge('pressure.repetitive_farming', self.pressure.repetitiveFarming or 0)
        end

        if backlog >= self:_pressureThreshold('saveBacklog') then
            self:_recordTruthEvent('pressure_threshold_breached', {
                metric = 'saveBacklog',
                value = backlog,
                threshold = self:_pressureThreshold('saveBacklog'),
            }, { truthType = 'pressure.threshold_breach' })
            self:_escalate('save_backlog_pressure', { backlog = backlog })
        end
        if self.pressure.lowDiversity >= self:_pressureThreshold('lowDiversity') then
            self:_recordTruthEvent('failure_plateau_exploration', { lowDiversity = self.pressure.lowDiversity }, { truthType = 'failure.plateau_exploration' })
        end
        if instability >= self:_pressureThreshold('instability') then
            self:_recordTruthEvent('failure_collapse_diversity_repair', { instability = instability }, { truthType = 'failure.collapse_diversity_repair' })
            self:_escalate('world_instability_pressure', { instability = instability })
        end
        if (self.pressure.ownershipConflictPressure or 0) >= self:_pressureThreshold('ownershipConflict') then
            self:_recordTruthEvent('pressure_threshold_breached', {
                metric = 'ownershipConflict',
                value = self.pressure.ownershipConflictPressure,
                threshold = self:_pressureThreshold('ownershipConflict'),
            }, { truthType = 'pressure.threshold_breach' })
            self:_escalate('ownership_conflict_pressure', { count = self.pressure.ownershipConflictPressure })
        end
        if (self.pressure.duplicateRiskPressure or 0) >= self:_pressureThreshold('duplicateRisk') then
            self:_recordTruthEvent('pressure_threshold_breached', {
                metric = 'duplicateRisk',
                value = self.pressure.duplicateRiskPressure,
                threshold = self:_pressureThreshold('duplicateRisk'),
            }, { truthType = 'pressure.threshold_breach' })
            self:_escalate('duplicate_risk_pressure', { count = self.pressure.duplicateRiskPressure })
        end
        if (self.pressure.farmRepetitionPressure or 0) >= self:_pressureThreshold('farmRepetition') then
            self:_recordTruthEvent('failure_plateau_exploration', { farmRepetition = self.pressure.farmRepetitionPressure }, { truthType = 'failure.plateau_exploration' })
        end

        self:_updateSavePlan('pressure_recompute')
        local governanceState, governanceReason = RuntimeKernel.determineGovernanceState(self:_policy(), self.containment, self.pressure, instability)
        if governanceState == 'replay-only' then
            self:_setGovernanceState('replay-only', governanceReason, { replayPressure = self.pressure.replayPressure })
        elseif governanceState == 'degraded-safe' then
            self:_setGovernanceState('degraded-safe', governanceReason, { instability = instability })
        elseif governanceState == 'quarantine' then
            self:_setGovernanceState('quarantine', governanceReason, { duplicateRisk = self.pressure.duplicateRiskPressure })
        elseif governanceState == 'adaptive' then
            self:_setGovernanceState('adaptive', governanceReason, { ownershipConflict = self.pressure.ownershipConflictPressure })
        elseif governanceState == 'exploration' then
            self:_setGovernanceState('exploration', governanceReason, { lowDiversity = self.pressure.lowDiversity, farmRepetition = self.pressure.farmRepetitionPressure })
        elseif governanceState == 'repair' then
            self:_setGovernanceState('repair', governanceReason, { savePlan = deepcopy(self.savePlan) })
        else
            self:_setGovernanceState('normal', governanceReason, { pressure = deepcopy(self.pressure), savePlan = deepcopy(self.savePlan) })
        end
        self:_evaluatePolicyBundle('pressure_recompute')
        self:_refreshRecoveryVerification()
        self._recomputingPressure = false
    end

    function world:getRuntimeStatus()
        return {
            runtimeIdentity = deepcopy(self.runtimeIdentity),
            policy = self.policyBundle:snapshot(),
            policyHistory = deepcopy(self.policyHistory),
            policyVersion = self._lastPolicyId or (tostring((self:_policy().policyId or 'unknown')) .. '@' .. tostring((self:_policy().policyVersion or 'unknown'))),
            pressure = deepcopy(self.pressure),
            containment = deepcopy(self.containment),
            escalation = deepcopy(self.escalation),
            governance = deepcopy(self.governance),
            repairs = deepcopy(self.repairs),
            recovery = deepcopy(self.recovery),
            savePlan = deepcopy(self.savePlan),
            eventHistory = {
                total = math.max(0, (self.journal.nextSeq or 1) - 1),
                recent = tailEntries(self.journal:snapshot(), 32),
            },
            pendingSave = {
                count = self._pendingWorldSaveCount,
                reason = self._pendingWorldSaveReason,
                reasons = deepcopy(self._pendingWorldSaveReasons),
            },
            ownership = {
                worldId = self.runtimeIdentity.worldId,
                channelId = self.runtimeIdentity.channelId,
                runtimeInstanceId = self.runtimeIdentity.runtimeInstanceId,
                ownerId = self.runtimeIdentity.ownerId,
                runtimeEpoch = self.runtimeIdentity.runtimeEpoch,
                coordinatorEpoch = self.runtimeIdentity.coordinatorEpoch,
            },
            topology = deepcopy(self.topology),
            artifacts = {
                total = #(self.artifacts.entries or {}),
                byKind = deepcopy(self.artifacts.byKind),
            },
            watermark = {
                journalSeq = self.journal.nextSeq - 1,
                ledgerEventId = self.journal.nextLedgerEventId - 1,
            },
            health = {
                replayStatus = self.recovery.mode,
                replayWatermark = deepcopy(self.recovery.watermark),
                lastReplayDurationMs = self.recovery.lastReplayDurationMs or 0,
                divergenceCount = self.recovery.divergenceCount or 0,
                checkpointLineage = deepcopy(self.recovery.checkpointLineage),
                recoverySource = deepcopy(self.recovery.recoverySource),
                checkpointHealthScore = self.savePlan and self.savePlan.healthScore or 100,
                replayConfidence = self.recovery.confidence or 100,
                verificationSummary = deepcopy(self.recovery.verificationSummary),
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
        player.runtimeScope.ownerId = self.runtimeIdentity.ownerId
        player.runtimeScope.runtimeEpoch = self.runtimeIdentity.runtimeEpoch
        player.runtimeScope.ownerEpoch = self.runtimeIdentity.ownerEpoch
        player.runtimeScope.coordinatorEpoch = self.runtimeIdentity.coordinatorEpoch
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
        local savePlan = self:_updateSavePlan('snapshot')
        local verificationSummary = self:_refreshRecoveryVerification()
        local checkpointId = string.format('%s:%s:%s:%s', tostring(self.runtimeIdentity.worldId), tostring(self.runtimeIdentity.channelId), tostring(self.runtimeIdentity.runtimeInstanceId), tostring(self:_now()))
        local snapshot = {
            version = 2,
            savedAt = self:_now(),
            checkpoint = {
                checkpoint_id = checkpointId,
                schema_version = 2,
                journal_watermark = self.journal.nextSeq - 1,
                ledger_watermark = self.journal.nextLedgerEventId - 1,
                owner_epoch = self.runtimeIdentity.ownerEpoch,
                runtime_epoch = self.runtimeIdentity.runtimeEpoch,
                coordinator_epoch = self.runtimeIdentity.coordinatorEpoch,
                timestamp = self:_now(),
                replay_base_revision = self.worldRepository and self.worldRepository:lastLoadedRevision() or 0,
                runtime_scope = {
                    world_id = self.runtimeIdentity.worldId,
                    channel_id = self.runtimeIdentity.channelId,
                    runtime_instance_id = self.runtimeIdentity.runtimeInstanceId,
                    owner_id = self.runtimeIdentity.ownerId,
                },
                policy = self.policyBundle:snapshot(),
                policy_history = self.policyBundle:historySnapshot(),
                truth_source = 'append_only_journal',
                checkpoint_class = savePlan.checkpointClass,
                flush_urgency = savePlan.urgency,
                commit_state = {
                    staged = true,
                    finalized = true,
                    repository_loaded_revision = self.worldRepository and self.worldRepository:lastLoadedRevision() or 0,
                },
            },
            boss = self.bossSystem:snapshot(),
            drops = limitDropSnapshot(self.dropSystem:snapshot(), persistedDropsPerMap),
            activePlayers = self:_activePlayerCheckpoint(),
            journal = journalSnapshot,
            recovery = deepcopy(self.recovery),
            pressure = deepcopy(self.pressure),
            escalation = deepcopy(self.escalation),
            governance = deepcopy(self.governance),
            repairs = deepcopy(self.repairs),
            topology = deepcopy(self.topology),
            policyHistory = self.policyBundle:historySnapshot(),
            savePlan = deepcopy(savePlan),
            artifacts = tailEntries(self.artifacts.entries, tonumber(runtimeCfg.persistedArtifactEntries) or 256),
            materialized_digest = self:_materializedDigest(),
            health = {
                replay_status = self.recovery.mode,
                replay_watermark = deepcopy(self.recovery.watermark),
                last_replay_duration_ms = self.recovery.lastReplayDurationMs or 0,
                divergence_count = self.recovery.divergenceCount or 0,
                checkpoint_lineage = deepcopy(self.recovery.checkpointLineage),
                checkpoint_validity_score = 100,
                replay_confidence = verificationSummary.confidence,
                verification_summary = deepcopy(verificationSummary),
            },
        }
        snapshot.health.checkpoint_validity_score = self:_checkpointValidityHealth(snapshot)
        return snapshot
    end

    function world:saveWorldState(reason)
        if not self.worldRepository or self._restoringWorldState or self._savingWorldState then return true end
        if self.containment.saveQuarantine then return false, 'save_quarantined' end
        self._savingWorldState = true
        local now = self:_now()
        local startedAt = os.clock()
        local savePlan = self:_updateSavePlan(reason)
        self.recovery.checkpointLineage = self.recovery.checkpointLineage or {}
        local predictedCheckpointId = string.format('%s:%s:%s:%s', tostring(self.runtimeIdentity.worldId), tostring(self.runtimeIdentity.channelId), tostring(self.runtimeIdentity.runtimeInstanceId), tostring(now))
        self.recovery.checkpointLineage[#self.recovery.checkpointLineage + 1] = {
            checkpointId = predictedCheckpointId,
            revision = self.worldRepository and self.worldRepository:lastLoadedRevision() or 0,
            reason = tostring(reason or 'unspecified'),
            at = now,
            checkpointClass = savePlan.checkpointClass,
            urgency = savePlan.urgency,
        }
        while #self.recovery.checkpointLineage > 32 do table.remove(self.recovery.checkpointLineage, 1) end
        local snapshot = self:snapshotWorldState()
        self:_artifact('checkpoint_metadata', self:_ownershipScope(), {
            phase = 'staged',
            reason = reason,
            checkpoint = deepcopy(snapshot.checkpoint),
            savePlan = deepcopy(savePlan),
        })
        self:_recordRuntimeEvent('world_checkpoint_stage', {
            reason = reason,
            checkpoint = snapshot.checkpoint,
            policyVersion = self._lastPolicyId,
            savePlan = savePlan,
        })
        local ok, err = self.worldRepository:save(snapshot)
        self._savingWorldState = false
        local elapsedMs = math.floor((os.clock() - startedAt) * 1000)
        if ok then
            self:_artifact('checkpoint_metadata', self:_ownershipScope(), {
                phase = 'finalized',
                reason = reason,
                checkpoint = deepcopy(snapshot.checkpoint),
                duration_ms = elapsedMs,
                health_score = snapshot.health and snapshot.health.checkpoint_validity_score or nil,
            })
            self:_recordRuntimeEvent('world_checkpoint_commit', {
                reason = reason,
                checkpoint = snapshot.checkpoint,
                duration_ms = elapsedMs,
            })
            self._lastWorldSaveAt = now
            self._pendingWorldSaveReason = nil
            self._pendingWorldSaveReasons = {}
            self._pendingWorldSaveCount = 0
            self._worldStateDirty = false
            self._savingFailures = 0
            self.recovery.checkpointId = snapshot.checkpoint and snapshot.checkpoint.checkpoint_id or nil
            self.recovery.checkpointRevision = self.worldRepository:lastSavedRevision() or self.recovery.checkpointRevision
            self.recovery.recoverySource = {
                source = 'checkpoint_commit',
                checkpointId = self.recovery.checkpointId,
                revision = self.recovery.checkpointRevision,
                reportArtifactId = nil,
            }
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
            self:_recordRuntimeEvent('world_checkpoint_finalize', {
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
            self:appendLedgerEvent({
                event_type = 'repair_compensation',
                actor_id = self.runtimeIdentity.ownerId,
                source_system = 'world_repository',
                correlation_id = snapshot.checkpoint and snapshot.checkpoint.checkpoint_id,
                map_id = reason,
                rollback_of = snapshot.checkpoint and snapshot.checkpoint.checkpoint_id,
                metadata = { reason = reason, error = tostring(err), action = 'world_save_rollback' },
            })
            self:_recordRuntimeEvent('world_checkpoint_save_failed', { reason = reason, error = tostring(err) })
            self:_recordRepairAction('world_save_failed', self:_ownershipScope(), tostring(reason), 'retry_pending', {
                error = tostring(err),
                failures = self._savingFailures,
                checkpointClass = savePlan.checkpointClass,
            })
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
        self:_artifact('save_backlog_snapshot', self:_ownershipScope(), {
            reason = tostring(reason or 'unspecified'),
            pendingCount = self._pendingWorldSaveCount,
            pendingReasons = tailEntries(reasons, 16),
        })
        self:_updateSavePlan(reason)
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
        local savePolicy = self:_policySection('savePolicy')
        local debounceSec = math.max(0, tonumber(savePolicy.debounceSec) or 0)
        local now = self:_now()
        local savePlan = self:_updateSavePlan(reason)
        if self.containment.persistenceQuarantine then return false, 'save_quarantined' end
        if savePlan.urgency == 'blocked' then
            return false, 'save_quarantined'
        end
        if savePlan.urgency == 'immediate' and savePlan.checkpointClass == 'replay_anchor' then
            return self:saveWorldState(reason or self._pendingWorldSaveReason)
        end
        if (self.pressure.ownershipConflictPressure or 0) > 0 and self:_policySection('savePolicy').immediateWhenOwnershipConflict == true then
            return self:saveWorldState(reason or self._pendingWorldSaveReason)
        end
        if savePlan.urgency == 'immediate' and savePlan.checkpointClass == 'integrity_checkpoint' then
            self:_recordGovernanceDecision('save_backlog', 'flush_immediately', { pending = self._pendingWorldSaveCount })
            return self:saveWorldState(reason or self._pendingWorldSaveReason)
        end
        if savePlan.checkpointClass == 'integrity_checkpoint' and (self._pendingWorldSaveCount or 0) >= (tonumber(savePolicy.mutationDensityThreshold) or math.huge) then
            self:_artifact('checkpoint_metadata', self:_ownershipScope(), {
                class = 'integrity_checkpoint',
                reason = reason or self._pendingWorldSaveReason,
                pending = self._pendingWorldSaveCount,
            })
            return self:saveWorldState(reason or self._pendingWorldSaveReason)
        end
        if debounceSec > 0 and self._lastWorldSaveAt and (now - self._lastWorldSaveAt) < debounceSec then
            if self.metrics then self.metrics:increment('world_state.save_debounced', 1, { reason = tostring(reason or self._pendingWorldSaveReason) }) end
            return true, 'debounced'
        end
        return self:saveWorldState(reason or self._pendingWorldSaveReason)
    end

    function world:_rebuildRecoveryInvariants()
        self.recoveryInvariants = { claimedDrops = {}, bossRewardClaims = {}, itemInstanceIds = {}, ownershipScopes = {} }
        local ledger = self.journal:ledgerSnapshot()
        local activeDropIds = {}
        for _, entry in ipairs(ledger) do
            if entry.event_type == 'boss_reward_claim' and entry.idempotency_key then
                if self.recoveryInvariants.bossRewardClaims[entry.idempotency_key] then
                    return false, 'duplicate_boss_reward_claim'
                end
                self.recoveryInvariants.bossRewardClaims[entry.idempotency_key] = true
            end
            if entry.event_type == 'item_create' then
                local iid = entry.item_instance_id
                if iid and self.recoveryInvariants.itemInstanceIds[iid] then
                    return false, 'duplicate_item_instance'
                end
                if iid then self.recoveryInvariants.itemInstanceIds[iid] = true end
            end
            if entry.event_type == 'mesos_spend' or entry.event_type == 'mesos_grant' then
                local post = entry.post_state or {}
                local mesos = tonumber(post.mesos)
                if mesos and mesos < 0 then
                    return false, 'negative_mesos_after_replay'
                end
            end
            if entry.event_type == 'drop_claim' and entry.source_event_id then
                local dk = string.format('%s:%s:%s:%s',
                    tostring(entry.world_id or self.runtimeIdentity.worldId),
                    tostring(entry.channel_id or self.runtimeIdentity.channelId),
                    tostring(entry.runtime_instance_id or self.runtimeIdentity.runtimeInstanceId),
                    tostring(entry.source_event_id))
                if self.recoveryInvariants.claimedDrops[dk] then
                    return false, 'duplicate_drop_claim'
                end
                self.recoveryInvariants.claimedDrops[dk] = true
            end
            if entry.owner_id and entry.runtime_epoch and entry.coordinator_epoch then
                local ownershipKey = table.concat({
                    tostring(entry.world_id or self.runtimeIdentity.worldId),
                    tostring(entry.channel_id or self.runtimeIdentity.channelId),
                    tostring(entry.runtime_instance_id or self.runtimeIdentity.runtimeInstanceId),
                    tostring(entry.owner_id),
                }, ':')
                local existing = self.recoveryInvariants.ownershipScopes[ownershipKey]
                if existing and tonumber(existing.runtime_epoch) ~= tonumber(entry.runtime_epoch) then
                    return false, 'ownership_epoch_conflict'
                end
                self.recoveryInvariants.ownershipScopes[ownershipKey] = {
                    runtime_epoch = tonumber(entry.runtime_epoch),
                    coordinator_epoch = tonumber(entry.coordinator_epoch),
                }
            end
        end
        for _, drop in ipairs(self.dropSystem:listAllDrops()) do
            local claimKey = self:_dropClaimKey(drop)
            if activeDropIds[claimKey] then return false, 'duplicate_active_drop_scope' end
            activeDropIds[claimKey] = true
            if drop.runtimeInstanceId ~= nil and tostring(drop.runtimeInstanceId) == '' then
                return false, 'invalid_drop_runtime_scope'
            end
        end
        for _, player in pairs(self.players or {}) do
            if player.runtimeScope then
                if player.currentMapId and player.runtimeScope.mapId and player.runtimeScope.mapId ~= player.currentMapId then
                    return false, 'player_scope_map_mismatch'
                end
                if player.runtimeScope.worldId and tostring(player.runtimeScope.worldId) ~= tostring(self.runtimeIdentity.worldId) then
                    return false, 'player_scope_world_mismatch'
                end
                if player.runtimeScope.channelId and tostring(player.runtimeScope.channelId) ~= tostring(self.runtimeIdentity.channelId) then
                    return false, 'player_scope_channel_mismatch'
                end
                if player.runtimeScope.runtimeInstanceId and tostring(player.runtimeScope.runtimeInstanceId) ~= tostring(self.runtimeIdentity.runtimeInstanceId) then
                    return false, 'player_scope_runtime_mismatch'
                end
            end
            local itemOk, itemErr = self.itemSystem:validatePlayerItemTopology(player)
            if not itemOk then return false, itemErr end
        end
        local policy = self:_policy()
        if type(policy.lineage) ~= 'table' or type(policy.activation) ~= 'table' then
            return false, 'policy_bundle_incomplete'
        end
        local rewardArtifacts = self.artifacts and self.artifacts.byKind and self.artifacts.byKind.reward_eligibility_state or {}
        local eligibilityClaims = {}
        for _, artifact in ipairs(rewardArtifacts or {}) do
            local claimKey = artifact and artifact.detail and artifact.detail.claimKey or nil
            if claimKey then
                if eligibilityClaims[claimKey] then
                    return false, 'duplicate_reward_eligibility'
                end
                eligibilityClaims[claimKey] = true
                if self.recoveryInvariants.bossRewardClaims[claimKey] ~= true then
                    return false, 'reward_eligibility_inconsistent'
                end
            end
        end
        local checkpointPolicy = self.recovery.recoverySource and self.recovery.recoverySource.policy or nil
        if checkpointPolicy and stableSerialize(checkpointPolicy) ~= stableSerialize(policy) then
            return false, 'policy_bundle_inconsistent'
        end
        local commitState = self.recovery.recoverySource and self.recovery.recoverySource.commitState or nil
        if type(commitState) == 'table' and commitState.finalized ~= true then
            return false, 'staged_commit_not_finalized'
        end
        if tonumber(self.runtimeIdentity.ownerEpoch) ~= nil and tonumber(self.runtimeIdentity.runtimeEpoch) ~= nil
            and tonumber(self.runtimeIdentity.ownerEpoch) > tonumber(self.runtimeIdentity.runtimeEpoch) then
            return false, 'ownership_epoch_inconsistent'
        end
        return true
    end

    function world:_replayJournalEntries(entries, sinceSeq)
        local replayed = 0
        local minSeq = math.max(0, math.floor(tonumber(sinceSeq) or 0))
        for _, entry in ipairs(entries or {}) do
            local seq = math.max(0, math.floor(tonumber(entry.seq) or 0))
            if seq > minSeq then
                local eventName = tostring(entry.event or 'unknown')
                if eventName == 'ownership_conflict' then
                    self:_recordOwnershipConflict('replay', entry.payload, { recordEvent = false })
                elseif eventName == 'mob_killed' or eventName == 'boss_killed' then
                    self:_recordFarmSignal({ id = entry.payload and entry.payload.playerId or nil }, entry.payload and (entry.payload.mobId or entry.payload.bossId), { recordArtifact = false })
                elseif eventName == 'failure_escalated' then
                    self.escalation.level = math.max(self.escalation.level or 0, math.floor(tonumber(entry.payload and entry.payload.level) or 0))
                    self.escalation.severity = self:_severityName(self.escalation.level)
                elseif eventName == 'governance_transition' then
                    self.governance.state = tostring(entry.payload and entry.payload.to or self.governance.state or 'normal')
                elseif eventName == 'repair_action' then
                    self.repairs.state = tostring(entry.payload and entry.payload.kind or self.repairs.state or 'idle')
                end
                replayed = replayed + 1
            end
        end
        return replayed
    end

    function world:restoreWorldState()
        if not self.worldRepository then return false end
        self._replayingRecovery = true
        self:_recordTruthEvent('recovery_start', { phase = 'world_restore' }, { truthType = 'recovery.start', forceRecord = true })
        self:_recordTruthEvent('replay_start', { mode = 'checkpoint_restore' }, { truthType = 'replay.start', forceRecord = true })
        self:_replayPhase('checkpoint_load', 'in_progress')
        local startedAt = os.clock()
        local snapshot, loadStatus, err
        if type(self.worldRepository.loadDetailed) == 'function' then
            snapshot, loadStatus, err = self.worldRepository:loadDetailed()
        else
            snapshot, err = self.worldRepository:load()
            if err then loadStatus = RecoveryKernel.classifyLoadError(err) elseif snapshot then loadStatus = 'ok' else loadStatus = 'not_found' end
        end
        if err then
            if self.metrics then
                self.metrics:increment('world_state.load_error', 1)
                self.metrics:error('world_state_load_failed', { error = tostring(err), status = tostring(loadStatus) })
            end
            self:_replayPhase('checkpoint_load', 'failed', { error = tostring(err) })
            self.recovery.valid = false
            self.recovery.recoverySource = {
                source = tostring(loadStatus or 'load_error'),
                checkpointId = nil,
                revision = 0,
                reportArtifactId = nil,
            }
            self:_refreshRecoveryVerification()
            self:_recordTruthEvent('recovery_end', { phase = 'world_restore', status = 'failed', reason = tostring(err) }, { truthType = 'recovery.end', forceRecord = true })
            self._replayingRecovery = false
            return false, err
        end
        if not snapshot then
            self.recovery.mode = 'cold_start'
            self.recovery.valid = true
            self.recovery.recoverySource = {
                source = tostring(loadStatus or 'cold_start'),
                checkpointId = nil,
                revision = 0,
                reportArtifactId = nil,
            }
            self:_refreshRecoveryVerification()
            self._replayingRecovery = false
            return false
        end
        if type(snapshot) ~= 'table' then
            self._replayingRecovery = false
            return false, 'invalid_world_snapshot'
        end

        local previousJournal = self.journal:serialize()
        local previousDrops = self.dropSystem:snapshot()
        local previousBoss = self.bossSystem:snapshot()
        local previousPlayers = deepcopy(self.players)
        local previousMapPlayers = deepcopy(self.mapPlayers)
        local previousPolicyBundle = self.policyBundle
        local previousPolicyHistory = deepcopy(self.policyHistory)
        local previousSavePlan = deepcopy(self.savePlan)

        self._restoringWorldState = true
        self:_replayPhase('event_hydration', 'in_progress')
        local ok, restoreErr = pcall(function()
            self.journal:restore(snapshot.journal)
            self.dropSystem:restore(snapshot.drops)
            self.bossSystem:restore(snapshot.boss)
            self.governance = deepcopy(snapshot.governance or self.governance)
            self.repairs = deepcopy(snapshot.repairs or self.repairs)
            self.topology = deepcopy(snapshot.topology or self.topology)
            self.policyBundle = RuntimePolicyBundle.new(self.worldConfig, snapshot.checkpoint and snapshot.checkpoint.policy or self:_policy())
            self.policyBundle.history = deepcopy(snapshot.policyHistory or self.policyBundle:historySnapshot())
            self.policyHistory = deepcopy(snapshot.policyHistory or self.policyBundle:historySnapshot())
            self.savePlan = deepcopy(snapshot.savePlan or self.savePlan)
            self.artifacts.entries = deepcopy(snapshot.artifacts or {})
            self.artifacts.byKind = {}
            for _, artifact in ipairs(self.artifacts.entries) do
                self.artifacts.byKind[artifact.kind] = self.artifacts.byKind[artifact.kind] or {}
                self.artifacts.byKind[artifact.kind][#self.artifacts.byKind[artifact.kind] + 1] = artifact
            end
            self.artifacts.nextId = (#self.artifacts.entries or 0) + 1
            self.players = {}
            self.mapPlayers = {}
            for playerId, playerSnapshot in pairs(snapshot.activePlayers or {}) do
                local restoredPlayer = self.itemSystem:sanitizePlayerProfile(playerSnapshot, playerId)
                restoredPlayer.currentMapId = playerSnapshot.currentMapId or restoredPlayer.currentMapId or self.worldConfig.runtime.defaultMapId
                restoredPlayer.runtimeScope = deepcopy(playerSnapshot.runtimeScope or restoredPlayer.runtimeScope or {})
                restoredPlayer.runtimeScope.mapId = restoredPlayer.currentMapId
                restoredPlayer.runtimeScope.mapInstanceId = restoredPlayer.runtimeScope.mapInstanceId or (tostring(restoredPlayer.currentMapId) .. '@' .. tostring(self.runtimeIdentity.runtimeInstanceId))
                restoredPlayer.runtimeScope.worldId = restoredPlayer.runtimeScope.worldId or self.runtimeIdentity.worldId
                restoredPlayer.runtimeScope.channelId = restoredPlayer.runtimeScope.channelId or self.runtimeIdentity.channelId
                restoredPlayer.runtimeScope.runtimeInstanceId = restoredPlayer.runtimeScope.runtimeInstanceId or self.runtimeIdentity.runtimeInstanceId
                restoredPlayer.position = deepcopy(playerSnapshot.position or restoredPlayer.position or self:_defaultMapPosition(restoredPlayer.currentMapId))
                restoredPlayer.dirty = false
                self.players[playerId] = restoredPlayer
                self.mapPlayers[restoredPlayer.currentMapId] = self.mapPlayers[restoredPlayer.currentMapId] or {}
                self.mapPlayers[restoredPlayer.currentMapId][playerId] = true
            end
        end)
        self._restoringWorldState = false

        if not ok then
            self._restoringWorldState = true
            pcall(function()
                self.journal:restore(previousJournal)
                self.dropSystem:restore(previousDrops)
                self.bossSystem:restore(previousBoss)
                self.players = previousPlayers
                self.mapPlayers = previousMapPlayers
                self.policyBundle = previousPolicyBundle
                self.policyHistory = previousPolicyHistory
                self.savePlan = previousSavePlan
            end)
            self._restoringWorldState = false
            if self.metrics then
                self.metrics:increment('world_state.restore_error', 1)
                self.metrics:error('world_state_restore_failed', { error = tostring(restoreErr) })
            end
            self:_replayPhase('event_hydration', 'failed', { error = tostring(restoreErr) })
            self.recovery.valid = false
            self:_escalate('checkpoint_restore_failed', { error = tostring(restoreErr) })
            self._replayingRecovery = false
            return false, 'restore_failed:' .. tostring(restoreErr)
        end

        self:_replayPhase('deterministic_reconstruction', 'completed')
        self:_replayPhase('state_reconstruction', 'completed')
        self:_replayPhase('invariant_verification', 'in_progress')
        local checkpoint = snapshot.checkpoint or {}
        self.recovery.recoverySource = {
            source = 'checkpoint_restore',
            checkpointId = checkpoint.checkpoint_id,
            revision = self.worldRepository:lastLoadedRevision() or 0,
            reportArtifactId = nil,
            policy = deepcopy(checkpoint.policy),
            commitState = deepcopy(checkpoint.commit_state),
        }
        local invOk, invErr = self:_rebuildRecoveryInvariants()
        if not invOk then
            self.recovery.mode = 'replay_restore_required'
            self.recovery.valid = false
            self.containment.replayOnly = true
            self.containment.ownershipReject = true
            self:_recordRepairAction('replay_invariant_violation', self:_ownershipScope(), invErr, 'entered_replay_only', {})
            self:_escalate('replay_invariant_violation', { invariant = invErr })
            self:_replayPhase('invariant_verification', 'failed', { invariant = invErr })
            self:_replayPhase('runtime_activation', 'failed', { invariant = invErr })
            self:_refreshRecoveryVerification()
            self:_recordTruthEvent('recovery_end', { phase = 'world_restore', status = 'failed', reason = tostring(invErr) }, { truthType = 'recovery.end', forceRecord = true })
            self._replayingRecovery = false
            return false, invErr
        end

        self:_replayPhase('event_hydration', 'completed', { checkpointId = checkpoint.checkpoint_id })
        local replayedEntries = self:_replayJournalEntries(self.journal:snapshot(), tonumber(checkpoint.journal_watermark) or 0)
        self.recovery.watermark = {
            journal = tonumber(checkpoint.journal_watermark) or 0,
            ledger = tonumber(checkpoint.ledger_watermark) or 0,
        }
        self.recovery.valid = true
        self.recovery.checkpointId = checkpoint.checkpoint_id
        self.recovery.replayBaseRevision = tonumber(checkpoint.replay_base_revision) or 0
        self.recovery.replayedEntries = replayedEntries
        self.recovery.checkpointLineage = deepcopy(snapshot.health and snapshot.health.checkpoint_lineage or self.recovery.checkpointLineage or {})
        self.recovery.checkpointRevision = self.worldRepository:lastLoadedRevision() or 0
        local actualDigest = self:_materializedDigest()
        self.recovery.divergence = snapshot.materialized_digest ~= nil and snapshot.materialized_digest ~= actualDigest
        if self.recovery.divergence then
            self.recovery.divergenceCount = (self.recovery.divergenceCount or 0) + 1
            local divergence = self:_artifact('replay_report', self:_ownershipScope(), {
                expectedDigest = snapshot.materialized_digest,
                actualDigest = actualDigest,
                checkpointId = checkpoint.checkpoint_id,
                divergenceCounter = self.recovery.divergenceCount,
            })
            self.recovery.lastReplayReportId = divergence.artifactId
            self.recovery.recoverySource.reportArtifactId = divergence.artifactId
            self:_recordTruthEvent('replay_divergence_detected', {
                checkpointId = checkpoint.checkpoint_id,
                expectedDigest = snapshot.materialized_digest,
                actualDigest = actualDigest,
                reportArtifactId = divergence.artifactId,
            }, { truthType = 'replay.divergence', forceRecord = true })
            self:_recordRepairAction('replay_divergence', self:_ownershipScope(), 'digest_mismatch', 'repair_escalation', {
                expectedDigest = snapshot.materialized_digest,
                actualDigest = actualDigest,
            })
            self:_escalate('replay_divergence_detected', { expectedDigest = snapshot.materialized_digest, actualDigest = actualDigest })
        end
        self:_replayPhase('invariant_verification', 'completed')
        self:_replayPhase('runtime_activation', self.recovery.divergence and 'degraded' or 'completed')
        self.recovery.mode = self.recovery.divergence and 'degraded_safe' or 'open_runtime'

        for _, drop in ipairs(self.dropSystem:listAllDrops()) do
            self:_emit('onDropSpawned', drop)
        end
        for _, encounter in pairs(self.bossSystem.encounters) do
            if encounter.alive then self:_emit('onBossSpawned', encounter) end
        end

        local elapsedMs = math.floor((os.clock() - startedAt) * 1000)
        self.recovery.lastReplayDurationMs = elapsedMs
        if self.metrics then
            self.metrics:time('world_state.restore.duration_ms', elapsedMs)
            self.metrics:gauge('world_state.replay_entries', self.recovery.replayedEntries or 0)
            self.metrics:gauge('world_state.recovery_valid', self.recovery.valid and 1 or 0)
        end
        local report = self:_artifact('replay_report', self:_ownershipScope(), {
            checkpoint_id = self.recovery.checkpointId,
            replayed_entries = self.recovery.replayedEntries,
            duration_ms = elapsedMs,
            divergence = self.recovery.divergence,
            checkpoint_class = checkpoint.checkpoint_class,
        })
        self.recovery.lastReplayReportId = report.artifactId
        self.recovery.recoverySource.reportArtifactId = report.artifactId
        self:_refreshRecoveryVerification()
        self:_recordTruthEvent('world_recovered', {
            checkpoint_id = self.recovery.checkpointId,
            replayed_entries = self.recovery.replayedEntries,
            duration_ms = elapsedMs,
            replay_report_id = report.artifactId,
        }, { truthType = 'recovery.restore', forceRecord = true })
        self:_recordTruthEvent('recovery_end', {
            checkpoint_id = self.recovery.checkpointId,
            replay_report_id = report.artifactId,
            confidence = self.recovery.confidence,
        }, { truthType = 'recovery.end', forceRecord = true })
        self:_recordTruthEvent('replay_finish', {
            mode = 'checkpoint_restore',
            replayed_entries = self.recovery.replayedEntries,
            checkpoint_id = self.recovery.checkpointId,
        }, { truthType = 'replay.finish', forceRecord = true })
        self:_recomputePressure()
        self._replayingRecovery = false
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
            world:_recordTruthEvent('mob_spawned', { mapId = mob.mapId, mobId = mob.mobId, spawnId = mob.spawnId }, {
                truthType = 'spawn.create',
                mapId = mob.mapId,
                spawnId = mob.spawnId,
            })
            world:_emit('onMobSpawned', mob)
        end,
        onKill = function(mob)
            world:_recordTruthEvent('mob_despawned', { mapId = mob.mapId, mobId = mob.mobId, spawnId = mob.spawnId }, {
                truthType = 'spawn.despawn',
                mapId = mob.mapId,
                spawnId = mob.spawnId,
            })
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
        player.runtimeScope = player.runtimeScope or {}
        player.runtimeScope.worldId = self.runtimeIdentity.worldId
        player.runtimeScope.channelId = self.runtimeIdentity.channelId
        player.runtimeScope.runtimeInstanceId = self.runtimeIdentity.runtimeInstanceId
        player.runtimeScope.mapId = mapId
        player.runtimeScope.mapInstanceId = tostring(mapId) .. '@' .. tostring(self.runtimeIdentity.runtimeInstanceId)
        self.topology.mapInstances[player.runtimeScope.mapInstanceId] = self.topology.mapInstances[player.runtimeScope.mapInstanceId] or {
            mapId = mapId,
            worldId = self.runtimeIdentity.worldId,
            channelId = self.runtimeIdentity.channelId,
            runtimeInstanceId = self.runtimeIdentity.runtimeInstanceId,
            scope = 'runtime_local',
        }
        player.lastMapChangeAt = self:_now()
        player.dirty = true
        self:_setPlayerPosition(player, self:_defaultMapPosition(mapId), not self.strictRuntimeBoundary)
        self:_recordTruthEvent('player_map_changed', { playerId = player.id, mapId = mapId }, {
            truthType = 'topology.route_commit',
            playerId = player.id,
            mapId = mapId,
        })
        self:_emit('onPlayerMapChanged', player, mapId)
        return true
    end

    function world:transferOwnership(nextOwnerId, nextOwnerEpoch, detail)
        local previous = {
            ownerId = self.runtimeIdentity.ownerId,
            ownerEpoch = self.runtimeIdentity.ownerEpoch,
            runtimeEpoch = self.runtimeIdentity.runtimeEpoch,
        }
        local requestedEpoch = tonumber(nextOwnerEpoch)
        local nextEpoch = requestedEpoch ~= nil and math.floor(requestedEpoch) or (previous.ownerEpoch + 1)
        if nextEpoch <= previous.ownerEpoch then
            self:_recordOwnershipConflict('ownership_transfer_stale_epoch', { previous = previous, requestedEpoch = nextOwnerEpoch })
            self:_recordRepairAction('ownership_conflict', self:_ownershipScope(), 'stale_owner_epoch', 'quarantine', { requestedEpoch = nextOwnerEpoch })
            return false, 'ownership_epoch_stale'
        end
        self.runtimeIdentity.ownerId = tostring(nextOwnerId or self.runtimeIdentity.ownerId)
        self.runtimeIdentity.ownerEpoch = nextEpoch
        self.runtimeIdentity.runtimeEpoch = math.max(self.runtimeIdentity.runtimeEpoch, nextEpoch)
        self:_artifact('ownership_transition', self:_ownershipScope(), {
            transition = 'ownership_transfer',
            previous = previous,
            next = {
                ownerId = self.runtimeIdentity.ownerId,
                ownerEpoch = self.runtimeIdentity.ownerEpoch,
                runtimeEpoch = self.runtimeIdentity.runtimeEpoch,
            },
            detail = deepcopy(detail or {}),
        })
        self:_recordRuntimeEvent('ownership_transferred', {
            previous = previous,
            next = {
                ownerId = self.runtimeIdentity.ownerId,
                ownerEpoch = self.runtimeIdentity.ownerEpoch,
                runtimeEpoch = self.runtimeIdentity.runtimeEpoch,
            },
            detail = deepcopy(detail or {}),
        })
        for _, player in pairs(self.players or {}) do
            player.runtimeScope = player.runtimeScope or {}
            player.runtimeScope.ownerId = self.runtimeIdentity.ownerId
            player.runtimeScope.ownerEpoch = self.runtimeIdentity.ownerEpoch
            player.runtimeScope.runtimeEpoch = self.runtimeIdentity.runtimeEpoch
        end
        self:markWorldStateDirty('ownership_transfer')
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

        self:_recordTruthEvent('player_save_staged', { playerId = player.id, requireWorldSave = requireWorldSave == true, phase = 'player_save_begin' }, {
            truthType = 'player.save.stage',
            playerId = player.id,
            mapId = player.currentMapId,
            stageLink = 'player_save_begin',
        })
        self:_recordRuntimeEvent('player_lifecycle_save_stage', { playerId = player.id, runtimeScope = deepcopy(player.runtimeScope) })
        local ok, err = self.playerRepository:save(player)
        if not ok then
            self:_recordTruthEvent('player_save_staged', { playerId = player.id, requireWorldSave = requireWorldSave == true, phase = 'player_save_failed', error = tostring(err) }, {
                truthType = 'player.save.rollback',
                playerId = player.id,
                mapId = player.currentMapId,
                stageLink = 'player_save_failed',
            })
            if self.metrics then
                self.metrics:increment('player_state.save_error', 1)
                self.metrics:error('player_state_save_failed', { playerId = tostring(player.id), error = tostring(err) })
            end
            return false, err
        end
        self:_recordRuntimeEvent('player_lifecycle_save_commit', { playerId = player.id, runtimeScope = deepcopy(player.runtimeScope) })

        if requireWorldSave then
            local worldSaved, worldErr = self:saveWorldState('player_save:' .. tostring(player.id))
            if not worldSaved then
                player.dirty = true
                self:_recordTruthEvent('player_save_staged', { playerId = player.id, phase = 'world_save_failed', error = tostring(worldErr) }, {
                    truthType = 'player.save.rollback',
                    playerId = player.id,
                    mapId = player.currentMapId,
                    stageLink = 'world_save_failed',
                })
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
                self:appendLedgerEvent({
                    event_type = 'repair_compensation',
                    actor_id = player.id,
                    correlation_id = string.format('player_save:%s:%s', tostring(player.id), tostring(self:_now())),
                    source_system = 'player_repository',
                    rollback_of = tostring(player.id),
                    metadata = { action = 'player_save_rollback', error = tostring(worldErr) },
                })
                if not rollbackOk then
                    self:_recordTruthEvent('player_save_staged', { playerId = player.id, phase = 'rollback_failed', error = tostring(rollbackErr) }, {
                        truthType = 'player.save.rollback',
                        playerId = player.id,
                        mapId = player.currentMapId,
                        stageLink = 'rollback_failed',
                    })
                    return false, 'world_state_save_failed:' .. tostring(worldErr) .. ';rollback_failed:' .. tostring(rollbackErr)
                end
                self:_recordTruthEvent('player_save_staged', { playerId = player.id, phase = 'rollback_completed' }, {
                    truthType = 'player.save.rollback',
                    playerId = player.id,
                    mapId = player.currentMapId,
                    stageLink = 'rollback_completed',
                })
                return false, worldErr or 'world_state_save_failed'
            end
        end

        player.dirty = false
        player.lastSavedAt = self:_now()
        self:_recordTruthEvent('player_save_staged', { playerId = player.id, phase = 'commit_complete' }, {
            truthType = 'player.save.commit',
            playerId = player.id,
            mapId = player.currentMapId,
            stageLink = 'commit_complete',
        })
        self:_recordRuntimeEvent('player_lifecycle_save_finalize', { playerId = player.id, at = player.lastSavedAt, runtimeScope = deepcopy(player.runtimeScope) })
        self:_recordTruthEvent('player_saved', { playerId = player.id, version = player.version, at = player.lastSavedAt }, {
            truthType = 'player.save.finalize',
            playerId = player.id,
            mapId = player.currentMapId,
        })
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
        local loaded, loadErr = nil, nil
        local loadStatus = 'unknown'
        if self.playerRepository and type(self.playerRepository.loadDetailed) == 'function' then
            loaded, loadStatus, loadErr = self.playerRepository:loadDetailed(playerId)
        else
            loaded, loadErr = self.playerRepository:load(playerId)
            if loadErr then loadStatus = 'storage_error' elseif loaded then loadStatus = 'ok' else loadStatus = 'not_found' end
        end
        if loadErr then
            if self.metrics then
                self.metrics:increment('player_state.load_error', 1, { status = tostring(loadStatus) })
                self.metrics:error('player_state_load_failed', { playerId = tostring(playerId), error = tostring(loadErr), status = tostring(loadStatus) })
            end
        self:_recordTruthEvent('player_load_failed', { playerId = playerId, status = loadStatus, error = tostring(loadErr) }, {
            truthType = 'player.load.failed',
            playerId = playerId,
        })
        return nil, loadErr
    end
        local player = self.itemSystem:sanitizePlayerProfile(loaded, playerId)
        self:_ensurePlayerSystems(player)
        player.runtimeScope = player.runtimeScope or {}
        player.runtimeScope.worldId = self.runtimeIdentity.worldId
        player.runtimeScope.channelId = self.runtimeIdentity.channelId
        player.runtimeScope.runtimeInstanceId = self.runtimeIdentity.runtimeInstanceId
        player.runtimeScope.ownerId = self.runtimeIdentity.ownerId
        player.runtimeScope.runtimeEpoch = self.runtimeIdentity.runtimeEpoch
        player.runtimeScope.ownerEpoch = self.runtimeIdentity.ownerEpoch
        player.runtimeScope.coordinatorEpoch = self.runtimeIdentity.coordinatorEpoch
        player.currentMapId = player.currentMapId or (self.worldConfig.runtime and self.worldConfig.runtime.defaultMapId) or 'henesys_hunting_ground'
        player.runtimeScope.mapId = player.currentMapId
        player.runtimeScope.mapInstanceId = tostring(player.currentMapId) .. '@' .. tostring(self.runtimeIdentity.runtimeInstanceId)
        if loaded then player.dirty = false else player.dirty = true end
        if not player.position then self:_setPlayerPosition(player, self:_defaultMapPosition(player.currentMapId), not self.strictRuntimeBoundary) end
        self.players[playerId] = player
        self.sessionOrchestrator:bind(playerId, {
            channelId = self.runtimeIdentity.channelId,
            runtimeInstanceId = self.runtimeIdentity.runtimeInstanceId,
            currentMapId = player.currentMapId,
            transferState = 'idle',
        })
        self.mapPlayers[player.currentMapId] = self.mapPlayers[player.currentMapId] or {}
        self.mapPlayers[player.currentMapId][playerId] = true
        self:_recordTruthEvent('player_loaded', { playerId = playerId, loaded = loaded ~= nil, scope = deepcopy(player.runtimeScope) }, {
            truthType = loaded ~= nil and 'player.load.restore' or 'player.create',
            playerId = playerId,
            mapId = player.currentMapId,
        })
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
        self:_recordTruthEvent('player_unloaded', { playerId = playerId }, {
            truthType = 'player.unload',
            playerId = playerId,
            mapId = player.currentMapId,
        })
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
            derivedStats = self.statSystem:derived(player, self.itemSystem, player.activeEffects),
            currentMapId = player.currentMapId,
            position = deepcopy(player.position),
            runtimeScope = deepcopy(player.runtimeScope),
            stats = player.stats,
            jobId = player.jobId,
            skills = player.skills,
            activeEffects = player.activeEffects,
            inventoryLimits = player.inventoryLimits,
            social = player.social,
            progression = player.progression,
            achievements = player.achievements,
            achievementRewards = player.achievementRewards,
            tutorial = player.tutorial,
            buildRecommendation = self.buildRecommendationSystem:recommend(player),
            classProfile = self.playerClassSystem:refresh(player),
            questGuidance = self:_nextQuestGuidance(player),
            recommendedRoute = self:_recommendedRoute(player),
            journeyPlan = self:_playerJourneyPlan(player),
            huntingLoop = player.huntingLoop,
            setBonuses = player.setBonuses,
            lastCombatFeedback = player.lastCombatFeedback,
            lastLootFeedback = player.lastLootFeedback,
            combatClarity = {
                combo = player.comboState,
                bossPrepHint = player.currentMapId and ((self.worldConfig.maps[player.currentMapId] or {}).metadata or {}).sharedFarmingZones or nil,
            },
            socialProgression = {
                partyBuffs = player.partyBuffs,
                guildId = player.guildId,
                raidProgress = player.raidProgress,
            },
            craftingProfile = player.craftingProfile,
            inventory = self.itemSystem:exportInventory(player),
            equipment = player.equipment,
            quests = self.questSystem:snapshotPlayer(player),
            kills = player.killLog,
            dirty = player.dirty,
            version = player.version,
        }
        self.entityIndex:index('player', player.currentMapId or 'global', player.id, snapshot)
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
                    ai = mob.ai,
                    rare = mob.rare == true,
                    tacticalRole = mob.tacticalRole,
                    chokePoint = mob.chokePoint,
                    mobilityAdvantage = mob.mobilityAdvantage,
                    hitReaction = mob.lastHitReaction or mob.hitReaction,
                }
                self.entityIndex:index('mob', mapId, spawnId, mobsOut[#mobsOut])
            end
            table.sort(mobsOut, function(a, b) return a.spawnId < b.spawnId end)
        end
        local encounter = self.bossSystem:getEncounter(mapId)
        local bossOut = nil
        local dropsOut = self.dropSystem:listDrops(mapId)
        for _, drop in ipairs(dropsOut) do
            local itemDef = self.items[drop.itemId] or {}
            drop.progressionTier = itemDef.progressionTier
            drop.desirability = itemDef.desirability
            drop.excitement = drop.excitement or itemDef.excitement
        end
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
                mechanic = encounter.currentMechanic,
                telegraph = self.bossMechanicsSystem:telegraph(encounter),
                raid = encounter.raid == true,
            }
            self.entityIndex:index('boss', mapId, encounter.bossId, bossOut)
        end
        return {
            mapId = mapId,
            population = self:getMapPopulation(mapId),
            mobs = mobsOut,
            drops = dropsOut,
            boss = bossOut,
            regionalEvent = self.worldEventSystem:regional(mapId),
            metadata = deepcopy((self.worldConfig.maps[mapId] or {}).metadata),
            recommendedLevel = (self.worldConfig.maps[mapId] or {}).recommended_level,
            socialDensity = math.max(0, self:getMapPopulation(mapId) + #mobsOut + (#dropsOut > 0 and 1 or 0)),
            huntPreview = {
                routeCount = type(((self.worldConfig.maps[mapId] or {}).metadata or {}).movementRoutes) == 'table' and #(((self.worldConfig.maps[mapId] or {}).metadata or {}).movementRoutes) or 0,
                verticality = type(((self.worldConfig.maps[mapId] or {}).metadata or {}).verticalLayers) == 'table' and #(((self.worldConfig.maps[mapId] or {}).metadata or {}).verticalLayers) or 0,
                chokePoints = type(((self.worldConfig.maps[mapId] or {}).metadata or {}).chokePoints) == 'table' and #(((self.worldConfig.maps[mapId] or {}).metadata or {}).chokePoints) or 0,
                eliteCount = (function()
                    local count = 0
                    for _, mob in ipairs(mobsOut) do
                        if mob.rare or tostring(mob.ai or ''):find('pursue', 1, true) then count = count + 1 end
                    end
                    return count
                end)(),
            },
            tacticalMapMeta = {
                chokePoints = deepcopy((((self.worldConfig.maps[mapId] or {}).metadata or {}).chokePoints) or {}),
                mobilityAdvantageZones = deepcopy((((self.worldConfig.maps[mapId] or {}).metadata or {}).mobilityAdvantageZones) or {}),
                sharedFarmingZones = deepcopy((((self.worldConfig.maps[mapId] or {}).metadata or {}).sharedFarmingZones) or {}),
                environmentStory = (((self.worldConfig.maps[mapId] or {}).metadata or {}).environmentStory),
            },
            groupPlay = {
                recommended = ((self.worldConfig.maps[mapId] or {}).metadata or {}).sharedFarmingZones ~= nil,
                socialHotspots = deepcopy((((self.worldConfig.maps[mapId] or {}).metadata or {}).socialHotspots) or {}),
            },
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
                player.lastLootFeedback = self.combatFeedback:lootDrop(drop)
                player.huntingLoop.recentDrops[#player.huntingLoop.recentDrops + 1] = {
                    itemId = drop.itemId,
                    rarity = drop.rarity,
                    excitement = drop.excitement,
                    dopamine = drop.dopamine,
                }
                while #player.huntingLoop.recentDrops > 5 do table.remove(player.huntingLoop.recentDrops, 1) end
                self:_emitRewardLedger(player, 'drop_claim', { source_system = 'drop_system', correlation_id = ctx.correlationId, source_event_id = ctx.sourceEventId, map_id = mapId, boss_id = ctx.bossId, item_id = drop.itemId, quantity = drop.quantity, idempotency_key = string.format('reward:auto:%s:%s:%s', tostring(player.id), tostring(drop.itemId), tostring(ctx.correlationId or os.time())), lineage_reference = self:_lineageReference('drop_auto', drop.itemId), metadata = { mode = 'auto_pickup', reason = ctx.source } })
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
            worldId = self.runtimeIdentity.worldId,
            channelId = self.runtimeIdentity.channelId,
            runtimeInstanceId = self.runtimeIdentity.runtimeInstanceId,
            ownerScope = deepcopy(player.runtimeScope),
        })
        for _, record in ipairs(records) do
            self:_artifact('drop_lifecycle_state', self:_ownershipScope(mapId, { dropId = record.dropId }), {
                phase = 'spawned',
                drop = deepcopy(record),
            })
            self:_emit('onDropSpawned', record)
        end
        return records
    end

    function world:_applyMobRewards(player, mob, forceAutoPickup)
        self:_recordFarmSignal(player, mob.mobId)
        player.huntingLoop.streak = (player.huntingLoop.streak or 0) + 1
        player.huntingLoop.rareSince = (player.huntingLoop.rareSince or 0) + 1
        local correlationId = string.format('mob_reward:%s:%s:%s', tostring(player.id), tostring(mob.spawnId), tostring(self:_now()))
        local mesosReward = self:_rollMesos(mob.template.mesos_min, mob.template.mesos_max)
        local expReward = mob.template.exp or 0
        local beforeLevel = player.level
        local beneficiaries = self.partySystem:shareRewards(self, player, expReward, mesosReward)
        if player.level > beforeLevel then self.progressionSystem:onLevelUp(player) end
        local rawDrops = self.dropSystem:rollDrops(mob, player)
        local delivered = self:_processDropAcquisition(player, mob.mapId, mob, rawDrops, forceAutoPickup, { source = 'mob_drop', correlationId = correlationId, sourceEventId = tostring(mob.spawnId) })
        self.questSystem:onKill(player, mob.mobId, 1)
        player.killLog[mob.mobId] = (player.killLog[mob.mobId] or 0) + 1
        player.dirty = true
        self:_recordTruthEvent('mob_killed', { playerId = player.id, mapId = mob.mapId, mobId = mob.mobId, spawnId = mob.spawnId }, {
            truthType = 'spawn.kill',
            playerId = player.id,
            mapId = mob.mapId,
            spawnId = mob.spawnId,
        })
        if mob.rare then self.achievementsSystem:unlock(player, 'rare_hunter') end
        if mob.rare then player.huntingLoop.rareSince = 0 end
        if mob.rare then player.lastCombatFeedback = { kind = 'rare_spawn_clear', message = 'Rare route spike cleared', impact = 'elevated_drop_tension', reaction = mob.lastHitReaction or mob.hitReaction } end
        if not mob.rare then
            player.lastCombatFeedback = {
                kind = 'mob_clear',
                message = mob.template.identity or 'Route target defeated',
                impact = mob.tacticalRole or 'lane_clear',
                reaction = mob.lastHitReaction or mob.hitReaction,
            }
        end
        if player.huntingLoop.streak >= 10 then self.tutorialSystem:advance(player, 'move') end
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
        player.lastCombatFeedback = {
            kind = 'hit_confirm',
            message = mobOrErr.template.identity or 'Target struck',
            impact = mobOrErr.lastHitReaction or mobOrErr.hitReaction,
            remainingHp = mobOrErr.hp,
            maxHp = mobOrErr.maxHp,
        }
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
        if record.worldId and tostring(record.worldId) ~= tostring(self.runtimeIdentity.worldId) then
            self:_recordOwnershipConflict('drop_world_scope_conflict', { expected = record.worldId, actual = self.runtimeIdentity.worldId, dropId = dropId })
            return false, 'runtime_world_conflict'
        end
        if record.channelId and tostring(record.channelId) ~= tostring(self.runtimeIdentity.channelId) then
            self:_recordOwnershipConflict('drop_channel_scope_conflict', { expected = record.channelId, actual = self.runtimeIdentity.channelId, dropId = dropId })
            return false, 'runtime_channel_conflict'
        end
        if record.runtimeInstanceId and tostring(record.runtimeInstanceId) ~= tostring(self.runtimeIdentity.runtimeInstanceId) then
            self:_recordOwnershipConflict('drop_runtime_scope_conflict', { expected = record.runtimeInstanceId, actual = self.runtimeIdentity.runtimeInstanceId, dropId = dropId })
            return false, 'runtime_instance_conflict'
        end
        local claimKey = self:_dropClaimKey(record)
        if self.recoveryInvariants.claimedDrops[claimKey] then
            self.duplicationGuard:recordClaim(claimKey)
            self.exploitMonitor:flag(player.id, 'duplicate_drop_claim')
            self:_escalate('duplicate_drop_claim_attempt', { dropId = dropId, playerId = player.id })
            return false, 'duplicate_drop_claim'
        end
        local ok, recordOrErr = self.dropSystem:pickupDrop(player, record.mapId, dropId, self.itemSystem, { now = self:_now() })
        if not ok then return false, recordOrErr end
        self.recoveryInvariants.claimedDrops[claimKey] = true
        self.duplicationGuard:recordClaim(claimKey)
        self.questSystem:onItemAcquired(player, recordOrErr.itemId, recordOrErr.quantity)
        self:_recordTruthEvent('drop_picked', { playerId = player.id, mapId = record.mapId, dropId = dropId, itemId = recordOrErr.itemId }, {
            truthType = 'drop.pick',
            playerId = player.id,
            mapId = record.mapId,
            dropId = dropId,
            itemId = recordOrErr.itemId,
        })
        self:_emitRewardLedger(player, 'drop_claim', { source_system = 'drop_system', map_id = record.mapId, item_id = recordOrErr.itemId, quantity = recordOrErr.quantity, source_event_id = tostring(dropId), correlation_id = recordOrErr.correlationId, idempotency_key = string.format('reward:pickup:%s:%s', tostring(player.id), tostring(dropId)), lineage_reference = self:_lineageReference('drop', dropId), metadata = { mode = 'manual_pickup' } })
        self:_artifact('drop_lifecycle_state', self:_ownershipScope(record.mapId, { dropId = dropId }), {
            phase = 'picked',
            drop = deepcopy(recordOrErr),
            claimKey = claimKey,
            playerId = player.id,
        })
        self:_emit('onDropPicked', recordOrErr, player)
        self:publishPlayerSnapshot(player)
        return true, recordOrErr
    end

    function world:spawnBoss(bossId, mapId)
        local def = self.bossSystem.bossTable[bossId]
        local targetMapId = mapId or (def and def.mapId)
        if def and tostring(def.uniqueness or 'channel_unique') == 'world_unique'
            and (self.pressure.ownershipConflictPressure or 0) >= (tonumber(self:_policySection('bossUniqueness').worldUniqueThrottle) or math.huge) then
            return false, 'boss_throttled_by_pressure'
        end
        local encounter, err, remaining = self.bossSystem:spawnEncounter(bossId, targetMapId)
        if type(encounter) == 'table' then
            if not encounter.position then encounter.position = deepcopy(def and def.position) end
            self:_recordRuntimeEvent('boss_spawned', { bossId = bossId, mapId = targetMapId, scope = deepcopy(self.runtimeIdentity) })
            self:_artifact('boss_encounter_state', self:_ownershipScope(targetMapId, { bossId = bossId, uniqueness = def and def.uniqueness }), {
                phase = 'spawned',
                encounter = deepcopy(encounter),
            })
            self:_emit('onBossSpawned', encounter)
        end
        return encounter, err, remaining
    end

    function world:_applyBossRewards(player, encounter, rawDrops)
        local bossDef = self.mobs[encounter.bossId] or {}
        local correlationId = string.format('boss_reward:%s:%s:%s', tostring(player.id), tostring(encounter.bossId), tostring(self:_now()))
        local mesosReward = self:_rollMesos(bossDef.mesos_min, bossDef.mesos_max)
        local beforeLevel = player.level
        local beneficiaries = self.partySystem:shareRewards(self, player, bossDef.exp or 0, mesosReward)
        if player.level > beforeLevel then self.progressionSystem:onLevelUp(player) end
        local position = self:_bossPosition(encounter)
        local delivered = self:_processDropAcquisition(player, encounter.mapId, position, rawDrops, self.autoPickupDrops == true, { source = 'boss_drop', correlationId = correlationId, bossId = encounter.bossId, sourceEventId = tostring(encounter.bossId) })
        local claimKey = self:_bossRewardClaimKey(player.id, encounter)
        if self.recoveryInvariants.bossRewardClaims[claimKey] then
            self:_escalate('duplicate_boss_reward_attempt', { playerId = player.id, bossId = encounter.bossId })
            return false, 'duplicate_boss_reward'
        end
        self.recoveryInvariants.bossRewardClaims[claimKey] = true
        self:_emitRewardLedger(player, 'boss_reward_claim', { source_system = 'boss_system', correlation_id = correlationId, map_id = encounter.mapId, boss_id = encounter.bossId, idempotency_key = claimKey, lineage_reference = self:_lineageReference('boss', encounter.bossId), metadata = { reward_kind = 'boss_clear', uniqueness = encounter.uniqueness or 'channel_unique' } })
        self:_artifact('reward_eligibility_state', self:_ownershipScope(encounter.mapId, { bossId = encounter.bossId }), {
            playerId = player.id,
            claimKey = claimKey,
            uniqueness = encounter.uniqueness or 'channel_unique',
        })
        self.questSystem:onKill(player, encounter.bossId, 1)
        player.killLog[encounter.bossId] = (player.killLog[encounter.bossId] or 0) + 1
        player.dirty = true
        if player.guildId then self.guildSystem:grantXp(player.guildId, 150) end
        self.achievementsSystem:unlock(player, 'raid_clear')
        self:_recordTruthEvent('boss_killed', { playerId = player.id, mapId = encounter.mapId, bossId = encounter.bossId }, {
            truthType = 'boss.clear',
            playerId = player.id,
            mapId = encounter.mapId,
            bossId = encounter.bossId,
        })
        self:_emit('onBossKilled', encounter, player, delivered)
        self:publishPlayerSnapshot(player)
        return { delivered = delivered, party = beneficiaries, mechanic = encounter.currentMechanic }
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
            player.lastCombatFeedback = {
                kind = 'boss_pressure',
                message = (resolvedEncounter.telegraphState and resolvedEncounter.telegraphState.text) or 'Boss pressure rising',
                impact = (resolvedEncounter.telegraphState and resolvedEncounter.telegraphState.punishWindow) or 'medium',
                phase = resolvedEncounter.phase,
            }
            self:saveWorldState('boss_damage')
            return true, nil
        end

        local rewards, rewardErr = self:_applyBossRewards(player, resolvedEncounter, dropsOrError)
        if rewards == false then return false, rewardErr end
        for raidId, raid in pairs(self.raidSystem.raids or {}) do
            if raid.bossId == resolvedEncounter.bossId and raid.phase ~= 'cleared' then
                self.raidSystem:complete(raidId, self)
                self.progressionSystem:grantRaidProgress(player, raid.rewardTier or 1)
            end
        end
        return true, rewards
    end

    function world:tickBosses()
        if next(self.players) == nil then return 0 end
        if (self.pressure.ownershipConflictPressure or 0) > 0 and self.containment.safeMode then
            return 0
        end
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

    function world:tickSpawns()
        local spawnPolicy = self:_policySection('spawnRegulation')
        local original = self.spawnSystem.maxSpawnPerTick
        local scale = 1.0
        if (self.pressure.entityDensityPressure or 0) >= (tonumber(spawnPolicy.densityThrottleThreshold) or math.huge) then
            scale = math.min(scale, tonumber(spawnPolicy.minTickScale) or 0.5)
        end
        if (self.pressure.farmRepetitionPressure or 0) >= (tonumber(spawnPolicy.farmRepetitionThrottleThreshold) or math.huge) then
            scale = math.min(scale, tonumber(spawnPolicy.minTickScale) or 0.5)
        end
        self.spawnSystem.maxSpawnPerTick = math.max(1, math.floor(original * scale))
        self.spawnSystem:tick()
        self.spawnSystem.maxSpawnPerTick = original
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
        self:_recordTruthEvent('item_granted', { playerId = player.id, itemId = itemId, quantity = quantity, reason = reason }, {
            truthType = 'item.create',
            playerId = player.id,
            mapId = player.currentMapId,
            itemId = itemId,
        })
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
        self:_emitRewardLedger(player, 'shop_buy', { source_system = 'economy_system', correlation_id = correlationId, npc_id = npcId, item_id = itemId, quantity = tonumber(quantity), lineage_reference = self:_lineageReference('shop_buy', itemId), metadata = { action = 'buy' } })
        self.questSystem:onItemAcquired(player, itemId, quantity)
        self:_recordTruthEvent('npc_buy', { playerId = player.id, npcId = npcId, itemId = itemId, quantity = quantity }, {
            truthType = 'mesos.value_mutation',
            playerId = player.id,
            mapId = player.currentMapId,
            npcId = npcId,
            itemId = itemId,
        })
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
        self:_emitRewardLedger(player, 'shop_sell', { source_system = 'economy_system', correlation_id = correlationId, npc_id = npcId, item_id = itemId, quantity = tonumber(quantity), lineage_reference = self:_lineageReference('shop_sell', itemId), metadata = { action = 'sell' } })
        self.questSystem:onItemRemoved(player, itemId, quantity)
        self:_recordTruthEvent('npc_sell', { playerId = player.id, npcId = npcId, itemId = itemId, quantity = quantity }, {
            truthType = 'mesos.value_mutation',
            playerId = player.id,
            mapId = player.currentMapId,
            npcId = npcId,
            itemId = itemId,
        })
        self:publishPlayerSnapshot(player)
        return true
    end

    function world:equipItem(player, itemId, instanceId)
        if not player then return false, 'invalid_player' end
        local actionOk, actionErr = self:_checkAction(player, 'equip', 1)
        if not actionOk then return false, actionErr end
        local ok, err = self.itemSystem:equip(player, itemId, instanceId, { correlation_id = string.format('equip:%s:%s:%s', tostring(player.id), tostring(itemId), tostring(self:_now())) })
        if not ok then return false, err end
        self:_recordTruthEvent('item_equipped', { playerId = player.id, itemId = itemId }, {
            truthType = 'item.equip',
            playerId = player.id,
            mapId = player.currentMapId,
            itemId = itemId,
        })
        self:publishPlayerSnapshot(player)
        return true
    end

    function world:unequipItem(player, slot)
        if not player then return false, 'invalid_player' end
        local actionOk, actionErr = self:_checkAction(player, 'equip', 1)
        if not actionOk then return false, actionErr end
        local ok, err = self.itemSystem:unequip(player, slot, { correlation_id = string.format('unequip:%s:%s:%s', tostring(player.id), tostring(slot), tostring(self:_now())) })
        if not ok then return false, err end
        self:_recordTruthEvent('item_unequipped', { playerId = player.id, slot = slot }, {
            truthType = 'item.unequip',
            playerId = player.id,
            mapId = player.currentMapId,
        })
        self:publishPlayerSnapshot(player)
        return true
    end

    function world:changeMap(player, mapId, sourceMapId)
        if not player then return false, 'invalid_player' end
        if self.containment.migrationBlocked then return false, 'migration_blocked' end
        if self.containment.ownershipReject then return false, 'ownership_rejected' end
        if not mapId or mapId == '' or not self.worldConfig.maps or not self.worldConfig.maps[mapId] then
            self:_recordRepairAction('migration_corruption', self:_ownershipScope(player and player.currentMapId, { playerId = player and player.id or nil }), 'invalid_destination', 'quarantine', { requestedMapId = mapId })
            return false, 'invalid_map'
        end
        if sourceMapId ~= nil and sourceMapId ~= '' and player.currentMapId ~= sourceMapId then
            self:_recordRepairAction('migration_corruption', self:_ownershipScope(player.currentMapId, { playerId = player.id }), 'source_mismatch', 'repair_escalation', {
                expectedSource = player.currentMapId,
                actualSource = sourceMapId,
                targetMapId = mapId,
            })
            return false, 'wrong_map'
        end
        local scope = player.runtimeScope or {}
        if scope.worldId and tostring(scope.worldId) ~= tostring(self.runtimeIdentity.worldId) then
            self._ownershipConflicts = (self._ownershipConflicts or 0) + 1
            self:_recordRuntimeEvent('ownership_conflict', { type = 'world', playerId = player.id, expected = self.runtimeIdentity.worldId, actual = scope.worldId })
            self:_recomputePressure()
            return false, 'runtime_world_conflict'
        end
        if scope.channelId and tostring(scope.channelId) ~= tostring(self.runtimeIdentity.channelId) then
            self._ownershipConflicts = (self._ownershipConflicts or 0) + 1
            self:_recordRuntimeEvent('ownership_conflict', { type = 'channel', playerId = player.id, expected = self.runtimeIdentity.channelId, actual = scope.channelId })
            self:_recomputePressure()
            return false, 'runtime_channel_conflict'
        end
        if scope.runtimeInstanceId and tostring(scope.runtimeInstanceId) ~= tostring(self.runtimeIdentity.runtimeInstanceId) then
            self._ownershipConflicts = (self._ownershipConflicts or 0) + 1
            self:_recordRuntimeEvent('ownership_conflict', { type = 'runtime_instance', playerId = player.id, expected = self.runtimeIdentity.runtimeInstanceId, actual = scope.runtimeInstanceId })
            self:_recomputePressure()
            return false, 'runtime_instance_conflict'
        end
        local source = sourceMapId
        if source == nil or source == '' then source = player.currentMapId end
        if source ~= mapId and not self:_isAllowedMapTransition(source, mapId) then
            self:_recordRepairAction('migration_corruption', self:_ownershipScope(source, { playerId = player.id, targetMapId = mapId }), 'invalid_transition', 'repair_escalation', {})
            return false, 'invalid_map_transition'
        end
        local actionOk, actionErr = self:_checkAction(player, 'map_change', 1)
        if not actionOk then return false, actionErr end
        local ok, err = self:setPlayerMap(player, mapId)
        if not ok then return false, err end
        local routeDecision, routedChannel = self.channelRouter:routeDecision(mapId)
        self.sessionOrchestrator:completeTransfer(player.id, {
            channelId = self.runtimeIdentity.channelId,
            runtimeInstanceId = self.runtimeIdentity.runtimeInstanceId,
            currentMapId = mapId,
            sourceMapId = source,
            targetChannelId = routeDecision and routeDecision.chosenChannelId or self.runtimeIdentity.channelId,
        })
        self:_recordRuntimeEvent('map_route_committed', {
            playerId = player.id,
            fromMapId = source,
            toMapId = mapId,
            routedChannelId = routedChannel and routedChannel.id or self.runtimeIdentity.channelId,
            routingDecision = deepcopy(routeDecision),
            source_scope = deepcopy(player.runtimeScope),
            target_scope = {
                worldId = self.runtimeIdentity.worldId,
                channelId = self.runtimeIdentity.channelId,
                runtimeInstanceId = self.runtimeIdentity.runtimeInstanceId,
                mapInstanceId = tostring(mapId) .. '@' .. tostring(self.runtimeIdentity.runtimeInstanceId),
                ownerId = self.runtimeIdentity.ownerId,
                ownerEpoch = self.runtimeIdentity.ownerEpoch,
                coordinatorEpoch = self.runtimeIdentity.coordinatorEpoch,
            },
            scope = deepcopy(player.runtimeScope),
        })
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
        self:_recordTruthEvent('quest_accepted', { playerId = player.id, questId = questId, npc = binding.npc, mapId = binding.mapId }, {
            truthType = 'quest.accept',
            playerId = player.id,
            mapId = binding.mapId,
            questId = questId,
            npcId = binding.npc,
        })
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
        self:_emitRewardLedger(player, 'quest_reward_claim', { source_system = 'quest_system', correlation_id = string.format('quest_turnin:%s:%s:%s', tostring(player.id), tostring(questId), tostring(self:_now())), quest_id = questId, lineage_reference = self:_lineageReference('quest', questId), metadata = { action = 'turn_in' } })
        self:_recordTruthEvent('quest_completed', { playerId = player.id, questId = questId, npc = binding.npc, mapId = binding.mapId }, {
            truthType = 'quest.complete',
            playerId = player.id,
            mapId = binding.mapId,
            questId = questId,
            npcId = binding.npc,
        })
        self:publishPlayerSnapshot(player)
        return true
    end

    function world:allocateStat(player, stat, amount)
        local ok, err = self.statSystem:allocate(player, stat, amount)
        if not ok then return false, err end
        return true, self:publishPlayerSnapshot(player)
    end

    function world:promoteJob(player, jobId)
        local ok, err = self.jobSystem:promote(player, jobId)
        if not ok then return false, err end
        self.skillSystem:ensurePlayer(player)
        return true, self:publishPlayerSnapshot(player)
    end

    function world:learnSkill(player, skillId)
        local ok, err = self.skillSystem:learn(player, skillId)
        if not ok then return false, err end
        return true, self:publishPlayerSnapshot(player)
    end

    function world:castSkill(player, skillId, target)
        local actionOk, actionErr = self:_checkAction(player, 'skill_cast', 1)
        if not actionOk then return false, actionErr end
        local allowed, bucket = self.distributedRateLimit:check(tostring(player.id) .. ':skill', 1)
        if not allowed then
            self.exploitMonitor:flag(player.id, 'skill_rate')
            return false, 'distributed_rate_limited'
        end
        local ok, payload = self.skillSystem:cast(player, skillId, target)
        if not ok then return false, payload end
        player.lastCombatFeedback = self.combatFeedback:skillCast(player, { id = skillId, visual = payload.visual, role = payload.role }, payload)
        if payload.area then self.tutorialSystem:advance(player, 'combat') end
        self:_emitOpsTelemetry('skill_cast', { playerId = player.id, skillId = skillId, bucket = bucket, result = payload.type })
        self:publishPlayerSnapshot(player)
        return true, payload
    end

    function world:enhanceEquipment(player, slot)
        return self.equipmentProgression:enhance(player, slot)
    end

    function world:createParty(player)
        local party = self.partySystem:create(player)
        self.tutorialSystem:advance(player, 'party')
        return party
    end

    function world:createGuild(player, name)
        return self.guildSystem:create(player, name)
    end

    function world:listPartyFinder(player, detail)
        return self.partyFinder:list(player, detail)
    end

    function world:getPlayerJourney(player)
        if not player then return nil, 'invalid_player' end
        return self:_playerJourneyPlan(player)
    end

    function world:findParties(filter)
        return self.partyFinder:find(filter)
    end

    function world:addFriend(player, otherId)
        return self.socialSystem:addFriend(player, otherId)
    end

    function world:tradeMesos(fromPlayer, toPlayer, amount)
        if not fromPlayer or not toPlayer then return false, 'invalid_player' end
        if fromPlayer.id == toPlayer.id then
            self.exploitMonitor:flag(fromPlayer.id, 'self_trade')
            return false, 'self_trade_blocked'
        end
        local ok, err = self.tradingSystem:tradeMesos(fromPlayer, toPlayer, amount)
        if not ok then return false, err end
        self.auditLog:append('player_trade', { fromPlayerId = fromPlayer.id, toPlayerId = toPlayer.id, amount = amount })
        if (tonumber(amount) or 0) >= math.max(1, math.floor(tonumber(self.economySystem.suspiciousTransactionMesos) or 1)) then
            self.exploitMonitor:flag(fromPlayer.id, 'high_value_trade')
        end
        self:_emitOpsTelemetry('player_trade', { fromPlayerId = fromPlayer.id, toPlayerId = toPlayer.id, amount = amount })
        return true
    end

    function world:listAuction(player, itemId, quantity, price)
        if not player then return false, 'invalid_player' end
        local listing = self.auctionHouse:listItem(player, itemId, quantity, price)
        self:_emitOpsTelemetry('auction_listing', {
            playerId = player.id,
            itemId = itemId,
            quantity = quantity,
            price = price,
            listingId = listing.id,
        })
        self.dailyWeeklySystem:mark(player, 'daily', 'auction:' .. tostring(itemId))
        return true, listing
    end

    function world:craftItem(player, recipeId)
        local recipe = self.gameplay.recipes[recipeId]
        if not recipe then return false, 'unknown_recipe' end
        local ok, crafted = self.craftingSystem:craft(player, recipe)
        if not ok then return false, crafted end
        self.dailyWeeklySystem:mark(player, 'daily', 'craft:' .. tostring(recipeId))
        self:publishPlayerSnapshot(player)
        return true, crafted
    end

    function world:openDialogue(npcId)
        return self.dialogueSystem:get(npcId)
    end

    function world:activateMapEvent(mapId, eventId, payload)
        return self.mapEventSystem:activate(mapId, eventId, payload)
    end

    function world:activateWorldEvent(kind, eventId)
        local active = self.worldEventSystem:activate(kind, eventId)
        for _, player in pairs(self.players or {}) do
            self.dailyWeeklySystem:mark(player, kind == 'weekly' and 'weekly' or 'daily', 'event:' .. tostring(eventId))
        end
        return active
    end

    function world:createRaid(player, bossId)
        local partyId = player.partyId or (self.partySystem:create(player).id)
        local raid = self.raidSystem:create(bossId, player, partyId)
        self.raidSystem:syncWithParty(raid.id, self)
        return raid
    end

    function world:channelTransfer(player, destinationMapId)
        local routeDecision, channel = self.channelRouter:routeDecision(destinationMapId)
        if not channel then return false, 'channel_not_found' end
        self.sessionOrchestrator:stageTransfer(player.id, {
            channelId = self.runtimeIdentity.channelId,
            runtimeInstanceId = self.runtimeIdentity.runtimeInstanceId,
            sourceMapId = player and player.currentMapId or nil,
            pendingMapId = destinationMapId,
            targetChannelId = channel.id,
            routingDecision = routeDecision,
        })
        self:_recordTruthEvent('channel_transfer_staged', {
            playerId = player and player.id or nil,
            sourceMapId = player and player.currentMapId or nil,
            targetMapId = destinationMapId,
            sourceChannelId = self.runtimeIdentity.channelId,
            targetChannelId = channel.id,
            routingDecision = deepcopy(routeDecision),
        }, {
            truthType = 'routing.channel_transfer',
            playerId = player and player.id or nil,
            mapId = destinationMapId,
        })
        return true, {
            channelId = channel.id,
            mapId = destinationMapId,
            routingDecision = routeDecision,
        }
    end

    function world:validateContent()
        return self.content.validation
    end

    function world:replayDeterminismReport()
        local events = self.journal and self.journal:snapshot() or {}
        local ok, detail = self.deterministicReplayValidator:validate(events)
        return { ok = ok, detail = detail }
    end

    function world:getStabilityReport()
        local memoryKb = collectgarbage and collectgarbage('count') or 0
        local memory = self.memoryGuard:inspect(memoryKb)
        local duplication = self.duplicationGuard:inspect(self)
        local inflation = self.inflationGuard:inspect(self.economySystem, self.auctionHouse)
        local telemetry = self.telemetryPipeline:snapshot()
        local scheduler = {
            now = self.scheduler.now,
            jobs = countTableKeys(self.scheduler.jobs),
            maxRunsPerTick = self.scheduler.maxRunsPerTick,
        }
        return {
            deterministicReplay = self:replayDeterminismReport(),
            memory = memory,
            duplication = duplication,
            inflation = inflation,
            telemetry = { counters = telemetry.counters, events = #telemetry.events },
            profiler = self.runtimeProfiler:snapshot(),
            performance = self.performanceCounters:snapshot(),
            scheduler = scheduler,
            exploitIncidents = #(self.exploitMonitor.incidents or {}),
            entityIndex = self.entityIndex:mapSummary(self.worldConfig.runtime.defaultMapId),
        }
    end

    function world:adminStatus()
        local operator = self.adminTools:getOperatorSnapshot(self)
        local status = self.adminConsole:status()
        local consistent, issues = self.consistencyValidator:validateWorld(self)
        return {
            runtime = status,
            consistent = consistent,
            issues = issues,
            policy = operator and operator.policy or nil,
            replay = self:replayDeterminismReport(),
            stability = operator and operator.stability or self:getStabilityReport(),
            performance = self.performanceCounters:snapshot(),
            batches = { queued = #self.eventBatcher.queue, flushed = #self.eventBatcher.flushed },
        }
    end

    function world:getControlPlaneReport()
        return self.adminTools:getControlPlaneReport(self)
    end

    function world:getEconomyReport()
        return {
            faucets = deepcopy(self.economySystem.faucets),
            sinks = deepcopy(self.economySystem.sinks),
            auctionListings = deepcopy(self.auctionHouse.listings),
            priceHistory = deepcopy(self.auctionHouse.priceHistory),
            priceSignals = deepcopy(self.economySystem.priceSignals),
            sinkPressure = self.economySystem.sinkPressure,
            control = self.economySystem:controlReport(),
        }
    end

    for mapId, mapConfig in pairs(worldConfig.maps or {}) do
        spawnSystem:registerMap(mapId, mapConfig.spawnGroups or {})
        world.cluster.channels[runtimeIdentity.channelId].maps[mapId] = true
    end

    local restoredWorldState, restoreErr = world:restoreWorldState()
    if restoreErr and config.allowWorldStateRestoreFailure ~= true then
        error('world_state_restore_failed:' .. tostring(restoreErr))
    end

    local runtimeCfg = worldConfig.runtime or {}
    scheduler:every('spawn_tick', tonumber(runtimeCfg.spawnTickSec) or 5, function() world:tickSpawns() end)
    scheduler:every('boss_tick', tonumber(runtimeCfg.bossTickSec) or 15, function() world:tickBosses() end)
    scheduler:every('autosave_tick', tonumber(runtimeCfg.autosaveTickSec) or 30, function() world:flushDirtyPlayers({ requireWorldSave = world.strictRuntimeBoundary }) end)
    scheduler:every('world_state_autosave_tick', tonumber(runtimeCfg.worldStateAutosaveTickSec) or 15, function() world:flushPendingWorldSave(world._pendingWorldSaveReason or 'periodic') end)
    scheduler:every('health_tick', tonumber(runtimeCfg.healthTickSec) or 30, function() healthcheck:run() end)
    scheduler:every('drop_expire_tick', tonumber(runtimeCfg.dropExpireTickSec) or 5, function() world:expireDrops() end)
    scheduler:every('world_ops_tick', 10, function()
        local startedAt = os.clock()
        local activeEntities = world.dropSystem:activeCount() + countTableKeys(world.players) + countTableKeys(world.bossSystem.encounters)
        local guardReport = world:_runStabilityGuards()
        world.runtimeProfiler:sample('players', world:getActivePlayerCount())
        world.runtimeProfiler:sample('entities', activeEntities)
        world.runtimeProfiler:sample('scheduler_jobs', countTableKeys(world.scheduler.jobs))
        world.runtimeProfiler:sample('event_queue_depth', #world.eventBatcher.queue)
        world.metricsAggregator:add('players_seen', world:getActivePlayerCount())
        world.metricsAggregator:set('active_players', world:getActivePlayerCount())
        world.metricsAggregator:set('pending_world_saves', world._pendingWorldSaveCount)
        world.metricsAggregator:set('duplicate_risk', world.pressure.duplicateRiskPressure or 0)
        world.metricsAggregator:set('reward_inflation', world.pressure.rewardInflationPressure or 0)
        world.metricsAggregator:recordSection('routing', world.channelRouter:latestDecision())
        world.metricsAggregator:recordSection('economy', world.economySystem:controlReport())
        world.metricsAggregator:recordSection('savePlan', deepcopy(world.savePlan))
        world.performanceCounters:record('entity_count', activeEntities)
        world.performanceCounters:record('combat_throughput', #world.telemetryPipeline.events)
        world.performanceCounters:record('batch_queue_depth', #world.eventBatcher.queue)
        world.performanceCounters:record('memory_kb', collectgarbage and collectgarbage('count') or 0)
        world.performanceCounters:record('scheduler_jobs', countTableKeys(world.scheduler.jobs))
        world.performanceCounters:record('duplication_issues', #(guardReport.duplication.issues or {}))
        world.performanceCounters:record('exploit_incidents', #(world.exploitMonitor.incidents or {}))
        world.snapshotManager:capture(world:snapshotWorldState(), {
            reason = 'world_ops_tick',
            savePlan = world.savePlan,
            pendingSaveCount = world._pendingWorldSaveCount,
            runtimeIdentity = world.runtimeIdentity,
        })
        world.eventBatcher:flush()
        world.runtimeProfiler:time('world_ops_tick_ms', math.floor((os.clock() - startedAt) * 1000))
    end)

    return world
end

return ServerBootstrap
