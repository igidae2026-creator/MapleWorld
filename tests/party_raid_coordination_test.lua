package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.')
local tank = world:createPlayer('tank')
local support = world:createPlayer('support')
local damage = world:createPlayer('damage')

tank.jobId = 'warrior'
support.jobId = 'magician'
damage.jobId = 'bowman'
world:_ensurePlayerSystems(tank)
world:_ensurePlayerSystems(support)
world:_ensurePlayerSystems(damage)

local party = world:createParty(tank)
assert(world.partySystem:join(support, party.id))
assert(world.partySystem:join(damage, party.id))
local synergy = world.partySystem:refreshSynergy(party.id, world)
assert(synergy.frontline >= 1 and synergy.support >= 1 and synergy.damage >= 1, 'party role synergy missing')

assert(world:changeMap(tank, 'henesys_boss', 'henesys_town'))
support.currentMapId = 'henesys_boss'
damage.currentMapId = 'henesys_boss'
local raid = world:createRaid(tank, 'henesys_overseer')
assert(raid.phase == 'ready' or raid.phase == 'forming', 'raid not created')
assert(world.raidSystem:syncWithParty(raid.id, world))
assert(world.raidSystem.raids[raid.id].rewardTier >= 1, 'raid reward tier missing')
print('party_raid_coordination_test: ok')
