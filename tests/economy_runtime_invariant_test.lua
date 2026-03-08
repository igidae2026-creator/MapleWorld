package.path = package.path .. ';./?.lua;../?.lua'

local Runtime = require('msw_runtime.state.gameplay_runtime')

local runtime = Runtime:new()
assert(runtime:bootstrap().ok == true, 'runtime bootstrap failed')
assert(runtime:onUserEnter({ playerId = 'p1' }).ok == true, 'player enter failed')

local function inventoryQuantity(bucket)
    if type(bucket) ~= 'table' then return 0 end
    if type(bucket.quantity) == 'number' then return bucket.quantity end
    local total = 0
    for _ in pairs(bucket) do
        total = total + 1
    end
    return total
end

local player = runtime.players.p1
local itemId = runtime.starterWeaponId
assert(itemId ~= nil, 'starter weapon missing')

local startingMesos = player.mesos
local beforeInventoryCount = player.inventory[itemId] and #player.inventory[itemId] or 0
local buyPrice = assert(runtime.economySystem:quoteNpcBuy(itemId, 1))

local originalAddItem = runtime.itemSystem.addItem
runtime.itemSystem.addItem = function(_, targetPlayer, targetItemId, quantity, instanceId, context)
    if targetPlayer == player and targetItemId == itemId then
        return false, 'forced_add_failure'
    end
    return originalAddItem(runtime.itemSystem, targetPlayer, targetItemId, quantity, instanceId, context)
end

local result = runtime:buyFromNpc('p1', itemId, 1, 'npc')

runtime.itemSystem.addItem = originalAddItem

assert(result.ok == false, 'forced npc buy failure should fail')
assert(result.error == 'forced_add_failure', 'forced npc buy failure reason mismatch')
assert(player.mesos == startingMesos, 'mesos should be restored after npc buy rollback')

local afterInventoryCount = player.inventory[itemId] and #player.inventory[itemId] or 0
assert(afterInventoryCount == beforeInventoryCount, 'inventory should not gain duplicate items on rollback')

