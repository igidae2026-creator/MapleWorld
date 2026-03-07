package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.', {
    autoPickupDrops = false,
    rng = function() return 0 end,
})

for i = 1, 15 do
    world:markWorldStateDirty('mutation_' .. tostring(i))
end

local status = world:getRuntimeStatus()
assert(status.savePlan.checkpointClass == 'integrity_checkpoint', 'save plan did not promote to integrity checkpoint')
assert(status.savePlan.urgency == 'immediate', 'save plan did not promote urgency')
assert((status.savePlan.healthScore or 0) < 100, 'save plan health score not reduced')

print('save_plan_test: ok')
