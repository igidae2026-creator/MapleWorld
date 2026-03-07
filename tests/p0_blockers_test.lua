package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')
local RuntimeAdapter = require('ops.runtime_adapter')
local PlayerRepository = require('ops.player_repository')

-- equip ordering / no duplicate on bad instance
local world = ServerBootstrap.boot('.')
local player = world:createPlayer('p0_equip')
assert(world.itemSystem:addItem(player, 'sword_bronze', 1), 'seed equip A failed')
assert(world.itemSystem:addItem(player, 'sword_bronze', 1), 'seed equip B failed')
local first = player.inventory.sword_bronze.instances[1].instanceId
local second = player.inventory.sword_bronze.instances[2].instanceId
assert(world:equipItem(player, 'sword_bronze', first), 'initial equip failed')
local ok, err = world:equipItem(player, 'sword_bronze', 'bogus_instance')
assert(not ok and err == 'instance_not_found', 'bogus instance did not fail safely')
assert(player.equipment.weapon and player.equipment.weapon.instanceId == first, 'equipped item changed on failed equip')
assert(player.inventory.sword_bronze and player.inventory.sword_bronze.quantity == 1 and player.inventory.sword_bronze.instances[1].instanceId == second, 'inventory duplicated or corrupted after failed equip')


-- failed equip with stale/foreign instanceId leaves state unchanged
local integrity = world:createPlayer('p0_integrity')
integrity.level = 40
assert(world.itemSystem:addItem(integrity, 'sword_bronze', 1), 'seed bronze failed')
assert(world.itemSystem:addItem(integrity, 'stumpy_axe', 1), 'seed axe failed')
local bronzeId = integrity.inventory.sword_bronze.instances[1].instanceId
local axeId = integrity.inventory.stumpy_axe.instances[1].instanceId
assert(world:equipItem(integrity, 'sword_bronze', bronzeId), 'integrity initial equip failed')
local inventoryBefore = world.itemSystem:exportInventory(integrity)
local equippedBefore = integrity.equipment.weapon and integrity.equipment.weapon.instanceId
local badOk, badErr = world:equipItem(integrity, 'sword_bronze', axeId)
assert(not badOk and badErr == 'instance_not_found', 'foreign instanceId did not fail closed')
assert(integrity.equipment.weapon and integrity.equipment.weapon.instanceId == equippedBefore, 'equip slot mutated after failed foreign-instance equip')
local inventoryAfter = world.itemSystem:exportInventory(integrity)
assert(inventoryAfter.sword_bronze and inventoryAfter.sword_bronze.quantity == (inventoryBefore.sword_bronze and inventoryBefore.sword_bronze.quantity or 0), 'sword quantity changed after failed equip')
assert(inventoryAfter.stumpy_axe and inventoryAfter.stumpy_axe.quantity == (inventoryBefore.stumpy_axe and inventoryBefore.stumpy_axe.quantity or 0), 'axe quantity changed after failed equip')
local seen = {}
for _, entry in pairs(inventoryAfter) do
    if type(entry.instances) == 'table' then
        for _, inst in ipairs(entry.instances) do
            assert(not seen[inst.instanceId], 'duplicate instance found in inventory after failed equip')
            seen[inst.instanceId] = true
        end
    end
end
assert(not seen[integrity.equipment.weapon.instanceId], 'equipped instance also present in inventory after failed equip')

-- authority boundaries for map and npc actions
local traveler = world:createPlayer('p0_authority')
local changed, changedErr = world:changeMap(traveler, 'forest_edge', 'henesys_hunting_ground')
assert(changed and not changedErr, 'valid map change failed')
local denied, deniedErr = world:changeMap(traveler, 'henesys_hunting_ground', 'ant_tunnel_1')
assert(not denied and deniedErr == 'wrong_map', 'map source validation failed')
local invalidMap, invalidMapErr = world:changeMap(traveler, 'bogus_map', 'forest_edge')
assert(not invalidMap and invalidMapErr == 'invalid_map', 'invalid destination map allowed')

local shopBuyer = world:createPlayer('p0_shop')
assert(world.economySystem:grantMesos(shopBuyer, 1000, 'seed'), 'seed mesos failed')
local buyOk = world:buyFromNpc(shopBuyer, 'Rina', 'hp_potion', 1)
assert(buyOk, 'valid npc buy failed')
local remoteBuy, remoteBuyErr = world:buyFromNpc(shopBuyer, 'Chief_Stan', 'hp_potion', 1)
assert(not remoteBuy and remoteBuyErr == 'wrong_map', 'remote npc buy allowed')
local badNpcBuy, badNpcErr = world:buyFromNpc(shopBuyer, 'BogusNpc', 'hp_potion', 1)
assert(not badNpcBuy and (badNpcErr == 'npc_not_found' or badNpcErr == 'invalid_npc'), 'invalid npc buy allowed')

