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

function EconomySystem:_record(kind, player, amount, meta)
    local entry = {
        kind = kind,
        playerId = player and player.id or nil,
        amount = amount,
        meta = meta or {},
        at = os.time(),
    }
    self.transactions[#self.transactions + 1] = entry
    if #self.transactions > self.maxTransactions then table.remove(self.transactions, 1) end
end

function EconomySystem:grantMesos(player, amount, reason)
    local mesos = self:_normalizeAmount(amount)
    if not player then return false, 'invalid_player' end
    if not mesos then return false, 'invalid_amount' end

    player.mesos = math.min(self.maxMesos, (tonumber(player.mesos) or 0) + mesos)
    self.faucets[reason or 'unknown'] = (self.faucets[reason or 'unknown'] or 0) + mesos
    self:_record('grant', player, mesos, { reason = reason })
    markDirty(player)
    if self.metrics then self.metrics:increment('economy.mesos_in', mesos, { reason = reason or 'unknown' }) end
    if self.logger and self.logger.info then self.logger:info('mesos_granted', { playerId = player.id, amount = mesos, reason = reason }) end
    return true
end

function EconomySystem:spendMesos(player, amount, reason)
    local mesos = self:_normalizeAmount(amount)
    if not player then return false, 'invalid_player' end
    if not mesos then return false, 'invalid_amount' end
    if (tonumber(player.mesos) or 0) < mesos then return false, 'insufficient_mesos' end

    player.mesos = player.mesos - mesos
    self.sinks[reason or 'unknown'] = (self.sinks[reason or 'unknown'] or 0) + mesos
    self:_record('spend', player, mesos, { reason = reason })
    markDirty(player)
    if self.metrics then self.metrics:increment('economy.mesos_out', mesos, { reason = reason or 'unknown' }) end
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
    self:_record('npc_sell', player, payout, { itemId = itemId, quantity = amount })
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
    self:_record('npc_buy', player, totalPrice, { itemId = itemId, quantity = amount })
    return true
end

function EconomySystem:snapshot()
    return { sinks = self.sinks, faucets = self.faucets, transactions = self.transactions }
end

return EconomySystem
