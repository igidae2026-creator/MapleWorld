local LootDistribution = {}

function LootDistribution.new()
    return setmetatable({}, { __index = LootDistribution })
end

function LootDistribution:split(players, drops)
    local result = {}
    local list = players or {}
    for i, drop in ipairs(drops or {}) do
        local owner = list[((i - 1) % math.max(1, #list)) + 1]
        result[#result + 1] = { ownerId = owner and owner.id or nil, drop = drop }
    end
    return result
end

return LootDistribution
