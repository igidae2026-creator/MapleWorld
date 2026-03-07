package.path = package.path .. ';./?.lua;../?.lua'

local EventJournal = require('ops.event_journal')
local ServerBootstrap = require('scripts.server_bootstrap')
local RuntimeAdapter = require('ops.runtime_adapter')
local WorldRepository = require('ops.world_repository')
local PlayerRepository = require('ops.player_repository')

-- journal trimming cap
local journal = EventJournal.new({ maxEntries = 3, time = function() return 0 end })
for i = 1, 5 do
    journal:append('evt', { i = i })
end
local entries = journal:snapshot()
assert(#entries == 3, 'journal cap did not trim to 3 entries')
assert(entries[1].seq == 3 and entries[3].seq == 5, 'journal cap did not preserve tail entries')


-- journal payload clamp
local payloadJournal = EventJournal.new({ maxEntries = 5, maxPayloadBytes = 32, time = function() return 0 end })
payloadJournal:append('evt', { massive = string.rep('x', 400), keep = 'ok' })
local clamped = payloadJournal:latest()
assert(clamped.payload.truncated == true, 'journal payload should be truncated under payload cap')

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
assert(saveCount == 0, 'journal append path should defer world saves in hot paths')
now = now + 16
world.scheduler:tick(16)
assert(saveCount >= 1, 'periodic autosave did not flush pending state')

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
    writerLeaseSec = 20,
    maxCommits = 2,
})
local repoB = WorldRepository.newMapleWorldsDataStorage({
    runtimeAdapter = adapter,
    storageName = 'TestWorldState',
    key = 'state',
    maxRevisions = 2,
    writerOwnerId = 'instanceB',
    writerEpoch = 1,
    writerLeaseSec = 20,
    maxCommits = 2,
})


local repoC = WorldRepository.newMapleWorldsDataStorage({
    runtimeAdapter = adapter,
    storageName = 'TestWorldState',
    key = 'state',
    maxRevisions = 2,
    writerOwnerId = 'instanceC',
    writerEpoch = 0,
    writerLeaseSec = 20,
    maxCommits = 2,
})

for i = 1, 4 do
    local ok, err = repoA:save({ version = i })
    assert(ok, 'repoA save failed: ' .. tostring(err))
end

local rawStore = _G._DataStorageService._stores['TestWorldState']
assert(rawStore['state__rev_1'] == '', 'old world revision was not trimmed under maxRevisions cap')
assert(rawStore['state__commit_1'] == '', 'old world commit marker was not trimmed under maxCommits cap')

local okB, errB = repoB:save({ version = 'from_b' })
assert(okB == false and (errB == 'world_owner_conflict' or errB == 'world_owner_epoch_conflict'), 'writer owner guard did not reject competing writer')

local okC, errC = repoC:save({ version = 'from_c' })
assert(okC == false and errC == 'world_owner_epoch_stale', 'stale writer epoch was not rejected')


-- player repository guardrails: head conflict + commit retention
local playerRepo = PlayerRepository.newMapleWorldsDataStorage({
    runtimeAdapter = adapter,
    storageName = 'TestPlayerState',
    key = 'profile',
    maxRevisions = 2,
    maxCommits = 2,
})
for i = 1, 4 do
    local ok, err = playerRepo:save({ id = 'player_guard', version = i })
    assert(ok, 'player repo save failed: ' .. tostring(err))
end
local playerStore = _G._DataStorageService._stores['TestPlayerState:player_guard']
assert(playerStore['profile__rev_1'] == '', 'old player revision was not trimmed under maxRevisions cap')
assert(playerStore['profile__commit_1'] == '', 'old player commit marker was not trimmed under maxCommits cap')

playerStore['profile__head'] = adapter:encodeData({ revision = 999, slot = 1 })
local conflictOk, conflictErr = playerRepo:save({ id = 'player_guard', version = 5 })
assert(conflictOk == false and conflictErr == 'player_head_conflict', 'player head conflict guard did not fail closed')

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
