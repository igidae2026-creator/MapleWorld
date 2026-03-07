local ContentLoader = require('data.content_loader')

local loaded = ContentLoader.load()
local content = loaded.content
local regionalProgression = loaded.regionalProgression or {}
local rareSpawns = loaded.rareSpawns or {}

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
            chokePoints = map.chokePoints,
            mobilityAdvantageZones = map.mobilityAdvantageZones,
            sharedFarmingZones = map.sharedFarmingZones,
            lore = map.lore,
            environmentStory = map.environmentStory,
            regionProgression = regionalProgression[map.tags and map.tags[1] or ''],
            rareSpawnTable = rareSpawns[mapId],
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
            maxAlive = mob.role == 'captain' and 4 or mob.role == 'elite' and 6 or 11,
            points = {
                { x = 18 + (#map.spawnGroups * 28), y = (#map.spawnGroups % 3) * 12 },
                { x = 42 + (#map.spawnGroups * 32), y = ((#map.spawnGroups + 1) % 3) * 12 },
                { x = 68 + (#map.spawnGroups * 20), y = ((#map.spawnGroups + 2) % 3) * 12 },
            },
            terrainRole = mob.role == 'elite' and 'anchor' or 'lane_clear',
            clusterRole = mob.role == 'captain' and 'choke_anchor' or mob.role == 'elite' and 'burst_anchor' or 'swarm_lane',
            chokePoint = ((map.metadata and map.metadata.chokePoints) or {})[1],
            mobilityAdvantage = ((map.metadata and map.metadata.mobilityAdvantageZones) or {})[1],
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

runtime.cityHubs = {
    starter_fields = 'starter_fields_town_01',
    henesys_plains = 'henesys_town',
    ellinia_forest = 'ellinia_forest_town_01',
    perion_rocklands = 'perion_rocklands_town_01',
    sleepywood_depths = 'sleepywood_depths_town_01',
    kerning_city_shadow = 'kerning_city_shadow_town_01',
    orbis_skyrealm = 'orbis_skyrealm_town_01',
    ludibrium_clockwork = 'ludibrium_clockwork_town_01',
    elnath_snowfield = 'elnath_snowfield_town_01',
    minar_mountain = 'minar_mountain_town_01',
    coastal_harbors = 'coastal_harbors_town_01',
    ancient_hidden_domains = 'ancient_hidden_domains_town_01',
}

runtime.regionGraph = {
    starter_fields = { 'henesys_plains', 'coastal_harbors' },
    henesys_plains = { 'starter_fields', 'ellinia_forest', 'perion_rocklands', 'coastal_harbors' },
    ellinia_forest = { 'henesys_plains', 'orbis_skyrealm', 'sleepywood_depths' },
    perion_rocklands = { 'henesys_plains', 'kerning_city_shadow', 'sleepywood_depths' },
    sleepywood_depths = { 'ellinia_forest', 'perion_rocklands', 'ancient_hidden_domains' },
    kerning_city_shadow = { 'perion_rocklands', 'ludibrium_clockwork', 'coastal_harbors' },
    orbis_skyrealm = { 'ellinia_forest', 'elnath_snowfield', 'minar_mountain' },
    ludibrium_clockwork = { 'kerning_city_shadow', 'elnath_snowfield', 'ancient_hidden_domains' },
    elnath_snowfield = { 'orbis_skyrealm', 'ludibrium_clockwork', 'minar_mountain' },
    minar_mountain = { 'orbis_skyrealm', 'elnath_snowfield', 'ancient_hidden_domains' },
    coastal_harbors = { 'starter_fields', 'henesys_plains', 'kerning_city_shadow' },
    ancient_hidden_domains = { 'sleepywood_depths', 'ludibrium_clockwork', 'minar_mountain' },
}

runtime.starterRoutes = {
    beginner = { 'starter_fields_town_01', 'forest_edge', 'starter_fields_combat_05', 'henesys_town', 'henesys_hunting_ground' },
    warrior = { 'henesys_town', 'henesys_hunting_ground', 'perion_rocky', 'perion_rocklands_dungeon_04' },
    mage = { 'henesys_town', 'ellinia_forest_town_01', 'ellinia_forest_combat_12', 'orbis_skyrealm_combat_08' },
    rogue = { 'forest_edge', 'kerning_city_shadow_town_01', 'kerning_city_shadow_combat_10', 'ludibrium_clockwork_combat_06' },
}

runtime.recommendedHuntingMaps = {
    [1] = { 'forest_edge', 'starter_fields_combat_02', 'henesys_hunting_ground' },
    [20] = { 'coastal_harbors_combat_10', 'ellinia_forest_combat_08', 'perion_rocky' },
    [40] = { 'sleepywood_depths_combat_12', 'kerning_city_shadow_combat_14', 'perion_rocklands_dungeon_04' },
    [60] = { 'orbis_skyrealm_combat_18', 'ludibrium_clockwork_combat_16', 'sleepywood_depths_dungeon_08' },
    [80] = { 'elnath_snowfield_combat_20', 'minar_mountain_combat_18', 'orbis_skyrealm_dungeon_10' },
    [100] = { 'minar_mountain_dungeon_12', 'ancient_hidden_domains_combat_22', 'ancient_hidden_domains_hidden_01' },
}

runtime.bossAccessConditions = {
    mano = { minLevel = 18, prerequisiteQuest = 'q_mano_hunt', accessMap = 'forest_edge' },
    stumpy = { minLevel = 30, prerequisiteQuest = 'dbexp_perion_rocklands_quest_040', accessMap = 'perion_rocky' },
    starter_fields_apex = { minLevel = 22, prerequisiteQuest = 'dbexp_starter_fields_quest_060', accessMap = 'starter_fields_dungeon_16' },
    henesys_plains_apex = { minLevel = 30, prerequisiteQuest = 'dbexp_henesys_plains_quest_060', accessMap = 'henesys_plains_dungeon_16' },
    ellinia_forest_apex = { minLevel = 44, prerequisiteQuest = 'dbexp_ellinia_forest_quest_060', accessMap = 'ellinia_forest_dungeon_16' },
    ancient_hidden_domains_apex = { minLevel = 118, prerequisiteQuest = 'dbexp_ancient_hidden_domains_quest_060', accessMap = 'ancient_hidden_domains_hidden_03' },
}

runtime.hiddenMapTriggers = {
    starter_fields = { triggerMap = 'starter_fields_dungeon_16', revealMap = 'starter_fields_hidden_01', requirement = 'dbexp_starter_fields_quest_048' },
    henesys_plains = { triggerMap = 'henesys_plains_dungeon_16', revealMap = 'henesys_plains_hidden_01', requirement = 'dbexp_henesys_plains_quest_048' },
    ellinia_forest = { triggerMap = 'ellinia_forest_dungeon_16', revealMap = 'ellinia_forest_hidden_01', requirement = 'dbexp_ellinia_forest_quest_048' },
    perion_rocklands = { triggerMap = 'perion_rocklands_dungeon_16', revealMap = 'perion_rocklands_hidden_01', requirement = 'dbexp_perion_rocklands_quest_048' },
    sleepywood_depths = { triggerMap = 'sleepywood_depths_dungeon_16', revealMap = 'sleepywood_depths_hidden_01', requirement = 'dbexp_sleepywood_depths_quest_048' },
    kerning_city_shadow = { triggerMap = 'kerning_city_shadow_dungeon_16', revealMap = 'kerning_city_shadow_hidden_01', requirement = 'dbexp_kerning_city_shadow_quest_048' },
    orbis_skyrealm = { triggerMap = 'orbis_skyrealm_dungeon_16', revealMap = 'orbis_skyrealm_hidden_01', requirement = 'dbexp_orbis_skyrealm_quest_048' },
    ludibrium_clockwork = { triggerMap = 'ludibrium_clockwork_dungeon_16', revealMap = 'ludibrium_clockwork_hidden_01', requirement = 'dbexp_ludibrium_clockwork_quest_048' },
    elnath_snowfield = { triggerMap = 'elnath_snowfield_dungeon_16', revealMap = 'elnath_snowfield_hidden_01', requirement = 'dbexp_elnath_snowfield_quest_048' },
    minar_mountain = { triggerMap = 'minar_mountain_dungeon_16', revealMap = 'minar_mountain_hidden_01', requirement = 'dbexp_minar_mountain_quest_048' },
    coastal_harbors = { triggerMap = 'coastal_harbors_dungeon_16', revealMap = 'coastal_harbors_hidden_01', requirement = 'dbexp_coastal_harbors_quest_048' },
    ancient_hidden_domains = { triggerMap = 'ancient_hidden_domains_dungeon_16', revealMap = 'ancient_hidden_domains_hidden_01', requirement = 'dbexp_ancient_hidden_domains_quest_048' },
}

runtime.questChainReferences = {
    starter_fields = { first = 'dbexp_starter_fields_quest_001', mid = 'dbexp_starter_fields_quest_033', climax = 'dbexp_starter_fields_quest_060' },
    henesys_plains = { first = 'dbexp_henesys_plains_quest_001', mid = 'dbexp_henesys_plains_quest_033', climax = 'dbexp_henesys_plains_quest_060' },
    ellinia_forest = { first = 'dbexp_ellinia_forest_quest_001', mid = 'dbexp_ellinia_forest_quest_033', climax = 'dbexp_ellinia_forest_quest_060' },
    perion_rocklands = { first = 'dbexp_perion_rocklands_quest_001', mid = 'dbexp_perion_rocklands_quest_033', climax = 'dbexp_perion_rocklands_quest_060' },
    sleepywood_depths = { first = 'dbexp_sleepywood_depths_quest_001', mid = 'dbexp_sleepywood_depths_quest_033', climax = 'dbexp_sleepywood_depths_quest_060' },
    kerning_city_shadow = { first = 'dbexp_kerning_city_shadow_quest_001', mid = 'dbexp_kerning_city_shadow_quest_033', climax = 'dbexp_kerning_city_shadow_quest_060' },
    orbis_skyrealm = { first = 'dbexp_orbis_skyrealm_quest_001', mid = 'dbexp_orbis_skyrealm_quest_033', climax = 'dbexp_orbis_skyrealm_quest_060' },
    ludibrium_clockwork = { first = 'dbexp_ludibrium_clockwork_quest_001', mid = 'dbexp_ludibrium_clockwork_quest_033', climax = 'dbexp_ludibrium_clockwork_quest_060' },
    elnath_snowfield = { first = 'dbexp_elnath_snowfield_quest_001', mid = 'dbexp_elnath_snowfield_quest_033', climax = 'dbexp_elnath_snowfield_quest_060' },
    minar_mountain = { first = 'dbexp_minar_mountain_quest_001', mid = 'dbexp_minar_mountain_quest_033', climax = 'dbexp_minar_mountain_quest_060' },
    coastal_harbors = { first = 'dbexp_coastal_harbors_quest_001', mid = 'dbexp_coastal_harbors_quest_033', climax = 'dbexp_coastal_harbors_quest_060' },
    ancient_hidden_domains = { first = 'dbexp_ancient_hidden_domains_quest_001', mid = 'dbexp_ancient_hidden_domains_quest_033', climax = 'dbexp_ancient_hidden_domains_quest_060' },
}

runtime.csvRegistry = {
    maps = 'data/maps.csv',
    mobs = 'data/mobs.csv',
    bosses = 'data/boss.csv',
    items = 'data/items.csv',
    quests = 'data/quests.csv',
    drops = 'data/drops.csv',
    npcs = 'data/npcs.csv',
    dialogues = 'data/dialogues.csv',
}

return runtime
