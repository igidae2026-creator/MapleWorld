local BossMechanicsSystem = {}

function BossMechanicsSystem.new()
    return setmetatable({}, { __index = BossMechanicsSystem })
end

function BossMechanicsSystem:phase(encounter)
    local ratio = (tonumber(encounter.hp) or 0) / math.max(1, tonumber(encounter.maxHp) or 1)
    if ratio <= 0.25 then return 3 end
    if ratio <= 0.55 then return 2 end
    return 1
end

return BossMechanicsSystem
