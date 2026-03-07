local DamageFormula = require('scripts.damage_formula')

local CombatResolution = {}

function CombatResolution.new(config)
    local cfg = config or {}
    local self = {
        statSystem = cfg.statSystem,
        buffSystem = cfg.buffSystem,
        itemSystem = cfg.itemSystem,
    }
    setmetatable(self, { __index = CombatResolution })
    return self
end

function CombatResolution:resolveSkillDamage(player, target, skill)
    local effects = self.buffSystem and self.buffSystem:tick(player) or {}
    local derived = self.statSystem and self.statSystem:derived(player, self.itemSystem, effects) or {}
    local outgoing = DamageFormula.resolve({
        derived = derived,
        target = target,
        skill = skill,
        critical = (tonumber(player.level) or 1) % 5 == 0,
    })
    local scaling = 1.0 + math.min(0.8, math.max(0, (tonumber(player.progression and player.progression.mastery) or 0) * 0.015))
    return math.max(1, math.floor(outgoing * scaling))
end

return CombatResolution
