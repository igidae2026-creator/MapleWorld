package.path = package.path .. ';./?.lua;../?.lua'

local EventJournal = require('ops.event_journal')
local ServerBootstrap = require('scripts.server_bootstrap')
local RuntimeAdapter = require('ops.runtime_adapter')
local WorldRepository = require('ops.world_repository')

-- journal trimming cap
local journal = EventJournal.new({ maxEntries = 3, time = function() return 0 end })
for i = 1, 5 do
    journal:append('evt', { i = i })
end
local entries = journal:snapshot()
assert(#entries == 3, 'journal cap did not trim to 3 entries')
assert(entries[1].seq == 3 and entries[3].seq == 5, 'journal cap did not preserve tail entries')

-- save amplification reduction via debounce
local saveCount = 0
local saveRepo = {
    save = function(_, _)
        saveCount = saveCount + 1
        return true
    end,
    load = function()
        return nil
    end,
}

local now = 1000
local world = ServerBootstrap.boot('.', {
    time = function() return now end,
    rng = function() return 0 end,
    worldRepository = saveRepo,
    worldConfig = {
        runtime = {
            defaultMapId = 'henesys_hunting_ground',
            worldStateAutosaveTickSec = 15,
            worldStateSaveDebounceSec = 5,
            journalMaxEntries = 100,
            persistedJournalEntries = 50,
            persistedDropsPerMap = 20,
            autoPickupDrops = false,
        },
        combat = {},
        actionBoundaries = {},
        actionRateLimits = {},
        maps = {
            henesys_hunting_ground = { spawnPosition = { x = 0, y = 0, z = 0 }, spawnGroups = {} },
        },
        bosses = {},
        drops = {},
        quests = { npcBindings = {} },
    },
})

for i = 1, 10 do
    world.journal:append('hot_evt', { i = i })
end
assert(saveCount == 1, 'journal append path still saves world for every append')
now = now + 16
world.scheduler:tick(16)
assert(saveCount >= 2, 'periodic autosave did not flush pending state')

-- writer owner guard + revision retention cap
local previousStorage = rawget(_G, '_DataStorageService')
_G._DataStorageService = {
    _stores = {},
    GetSharedDataStorage = function(self, storageName)
        local storageKey = tostring(storageName)
        self._stores[storageKey] = self._stores[storageKey] or {}
        local store = self._stores[storageKey]
        return {
            GetAndWait = function(_, key)
                return 0, store[key]
            end,
            SetAndWait = function(_, key, value)
                store[key] = value
                return 0
            end,
        }
    end,
    GetUserDataStorage = function(self, storageName, userId)
        local storageKey = tostring(storageName) .. ':' .. tostring(userId)
        self._stores[storageKey] = self._stores[storageKey] or {}
        local store = self._stores[storageKey]
        return {
            GetAndWait = function(_, key)
                return 0, store[key]
            end,
            SetAndWait = function(_, key, value)
                store[key] = value
                return 0
            end,
        }
    end,
}

local adapter = RuntimeAdapter.new({})
local repoA = WorldRepository.newMapleWorldsDataStorage({
    runtimeAdapter = adapter,
    storageName = 'TestWorldState',
    key = 'state',
    maxRevisions = 2,
    writerOwnerId = 'instanceA',
    writerEpoch = 1,
})
local repoB = WorldRepository.newMapleWorldsDataStorage({
    runtimeAdapter = adapter,
    storageName = 'TestWorldState',
    key = 'state',
    maxRevisions = 2,
    writerOwnerId = 'instanceB',
    writerEpoch = 1,
})

for i = 1, 4 do
    local ok, err = repoA:save({ version = i })
    assert(ok, 'repoA save failed: ' .. tostring(err))
end

local rawStore = _G._DataStorageService._stores['TestWorldState']
assert(rawStore['state__rev_1'] == '', 'old world revision was not trimmed under maxRevisions cap')

local okB, errB = repoB:save({ version = 'from_b' })
assert(okB == false and errB == 'world_owner_conflict', 'writer owner guard did not reject competing writer')

_G._DataStorageService = previousStorage


-- recovery journal deduplicates duplicated sequence numbers
local restoreJournal = EventJournal.new({ maxEntries = 10, time = function() return 0 end })
restoreJournal:restore({
    entries = {
        { seq = 1, at = 1, event = 'a', payload = {} },
        { seq = 1, at = 2, event = 'b', payload = {} },
        { seq = 2, at = 3, event = 'c', payload = {} },
    },
    nextSeq = 2,
})
local restored = restoreJournal:snapshot()
assert(#restored == 2, 'journal restore did not dedupe duplicate sequence numbers')
assert(restored[1].event == 'b' and restored[2].event == 'c', 'journal restore did not keep latest duplicate sequence entry')
assert(restoreJournal.nextSeq == 3, 'journal restore nextSeq was not normalized after dedupe')

print('storage_guardrails_test: ok')
