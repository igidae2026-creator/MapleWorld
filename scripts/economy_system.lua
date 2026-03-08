local EconomySystem = {}

local function isPositiveInteger(value)
    return type(value) == 'number' and value > 0 and value == math.floor(value)
end

local function clamp(value, low, high)
    value = tonumber(value) or 0
    if value < low then return low end
    if value > high then return high end
    return value
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
        ledgerSink = cfg.ledgerSink,
        nextTransactionId = 1,
        maxPlayerLedgerEntries = cfg.maxPlayerLedgerEntries or 64,
        suspiciousTransactionMesos = cfg.suspiciousTransactionMesos or 5000000,
        priceSignals = {},
        sinkPressure = 0,
        dynamicFeeResolver = cfg.dynamicFeeResolver,
        fieldPricePressureRate = tonumber(cfg.fieldPricePressureRate) or 0.14,
        fieldPricePressureCap = tonumber(cfg.fieldPricePressureCap) or 0.2,
        auctionListingFeeRate = tonumber(cfg.auctionListingFeeRate) or 0.045,
        auctionListingFeeFloor = math.max(0, math.floor(tonumber(cfg.auctionListingFeeFloor) or 18)),
        recentDynamicPricing = {},
        maxRecentDynamicPricing = math.max(1, math.floor(tonumber(cfg.maxRecentDynamicPricing) or 24)),
        dynamicSinkTotals = {},
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

