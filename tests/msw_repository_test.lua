package.path = package.path .. ';./?.lua;../?.lua'
local PlayerRepository = require('ops.player_repository')
local RuntimeAdapter = require('ops.runtime_adapter')

local previousStorage = rawget(_G, '_DataStorageService')
_G._DataStorageService = {
    _stores = {},
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
local repo = PlayerRepository.newMapleWorldsDataStorage({
    runtimeAdapter = adapter,
    storageName = 'TestStorage',
    key = 'profile',
})

local player = {
    id = 'msw_user',
    level = 7,
    mesos = 321,
    inventory = {
        hp_potion = { itemId = 'hp_potion', quantity = 3, enhancement = 0 },
    },
    equipment = {},
    questState = {},
    killLog = {},
    flags = {},
    version = 2,
}

assert(repo:save(player), 'msw storage save failed')
local loaded = repo:load('msw_user')
assert(type(loaded) == 'table', 'msw storage load returned nil')
assert(loaded.level == 7 and loaded.mesos == 321, 'msw storage roundtrip corrupted player state')
assert(loaded.inventory.hp_potion.quantity == 3, 'msw storage roundtrip lost inventory')

player.level = 8
assert(repo:save(player), 'msw storage second save failed')

local storageKey = 'TestStorage:msw_user'
local rawStore = _G._DataStorageService._stores[storageKey]
assert(type(rawStore) == 'table', 'test storage unavailable')
rawStore['profile__head'] = nil

local recovered = repo:load('msw_user')
assert(type(recovered) == 'table' and recovered.level == 8, 'msw storage failed to recover from head history')

_G._DataStorageService = previousStorage
print('msw_repository_test: ok')
