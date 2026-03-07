local EconomySystem = {}

local function isPositiveInteger(value)
    return type(value) == 'number' and value > 0 and value == math.floor(value)
end

local function markDirty(player)
    if not player then return end
    player.version = (tonumber(player.version) or 0) + 1
    player.dirty = true
end

function EconomySystem.new(config)
    local cfg = config or {}
    local self = {
        itemSystem = cfg.itemSystem,
        logger = cfg.logger,
        metrics = cfg.metrics,
        sinks = {},
        faucets = {},
        npcSellRate = cfg.npcSellRate or 0.5,
        maxMesos = cfg.maxMesos or 2147483647,
        transactions = {},
        maxTransactions = cfg.maxTransactions or 256,
        auditSink = cfg.auditSink,
        nextTransactionId = 1,
        maxPlayerLedgerEntries = cfg.maxPlayerLedgerEntries or 64,
        suspiciousTransactionMesos = cfg.suspiciousTransactionMesos or 5000000,
    }
    setmetatable(self, { __index = EconomySystem })
    return self
end

function EconomySystem:_normalizeAmount(amount)
    local normalized = math.floor(tonumber(amount) or 0)
    if not isPositiveInteger(normalized) then return nil end
    return normalized
end

function EconomySystem:_itemNpcPrice(itemId)
    local itemDef = self.itemSystem and self.itemSystem.items and self.itemSystem.items[itemId] or nil
    if not itemDef then return nil end
    return tonumber(itemDef.npcPrice or itemDef.npc_price) or 0
end

function EconomySystem:_appendPlayerLedger(player, entry)
    if type(player) ~= 'table' then return end
    local cap = math.max(0, math.floor(tonumber(self.maxPlayerLedgerEntries) or 0))
    if cap <= 0 then return end
    player.economyLedger = player.economyLedger or {}
    player.economyLedger[#player.economyLedger + 1] = {
        txId = entry.txId,
        kind = entry.kind,
        amount = entry.amount,
        reason = entry.meta and entry.meta.reason or nil,
        itemId = entry.meta and entry.meta.itemId or nil,
        quantity = entry.meta and entry.meta.quantity or nil,
        beforeMesos = entry.beforeMesos,
        afterMesos = entry.afterMesos,
        at = entry.at,
    }
    while #player.economyLedger > cap do
        table.remove(player.economyLedger, 1)
    end
end

function EconomySystem:_emitAudit(entry)
    if type(self.auditSink) ~= 'function' then return end
    local ok, err = pcall(self.auditSink, entry)
    if not ok then
        if self.metrics then self.metrics:increment('economy.audit_sink_error', 1) end
        if self.logger and self.logger.error then
            self.logger:error('economy_audit_sink_failed', { error = tostring(err), txId = entry.txId })
        end
    elseif self.metrics then
        self.metrics:increment('economy.audit_sink_ok', 1)
    end
end