-- world drop snapshot/restore schema compatibility
local t = 5000
local persistentWorldRepo = { state = nil,
    save = function(self, state) self.state = state return true end,
    load = function(self) return self.state end,
}
local worldA = ServerBootstrap.boot('.', {
    autoPickupDrops = false,
    rng = function() return 0 end,
    time = function() return t end,
    worldRepository = persistentWorldRepo,
    playerRepository = PlayerRepository.newMemory({}),
})
local p = worldA:createPlayer('p0_drops')
worldA.scheduler:tick(5)
local spawnId = next(worldA.spawnSystem.maps['henesys_hunting_ground'].active)
assert(spawnId, 'missing spawn for drop persistence')
assert(worldA:attackMob(p, 'henesys_hunting_ground', spawnId, 999), 'drop persistence kill failed')
assert(worldA:saveWorldState('p0_drop_schema'), 'drop persistence save failed')
local worldB = ServerBootstrap.boot('.', {
    autoPickupDrops = false,
    rng = function() return 0 end,
    time = function() return t end,
    worldRepository = persistentWorldRepo,
    playerRepository = PlayerRepository.newMemory({}),
})
assert(#worldB.dropSystem:listDrops('henesys_hunting_ground') >= 1, 'persisted drops lost on restore')

-- fail closed on repository load failure
local previousStorage = rawget(_G, '_DataStorageService')
_G._DataStorageService = {
    GetUserDataStorage = function()
        return {
            GetAndWait = function() error('read_failure') end,
            SetAndWait = function() return 0 end,
        }
    end,
}
local adapter = RuntimeAdapter.new({})
local failingRepo = PlayerRepository.newMapleWorldsDataStorage({ runtimeAdapter = adapter, storageName = 'FailingStorage', key = 'profile' })
local worldFail = ServerBootstrap.boot('.', { playerRepository = failingRepo })
local failedPlayer, failErr = worldFail:createPlayer('cannot_load')
assert(failedPlayer == nil and failErr ~= nil, 'load failure did not fail closed')
assert(worldFail.players['cannot_load'] == nil, 'blank player state was created after load failure')
_G._DataStorageService = previousStorage



-- drop restore supports map-bucket schema and capped snapshots remain restorable
local dropSystem = require('scripts.drop_system').new({ time = function() return t end })
dropSystem:restore({
    nextDropId = 42,
    dropsByMap = {
        henesys_hunting_ground = {
            { dropId = 21, mapId = 'henesys_hunting_ground', itemId = 'hp_potion', quantity = 1, expiresAt = t + 30, x = 0, y = 0, z = 0 },
        },
    },
})
local restoredDrop = dropSystem:getDrop(21)
assert(restoredDrop and restoredDrop.mapId == 'henesys_hunting_ground', 'dropsByMap schema did not restore active drop')
assert(dropSystem.nextDropId == 42, 'dropsByMap schema lost nextDropId')

-- do not unload dirty players when persistence fails on leave
local worldSaveFail = ServerBootstrap.boot('.', {
    playerRepository = {
        load = function() return nil end,
        save = function() return false, 'disk_down' end,
    },
})
local unsaved = worldSaveFail:createPlayer('p0_leave_fail')
unsaved.dirty = true
local left, leaveErr = worldSaveFail:onPlayerLeave('p0_leave_fail')
assert(left == false and leaveErr == 'disk_down', 'player leave should fail when save durability fails')
assert(worldSaveFail.players['p0_leave_fail'] ~= nil, 'dirty player was removed despite save failure')

-- live boot fails closed when world-state restore load errors
local liveAdapter = RuntimeAdapter.new({
    contextProvider = function()
        return { isServer = true, live = true, phase = 'server' }
    end,
})
local liveBootOk, liveBootErr = pcall(function()
    ServerBootstrap.boot('.', {
        runtimeAdapter = liveAdapter,
        worldRepository = {
            load = function() return nil, 'world_read_failure' end,
            save = function() return true end,
        },
        playerRepository = PlayerRepository.newMemory({}),
    })
end)
assert(liveBootOk == false and tostring(liveBootErr):find('world_state_restore_failed', 1, true), 'live restore load error did not fail closed at boot')

print('p0_blockers_test: ok')
