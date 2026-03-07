local SkillSystem = {}

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
    local definition = nil
    for _, skill in ipairs(self.skillTrees[player.jobId or 'beginner'] or {}) do
        if skill.id == skillId then definition = skill break end
    end
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
    local definition = nil
    for _, skill in ipairs(self.skillTrees[player.jobId or 'beginner'] or {}) do
        if skill.id == skillId then definition = skill break end
    end
    if not definition then return false, 'unknown_skill' end
    local now = math.floor(tonumber(self.time()) or os.time())
    if (tonumber(player.cooldowns[skillId]) or 0) > now then return false, 'skill_on_cooldown' end
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
            cooldownRemaining = math.max(0, (tonumber(player.cooldowns[skillId]) or now) - now),
        }
    end

    local damage = self.combat:resolveSkillDamage(player, target or {}, {
        id = definition.id,
        ratio = ((tonumber(definition.ratio) or 1) + ((mastery - 1) * 0.08)) * comboBonus,
        role = definition.role or 'damage',
        comboChain = combo.chain,
    })
    local hits = {}
    local targetCount = math.max(1, math.floor(tonumber(definition.aoeCount) or 1))
    for index = 1, targetCount do
        hits[#hits + 1] = {
            targetId = target and target.id or ('target-' .. tostring(index)),
            amount = math.max(1, math.floor(damage * (index == 1 and 1 or 0.72))),
            status = definition.statusEffect,
            reaction = definition.statusEffect and 'stagger' or 'hit',
        }
    end
    return true, {
        type = 'damage',
        amount = damage,
        target = target,
        hits = hits,
        area = targetCount > 1,
        visual = definition.visual or (targetCount > 1 and 'sweeping_arc' or 'single_hit'),
        role = definition.role or 'damage',
        branch = definition.branch or 'general',
        comboChain = combo.chain,
        comboBonus = comboBonus,
        impactDelay = tonumber(definition.impactDelay) or (targetCount > 1 and 0.24 or 0.12),
        hitReaction = definition.statusEffect and 'stagger' or 'flinch',
        cooldownRemaining = math.max(0, (tonumber(player.cooldowns[skillId]) or now) - now),
    }
end

return SkillSystem
