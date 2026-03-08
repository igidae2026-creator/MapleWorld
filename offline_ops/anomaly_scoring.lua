local AnomalyScoring = {}

function AnomalyScoring.new()
    return setmetatable({}, { __index = AnomalyScoring })
end

function AnomalyScoring:score(detail)
    local value = 0
    for _, v in pairs(detail or {}) do
        if type(v) == 'number' then value = value + v end
    end
    return value
end

return AnomalyScoring
