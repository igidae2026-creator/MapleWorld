local TradingSystem = {}

function TradingSystem.new(config)
    local self = {
        itemSystem = (config or {}).itemSystem,
        economySystem = (config or {}).economySystem,
        activeTrades = {},
        nextId = 1,
    }
    setmetatable(self, { __index = TradingSystem })
    return self
end

function TradingSystem:tradeMesos(fromPlayer, toPlayer, amount, context)
    amount = math.max(1, math.floor(tonumber(amount) or 0))
    local ctx = type(context) == 'table' and context or {}
    local requestId = ctx.requestId
    local correlationId = ctx.correlationId or requestId
    local spendMeta = {
        counterpartyId = toPlayer and toPlayer.id or nil,
        correlationId = correlationId,
        sourceEventId = requestId,
    }
    local grantMeta = {
        counterpartyId = fromPlayer and fromPlayer.id or nil,
        correlationId = correlationId,
        sourceEventId = requestId,
    }
    if requestId ~= nil then
        spendMeta.idempotencyKey = string.format('tradeMesos:%s:spend', tostring(requestId))
        grantMeta.idempotencyKey = string.format('tradeMesos:%s:grant', tostring(requestId))
    end
    local ok, err = self.economySystem:spendMesos(fromPlayer, amount, 'player_trade', spendMeta)
    if not ok then return false, err end
    local granted, grantErr = self.economySystem:grantMesos(toPlayer, amount, 'player_trade', grantMeta)
    if not granted then
        self.economySystem:grantMesos(fromPlayer, amount, 'player_trade_rollback', {
            correlationId = correlationId,
            rollbackOf = requestId,
            counterpartyId = toPlayer and toPlayer.id or nil,
        })
        return false, grantErr
    end
    return true
end

return TradingSystem
