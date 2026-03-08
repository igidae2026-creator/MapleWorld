local DamageFormula = {}

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

function DamageFormula.resolve(args)
    local derived = args.derived or {}
    local target = args.target or {}
    local skill = args.skill or {}
    local targetState = args.targetState or {}
    local ratio = tonumber(skill.ratio) or 1
    local offense = tonumber(skill.usesMagic) and tonumber(derived.magic) or tonumber(derived.attack)
    local base = math.max(1, math.floor((offense or 0) * ratio))
    local crit = args.critical and 1.35 or 1.0
    local comboPressure = math.max(0, (tonumber(skill.comboChain) or 1) - 1) * 0.03
    local defense = math.max(0, tonumber(targetState.defense) or tonumber(target.defense) or 0)
    local evasion = clamp(math.max(0, tonumber(targetState.evasion) or tonumber(target.evasion) or 0), 0, 0.85)
    if args.forceHit ~= true and evasion > 0 and not args.critical and (tonumber(args.hitRoll) or 1) < evasion then
        return {
            amount = 0,
            evaded = true,
            isCritical = false,
            defense = defense,
            evasion = evasion,
        }
    end
    local reduced = math.max(1, math.floor(base * (crit + comboPressure)) - math.floor(defense * 0.5))
    return {
        amount = math.max(1, reduced),
        evaded = false,
        isCritical = args.critical == true,
        defense = defense,
        evasion = evasion,
    }
end

return DamageFormula