local transactions = runtime.economySystem.transactions
assert(#transactions >= 2, 'rollback should record spend and compensation transactions')
local spendTx = transactions[#transactions - 1]
local rollbackTx = transactions[#transactions]
assert(spendTx.kind == 'spend' and spendTx.meta.reason == 'npc_buy', 'expected npc buy spend transaction')
assert(rollbackTx.kind == 'grant' and rollbackTx.meta.reason == 'npc_buy_rollback', 'expected npc buy rollback transaction')
assert((rollbackTx.amount or 0) == buyPrice, 'rollback amount should match original buy price')

assert(runtime:onUserEnter({ playerId = 'p2' }).ok == true, 'second player enter failed')

local tradeFrom = runtime.players.p1
local tradeTo = runtime.players.p2
local tradeStartFromMesos = tradeFrom.mesos
local tradeStartToMesos = tradeTo.mesos
local tradeStartTxCount = #runtime.economySystem.transactions
local tradeStartSeq = runtime.eventSeq

local firstTrade = runtime:tradeMesos({
    fromPlayerId = 'p1',
    toPlayerId = 'p2',
    amount = 125,
    requestId = 'trade:req:001',
})
assert(firstTrade.ok == true, 'first tradeMesos request should succeed')
assert(firstTrade.requestId == 'trade:req:001', 'first tradeMesos request id missing')

local duplicateTrade = runtime:tradeMesos({
    fromPlayerId = 'p1',
    toPlayerId = 'p2',
    amount = 125,
    requestId = 'trade:req:001',
})
assert(duplicateTrade.ok == true, 'duplicate tradeMesos request should replay as success')
assert(duplicateTrade.deduped == true, 'duplicate tradeMesos request should be marked deduped')
assert(duplicateTrade.requestId == 'trade:req:001', 'duplicate tradeMesos request id missing')

assert(tradeFrom.mesos == tradeStartFromMesos - 125, 'tradeMesos should debit sender only once')
assert(tradeTo.mesos == tradeStartToMesos + 125, 'tradeMesos should credit receiver only once')
assert(#runtime.economySystem.transactions == tradeStartTxCount + 2, 'tradeMesos duplicate should only record one spend and one grant')

local acceptedEvents = 0
local dedupedEvents = 0
for _, event in ipairs(runtime.eventStream) do
    if event.seq > tradeStartSeq and event.payload and event.payload.requestId == 'trade:req:001' then
        if event.kind == 'trade_mesos_applied' then
            acceptedEvents = acceptedEvents + 1
        elseif event.kind == 'trade_mesos_deduped' then
            dedupedEvents = dedupedEvents + 1
        end
    end
end
assert(acceptedEvents == 1, 'tradeMesos replay output should contain one accepted outcome for request id')
assert(dedupedEvents == 1, 'tradeMesos duplicate should emit one deduped outcome')

local tradeSpendTx = runtime.economySystem.transactions[tradeStartTxCount + 1]
local tradeGrantTx = runtime.economySystem.transactions[tradeStartTxCount + 2]
assert(tradeSpendTx.meta.idempotencyKey == 'tradeMesos:trade:req:001:spend', 'trade spend tx should carry idempotency key')
assert(tradeGrantTx.meta.idempotencyKey == 'tradeMesos:trade:req:001:grant', 'trade grant tx should carry idempotency key')
assert(tradeSpendTx.meta.correlationId == 'trade:req:001', 'trade spend tx should carry correlation id')
assert(tradeGrantTx.meta.correlationId == 'trade:req:001', 'trade grant tx should carry correlation id')

local buyPlayer = runtime.players.p1
local duplicateItemId, duplicateBuyPrice = nil, nil
for candidateItemId, item in pairs(runtime.normalized.items) do
    local price = runtime.economySystem:quoteNpcBuy(candidateItemId, 1)
    if item.stackable == false and price and price > 0 and price <= buyPlayer.mesos then
        if duplicateBuyPrice == nil
            or price < duplicateBuyPrice
            or (price == duplicateBuyPrice and tostring(candidateItemId) < tostring(duplicateItemId)) then
            duplicateItemId = candidateItemId
            duplicateBuyPrice = price
        end
    end
end
assert(duplicateItemId ~= nil, 'expected one affordable non-stackable npc buy candidate')
local buyStartMesos = buyPlayer.mesos
local buyStartTxCount = #runtime.economySystem.transactions
local buyStartSeq = runtime.eventSeq
local buyStartInventoryCount = inventoryQuantity(buyPlayer.inventory[duplicateItemId])

local firstBuy = runtime:buyFromNpc({
    playerId = 'p1',
    itemId = duplicateItemId,
    quantity = 1,
    npcId = 'npc',
    requestId = 'npcbuy:req:001',
})
assert(firstBuy.ok == true, 'first buyFromNpc request should succeed')
assert(firstBuy.requestId == 'npcbuy:req:001', 'first buyFromNpc request id missing')

local duplicateBuy = runtime:buyFromNpc({
    playerId = 'p1',
    itemId = duplicateItemId,
    quantity = 1,
    npcId = 'npc',
    requestId = 'npcbuy:req:001',
})
assert(duplicateBuy.ok == true, 'duplicate buyFromNpc request should replay as success')
assert(duplicateBuy.deduped == true, 'duplicate buyFromNpc request should be marked deduped')
assert(duplicateBuy.requestId == 'npcbuy:req:001', 'duplicate buyFromNpc request id missing')

assert(buyPlayer.mesos == buyStartMesos - duplicateBuyPrice, 'buyFromNpc duplicate should only spend mesos once')
local buyEndInventoryCount = inventoryQuantity(buyPlayer.inventory[duplicateItemId])
assert(buyEndInventoryCount == buyStartInventoryCount + 1, 'buyFromNpc duplicate should only grant inventory once')
assert(#runtime.economySystem.transactions == buyStartTxCount + 1, 'buyFromNpc duplicate should only record one spend transaction')

local buyAppliedEvents = 0
local buyDedupedEvents = 0
for _, event in ipairs(runtime.eventStream) do
    if event.seq > buyStartSeq and event.payload and event.payload.requestId == 'npcbuy:req:001' then
        if event.kind == 'npc_buy_applied' then
            buyAppliedEvents = buyAppliedEvents + 1
        elseif event.kind == 'npc_buy_deduped' then
            buyDedupedEvents = buyDedupedEvents + 1
        end
    end
end
assert(buyAppliedEvents == 1, 'buyFromNpc replay output should contain one accepted outcome for request id')
assert(buyDedupedEvents == 1, 'buyFromNpc duplicate should emit one deduped outcome')

local buySpendTx = runtime.economySystem.transactions[buyStartTxCount + 1]
assert(buySpendTx.kind == 'spend' and buySpendTx.meta.reason == 'npc_buy', 'buyFromNpc duplicate should leave a single npc buy spend transaction')
assert(buySpendTx.meta.correlationId == 'npcbuy:req:001', 'buyFromNpc spend tx should carry correlation id')

print('economy_runtime_invariant_test: ok')
