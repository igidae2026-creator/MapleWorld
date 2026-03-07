package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')
local world = ServerBootstrap.boot('.')
local player = world:createPlayer('raider')
local encounter = world.bossSystem:spawnEncounter('mano', 'forest_edge')
assert(encounter.alive, 'boss not alive')
local killed = false
for _ = 1, 20 do
    local ok, drops = world.bossSystem:damage('forest_edge', player, 300)
    assert(ok, 'damage failed')
    if drops then killed = true; assert(#drops >= 1, 'boss should drop loot'); break end
end
assert(killed, 'boss never died')
print('boss_test: ok')

local ledger = world.journal:ledgerSnapshot()
local foundBossClaim = false
for _, evt in ipairs(ledger) do
    if evt.event_type == 'reward_claim' and evt.metadata and evt.metadata.reward_kind == 'boss_clear' then foundBossClaim = true end
end
assert(foundBossClaim, 'boss clear reward claim missing in ledger')
