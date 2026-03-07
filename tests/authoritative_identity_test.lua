package.path = package.path .. ';./?.lua;../?.lua'
local WorldServerBridge = require('msw.world_server_bridge')

local previousStorage = rawget(_G, '_DataStorageService')
local previousUserService = rawget(_G, '_UserService')

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

local entities = {}
local function runtimeEntity(userId, mapId, position)
    return setmetatable({
        __runtime_authoritative = true,
        PlayerComponent = { UserId = tostring(userId) },
        CurrentMapName = mapId,
        TransformComponent = { Position = position or { x = 20, y = 0, z = 0 } },
    }, { __name = 'RuntimeEntity' })
end

entities.runtime_user = runtimeEntity('runtime_user', 'henesys_hunting_ground', { x = 20, y = 0, z = 0 })

_G._UserService = {
    GetUserEntityByUserId = function(_, userId)
        return entities[tostring(userId)]
    end,
    GetUserEntityByUserID = function(_, userId)
        return entities[tostring(userId)]
    end,
}

local bridge = WorldServerBridge.new({})
bridge:bootstrap()

local beforeEnter = bridge.runtimeAdapter:decodeData(bridge:getPlayerState(runtimeEntity('runtime_user', 'henesys_hunting_ground', { x = 20, y = 0, z = 0 })))
assert(not beforeEnter.ok and beforeEnter.error == 'player_not_active', 'ghost player created before authoritative enter')

assert(bridge:onUserEnter(runtimeEntity('runtime_user', 'henesys_hunting_ground', { x = 20, y = 0, z = 0 })), 'authoritative enter failed')
bridge:tick(5)

local state = bridge.runtimeAdapter:decodeData(bridge:getPlayerState(runtimeEntity('runtime_user', 'henesys_hunting_ground', { x = 20, y = 0, z = 0 })))
assert(state.ok and state.data.playerId == 'runtime_user', 'authoritative sender identity was not used')
assert(state.data.currentMapId == 'henesys_hunting_ground', 'authoritative map was not preserved')

local spoofed = bridge.runtimeAdapter:decodeData(bridge:getPlayerState({ UserId = 'runtime_user' }))
assert(not spoofed.ok and spoofed.error == 'invalid_user', 'spoofed sender created or resolved a ghost player')

assert(bridge:onUserLeave(runtimeEntity('runtime_user', 'henesys_hunting_ground', { x = 20, y = 0, z = 0 })), 'authoritative leave failed')
local afterLeave = bridge.runtimeAdapter:decodeData(bridge:getPlayerState(runtimeEntity('runtime_user', 'henesys_hunting_ground', { x = 20, y = 0, z = 0 })))
assert(not afterLeave.ok and afterLeave.error == 'player_not_active', 'offline player session remained active after leave')

_G._DataStorageService = previousStorage
_G._UserService = previousUserService
print('authoritative_identity_test: ok')
