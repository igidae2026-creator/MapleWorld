package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')
local PlayerRepository = require('ops.player_repository')
local WorldRepository = require('ops.world_repository')

local now = 7000
local worldRepo = WorldRepository.newMemory({})
local playerRepo = PlayerRepository.newMemory({})

local worldA = ServerBootstrap.boot('.', {
    rng = function() return 0 end,
    time = function() return now end,
    worldRepository = worldRepo,
    playerRepository = playerRepo,
    autoPickupDrops = false,
})
local player = worldA:createPlayer('replay_user')
worldA.scheduler:tick(5)
local spawnId = next(worldA.spawnSystem.maps['henesys_hunting_ground'].active)
assert(spawnId, 'missing spawn')
assert(worldA:attackMob(player, 'henesys_hunting_ground', spawnId, 999), 'mob kill failed')
assert(worldA:saveWorldState('replay_checkpoint'), 'checkpoint save failed')

local snapshot = worldRepo.state
assert(snapshot and snapshot.checkpoint and snapshot.checkpoint.checkpoint_id, 'checkpoint metadata missing')
assert(snapshot.checkpoint.schema_version == 2, 'checkpoint schema version missing')
assert(snapshot.checkpoint.timestamp == now, 'checkpoint timestamp missing')
assert(snapshot.checkpoint.owner_epoch ~= nil, 'checkpoint owner epoch missing')

local worldB = ServerBootstrap.boot('.', {
    rng = function() return 0 end,
    time = function() return now end,
    worldRepository = worldRepo,
    playerRepository = playerRepo,
    autoPickupDrops = false,
})
local status = worldB:getRuntimeStatus()
assert(status.recovery.valid == true, 'recovery should be valid')
assert(status.recovery.checkpointId == snapshot.checkpoint.checkpoint_id, 'checkpoint id not restored')
assert(status.watermark.journalSeq >= snapshot.checkpoint.journal_watermark, 'journal watermark regressed')

print('replay_checkpoint_test: ok')