function EconomySystem:_recordDynamicPricing(sample)
    if type(sample) ~= 'table' then return end
    local copy = {}
    for k, v in pairs(sample) do copy[k] = v end
    self.recentDynamicPricing[#self.recentDynamicPricing + 1] = copy
    while #self.recentDynamicPricing > self.maxRecentDynamicPricing do
        table.remove(self.recentDynamicPricing, 1)
    end
    local key = tostring(copy.action or 'unknown')
    self.dynamicSinkTotals[key] = (tonumber(self.dynamicSinkTotals[key]) or 0) + (tonumber(copy.surcharge) or 0)
end

function EconomySystem:_resolveDynamicPricing(action, player, baseAmount, context)
    local amount = math.max(0, math.floor(tonumber(baseAmount) or 0))
    if amount <= 0 then
        return 0, {
            action = action,
            baseAmount = amount,
            surcharge = 0,
            totalAmount = amount,
            intensity = 0,
            appliedRate = 0,
        }
    end

    local resolved = {}
    local ctx = type(context) == 'table' and context or {}
    resolved.intensity = tonumber(ctx.fieldPriceIntensity or ctx.intensity) or 0
    resolved.mapId = ctx.mapId
    resolved.region = ctx.region
    resolved.currentPopulation = ctx.currentPopulation
    resolved.populationTarget = ctx.populationTarget
    resolved.congestionPressure = ctx.congestionPressure
    resolved.routingReason = ctx.routingReason
    if type(self.dynamicFeeResolver) == 'function' then
        local ok, dynamicResolved = pcall(self.dynamicFeeResolver, action, player, amount, ctx)
        if ok and type(dynamicResolved) == 'table' then
            for k, v in pairs(dynamicResolved) do resolved[k] = v end
        end
    end
    local maxRate = clamp(self.fieldPricePressureCap, 0, 1)
    local baseRate = clamp(self.fieldPricePressureRate, 0, maxRate)
    local intensity = clamp(resolved.intensity or 0, 0, 1)
    local appliedRate = math.min(maxRate, baseRate * intensity)
    local surcharge = math.max(0, math.floor((amount * appliedRate) + 0.5))
    local sample = {
        action = action,
        baseAmount = amount,
        surcharge = surcharge,
        totalAmount = amount + surcharge,
        intensity = intensity,
        appliedRate = appliedRate,
        mapId = resolved.mapId,
        region = resolved.region,
        currentPopulation = resolved.currentPopulation,
        populationTarget = resolved.populationTarget,
        congestionPressure = resolved.congestionPressure,
        routingReason = resolved.routingReason,
    }
    if surcharge > 0 then self:_recordDynamicPricing(sample) end
    return surcharge, sample
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
    while #player.economyLedger > cap do table.remove(player.economyLedger, 1) end
end

function EconomySystem:_emitAudit(entry)
    if type(self.auditSink) ~= 'function' then return end
    local ok, err = pcall(self.auditSink, entry)
    if not ok then
        if self.metrics then self.metrics:increment('economy.audit_sink_error', 1) end
        if self.logger and self.logger.error then self.logger:error('economy_audit_sink_failed', { error = tostring(err), txId = entry.txId }) end
    elseif self.metrics then
        self.metrics:increment('economy.audit_sink_ok', 1)
    end
end

function EconomySystem:_emitLedgerEvent(player, eventType, mesosDelta, context)
    if type(self.ledgerSink) ~= 'function' then return nil end
    local ctx = type(context) == 'table' and context or {}
    local key = ctx.idempotencyKey or string.format('%s:%s:%s:%s', tostring(eventType), tostring(player and player.id or 'system'), tostring(ctx.reason or 'na'), tostring(ctx.correlationId or os.time()))
    local payload = {
        event_type = eventType,
        actor_id = player and player.id or nil,
        player_id = player and player.id or nil,
        source_system = 'economy_system',
        source_event_id = tostring(ctx.txId or ''),
        correlation_id = ctx.correlationId,
        map_id = ctx.mapId,
        boss_id = ctx.bossId,
        quest_id = ctx.questId,
        npc_id = ctx.npcId,
        item_id = ctx.itemId,
        quantity = ctx.quantity,
        mesos_delta = mesosDelta,
        pre_state = { mesos = ctx.beforeMesos },
        post_state = { mesos = ctx.afterMesos },
        idempotency_key = key,
        compensation_of = ctx.compensationOf,
        rollback_of = ctx.rollbackOf,
        metadata = { reason = ctx.reason, tx_kind = ctx.kind },
    }
    return self.ledgerSink(payload)
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
    if entry.meta and entry.meta.itemId and tonumber(entry.meta.unitPrice) then
        self.priceSignals[entry.meta.itemId] = self.priceSignals[entry.meta.itemId] or {}
        self.priceSignals[entry.meta.itemId][#self.priceSignals[entry.meta.itemId] + 1] = tonumber(entry.meta.unitPrice)
    end

    local delta = kind == 'spend' and -amount or amount
    self:_emitLedgerEvent(player, 'mesos_' .. tostring(kind), delta, {
        txId = entry.txId,
        beforeMesos = beforeMesos,
        afterMesos = afterMesos,
        reason = entry.meta.reason,
        kind = kind,
        itemId = entry.meta.itemId,
        quantity = entry.meta.quantity,
        npcId = entry.meta.npcId,
        questId = entry.meta.questId,
        bossId = entry.meta.bossId,
        correlationId = entry.meta.correlationId,
        idempotencyKey = entry.meta.idempotencyKey,
        compensationOf = entry.meta.compensationOf,
        rollbackOf = entry.meta.rollbackOf,
    })

    if amount >= math.max(1, math.floor(tonumber(self.suspiciousTransactionMesos) or 1)) then
        if self.metrics then self.metrics:increment('economy.suspicious_large_flow', 1, { kind = kind }) end
        if self.logger and self.logger.info then
            self.logger:info('economy_suspicious_large_flow', { txId = entry.txId, playerId = entry.playerId, kind = kind, amount = amount, reason = entry.meta.reason })
        end
    end
end

function EconomySystem:grantMesos(player, amount, reason, meta)
    local mesos = self:_normalizeAmount(amount)
    if not player then return false, 'invalid_player' end
    if not mesos then return false, 'invalid_amount' end

    local previous = tonumber(player.mesos) or 0
    player.mesos = math.min(self.maxMesos, previous + mesos)
    local applied = player.mesos - previous
    self.faucets[reason or 'unknown'] = (self.faucets[reason or 'unknown'] or 0) + applied
    local details = meta or {}
    details.reason = reason
    details.requested = mesos
    details.beforeMesos = previous
    details.afterMesos = player.mesos
    self:_record('grant', player, applied, details)
    markDirty(player)
    if self.metrics then
        self.metrics:increment('economy.mesos_in', applied, { reason = reason or 'unknown' })
        self.metrics:gauge('economy.player_balance', tonumber(player.mesos) or 0, { playerId = tostring(player.id) })
    end
    if self.logger and self.logger.info then self.logger:info('mesos_granted', { playerId = player.id, amount = applied, reason = reason }) end
    return true
end

function EconomySystem:spendMesos(player, amount, reason, meta)
    local mesos = self:_normalizeAmount(amount)
    if not player then return false, 'invalid_player' end
    if not mesos then return false, 'invalid_amount' end
    if (tonumber(player.mesos) or 0) < mesos then return false, 'insufficient_mesos' end

    local before = player.mesos
    player.mesos = player.mesos - mesos
    self.sinks[reason or 'unknown'] = (self.sinks[reason or 'unknown'] or 0) + mesos
    self.sinkPressure = self.sinkPressure + mesos
    local details = meta or {}
    details.reason = reason
    details.beforeMesos = before
    details.afterMesos = player.mesos
    self:_record('spend', player, mesos, details)
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

function EconomySystem:sellToNpc(player, itemId, quantity, context)
    local amount = math.floor(tonumber(quantity) or 0)
    if not isPositiveInteger(amount) then return false, 'invalid_quantity' end

    local payout, err = self:quoteNpcSell(itemId, amount)
    if payout == nil then return false, err end

    local ctx = type(context) == 'table' and context or {}
    local removed, removeErr = self.itemSystem:removeItem(player, itemId, amount, nil, {
        source = 'shop_sell',
        source_event_id = ctx.sourceEventId,
        correlation_id = ctx.correlationId,
        npc_id = ctx.npcId,
    })
    if not removed then return false, removeErr end
    local ok, grantErr = self:grantMesos(player, payout, 'npc_sell', { itemId = itemId, quantity = amount, npcId = ctx.npcId, correlationId = ctx.correlationId, unitPrice = math.max(1, math.floor(payout / math.max(1, amount))) })
    if not ok then
        self.itemSystem:addItem(player, itemId, amount, nil, { source = 'shop_sell_rollback', correlation_id = ctx.correlationId })
        return false, grantErr
    end
    return true
end

function EconomySystem:buyFromNpc(player, itemId, quantity, context)
    local amount = math.floor(tonumber(quantity) or 0)
    if not isPositiveInteger(amount) then return false, 'invalid_quantity' end

    local basePrice, err = self:quoteNpcBuy(itemId, amount)
    if basePrice == nil then return false, err end

    local ctx = type(context) == 'table' and context or {}
    local surcharge, pricing = self:_resolveDynamicPricing('npc_buy', player, basePrice, ctx)
    local totalPrice = basePrice + surcharge
    local spent, spendErr = self:spendMesos(player, totalPrice, 'npc_buy', {
        itemId = itemId,
        quantity = amount,
        npcId = ctx.npcId,
        correlationId = ctx.correlationId,
        mapId = ctx.mapId,
        unitPrice = math.max(1, math.floor(totalPrice / math.max(1, amount))),
        basePrice = basePrice,
        dynamicFee = surcharge,
        dynamicPricing = pricing,
    })
    if not spent then return false, spendErr end
    local added, addErr = self.itemSystem:addItem(player, itemId, amount, nil, {
        source = 'shop_buy',
        correlation_id = ctx.correlationId,
        npc_id = ctx.npcId,
        source_event_id = ctx.sourceEventId,
    })
    if not added then
        self:grantMesos(player, totalPrice, 'npc_buy_rollback', {
            rollbackOf = ctx.sourceEventId,
            correlationId = ctx.correlationId,
            mapId = ctx.mapId,
            dynamicFee = surcharge,
        })
        return false, addErr
    end
    return true
end

function EconomySystem:quoteAuctionListingFee(player, itemId, quantity, price, context)
    local amount = math.max(1, math.floor(tonumber(quantity) or 1))
    local unitPrice = math.max(1, math.floor(tonumber(price) or 1))
    local listingValue = amount * unitPrice
    local baseFee = math.max(self.auctionListingFeeFloor, math.floor((listingValue * self.auctionListingFeeRate) + 0.5))
    local surcharge, pricing = self:_resolveDynamicPricing('auction_listing', player, baseFee, context)
    return baseFee + surcharge, {
        itemId = itemId,
        quantity = amount,
        unitPrice = unitPrice,
        listingValue = listingValue,
        baseFee = baseFee,
        surcharge = surcharge,
        totalFee = baseFee + surcharge,
        pricing = pricing,
    }
end

function EconomySystem:snapshot()
    return {
        sinks = self.sinks,
        faucets = self.faucets,
        transactions = self.transactions,
        nextTransactionId = self.nextTransactionId,
        priceSignals = self.priceSignals,
        sinkPressure = self.sinkPressure,
        recentDynamicPricing = self.recentDynamicPricing,
        dynamicSinkTotals = self.dynamicSinkTotals,
    }
end

function EconomySystem:controlReport()
    local correlatedCount = 0
    local rollbackTaggedCount = 0
    local idempotentCount = 0
    for _, entry in ipairs(self.transactions or {}) do
        local meta = entry.meta or {}
        if meta.correlationId ~= nil then correlatedCount = correlatedCount + 1 end
        if meta.rollbackOf ~= nil or meta.compensationOf ~= nil then rollbackTaggedCount = rollbackTaggedCount + 1 end
        if meta.idempotencyKey ~= nil then idempotentCount = idempotentCount + 1 end
    end
    return {
        tuning = {
            npcSellRate = self.npcSellRate,
            maxMesos = self.maxMesos,
            suspiciousTransactionMesos = self.suspiciousTransactionMesos,
            maxPlayerLedgerEntries = self.maxPlayerLedgerEntries,
            fieldPricePressureRate = self.fieldPricePressureRate,
            fieldPricePressureCap = self.fieldPricePressureCap,
            auctionListingFeeRate = self.auctionListingFeeRate,
            auctionListingFeeFloor = self.auctionListingFeeFloor,
        },
        observability = {
            sinkPressure = self.sinkPressure,
            faucetReasons = self.faucets,
            sinkReasons = self.sinks,
            trackedPriceSignals = self.priceSignals,
            recentTransactions = self.transactions,
            recentDynamicPricing = self.recentDynamicPricing,
            dynamicSinkTotals = self.dynamicSinkTotals,
        },
        mutationBoundaries = {
            recentTransactionCount = #self.transactions,
            correlatedTransactionCount = correlatedCount,
            rollbackTaggedCount = rollbackTaggedCount,
            idempotentTransactionCount = idempotentCount,
            latestTransaction = self.transactions[#self.transactions],
            latestDynamicPricing = self.recentDynamicPricing[#self.recentDynamicPricing],
        },
    }
end

return EconomySystem
