package.path = package.path .. ';./?.lua;../?.lua'
local WorldServerBridge = require('msw.world_server_bridge')

local bridge = WorldServerBridge.new({})
assert(bridge:bootstrap(), 'bridge bootstrap failed')
assert(bridge:onUserEnter({ userId = 'recovery_user', CurrentMapName = 'henesys_hunting_ground' }), 'recovery user enter failed')
bridge:tick(5)

local mapState = bridge.runtimeAdapter:decodeData(bridge:getMapState('henesys_hunting_ground'))
assert(mapState and mapState.ok == true, 'map state fetch failed')
assert(type(mapState.data.mobs) == 'table' and #mapState.data.mobs >= 1, 'map state missing mobs')

local firstSpawnId = mapState.data.mobs[1].spawnId
bridge.mobEntities[firstSpawnId] = {
    entity = { Destroy = function() end },
    mapId = 'henesys_hunting_ground',
    path = '/server_runtime/mobs/mob_' .. tostring(firstSpawnId),
}
bridge.mobEntities['orphan_manual'] = {
    entity = { Destroy = function() end },
    mapId = 'henesys_hunting_ground',
    path = '/server_runtime/mobs/mob_orphan_manual',
}

local reconcile = bridge.runtimeAdapter:decodeData(bridge:reconcileRuntimeState(nil, 'henesys_hunting_ground'))
assert(reconcile and reconcile.ok == true, 'reconcileRuntimeState failed')
assert(reconcile.data and reconcile.data.state and reconcile.data.state.syncVersion ~= nil, 'reconcile result missing synced state')
assert(bridge.mobEntities['orphan_manual'] == nil, 'reconcile did not clean orphan mob entity')

local diagnostics = bridge.runtimeAdapter:decodeData(bridge:getBridgeDiagnostics())
assert(diagnostics and diagnostics.ok == true, 'bridge diagnostics failed')
assert(diagnostics.data and diagnostics.data.metrics and diagnostics.data.metrics.reconciliationRuns >= 1, 'diagnostics missing reconciliation count')
assert(diagnostics.data.desyncIncidents ~= nil, 'diagnostics missing desync incidents')

print('msw_recovery_test: ok')
