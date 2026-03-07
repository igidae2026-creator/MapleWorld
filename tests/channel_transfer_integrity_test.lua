package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.')
local player = world:createPlayer('channel-runner')
local ok = world:changeMap(player, 'henesys_fields', 'henesys_town')
assert(ok, 'map change failed')
local transferOk, payload = world:channelTransfer(player, 'henesys_dungeon')
assert(transferOk, 'channel transfer failed')
assert(payload.channelId == world.runtimeIdentity.channelId, 'unexpected channel route')
assert(world.sessionOrchestrator.sessions[player.id].pendingMapId == 'henesys_dungeon', 'pending transfer missing')
print('channel_transfer_integrity_test: ok')
