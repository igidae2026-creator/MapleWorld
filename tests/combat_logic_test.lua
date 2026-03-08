package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')

local now = 1000
local rolls = { 0.01, 0.99, 0.92, 0.98, 0.99, 0.97, 0.99, 0.96, 0.99, 0.95, 0.99, 0.94 }
local rollIndex = 0
local world = ServerBootstrap.boot('.', {
    time = function() return now end,
    rng = function()
        rollIndex = rollIndex + 1
        return rolls[rollIndex] or 0.99
    end,
})
local player = world:createPlayer('combat-spec')
player.level = 14
player.sp = 6
assert(world:promoteJob(player, 'warrior'))
assert(world:learnSkill(player, 'power_strike'))
local dummy = { id = 'dummy', defense = 20, level = 14, evasion = 0.05 }
local ok, payload = world:castSkill(player, 'power_strike', dummy)
assert(ok, 'skill cast failed')
assert(payload.hits and #payload.hits >= 1, 'expected combat hits')
assert(player.lastCombatFeedback and player.lastCombatFeedback.skillId == 'power_strike', 'missing feedback')
assert(payload.criticalCount >= 1, 'critical hit metadata missing')
assert(payload.evadedCount == 0, 'unexpected evade on low-evasion target')
assert(payload.statusApplied[1] and payload.statusApplied[1].kind == 'armor_break', 'status was not applied')
assert(dummy.activeEffects and #dummy.activeEffects == 1, 'target status tracking missing')
assert(player.lastCombatFeedback.criticalCount >= 1, 'combat feedback crit metadata missing')
assert(player.lastCombatFeedback.combatFlags and player.lastCombatFeedback.combatFlags.status == true, 'combat feedback status flag missing')

local afterBreak = { id = 'dummy-2', defense = 20, level = 14, activeEffects = dummy.activeEffects, evasion = 0.05 }
local ok2, followUp = world:castSkill(player, 'power_strike', afterBreak)
assert(ok2, 'follow-up cast failed')
assert(followUp.hits[1].effectiveDefense < payload.hits[1].effectiveDefense, 'armor break did not lower effective defense')

now = now + 20
local ok3, expired = world:castSkill(player, 'power_strike', afterBreak)
assert(ok3, 'post-expiry cast failed')
assert(expired.hits[1].effectiveDefense >= followUp.hits[1].effectiveDefense, 'expired status still changed defense')

local evasive = world:createPlayer('combat-evasion')
evasive.level = 14
evasive.sp = 6
assert(world:promoteJob(evasive, 'thief'))
assert(world:learnSkill(evasive, 'lucky_seven'))
local evadeTarget = { id = 'evader', defense = 6, level = 24, evasion = 0.95 }
local ok4, evaded = world:castSkill(evasive, 'lucky_seven', evadeTarget)
assert(ok4, 'evasion cast failed')
assert(evaded.evadedCount >= 1, 'high-evasion target did not evade')
assert(evaded.hits[1].amount == 0, 'evaded hit still dealt damage')
assert(evasive.lastCombatFeedback.combatFlags and evasive.lastCombatFeedback.combatFlags.evasion == true, 'combat feedback evasion flag missing')
print('combat_logic_test: ok')
