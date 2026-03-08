local SkillSystem = {}

local STATUS_REACTIONS = {
    armor_break = 'armor_shatter',
    slow = 'slow',
    stagger = 'stagger',
    bleed = 'bleed',
    stun = 'stun',
}

function SkillSystem.new(config)
    local cfg = config or {}
    local self = {
        skillTrees = cfg.skillTrees or {},
        buffSystem = cfg.buffSystem,
        combat = cfg.combat,
        time = cfg.time or os.time,
    }
    setmetatable(self, { __index = SkillSystem })
    return self
end

function SkillSystem:_definitionForPlayer(player, skillId)
    for _, skill in ipairs(self.skillTrees[player.jobId or 'beginner'] or {}) do
        if skill.id == skillId then return skill end
    end
    return nil
end

function SkillSystem:_eventHooks(now, definition, cooldownReadyAt, comboChain)
    local impactDelay = tonumber(definition.impactDelay) or ((tonumber(definition.aoeCount) or 1) > 1 and 0.24 or 0.12)
    local windup = math.max(0.03, math.floor((impactDelay * 0.45) * 100) / 100)
    local recovery = math.max(0.08, math.floor((impactDelay + 0.12 + (math.max(0, (tonumber(comboChain) or 1) - 1) * 0.01)) * 100) / 100)
    local cooldownAt = math.max(now, tonumber(cooldownReadyAt) or now)
    return {
        { kind = 'cast_start', at = now, offset = 0, window = 'input' },
        { kind = 'animation_commit', at = now + windup, offset = windup, window = 'windup' },
        { kind = 'impact', at = now + impactDelay, offset = impactDelay, window = 'impact' },
        { kind = 'recovery_complete', at = now + recovery, offset = recovery, window = 'recovery' },
        { kind = 'cooldown_ready', at = cooldownAt, offset = cooldownAt - now, window = 'cooldown' },
    }
end

function SkillSystem:getCooldownState(player, nowOverride)
    self:ensurePlayer(player)
    local now = math.floor(tonumber(nowOverride) or tonumber(self.time()) or os.time())
    local state = {}
    for skillId, readyAt in pairs(player.cooldowns or {}) do
        local remaining = math.max(0, math.floor((tonumber(readyAt) or 0) - now))
        if remaining > 0 then
            state[skillId] = {
                readyAt = tonumber(readyAt) or now,
                remaining = remaining,
            }
        else
            player.cooldowns[skillId] = nil
        end
    end
    return state
end

function SkillSystem:ensurePlayer(player)
    player.skills = player.skills or {}
    player.cooldowns = player.cooldowns or {}
    player.skillLoadout = player.skillLoadout or {}
    player.comboState = player.comboState or { chain = 0, lastSkillId = nil, lastCastAt = 0, branch = 'general' }
    local jobSkills = self.skillTrees[player.jobId or 'beginner'] or {}
    for _, skill in ipairs(jobSkills) do
        local row = player.skills[skill.id] or { level = 0, unlocked = false, rank = skill.rank or 'core', branch = skill.branch or 'general', style = skill.style or 'steady' }
        row.unlocked = row.unlocked or ((tonumber(player.level) or 1) >= (tonumber(skill.unlock) or 1))
        player.skills[skill.id] = row
    end
    return player
end

function SkillSystem:learn(player, skillId)
    self:ensurePlayer(player)
    local definition = self:_definitionForPlayer(player, skillId)
    if not definition then return false, 'unknown_skill' end
    if (tonumber(player.level) or 1) < (tonumber(definition.unlock) or 1) then return false, 'level_too_low' end
    if (tonumber(player.sp) or 0) <= 0 then return false, 'insufficient_sp' end
    player.skills[skillId].level = (tonumber(player.skills[skillId].level) or 0) + 1
    player.skills[skillId].unlocked = true
    player.sp = (tonumber(player.sp) or 0) - 1
    player.dirty = true
    return true
end

