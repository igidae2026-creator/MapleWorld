package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.', {
    autoPickupDrops = false,
    rng = function() return 0 end,
})
local player = world:createPlayer('picker')

world.scheduler:tick(5)
local active = world.spawnSystem.maps['henesys_hunting_ground'].active
local spawnId = nil
for id, mob in pairs(active) do
    if mob.mobId == 'snail' then spawnId = id break end
end
assert(spawnId, 'no snail available for drop pickup test')

local ok = world:attackMob(player, 'henesys_hunting_ground', spawnId, 999)
assert(ok, 'mob attack failed')
local drops = world.dropSystem:listDrops('henesys_hunting_ground')
assert(#drops >= 1, 'drop did not register in world state')

local dropId = drops[1].dropId
local picked, record = world:pickupDrop(player, 'henesys_hunting_ground', dropId)
assert(picked, 'pickup failed')
assert(record.dropId == dropId, 'picked wrong drop')
assert(world.dropSystem:getDrop(dropId) == nil, 'drop still active after pickup')
assert(world.itemSystem:countItem(player, record.itemId) >= record.quantity, 'inventory not updated after pickup')

print('drop_pickup_test: ok')

local ledger = world.journal:ledgerSnapshot()
local found = false
for _, evt in ipairs(ledger) do
    if evt.event_type == 'reward_claim' and evt.source_system == 'drop_system' then found = true break end
end
assert(found, 'drop pickup should write reward claim ledger event')
