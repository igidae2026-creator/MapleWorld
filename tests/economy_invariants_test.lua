package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.')
local seller = world:createPlayer('seller')
local buyer = world:createPlayer('buyer')

assert(world.economySystem:grantMesos(seller, 300, 'seed'), 'seller seed failed')
assert(world.economySystem:grantMesos(buyer, 300, 'seed'), 'buyer seed failed')
assert(world.economySystem:buyFromNpc(seller, 'hp_potion', 10, { npcId = 'Rina', correlationId = 'seed-buy-1' }), 'seller npc buy failed')
assert(world.economySystem:buyFromNpc(buyer, 'hp_potion', 10, { npcId = 'Rina', correlationId = 'seed-buy-2' }), 'buyer npc buy failed')
assert(world:tradeMesos(seller, buyer, 50), 'player trade failed')
assert(world:listAuction(seller, 'hp_potion', 3, 45), 'auction listing failed')

world.scheduler:tick(10)
local stable = world:getStabilityReport()
assert(stable.inflation.ok == true, 'balanced economy incorrectly flagged as unstable')
local economyReport = world:getEconomyReport()
assert(type(economyReport.control) == 'table', 'economy control report missing')
assert(economyReport.control.tuning.npcSellRate ~= nil, 'economy tuning point missing')
assert(economyReport.control.mutationBoundaries ~= nil, 'economy mutation boundaries missing')
assert(economyReport.control.mutationBoundaries.correlatedTransactionCount >= 2, 'economy correlation coverage missing')

assert(world.economySystem:grantMesos(seller, 5000, 'event_spike'), 'event spike grant failed')
world.scheduler:tick(10)
local inflated = world:getStabilityReport()
assert(inflated.inflation.ok == false, 'inflation guard did not trigger under faucet spike')
assert(#world.exploitMonitor.incidents >= 1, 'inflation spike did not surface an incident')
print('economy_invariants_test: ok')
