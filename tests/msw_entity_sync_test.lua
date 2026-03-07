package.path = package.path .. ';./?.lua;../?.lua'
local WorldServerBridge = require('msw.world_server_bridge')

local bridge = WorldServerBridge.new({})
assert(bridge:bootstrap(), 'bridge bootstrap failed')
assert(bridge:onUserEnter({ userId = 'sync_user', CurrentMapName = 'henesys_hunting_ground' }), 'sync user enter failed')
bridge:tick(5)

local playerState = bridge.runtimeAdapter:decodeData(bridge:getPlayerState('sync_user'))
assert(playerState and playerState.ok == true, 'player state fetch failed')
assert(playerState.data and playerState.data.syncVersion ~= nil, 'player state missing sync version')

local mapState = bridge.runtimeAdapter:decodeData(bridge:getMapState('henesys_hunting_ground'))
assert(mapState and mapState.ok == true, 'map state fetch failed')
assert(mapState.data and mapState.data.syncVersion ~= nil, 'map state missing sync version')
assert(type(mapState.data.mobs) == 'table' and #mapState.data.mobs >= 1, 'map state missing mobs')

local spawnId = mapState.data.mobs[1].spawnId
local attack = bridge.runtimeAdapter:decodeData(bridge:attackMob('sync_user', 'henesys_hunting_ground', spawnId, 50))
assert(attack and attack.ok == true, 'mob attack failed')

local deltas = bridge.runtimeAdapter:decodeData(bridge:getStateDelta('sync_user', 'henesys_hunting_ground', 0))
assert(deltas and deltas.ok == true, 'state delta fetch failed')
assert(type(deltas.data.deltas) == 'table' and #deltas.data.deltas >= 1, 'state delta payload was empty')

local hasPlayerDelta = false
local hasMapDelta = false
for _, delta in ipairs(deltas.data.deltas) do
    if delta.scopeKind == 'player' then hasPlayerDelta = true end
    if delta.scopeKind == 'map' or delta.scopeKind == 'entity' then hasMapDelta = true end
end
assert(hasPlayerDelta, 'state delta payload missing player updates')
assert(hasMapDelta, 'state delta payload missing map or entity updates')

print('msw_entity_sync_test: ok')
