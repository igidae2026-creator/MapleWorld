package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.')
local alpha = world:createPlayer('alpha-trader')
local beta = world:createPlayer('beta-trader')

world.economySystem:grantMesos(alpha, 5000, 'seed')
local tradeOk = world:tradeMesos(alpha, beta, 700)
assert(tradeOk, 'trade failed')
assert(alpha.mesos == 4300, 'source mesos mismatch')
assert(beta.mesos == 700, 'target mesos mismatch')
world:grantItem(alpha, 'henesys_bronze_blade', 1)
local listed, listing = world:listAuction(alpha, 'henesys_bronze_blade', 1, 999)
assert(listed and listing.id ~= nil, 'listing failed')
assert(world:getEconomyReport().auctionListings[listing.id] ~= nil, 'listing not visible in report')
print('market_transfer_test: ok')
