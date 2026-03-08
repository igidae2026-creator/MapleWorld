package.path = package.path .. ';./?.lua;../?.lua'

local BuffSystem = require('scripts.buff_debuff_system')
local CombatResolution = require('scripts.combat_resolution')
local CombatFeedback = require('scripts.combat_feedback')
local SkillSystem = require('scripts.skill_system')
local StatSystem = require('scripts.stat_system')

local now = 100
local rolls = { 0.01, 0.99, 0.95, 0.99, 0.8, 0.99 }
local rollIndex = 0

local function rng()
    rollIndex = rollIndex + 1
    return rolls[rollIndex] or 0.99
end

local buffSystem = BuffSystem.new({
    time = function() return now end,
})
local statSystem = StatSystem.new({})
local combat = CombatResolution.new({
    statSystem = statSystem,
    buffSystem = buffSystem,
    itemSystem = {
        getPower = function() return 0 end,
    },
    rng = rng,
})
local skillSystem = SkillSystem.new({
    time = function() return now end,
    buffSystem = buffSystem,
    combat = combat,
    skillTrees = {
        warrior = {
            {
                id = 'earthsplitter',
                type = 'damage',
                ratio = 1.9,
                mpCost = 10,
                cooldown = 12,
                unlock = 1,
                role = 'tank',
                visual = 'earth_crack',
                aoeCount = 2,
                statusEffect = 'stagger',
                branch = 'vanguard',
                impactDelay = 0.24,
            },
        },
    },
})
local feedback = CombatFeedback.new()

local player = {
    id = 'runtime-contract',
    level = 20,
    jobId = 'warrior',
    sp = 1,
    stats = { str = 35, dex = 10, int = 4, luk = 6, hp = 80, mp = 60 },
    progression = { mastery = 3 },
}
local target = { id = 'mob-1', defense = 20, level = 20, evasion = 0.04 }

skillSystem:ensurePlayer(player)
assert(skillSystem:learn(player, 'earthsplitter'))

local ok, payload = skillSystem:cast(player, 'earthsplitter', target)
assert(ok, 'cast failed')
assert(payload.criticalCount >= 1, 'critical hit metadata missing')
assert(payload.hits[1].effectiveDefense >= 1, 'effective defense missing')
assert(payload.statusApplied[1] and payload.statusApplied[1].kind == 'stagger', 'status application missing')
assert(payload.targetStatusState[1] and payload.targetStatusState[1].remainingDuration == 5, 'status duration snapshot missing')
assert(payload.cooldownRemaining == 12, 'cooldown metadata missing')
assert(payload.cooldownReadyAt == 112, 'cooldown ready timestamp missing')
assert(payload.animationLockSec >= payload.impactDelay, 'animation lock shorter than impact timing')
assert(#payload.eventHooks == 5, 'animation event hooks missing')
assert(payload.eventHooks[1].kind == 'cast_start', 'cast start hook missing')
assert(payload.eventHooks[3].kind == 'impact', 'impact hook missing')
assert(payload.eventHooks[5].kind == 'cooldown_ready', 'cooldown ready hook missing')
assert(payload.eventHooks[3].at > payload.eventHooks[2].at, 'impact hook ordering invalid')
assert(target.activeEffects and #target.activeEffects == 1, 'target status state not persisted')

local eventFeedback = feedback:skillCast(player, { id = 'earthsplitter', role = 'tank', visual = 'earth_crack' }, payload)
assert(eventFeedback.criticalCount == payload.criticalCount, 'feedback critical count mismatch')
assert(eventFeedback.targetStatusState[1] and eventFeedback.targetStatusState[1].kind == 'stagger', 'feedback status timeline missing')
assert(eventFeedback.eventHooks[5] and eventFeedback.eventHooks[5].kind == 'cooldown_ready', 'feedback event hooks missing')

local cooldownState = skillSystem:getCooldownState(player, now)
assert(cooldownState.earthsplitter and cooldownState.earthsplitter.remaining == 12, 'cooldown state missing active skill')

local locked, lockErr = skillSystem:cast(player, 'earthsplitter', target)
assert(not locked and lockErr == 'skill_on_cooldown', 'cooldown guard failed')

now = 104
local activeTargetEffects = buffSystem:snapshot(target)
assert(activeTargetEffects[1] and activeTargetEffects[1].remainingDuration == 1, 'buff duration management drifted')

now = 113
assert(next(skillSystem:getCooldownState(player, now)) == nil, 'expired cooldown was not cleaned up')
assert(#buffSystem:snapshot(target) == 0, 'expired status effect not removed')

print('combat_runtime_contract_test: ok')
