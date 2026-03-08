local CheatDetection = {}

function CheatDetection.new()
    return setmetatable({ scores = {} }, { __index = CheatDetection })
end

function CheatDetection:observe(playerId, signal, amount)
    local key = tostring(playerId)
    self.scores[key] = (self.scores[key] or 0) + math.max(1, math.floor(tonumber(amount) or 1))
    return self.scores[key]
end

return CheatDetection
