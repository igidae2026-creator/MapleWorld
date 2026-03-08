package.path = package.path .. ';./?.lua;../?.lua'

local Runtime = require('msw_runtime.state.gameplay_runtime')

local runtime = Runtime:new()

local boot = runtime:bootstrap()
assert(boot.ok == true and boot.booted == true, 'runtime bootstrap failed')

local entered = runtime:onUserEnter({ playerId = 'p1' })
assert(entered.ok == true, 'player enter failed')

local playerState = runtime:getPlayerState('p1')
assert(playerState.ok == true, 'player state fetch failed')
assert(playerState.player.level == 1, 'new player level mismatch')
assert(playerState.player.mapId ~= nil, 'new player map missing')

local mapState = runtime:getMapState('p1')
assert(mapState.ok == true, 'map state failed')
assert(#mapState.mobs > 0, 'starter map should have mobs')

local spawnId = mapState.mobs[1].spawnId
local initialHp = mapState.mobs[1].hp
local hit = runtime:attackMob('p1', spawnId)
assert(hit.ok == true, 'basic attack failed')
assert(hit.mob.hp < initialHp or hit.killed == true, 'mob hp did not change')

local killResult = hit
while killResult.ok == true and killResult.killed ~= true do
    killResult = runtime:attackMob('p1', spawnId)
end
assert(killResult.ok == true and killResult.killed == true, 'mob kill flow failed')
assert(type(killResult.drops) == 'table', 'drop registration missing')

if #killResult.drops > 0 then
    local pickup = runtime:pickupDrop('p1', killResult.drops[1].dropId)
    assert(pickup.ok == true, 'drop pickup failed')
    assert(pickup.player.inventory[killResult.drops[1].itemId] ~= nil, 'picked item missing from inventory')
end

print('msw_runtime_gameplay_test: ok')
