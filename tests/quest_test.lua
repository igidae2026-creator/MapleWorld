package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')
local world = ServerBootstrap.boot('.')
local player = world:createPlayer('quester')
local accepted = world.questSystem:accept(player, 'q_snail_cleanup')
assert(accepted, 'quest accept failed')
local killed = 0
for cycle = 1, 5 do
    world.scheduler:tick(5)
    for spawnId, mob in pairs(world.spawnSystem.maps['henesys_hunting_ground'].active) do
        if mob.mobId == 'snail' and killed < 5 then
            world:killMob(player, 'henesys_hunting_ground', spawnId)
            killed = killed + 1
        end
    end
end
assert(world.questSystem:isComplete(player, 'q_snail_cleanup'), 'quest progress incomplete')
assert(world.questSystem:turnIn(player, 'q_snail_cleanup'), 'turn in failed')
assert(player.mesos >= 100, 'quest reward mesos missing')
print('quest_test: ok')
