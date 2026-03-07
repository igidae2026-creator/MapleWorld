return {
    runtime = {
        defaultMapId = 'henesys_hunting_ground',
        componentAttachPath = '/server_runtime',
        spawnTickSec = 5,
        bossTickSec = 15,
        autosaveTickSec = 30,
        healthTickSec = 30,
        dropExpireTickSec = 5,
        dropExpireSec = 90,
        dropOwnerWindowSec = 2,
        maxWorldDropsPerMap = 250,
        worldStateAutosaveTickSec = 15,
        playerStorageName = 'GenesisPlayerState',
        playerStorageKey = 'profile',
        playerProfileSlotCount = 2,
        worldStorageName = 'GenesisWorldState',
        worldStorageKey = 'state',
        worldStateSlotCount = 3,
        persistedDropsPerMap = 120,
        persistedJournalEntries = 0,
        journalMaxEntries = 0,
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
    actionRateLimits = {
        mob_attack = { tokens = 12, recharge = 8 },
        boss_attack = { tokens = 24, recharge = 8 },
        drop_pickup = { tokens = 8, recharge = 6 },
        equip = { tokens = 6, recharge = 4 },
        shop = { tokens = 4, recharge = 2 },
        quest = { tokens = 4, recharge = 2 },
        map_change = { tokens = 4, recharge = 1.5 },
    },
    maps = {
        henesys_hunting_ground = {
            spawnPosition = { x = 20, y = 0, z = 0 },
            spawnGroups = {
                { id='group_snail', mobId='snail', maxAlive=12, points={{x=10,y=0},{x=35,y=0},{x=60,y=0}} },
                { id='group_mushroom', mobId='orange_mushroom', maxAlive=8, points={{x=120,y=0},{x=145,y=0}} },
            },
            runtime = {
                mobParentPath = '/server_runtime/henesys_hunting_ground/mobs',
                dropParentPath = '/server_runtime/henesys_hunting_ground/drops',
                mobModelIds = {
                    snail = 'mob/snail',
                    orange_mushroom = 'mob/orange_mushroom',
                },
            },
        },
        ant_tunnel_1 = {
            spawnPosition = { x = 28, y = 0, z = 0 },
            spawnGroups = {
                { id='group_horny', mobId='horny_mushroom', maxAlive=10, points={{x=20,y=0},{x=90,y=0}} },
                { id='group_zombie', mobId='zombie_mushroom', maxAlive=6, points={{x=130,y=0},{x=190,y=0}} },
            },
            runtime = {
                mobParentPath = '/server_runtime/ant_tunnel_1/mobs',
                dropParentPath = '/server_runtime/ant_tunnel_1/drops',
                mobModelIds = {
                    horny_mushroom = 'mob/horny_mushroom',
                    zombie_mushroom = 'mob/zombie_mushroom',
                },
            },
        },
        forest_edge = {
            spawnPosition = { x = 80, y = 0, z = 0 },
            spawnGroups = {},
            runtime = {
                bossParentPath = '/server_runtime/forest_edge/bosses',
                dropParentPath = '/server_runtime/forest_edge/drops',
            },
        },
        perion_rocky = {
            spawnPosition = { x = 110, y = 0, z = 0 },
            spawnGroups = {},
            runtime = {
                bossParentPath = '/server_runtime/perion_rocky/bosses',
                dropParentPath = '/server_runtime/perion_rocky/drops',
            },
        },
    },
    bosses = {
        mano = {
            modelId = 'boss/mano',
            parentPath = '/server_runtime/forest_edge/bosses',
            spawnPosition = { x = 80, y = 0, z = 0 },
        },
        stumpy = {
            modelId = 'boss/stumpy',
            parentPath = '/server_runtime/perion_rocky/bosses',
            spawnPosition = { x = 110, y = 0, z = 0 },
        },
    },
    drops = {
        defaultModelId = 'item/red_potion',
        modelIds = {
            snail_shell = 'item/snail_shell',
            mushroom_spore = 'item/mushroom_spore',
            red_potion = 'item/red_potion',
            hp_potion = 'item/hp_potion',
            wooden_armor = 'item/wooden_armor',
            mushcap_hat = 'item/mushcap_hat',
            zombie_glove = 'item/zombie_glove',
            mano_shell = 'item/mano_shell',
            sword_bronze = 'item/sword_bronze',
            stumpy_axe = 'item/stumpy_axe',
        },
    },
    quests = {
        npcBindings = {
            Rina = { mapId = 'henesys_hunting_ground', x = 20, y = 0, z = 0 },
            Sera = { mapId = 'henesys_hunting_ground', x = 20, y = 0, z = 0 },
            Chief_Stan = { mapId = 'forest_edge', x = 80, y = 0, z = 0 },
        },
    },
}
