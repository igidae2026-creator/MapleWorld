package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.')
local player = world:createPlayer('channel-runner')
local ok = world:changeMap(player, 'henesys_fields', 'henesys_town')
assert(ok, 'map change failed')
local transferOk, payload = world:channelTransfer(player, 'henesys_dungeon')
assert(transferOk, 'channel transfer failed')
assert(payload.channelId == world.runtimeIdentity.channelId, 'unexpected channel route')
local session = world.sessionOrchestrator.sessions[player.id]
assert(session.pendingMapId == 'henesys_dungeon', 'pending transfer missing')
assert(session.sourceMapId == 'henesys_town', 'source map missing from staged transfer')
assert(session.targetChannelId == world.runtimeIdentity.channelId, 'target channel missing from staged transfer')
assert(session.transferState == 'pending', 'transfer state should be pending')
assert(world.sessionOrchestrator:pendingTransferCount() == 1, 'pending transfer count missing')
assert(type(payload.routingDecision) == 'table', 'routing decision missing from transfer payload')
assert(payload.routingDecision.reason ~= nil, 'routing decision reason missing')
print('channel_transfer_integrity_test: ok')
