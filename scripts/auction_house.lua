local AuctionHouse = {}

function AuctionHouse.new(config)
    local self = {
        economy = (config or {}).economy,
        listings = {},
        nextId = 1,
        priceHistory = {},
        monitors = {},
    }
    setmetatable(self, { __index = AuctionHouse })
    return self
end

function AuctionHouse:listItem(player, itemId, quantity, price)
    local id = 'listing-' .. tostring(self.nextId)
    self.nextId = self.nextId + 1
    self.listings[id] = {
        id = id,
        sellerId = player.id,
        itemId = itemId,
        quantity = math.max(1, math.floor(tonumber(quantity) or 1)),
        price = math.max(1, math.floor(tonumber(price) or 1)),
    }
    self.priceHistory[itemId] = self.priceHistory[itemId] or {}
    self.priceHistory[itemId][#self.priceHistory[itemId] + 1] = self.listings[id].price
    return self.listings[id]
end

function AuctionHouse:marketSnapshot(itemId)
    local history = self.priceHistory[itemId] or {}
    local low, high, sum = nil, nil, 0
    for _, price in ipairs(history) do
        low = low and math.min(low, price) or price
        high = high and math.max(high, price) or price
        sum = sum + price
    end
    return {
        itemId = itemId,
        low = low or 0,
        high = high or 0,
        average = #history > 0 and math.floor(sum / #history) or 0,
        samples = #history,
    }
end

return AuctionHouse
