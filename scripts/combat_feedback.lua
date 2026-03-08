local CombatFeedback = {}

function CombatFeedback.new()
    return setmetatable({}, { __index = CombatFeedback })
end

function CombatFeedback:skillCast(player, skill, result)
    local damageTotal = 0
    local criticalCount = 0
    local evadedCount = 0
    for _, hit in ipairs(result.hits or {}) do damageTotal = damageTotal + (tonumber(hit.amount) or 0) end
    for _, hit in ipairs(result.hits or {}) do
        if hit.isCritical then criticalCount = criticalCount + 1 end
        if hit.evaded then evadedCount = evadedCount + 1 end
    end
    return {
        actorId = player.id,
        skillId = skill.id,
        role = skill.role or 'damage',
        visual = skill.visual or 'default_arc',
        sfx = skill.sfx or 'skill_hit',
        result = result,
        chainCount = result.comboChain or 1,
        impactTiming = result.impactDelay or 0.12,
        reaction = result.hitReaction or (result.area and 'sweeping_hit' or 'single_hit'),
        damageText = string.format('%s x%d', tostring(damageTotal > 0 and damageTotal or result.amount or 0), #(result.hits or { 1 })),
        readability = result.area and 'multi-target sweep' or 'focused strike',
        criticalCount = criticalCount,
        evadedCount = evadedCount,
        statusApplied = result.statusApplied or {},
        targetStatusState = result.targetStatusState or {},
        critRate = result.critRate,
        animationLockSec = result.animationLockSec,
        cooldownRemaining = result.cooldownRemaining,
        cooldownReadyAt = result.cooldownReadyAt,
        eventHooks = result.eventHooks or {},
        combatFlags = {
            crit = criticalCount > 0,
            evasion = evadedCount > 0,
            status = #(result.statusApplied or {}) > 0,
        },
    }
end

function CombatFeedback:lootDrop(drop)
    return {
        itemId = drop.itemId,
        rarity = drop.rarity,
        anticipation = drop.anticipation,
        excitement = drop.excitement,
        message = ({
            jackpot = 'Jackpot drop',
            boss_signature = 'Boss signature drop',
            mini_jackpot = 'Mini-jackpot drop',
            route_chase = 'Route chase drop',
            crafting_cache = 'Crafting cache',
            crafting_breakpoint = 'Crafting breakpoint',
        })[drop.excitement or ''] or 'Loot secured',
        beam = ({
            common = 'white',
            uncommon = 'green',
            rare = 'blue',
            epic = 'gold',
        })[drop.rarity or 'common'] or 'white',
    }
end

return CombatFeedback
