package.path = package.path .. ';./?.lua;../?.lua'

local Runtime = require('msw_runtime.state.gameplay_runtime')

local runtime = Runtime:new()
assert(runtime:bootstrap().ok == true, 'bootstrap failed')
assert(runtime:onUserEnter({ playerId = 'p2' }).ok == true, 'player enter failed')

local player = runtime.players.p2
player.ap = 5
player.sp = 5
player.level = 30

local job = runtime:promoteJob('p2', 'warrior')
assert(job.ok == true, 'job promotion failed')
assert(runtime.players.p2.jobId == 'warrior', 'job not updated')

local allocate = runtime:allocateStat('p2', 'str', 3)
assert(allocate.ok == true, 'stat allocation failed')
assert(runtime.players.p2.stats.str >= 7, 'stat allocation did not apply')

local learn = runtime:learnSkill('p2', 'power_strike')
assert(learn.ok == true, 'skill learn failed')
assert(runtime.players.p2.skills.power_strike.level >= 1, 'skill level did not increment')

local buy = runtime:buyFromNpc('p2', runtime.starterWeaponId, 1, 'npc')
assert(buy.ok == true, 'npc buy failed')

local equip = runtime:equipItem('p2', runtime.starterWeaponId)
assert(equip.ok == true, 'equip failed')
assert(equip.player.equipment.weapon ~= nil, 'weapon not equipped')

local enhance = runtime:enhanceEquipment('p2', runtime.starterWeaponId, 'weapon')
assert(enhance.ok == true, 'enhancement failed')
assert(enhance.player.equipment.weapon.enhancement >= 1, 'enhancement did not apply')

local unequip = runtime:unequipItem('p2', 'weapon')
assert(unequip.ok == true, 'unequip failed')
assert(unequip.player.equipment.weapon == nil, 'weapon still equipped')

local questId, questDef = nil, nil
for candidateId, candidateQuest in pairs(runtime.normalized.quests) do
    if (tonumber(candidateQuest.requiredLevel) or 9999) <= runtime.players.p2.level then
        if questId == nil or (tonumber(candidateQuest.requiredLevel) or 9999) < (tonumber(questDef.requiredLevel) or 9999) then
            questId, questDef = candidateId, candidateQuest
        end
    end
end
assert(questId ~= nil, 'quest catalog missing')
assert(runtime:acceptQuest('p2', questId).ok == true, 'quest accept failed')

local firstObjective = questDef.objectives[1]
assert(firstObjective ~= nil, 'quest missing objectives')
if firstObjective.type == 'collect' then
    assert(runtime.itemSystem:addItem(player, firstObjective.targetId, firstObjective.required, nil, { source = 'test' }) == true, 'seed collect item failed')
    runtime.questSystem:onItemAcquired(player, firstObjective.targetId, firstObjective.required)
else
    runtime.questSystem:onKill(player, firstObjective.targetId, firstObjective.required)
end
assert(runtime.questSystem:isComplete(player, questId) == true, 'quest did not complete')

local turnIn = runtime:turnInQuest('p2', questId)
assert(turnIn.ok == true, 'quest turn-in failed')
assert(turnIn.player.questState[questId].completed == true, 'quest completion not persisted')

local recommendation = runtime:getBuildRecommendation('p2')
assert(recommendation.ok == true and recommendation.build.role ~= nil, 'build recommendation failed')

print('msw_runtime_progression_test: ok')
