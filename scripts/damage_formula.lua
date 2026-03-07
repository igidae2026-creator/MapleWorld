local DamageFormula = {}

function DamageFormula.resolve(args)
    local derived = args.derived or {}
    local target = args.target or {}
    local skill = args.skill or {}
    local ratio = tonumber(skill.ratio) or 1
    local base = math.max(1, math.floor((tonumber(derived.attack) or 0) * ratio))
    local crit = args.critical and 1.35 or 1.0
    local reduced = math.max(1, math.floor(base * crit) - math.floor((tonumber(target.defense) or 0) * 0.5))
    return math.max(1, reduced)
end

return DamageFormula
