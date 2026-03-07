local Aggregator = {}

function Aggregator.new()
    return setmetatable({ counters = {} }, { __index = Aggregator })
end

function Aggregator:add(name, amount)
    self.counters[name] = (self.counters[name] or 0) + (tonumber(amount) or 0)
    return self.counters[name]
end

return Aggregator
