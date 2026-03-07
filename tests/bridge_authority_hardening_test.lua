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

entities.bridge_guard = runtimeEntity('bridge_guard', 'henesys_hunting_ground', { x = 20, y = 0, z = 0 })

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
assert(bridge:onUserEnter(entities.bridge_guard), 'authoritative enter failed')

local function decode(payload)
    return bridge.runtimeAdapter:decodeData(payload)
end

local buyMissingNpc = decode(bridge:buyFromNpc(entities.bridge_guard, nil, 'hp_potion', 1))
assert(not buyMissingNpc.ok and buyMissingNpc.error == 'invalid_npc', 'npc id was not required on bridge buy')

local buyWrongMap = decode(bridge:buyFromNpc(entities.bridge_guard, 'Chief_Stan', 'hp_potion', 1))
assert(not buyWrongMap.ok and buyWrongMap.error == 'wrong_map', 'remote npc buy unexpectedly allowed')

local mapMissingSource = decode(bridge:changeMap(entities.bridge_guard, 'forest_edge', nil))
assert(not mapMissingSource.ok and mapMissingSource.error == 'missing_transition_source', 'bridge map change allowed without source')

local badTransition = decode(bridge:changeMap(entities.bridge_guard, 'perion_rocky', 'henesys_hunting_ground'))
assert(not badTransition.ok and badTransition.error == 'invalid_map_transition', 'bridge map change allowed invalid transition route')

local validTransition = decode(bridge:changeMap(entities.bridge_guard, 'forest_edge', 'henesys_hunting_ground'))
assert(validTransition.ok and validTransition.data.currentMapId == 'forest_edge', 'valid bridge map transition was blocked')

entities.bridge_guard = runtimeEntity('bridge_guard', 'forest_edge', { x = 80, y = 0, z = 0 })
local buyInRange = decode(bridge:buyFromNpc(entities.bridge_guard, 'Chief_Stan', 'hp_potion', 1))
assert(buyInRange.ok, 'in-range npc buy on authoritative bridge failed')

_G._DataStorageService = previousStorage
_G._UserService = previousUserService

print('bridge_authority_hardening_test: ok')
