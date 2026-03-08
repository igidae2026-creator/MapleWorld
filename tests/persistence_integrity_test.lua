package.path = package.path .. ';./?.lua;../?.lua'

local RuntimeAdapter = require('ops.runtime_adapter')
local PlayerRepository = require('ops.player_repository')
local WorldRepository = require('ops.world_repository')
local ServerBootstrap = require('scripts.server_bootstrap')

-- not-found codes are treated as misses, not storage errors
local previousStorage = rawget(_G, '_DataStorageService')
_G._DataStorageService = {
    GetUserDataStorage = function()
        return {
            GetAndWait = function() return 404, nil end,
            SetAndWait = function() return 0 end,
        }
    end,
    GetSharedDataStorage = function()
        return {
            GetAndWait = function() return 1004, nil end,
            SetAndWait = function() return 0 end,
        }
    end,
}

local adapter = RuntimeAdapter.new({})
local playerRepo = PlayerRepository.newMapleWorldsDataStorage({ runtimeAdapter = adapter, storageName = 'NFPlayer', key = 'profile' })
local worldRepo = WorldRepository.newMapleWorldsDataStorage({ runtimeAdapter = adapter, storageName = 'NFWorld', key = 'state' })

local loadedPlayer, playerErr = playerRepo:load('u1')
assert(loadedPlayer == nil and playerErr == nil, 'not-found player read should be a miss, not an error')
local loadedWorld, worldErr = worldRepo:load()
assert(loadedWorld == nil and worldErr == nil, 'not-found world read should be a miss, not an error')

local detailValue, detailStatus, detailErr = playerRepo:loadDetailed('u1')
assert(detailValue == nil and detailStatus == 'not_found' and detailErr == nil, 'loadDetailed miss classification incorrect')
_G._DataStorageService = previousStorage

-- boot fails closed on world restore load errors (not only in strict-live mode)
local okBoot, errBoot = pcall(function()
    ServerBootstrap.boot('.', {
        worldRepository = {
            load = function() return nil, 'disk_offline' end,
            save = function() return true end,
        },
        playerRepository = PlayerRepository.newMemory({}),
    })
end)
assert(okBoot == false and tostring(errBoot):find('world_state_restore_failed', 1, true), 'boot did not fail closed on world load error')

-- durability boundary: dirty is only cleared when both required saves succeed and world-save failure keeps dirty true
local playerSaved = 0
local worldSaved = 0
local failWorld = true
local world = ServerBootstrap.boot('.', {
    playerRepository = {
        store = {},
        load = function(self, playerId)
            local existing = self.store[playerId]
            if existing then
                local copy = {}
                for k, v in pairs(existing) do copy[k] = v end
                return copy
            end
            return nil
        end,
        save = function(self, player)
            playerSaved = playerSaved + 1
            local copy = {}
            for k, v in pairs(player) do copy[k] = v end
            self.store[player.id] = copy
            return true
        end,
    },
    worldRepository = {
        save = function(_, _)
            worldSaved = worldSaved + 1
            if failWorld then return false, 'world_write_failed' end
            return true
        end,
        load = function() return nil end,
    },
})

local p = world:createPlayer('durable_user')
p.level = 12
p.dirty = true
local saveOk, saveErr = world:savePlayer(p, { requireWorldSave = true })
assert(saveOk == false and saveErr == 'world_write_failed', 'save should fail when required world save fails')
assert(p.dirty == true, 'player dirty flag was cleared before durability boundary success')
assert(playerSaved >= 1 and worldSaved >= 1, 'expected both player and world save attempts')

failWorld = false
local saveOk2, saveErr2 = world:savePlayer(p, { requireWorldSave = true })
assert(saveOk2 == true and saveErr2 == nil, 'save should pass once world save succeeds')
assert(p.dirty == false, 'player dirty flag should clear only after boundary save succeeds')

-- drop snapshot schema mismatch regression: dropsByMap-only snapshot remains restorable end-to-end
local persisted = {
    version = 1,
    savedAt = 42,
    boss = { encounters = {} },
    journal = { entries = {}, nextSeq = 1 },
    drops = {
        nextDropId = 13,
        dropsByMap = {
            henesys_hunting_ground = {
                { dropId = 12, mapId = 'henesys_hunting_ground', itemId = 'hp_potion', quantity = 2, expiresAt = 999999, x = 0, y = 0, z = 0 },
            },
        },
    },
}

local worldRestored = ServerBootstrap.boot('.', {
    autoPickupDrops = false,
    worldRepository = {
        load = function() return persisted end,
        save = function() return true end,
    },
    playerRepository = PlayerRepository.newMemory({}),
})
local restoredDrops = worldRestored.dropSystem:listDrops('henesys_hunting_ground')
assert(#restoredDrops == 1 and restoredDrops[1].dropId == 12, 'dropsByMap-only persisted snapshot did not restore correctly')

-- replay invariants fail closed on invalid negative mesos ledger post-state
local invalidReplaySnapshot = {
    version = 2,
    savedAt = 77,
    checkpoint = {
        checkpoint_id = 'invalid-neg-mesos',
        journal_watermark = 1,
        replay_base_revision = 0,
    },
    boss = { encounters = {} },
    drops = { nextDropId = 1, drops = {}, dropsByMap = {} },
    journal = {
        entries = {},
        ledgerEntries = {
            {
                ledger_event_id = 1,
                event_type = 'mesos_spend',
                source_system = 'economy_system',
                player_id = 'u1',
                post_state = { mesos = -5 },
            },
        },
        nextSeq = 2,
        nextLedgerEventId = 2,
    },
}

local invalidBootOk, invalidBootErr = pcall(function()
    ServerBootstrap.boot('.', {
        worldRepository = {
            load = function() return invalidReplaySnapshot end,
            save = function() return true end,
        },
        playerRepository = PlayerRepository.newMemory({}),
    })
end)
assert(invalidBootOk == false and tostring(invalidBootErr):find('negative_mesos_after_replay', 1, true), 'invalid replay state did not fail closed')

-- snapshot captures are immutable once staged
local snapshotWorld = ServerBootstrap.boot('.', {
    worldRepository = {
        load = function() return nil end,
        save = function() return true end,
    },
    playerRepository = PlayerRepository.newMemory({}),
})
local snapshotId, snapshotEntry = snapshotWorld.snapshotManager:capture({ players = { count = 1 } }, { reason = 'test' })
snapshotEntry.state.players.count = 99
local storedSnapshot = snapshotWorld.snapshotManager:get(snapshotId)
assert(storedSnapshot.state.players.count == 1, 'snapshot capture should isolate stored state from later mutation')
assert(storedSnapshot.metadata.reason == 'test', 'snapshot metadata missing')

print('persistence_integrity_test: ok')
