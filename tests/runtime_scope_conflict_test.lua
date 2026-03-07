package.path = package.path .. ';./?.lua;../?.lua'
local WorldServerBridge = require('msw.world_server_bridge')

local bridge = WorldServerBridge.new({})
local world = bridge:bootstrap()
assert(world, 'bridge bootstrap failed')

local okEnter = bridge:onUserEnter({ userId = 'scope_user', mapId = 'henesys_hunting_ground', worldId = 'world-1', channelId = 'channel-1' })
assert(okEnter == true, 'user enter failed')

local resp = bridge:getPlayerState({ userId = 'scope_user', mapId = 'henesys_hunting_ground', worldId = 'world-X', channelId = 'channel-1' })
local decoded = bridge.runtimeAdapter:decodeData(resp)
assert(decoded and decoded.ok == false, 'scope conflict did not fail closed')
assert(tostring(decoded.error):find('runtime_world_conflict', 1, true), 'expected runtime scope conflict')

local samePlayer = bridge.world.players.scope_user
samePlayer.runtimeScope.runtimeInstanceId = 'runtime-main'
local respInstance = bridge:getPlayerState({ userId = 'scope_user', mapId = 'henesys_hunting_ground', worldId = 'world-1', channelId = 'channel-1', runtimeInstanceId = 'runtime-other' })
local decodedInstance = bridge.runtimeAdapter:decodeData(respInstance)
assert(decodedInstance and decodedInstance.ok == false, 'runtime instance conflict did not fail closed')
assert(tostring(decodedInstance.error):find('runtime_instance_conflict', 1, true), 'expected runtime instance conflict')

print('runtime_scope_conflict_test: ok')
