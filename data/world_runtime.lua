local ContentLoader = require('data.content_loader')

local loaded = ContentLoader.load()
local content = loaded.content

local runtime = {
    runtime = {
        defaultMapId = 'henesys_town',
        componentAttachPath = '/server_runtime',
        spawnTickSec = 4,
        bossTickSec = 12,
        autosaveTickSec = 20,
        healthTickSec = 20,
        dropExpireTickSec = 5,
        dropExpireSec = 120,
        dropOwnerWindowSec = 3,
        maxWorldDropsPerMap = 400,
        worldStateAutosaveTickSec = 12,
        playerStorageName = 'MapleWorldPlayerState',
        playerStorageKey = 'profile',
        playerProfileSlotCount = 3,
        worldStorageName = 'MapleWorldState',
        worldStorageKey = 'state',
        worldStateSlotCount = 5,
        persistedDropsPerMap = 180,
        persistedJournalEntries = 4000,
        journalMaxEntries = 12000,
        journalMaxPayloadBytes = 4096,
        ledgerMaxEntries = 40000,
        worldStateSaveDebounceSec = 3,
        saveReplayAnchorThreshold = 1,
        worldRevisionRetention = 64,
        worldCommitRetention = 128,
        playerRevisionRetention = 24,
        worldWriterLeaseSec = 45,
        worldWriterOwnerId = 'control-plane',
        worldWriterEpoch = 2,
        coordinatorEpoch = 2,
        worldId = 'world-alpha',
        channelId = 'channel-1',
        runtimeInstanceId = 'runtime-alpha-1',
        topologyMode = 'world_cluster_capable',
        policyBundleId = 'mapleworld.upper-bound',
        policyBundleVersion = '2.0.0',
        policyBundleClass = 'expansion',
        pressureDensityThreshold = 0.9,
        pressureSaveBacklogThreshold = 80,
        pressureRewardInflationThreshold = 16,
        pressureReplayThreshold = 1,
        pressureInstabilityThreshold = 3,
        pressureLowDiversityThreshold = 6,
        pressureOwnershipConflictThreshold = 1,
        pressureDuplicateRiskThreshold = 1,
        pressureFarmRepetitionThreshold = 10,
        safeModeSeverityThreshold = 3,
        rewardQuarantineSeverityThreshold = 2,
        migrationBlockSeverityThreshold = 2,
        persistenceQuarantineSeverityThreshold = 3,
        replayOnlySeverityThreshold = 4,
        autoPickupDrops = true,
        defaultBossUniquenessScope = 'channel_unique',
        suspiciousTransactionMesos = 7500000,
        maxPlayerEconomyLedgerEntries = 96,
    },
    combat = {
        minimumDamage = 1,
        mobDamageCapFactor = 7.0,
        bossDamageCapFactor = 4.5,
        bossDamageMaxHpFactor = 0.12,
        mobDamageMinCap = 14,
        bossDamageMinCap = 0,
        mobDamageFloorPerLevel = 4,
        bossDamageFloorPerLevel = 9,
    },
    actionBoundaries = {
        mobAttackRange = 56,
        bossAttackRange = 72,
        dropPickupRange = 40,
        questNpcRange = 36,
    },
    mapTransitions = {},
    actionRateLimits = {
        mob_attack = { tokens = 14, recharge = 8 },
        boss_attack = { tokens = 28, recharge = 8 },
        drop_pickup = { tokens = 10, recharge = 6 },
        equip = { tokens = 8, recharge = 5 },
        shop = { tokens = 6, recharge = 3 },
        quest = { tokens = 6, recharge = 3 },
        map_change = { tokens = 6, recharge = 2 },
        skill_cast = { tokens = 12, recharge = 8 },
        social = { tokens = 20, recharge = 12 },
        market = { tokens = 10, recharge = 8 },
    },
    maps = {},
    bosses = {},
    drops = {
        defaultModelId = 'item/red_potion',
        modelIds = {},
    },
    quests = {
        npcBindings = {},
    },
}

for mapId, map in pairs(content.maps or {}) do
    runtime.mapTransitions[mapId] = map.transitions or {}
    runtime.maps[mapId] = {
        recommended_level = map.recommended_level,
        spawnPosition = map.spawnPosition,
        spawnGroups = {},
        metadata = {
            huntingRole = map.huntingRole,
            terrainStrategy = map.terrainStrategy,
            verticalLayers = map.verticalLayers,
            movementRoutes = map.movementRoutes,
            socialHotspots = map.socialHotspots,
            lore = map.lore,
        },
        runtime = {
            mobParentPath = '/server_runtime/' .. mapId .. '/mobs',
            bossParentPath = '/server_runtime/' .. mapId .. '/bosses',
            dropParentPath = '/server_runtime/' .. mapId .. '/drops',
            mobModelIds = {},
        },
    }
end

for mobId, mob in pairs(content.mobs or {}) do
    local map = runtime.maps[mob.map_pool]
    if map then
        map.spawnGroups[#map.spawnGroups + 1] = {
            id = mobId .. '_group',
            mobId = mobId,
            maxAlive = mob.role == 'elite' and 5 or 10,
            points = {
                { x = 18 + (#map.spawnGroups * 28), y = (#map.spawnGroups % 3) * 12 },
                { x = 42 + (#map.spawnGroups * 32), y = ((#map.spawnGroups + 1) % 3) * 12 },
                { x = 68 + (#map.spawnGroups * 20), y = ((#map.spawnGroups + 2) % 3) * 12 },
            },
            terrainRole = mob.role == 'elite' and 'anchor' or 'lane_clear',
        }
        map.runtime.mobModelIds[mobId] = mob.asset_key
    end
end

for bossId, boss in pairs(content.bosses or {}) do
    runtime.bosses[bossId] = {
        modelId = boss.asset_key,
        parentPath = '/server_runtime/' .. boss.map_id .. '/bosses',
        spawnPosition = { x = 96, y = 0, z = 0 },
        uniqueness = boss.uniqueness or 'channel_unique',
    }
end

for itemId, item in pairs(content.items or {}) do
    runtime.drops.modelIds[itemId] = item.asset_key
end

for npcId, npc in pairs(content.npcs or {}) do
    runtime.quests.npcBindings[npcId] = {
        mapId = npc.map_id,
        x = npc.x,
        y = npc.y,
        z = npc.z,
        shopId = npc.shopId,
        catalog = npc.catalog,
    }
end

return runtime