function EconomySystem:_record(kind, player, amount, meta)
    local beforeMesos = tonumber(meta and meta.beforeMesos)
    local afterMesos = tonumber(meta and meta.afterMesos)
    if beforeMesos == nil then beforeMesos = player and tonumber(player.mesos) or 0 end
    if afterMesos == nil then
        afterMesos = beforeMesos
        if kind == 'grant' then
            afterMesos = math.min(self.maxMesos, beforeMesos + amount)
        elseif kind == 'spend' then
            afterMesos = beforeMesos - amount
        end
    end

    local entry = {
        txId = self.nextTransactionId,
        kind = kind,
        playerId = player and player.id or nil,
        amount = amount,
        beforeMesos = beforeMesos,
        afterMesos = afterMesos,
        meta = meta or {},
        at = os.time(),
    }
    self.nextTransactionId = self.nextTransactionId + 1

    self.transactions[#self.transactions + 1] = entry
    if #self.transactions > self.maxTransactions then table.remove(self.transactions, 1) end
    self:_appendPlayerLedger(player, entry)
    self:_emitAudit(entry)

    if amount >= math.max(1, math.floor(tonumber(self.suspiciousTransactionMesos) or 1)) then
        if self.metrics then self.metrics:increment('economy.suspicious_large_flow', 1, { kind = kind }) end
        if self.logger and self.logger.info then
            self.logger:info('economy_suspicious_large_flow', {
                txId = entry.txId,
                playerId = entry.playerId,
                kind = kind,
                amount = amount,
                reason = entry.meta.reason,
            })
        end
    end
end

function EconomySystem:grantMesos(player, amount, reason)
    local mesos = self:_normalizeAmount(amount)
    if not player then return false, 'invalid_player' end
    if not mesos then return false, 'invalid_amount' end

    local previous = tonumber(player.mesos) or 0
    player.mesos = math.min(self.maxMesos, previous + mesos)
    local applied = player.mesos - previous
    self.faucets[reason or 'unknown'] = (self.faucets[reason or 'unknown'] or 0) + applied
    self:_record('grant', player, applied, { reason = reason, requested = mesos, beforeMesos = previous, afterMesos = player.mesos })
    markDirty(player)
    if self.metrics then
        self.metrics:increment('economy.mesos_in', applied, { reason = reason or 'unknown' })
        self.metrics:gauge('economy.player_balance', tonumber(player.mesos) or 0, { playerId = tostring(player.id) })
    end
    if self.logger and self.logger.info then self.logger:info('mesos_granted', { playerId = player.id, amount = applied, reason = reason }) end
    return true
end

function EconomySystem:spendMesos(player, amount, reason)
    local mesos = self:_normalizeAmount(amount)
    if not player then return false, 'invalid_player' end
    if not mesos then return false, 'invalid_amount' end
    if (tonumber(player.mesos) or 0) < mesos then return false, 'insufficient_mesos' end

    player.mesos = player.mesos - mesos
    self.sinks[reason or 'unknown'] = (self.sinks[reason or 'unknown'] or 0) + mesos
    self:_record('spend', player, mesos, { reason = reason, beforeMesos = player.mesos + mesos, afterMesos = player.mesos })
    markDirty(player)
    if self.metrics then
        self.metrics:increment('economy.mesos_out', mesos, { reason = reason or 'unknown' })
        self.metrics:gauge('economy.player_balance', tonumber(player.mesos) or 0, { playerId = tostring(player.id) })
    end
    if self.logger and self.logger.info then self.logger:info('mesos_spent', { playerId = player.id, amount = mesos, reason = reason }) end
    return true
end

function EconomySystem:quoteNpcBuy(itemId, quantity)
    local amount = math.floor(tonumber(quantity) or 0)
    if not isPositiveInteger(amount) then return nil, 'invalid_quantity' end
    local npcPrice = self:_itemNpcPrice(itemId)
    if npcPrice == nil then return nil, 'unknown_item' end
    return npcPrice * amount
end

function EconomySystem:quoteNpcSell(itemId, quantity)
    local amount = math.floor(tonumber(quantity) or 0)
    if not isPositiveInteger(amount) then return nil, 'invalid_quantity' end
    local npcPrice = self:_itemNpcPrice(itemId)
    if npcPrice == nil then return nil, 'unknown_item' end
    return math.max(0, math.floor(npcPrice * self.npcSellRate) * amount)
end

function EconomySystem:sellToNpc(player, itemId, quantity)
    local amount = math.floor(tonumber(quantity) or 0)
    if not isPositiveInteger(amount) then return false, 'invalid_quantity' end

    local payout, err = self:quoteNpcSell(itemId, amount)
    if payout == nil then return false, err end

    local removed, removeErr = self.itemSystem:removeItem(player, itemId, amount)
    if not removed then return false, removeErr end
    local ok, grantErr = self:grantMesos(player, payout, 'npc_sell')
    if not ok then
        self.itemSystem:addItem(player, itemId, amount)
        return false, grantErr
    end
    self:_record('npc_sell', player, payout, { itemId = itemId, quantity = amount, reason = 'npc_sell' })
    return true
end

function EconomySystem:buyFromNpc(player, itemId, quantity)
    local amount = math.floor(tonumber(quantity) or 0)
    if not isPositiveInteger(amount) then return false, 'invalid_quantity' end

    local totalPrice, err = self:quoteNpcBuy(itemId, amount)
    if totalPrice == nil then return false, err end

    local spent, spendErr = self:spendMesos(player, totalPrice, 'npc_buy')
    if not spent then return false, spendErr end
    local added, addErr = self.itemSystem:addItem(player, itemId, amount)
    if not added then
        self:grantMesos(player, totalPrice, 'npc_buy_rollback')
        return false, addErr
    end
    self:_record('npc_buy', player, totalPrice, { itemId = itemId, quantity = amount, reason = 'npc_buy' })
    return true
end

function EconomySystem:snapshot()
    return {
        sinks = self.sinks,
        faucets = self.faucets,
        transactions = self.transactions,
        nextTransactionId = self.nextTransactionId,
    }
end

return EconomySystem
