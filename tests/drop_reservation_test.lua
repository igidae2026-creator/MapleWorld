package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')

local currentTime = 1000
local world = ServerBootstrap.boot('.', {
    autoPickupDrops = false,
    rng = function() return 0 end,
    time = function() return currentTime end,
})
local owner = world:createPlayer('owner')
local thief = world:createPlayer('thief')

world.scheduler:tick(5)
local active = world.spawnSystem.maps['henesys_hunting_ground'].active
local spawnId = nil
for id, mob in pairs(active) do
    if mob.mobId == 'snail' then spawnId = id break end
end
assert(spawnId, 'no snail available for drop reservation test')

local ok = world:attackMob(owner, 'henesys_hunting_ground', spawnId, 999)
assert(ok, 'owner attack failed')
local drops = world.dropSystem:listDrops('henesys_hunting_ground')
assert(#drops >= 1, 'drop did not register')

local blocked, blockedErr = world:pickupDrop(thief, 'henesys_hunting_ground', drops[1].dropId)
assert(not blocked and blockedErr == 'drop_reserved', 'reservation window did not protect owner')

currentTime = currentTime + 3
local picked, record = world:pickupDrop(thief, 'henesys_hunting_ground', drops[1].dropId)
assert(picked and record.dropId == drops[1].dropId, 'drop was not released after reservation window')

print('drop_reservation_test: ok')
