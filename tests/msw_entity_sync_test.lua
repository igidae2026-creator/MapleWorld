package.path = package.path .. ';./?.lua;../?.lua'
local WorldServerBridge = require('msw.world_server_bridge')

local bridge = WorldServerBridge.new({})
assert(bridge:bootstrap(), 'bridge bootstrap failed')
assert(bridge:onUserEnter({ userId = 'sync_user', CurrentMapName = 'henesys_hunting_ground' }), 'sync user enter failed')
bridge:tick(5)

local playerState = bridge.runtimeAdapter:decodeData(bridge:getPlayerState('sync_user'))
assert(playerState and playerState.ok == true, 'player state fetch failed')
assert(playerState.data and playerState.data.syncVersion ~= nil, 'player state missing sync version')
assert(playerState.data.authority and playerState.data.authority.playerId == 'sync_user', 'player state missing authority player binding')
assert(playerState.data.authority.mapId == 'henesys_hunting_ground', 'player state authority map mismatch')

local mapState = bridge.runtimeAdapter:decodeData(bridge:getMapState('henesys_hunting_ground'))
assert(mapState and mapState.ok == true, 'map state fetch failed')
assert(mapState.data and mapState.data.syncVersion ~= nil, 'map state missing sync version')
assert(type(mapState.data.mobs) == 'table' and #mapState.data.mobs >= 1, 'map state missing mobs')
assert(mapState.data.bridgeMeta and mapState.data.bridgeMeta.authority and mapState.data.bridgeMeta.authority.mapId == 'henesys_hunting_ground', 'map state missing authority bridge metadata')

local spawnId = mapState.data.mobs[1].spawnId
local attack = bridge.runtimeAdapter:decodeData(bridge:attackMob('sync_user', 'henesys_hunting_ground', spawnId, 50))
assert(attack and attack.ok == true, 'mob attack failed')

local deltas = bridge.runtimeAdapter:decodeData(bridge:getStateDelta('sync_user', 'henesys_hunting_ground', 0))
assert(deltas and deltas.ok == true, 'state delta fetch failed')
assert(type(deltas.data.deltas) == 'table' and #deltas.data.deltas >= 1, 'state delta payload was empty')
assert(deltas.data.scopeKind == 'map', 'state delta scope kind mismatch')
assert(deltas.data.authority and deltas.data.authority.mapId == 'henesys_hunting_ground', 'state delta missing authority scope')

local hasPlayerDelta = false
local hasMapDelta = false
for _, delta in ipairs(deltas.data.deltas) do
    if delta.scopeKind == 'player' then hasPlayerDelta = true end
    if delta.scopeKind == 'map' or delta.scopeKind == 'entity' then hasMapDelta = true end
end
assert(hasPlayerDelta, 'state delta payload missing player updates')
assert(hasMapDelta, 'state delta payload missing map or entity updates')

local foreignScope = bridge.runtimeAdapter:decodeData(bridge:getStateDelta('sync_user', 'ellinia', 0))
assert(foreignScope and foreignScope.ok == false and foreignScope.error == 'scope_not_authoritative', 'foreign state scope was not rejected')

local reconcile = bridge.runtimeAdapter:decodeData(bridge:reconcileRuntimeState('sync_user', 'henesys_hunting_ground'))
assert(reconcile and reconcile.ok == true, 'reconcile runtime state failed')
assert(reconcile.data.authority and reconcile.data.authority.playerId == 'sync_user', 'reconcile missing authority metadata')

local foreignReconcile = bridge.runtimeAdapter:decodeData(bridge:reconcileRuntimeState('sync_user', 'ellinia'))
assert(foreignReconcile and foreignReconcile.ok == false and foreignReconcile.error == 'scope_not_authoritative', 'foreign reconcile scope was not rejected')

print('msw_entity_sync_test: ok')
