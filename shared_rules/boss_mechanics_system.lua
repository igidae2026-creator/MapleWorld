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

function BossMechanicsSystem:telegraph(encounter)
    local mechanic = encounter and encounter.currentMechanic or {}
    return {
        phase = encounter and encounter.phase or 1,
        pattern = mechanic.pattern or 'opening_read',
        hazard = mechanic.hazard or 'single_strike',
        text = mechanic.text or 'Watch the boss and move before the burst lands.',
        punishWindow = mechanic.punishWindow or 'medium',
    }
end

return BossMechanicsSystem
