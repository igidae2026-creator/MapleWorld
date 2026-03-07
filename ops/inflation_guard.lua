local InflationGuard = {}

function InflationGuard.new(config)
    local cfg = config or {}
    local self = {
        ratioThreshold = tonumber(cfg.ratioThreshold) or 1.6,
        history = {},
        marketSpreadThreshold = tonumber(cfg.marketSpreadThreshold) or 3.5,
    }
    setmetatable(self, { __index = InflationGuard })
    return self
end

function InflationGuard:inspect(economy, auctionHouse)
    local faucets, sinks = 0, 0
    for _, value in pairs((economy and economy.faucets) or {}) do faucets = faucets + (tonumber(value) or 0) end
    for _, value in pairs((economy and economy.sinks) or {}) do sinks = sinks + (tonumber(value) or 0) end
    local effectiveSinks = math.max(1, sinks)
    local ratio = faucets / effectiveSinks
    local hottestItem, hottestAverage, hottestSamples = nil, 0, 0
    for itemId, history in pairs((auctionHouse and auctionHouse.priceHistory) or {}) do
        local sum = 0
        for _, price in ipairs(history or {}) do sum = sum + (tonumber(price) or 0) end
        local average = #history > 0 and (sum / #history) or 0
        if average > hottestAverage then
            hottestItem = itemId
            hottestAverage = average
            hottestSamples = #history
        end
    end
    local sinkPressure = tonumber(economy and economy.sinkPressure) or 0
    local marketSpread = hottestAverage / math.max(1, sinkPressure > 0 and (sinkPressure / math.max(1, hottestSamples)) or 1)
    local report = {
        ok = ratio <= self.ratioThreshold and marketSpread <= self.marketSpreadThreshold,
        faucetTotal = faucets,
        sinkTotal = sinks,
        ratio = ratio,
        threshold = self.ratioThreshold,
        hottestItem = hottestItem,
        hottestAverage = hottestAverage,
        hottestSamples = hottestSamples,
        marketSpread = marketSpread,
        marketSpreadThreshold = self.marketSpreadThreshold,
    }
    self.history[#self.history + 1] = report
    while #self.history > 32 do table.remove(self.history, 1) end
    return report
end

return InflationGuard
