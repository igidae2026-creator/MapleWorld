package.path = package.path .. ';./?.lua;../?.lua'
local WorldServerBridge = require('msw.world_server_bridge')

local bridge = WorldServerBridge.new({})
bridge:bootstrap()
assert(bridge:onUserEnter({ userId = 'bridge_user', CurrentMapName = 'henesys_hunting_ground' }), 'bridge enter failed')
bridge:tick(5)

local playerState = bridge.runtimeAdapter:decodeData(bridge:getPlayerState('bridge_user'))
assert(playerState.ok, 'bridge player state request failed')
assert(playerState.data.currentMapId == 'henesys_hunting_ground', 'bridge player map state mismatch')

local mapState = bridge.runtimeAdapter:decodeData(bridge:getMapState('henesys_hunting_ground'))
assert(mapState.ok, 'bridge map state request failed')
assert(#mapState.data.mobs >= 1, 'bridge map state missing mobs')

local spawnId = mapState.data.mobs[1].spawnId
local attack = bridge.runtimeAdapter:decodeData(bridge:attackMob('bridge_user', 'henesys_hunting_ground', spawnId, 999))
assert(attack.ok, 'bridge mob attack failed')
assert(attack.data.player.playerId == 'bridge_user', 'bridge attack response missing player snapshot')

print('runtime_bridge_test: ok')
