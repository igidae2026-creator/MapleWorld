package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')
local world = ServerBootstrap.boot('.')
local player = world:createPlayer('merchant')
world.economySystem:grantMesos(player, 500, 'seed')
assert(world.economySystem:buyFromNpc(player, 'hp_potion', 5, 20), 'npc buy failed')
assert(player.inventory['hp_potion'].quantity == 5, 'inventory quantity mismatch')
assert(world.economySystem:sellToNpc(player, 'hp_potion', 2, 10), 'npc sell failed')
assert(player.mesos == 420, 'mesos accounting mismatch')
local snapshot = world.economySystem:snapshot()
assert(snapshot.faucets.seed == 500, 'faucet tracking failed')
assert(snapshot.sinks.npc_buy == 100, 'sink tracking failed')
assert(type(player.economyLedger) == 'table' and #player.economyLedger >= 3, 'player economy ledger did not capture mutations')
local auditEvents = world.journal:snapshot()
local foundAudit = false
for _, evt in ipairs(auditEvents) do
    if evt.event == 'economy_mutation' then
        foundAudit = true
        assert(evt.payload.txId ~= nil, 'economy mutation audit payload missing txId')
        break
    end
end
assert(foundAudit, 'economy mutation events were not journaled for auditability')
print('economy_test: ok')

local ledger = world.journal:ledgerSnapshot()
assert(#ledger > 0, 'ledger snapshot should not be empty')
local hasNpcBuy = false
for _, evt in ipairs(ledger) do
    if evt.event_type == 'mesos_spend' and evt.metadata and evt.metadata.reason == 'npc_buy' then hasNpcBuy = true end
end
assert(hasNpcBuy, 'ledger missing npc buy mesos spend')
