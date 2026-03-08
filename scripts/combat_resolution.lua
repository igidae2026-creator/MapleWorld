local DamageFormula = require('scripts.damage_formula')

local CombatResolution = {}

local STATUS_PROFILES = {
    armor_break = { duration = 12, defenseMultiplier = 0.78, feedback = 'armor_break' },
    slow = { duration = 8, evasionMultiplier = 0.82, feedback = 'slow' },
    stagger = { duration = 5, defenseMultiplier = 0.9, evasionMultiplier = 0.7, feedback = 'stagger' },
    bleed = { duration = 10, bonusDamageRate = 0.08, feedback = 'bleed' },
    stun = { duration = 3, evasionMultiplier = 0.0, forceHit = true, feedback = 'stun' },
}

function CombatResolution.new(config)
    local cfg = config or {}
    local self = {
        statSystem = cfg.statSystem,
        buffSystem = cfg.buffSystem,
        itemSystem = cfg.itemSystem,
        rng = cfg.rng or math.random,
    }
    setmetatable(self, { __index = CombatResolution })
    return self
end

function CombatResolution:_statusProfile(kind)
    return STATUS_PROFILES[kind]
end

function CombatResolution:_targetState(target, activeEffects)
    local state = {
        defense = math.max(0, tonumber(target.defense) or 0),
        evasion = math.max(0, tonumber(target.evasion) or 0),
        forceHit = false,
        statuses = {},
        statusDurations = {},
    }
    local targetLevel = math.max(1, tonumber(target.level) or tonumber(target.template and target.template.level) or 1)
    local targetRole = target.role or (target.template and target.template.role)
    state.defense = math.max(state.defense, math.floor(targetLevel * 0.7))
    if state.evasion == 0 then
        state.evasion = math.min(0.22, 0.03 + (targetLevel * 0.003))
    end
    if targetRole == 'elite' then state.evasion = state.evasion + 0.04 end
    if target.rare then state.evasion = state.evasion + 0.03 end
    if target.isBoss or target.bossId then state.evasion = state.evasion + 0.05 end
    for _, effect in ipairs(activeEffects or {}) do
        if effect.kind then
            state.statuses[#state.statuses + 1] = effect.kind
            state.statusDurations[effect.kind] = math.max(0, (tonumber(effect.expiresAt) or 0) - (tonumber(effect.appliedAt) or 0))
        end
        if effect.defenseMultiplier then state.defense = math.floor(state.defense * tonumber(effect.defenseMultiplier)) end
        if effect.evasionMultiplier ~= nil then state.evasion = state.evasion * tonumber(effect.evasionMultiplier) end
        if effect.evasionDelta ~= nil then state.evasion = state.evasion + tonumber(effect.evasionDelta) end
        if effect.bonusDamageRate ~= nil then state.defense = math.max(0, state.defense - math.floor(state.defense * tonumber(effect.bonusDamageRate))) end
        if effect.forceHit then state.forceHit = true end
    end
    state.evasion = math.max(0, math.min(0.85, state.evasion))
    return state
end

function CombatResolution:resolveSkillDamage(player, target, skill, hitContext)
    local attackerEffects = self.buffSystem and self.buffSystem:tick(player) or {}
    local targetEffects = (self.buffSystem and target) and self.buffSystem:tick(target) or {}
    local derived = self.statSystem and self.statSystem:derived(player, self.itemSystem, attackerEffects) or {}
    local targetState = self:_targetState(target or {}, targetEffects)
    local critRoll = hitContext and tonumber(hitContext.critRoll) or self.rng()
    local hitRoll = hitContext and tonumber(hitContext.hitRoll) or self.rng()
    local outgoing = DamageFormula.resolve({
        derived = derived,
        target = target,
        targetState = targetState,
        skill = skill,
        critical = critRoll <= math.max(0, tonumber(derived.critRate) or 0),
        hitRoll = hitRoll,
        forceHit = targetState.forceHit,
    })
    local chainBonus = math.max(0, tonumber(skill.comboChain) or 1) - 1
    local scaling = 1.0
        + math.min(0.8, math.max(0, (tonumber(player.progression and player.progression.mastery) or 0) * 0.015))
        + math.min(0.25, chainBonus * 0.04)
    outgoing.amount = math.max(0, math.floor((tonumber(outgoing.amount) or 0) * scaling))
    outgoing.statuses = targetState.statuses
    outgoing.statusDurations = targetState.statusDurations
    outgoing.critRate = tonumber(derived.critRate) or 0
    return outgoing
end

function CombatResolution:buildStatusEffect(skill, sourcePlayer)
    local profile = self:_statusProfile(skill and skill.statusEffect)
    if not profile then return nil end
    return {
        kind = skill.statusEffect,
        sourceSkillId = skill.id,
        duration = profile.duration,
        defenseMultiplier = profile.defenseMultiplier,
        evasionMultiplier = profile.evasionMultiplier,
        evasionDelta = profile.evasionDelta,
        bonusDamageRate = profile.bonusDamageRate,
        forceHit = profile.forceHit,
        sourcePlayerId = sourcePlayer and sourcePlayer.id or nil,
    }
end

return CombatResolution
