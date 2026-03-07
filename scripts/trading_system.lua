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

function TradingSystem:tradeMesos(fromPlayer, toPlayer, amount)
    amount = math.max(1, math.floor(tonumber(amount) or 0))
    local ok, err = self.economySystem:spendMesos(fromPlayer, amount, 'player_trade')
    if not ok then return false, err end
    self.economySystem:grantMesos(toPlayer, amount, 'player_trade')
    return true
end

return TradingSystem
