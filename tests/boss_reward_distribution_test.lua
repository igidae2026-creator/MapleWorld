package.path = package.path .. ';./?.lua;../?.lua'

local Runtime = require('msw_runtime.state.gameplay_runtime')

local runtime = Runtime:new()
assert(runtime:bootstrap().ok == true, 'runtime bootstrap failed')
assert(runtime:onUserEnter({ playerId = 'p1' }).ok == true, 'player 1 enter failed')
assert(runtime:onUserEnter({ playerId = 'p2' }).ok == true, 'player 2 enter failed')

local bossId, bossDef = nil, nil
for candidateId, candidate in pairs(runtime.normalized.bosses) do
    bossId, bossDef = candidateId, candidate
    break
end
assert(bossId ~= nil and bossDef ~= nil, 'boss catalog missing')

assert(runtime:changeMap('p1', bossDef.mapId).ok == true, 'player 1 map change failed')
assert(runtime:changeMap('p2', bossDef.mapId).ok == true, 'player 2 map change failed')

local encounter = runtime.bossSystem:spawnEncounter(bossId, bossDef.mapId)
assert(type(encounter) == 'table', 'boss spawn failed')

local p1Hit = math.floor(bossDef.hp * 0.55)
local p2Hit = bossDef.hp - p1Hit

local first = runtime:damageBoss('p1', p1Hit)
assert(first.ok == true, 'player 1 boss damage failed')
assert(first.boss.alive == true, 'boss should survive first hit')

local second = runtime:damageBoss('p2', p2Hit)
assert(second.ok == true, 'player 2 boss damage failed')
assert(second.boss.resolved == true, 'boss should be resolved after second hit')

local p1State = runtime:getPlayerState('p1')
local p2State = runtime:getPlayerState('p2')
assert(p1State.player.progression.raidTier >= 1, 'player 1 raid progress missing')
assert(p2State.player.progression.raidTier >= 1, 'player 2 raid progress missing')

local drops = runtime:getMapState(bossDef.mapId).drops
local p1Owned, p2Owned = 0, 0
local p2DropId = nil
for _, drop in ipairs(drops) do
    if drop.ownerId == 'p1' and drop.sourceBossId == bossId then p1Owned = p1Owned + 1 end
    if drop.ownerId == 'p2' and drop.sourceBossId == bossId then
        p2Owned = p2Owned + 1
        p2DropId = p2DropId or drop.dropId
    end
end

assert(p1Owned > 0, 'player 1 should have boss-owned drops')
assert(p2Owned > 0, 'player 2 should have boss-owned drops')
assert(p2DropId ~= nil, 'player 2 reserved drop missing')

local blocked = runtime:pickupDrop('p1', p2DropId)
assert(blocked.ok == false and blocked.error == 'drop_reserved', 'cross-owner pickup should be blocked')

print('boss_reward_distribution_test: ok')
