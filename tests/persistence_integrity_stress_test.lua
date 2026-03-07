package.path = package.path .. ';./?.lua;../?.lua'

local PlayerRepository = require('ops.player_repository')
local ServerBootstrap = require('scripts.server_bootstrap')

local persisted
local worldRepository = {
    load = function() return persisted end,
    save = function(_, snapshot)
        persisted = snapshot
        return true
    end,
    lastLoadedRevision = function() return 0 end,
}

local world = ServerBootstrap.boot('.', {
    playerRepository = PlayerRepository.newMemory({}),
    worldRepository = worldRepository,
})

for i = 1, 24 do
    world:createPlayer('persist-' .. tostring(i))
end

for _ = 1, 8 do
    world.scheduler:tick(5)
    local active = world.spawnSystem.maps['henesys_hunting_ground'].active
    for _, player in pairs(world.players) do
        local spawnId = next(active)
        if spawnId then world:killMob(player, 'henesys_hunting_ground', spawnId) end
    end
end

assert(world:saveWorldState('stress_integrity'), 'world save failed')
assert(type(persisted) == 'table' and type(persisted.activePlayers) == 'table', 'persisted snapshot missing active players')

local restored = ServerBootstrap.boot('.', {
    playerRepository = PlayerRepository.newMemory({}),
    worldRepository = worldRepository,
})

assert(restored:getActivePlayerCount() == world:getActivePlayerCount(), 'restored player count mismatch')
assert(restored:replayDeterminismReport().ok == true, 'restored replay determinism failed')
assert(restored:getStabilityReport().duplication.ok == true, 'restored duplication guard flagged invalid state')
print('persistence_integrity_stress_test: ok')