function SkillSystem:cast(player, skillId, target)
    self:ensurePlayer(player)
    local definition = self:_definitionForPlayer(player, skillId)
    if not definition then return false, 'unknown_skill' end
    local now = math.floor(tonumber(self.time()) or os.time())
    local cooldownState = self:getCooldownState(player, now)
    if cooldownState[skillId] then return false, 'skill_on_cooldown' end
    if (tonumber(player.stats.mp) or 0) < (tonumber(definition.mpCost) or 0) then return false, 'insufficient_mp' end

    local combo = player.comboState or { chain = 0, lastSkillId = nil, lastCastAt = 0, branch = 'general' }
    local comboWindow = tonumber(definition.comboWindow) or 4
    if (now - (tonumber(combo.lastCastAt) or 0)) <= comboWindow then
        if combo.lastSkillId ~= skillId then
            combo.chain = math.min(5, (tonumber(combo.chain) or 0) + 1)
        else
            combo.chain = math.max(1, math.floor((tonumber(combo.chain) or 1) * 0.5))
        end
    else
        combo.chain = 1
    end
    combo.lastSkillId = skillId
    combo.lastCastAt = now
    combo.branch = definition.branch or 'general'
    player.comboState = combo

    player.stats.mp = (tonumber(player.stats.mp) or 0) - (tonumber(definition.mpCost) or 0)
    local cooldown = math.max(0, math.floor(tonumber(definition.cooldown) or 0))
    local cooldownReduction = math.min(cooldown, math.max(0, combo.chain - 1))
    player.cooldowns[skillId] = now + math.max(0, cooldown - cooldownReduction)
    local cooldownReadyAt = tonumber(player.cooldowns[skillId]) or now
    local eventHooks = self:_eventHooks(now, definition, cooldownReadyAt, combo.chain)
    player.dirty = true

    local learned = player.skills[skillId] or {}
    local mastery = math.max(1, tonumber(learned.level) or 1)
    local comboBonus = 1 + (math.max(0, combo.chain - 1) * 0.06)
    if definition.type == 'buff' then
        local effect = self.buffSystem:apply(player, {
            skillId = skillId,
            stat = definition.stat,
            amount = (tonumber(definition.amount) or 0) + math.max(0, mastery - 1),
            duration = definition.duration,
            kind = definition.effectKind or 'buff',
        })
        return true, {
            type = 'buff',
            effect = effect,
            visual = definition.visual or 'aura_ring',
            branch = definition.branch or 'general',
            comboChain = combo.chain,
            impactDelay = tonumber(definition.impactDelay) or 0.15,
            cooldownRemaining = math.max(0, cooldownReadyAt - now),
            cooldownReadyAt = cooldownReadyAt,
            castAt = now,
            animationLockSec = math.max(0, tonumber(eventHooks[4] and eventHooks[4].offset) or 0),
            eventHooks = eventHooks,
        }
    end

    local damage = self.combat:resolveSkillDamage(player, target or {}, {
        id = definition.id,
        ratio = ((tonumber(definition.ratio) or 1) + ((mastery - 1) * 0.08)) * comboBonus,
        role = definition.role or 'damage',
        comboChain = combo.chain,
        statusEffect = definition.statusEffect,
        usesMagic = player.jobId == 'magician',
    })
    local hits = {}
    local targetCount = math.max(1, math.floor(tonumber(definition.aoeCount) or 1))
    local statusApplied = {}
    local evadedCount = 0
    local criticalCount = 0
    for index = 1, targetCount do
        local resolved = (index == 1) and damage or self.combat:resolveSkillDamage(player, target or {}, {
            id = definition.id,
            ratio = ((tonumber(definition.ratio) or 1) + ((mastery - 1) * 0.08)) * comboBonus,
            role = definition.role or 'damage',
            comboChain = combo.chain,
            statusEffect = definition.statusEffect,
            usesMagic = player.jobId == 'magician',
        })
        local applied = nil
        if target and index == 1 and definition.statusEffect and not resolved.evaded then
            applied = self.combat:buildStatusEffect({ id = definition.id, statusEffect = definition.statusEffect }, player)
            if applied then
                applied = self.buffSystem:applyStatus(target, applied)
                statusApplied[#statusApplied + 1] = {
                    kind = applied.kind,
                    duration = math.max(0, (tonumber(applied.expiresAt) or 0) - (tonumber(applied.appliedAt) or 0)),
                }
            end
        end
        if resolved.evaded then evadedCount = evadedCount + 1 end
        if resolved.isCritical then criticalCount = criticalCount + 1 end
        hits[#hits + 1] = {
            targetId = target and target.id or ('target-' .. tostring(index)),
            amount = math.max(0, math.floor((tonumber(resolved.amount) or 0) * (index == 1 and 1 or 0.72))),
            status = applied and applied.kind or nil,
            reaction = resolved.evaded and 'evade' or STATUS_REACTIONS[definition.statusEffect] or 'hit',
            evaded = resolved.evaded,
            isCritical = resolved.isCritical,
            effectiveDefense = resolved.defense,
            effectiveEvasion = resolved.evasion,
            activeStatuses = resolved.statuses,
        }
    end
    local targetStatusState = target and self.buffSystem:snapshot(target) or {}
    return true, {
        type = 'damage',
        amount = math.max(0, tonumber(hits[1] and hits[1].amount) or 0),
        target = target,
        hits = hits,
        area = targetCount > 1,
        visual = definition.visual or (targetCount > 1 and 'sweeping_arc' or 'single_hit'),
        role = definition.role or 'damage',
        branch = definition.branch or 'general',
        comboChain = combo.chain,
        comboBonus = comboBonus,
        impactDelay = tonumber(definition.impactDelay) or (targetCount > 1 and 0.24 or 0.12),
        hitReaction = evadedCount > 0 and 'evade' or STATUS_REACTIONS[definition.statusEffect] or 'flinch',
        cooldownRemaining = math.max(0, cooldownReadyAt - now),
        cooldownReadyAt = cooldownReadyAt,
        castAt = now,
        animationLockSec = math.max(0, tonumber(eventHooks[4] and eventHooks[4].offset) or 0),
        eventHooks = eventHooks,
        statusApplied = statusApplied,
        targetStatusState = targetStatusState,
        criticalCount = criticalCount,
        evadedCount = evadedCount,
        critRate = damage.critRate,
    }
end

return SkillSystem
