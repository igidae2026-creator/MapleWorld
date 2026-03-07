package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.', {
    autoPickupDrops = false,
    rng = function() return 0 end,
})

local ok, err = world:replacePolicyBundle({
    policyId = 'genesis.experimental',
    policyVersion = '2.1.0',
    adoptionSource = 'test_override',
    savePolicy = { debounceSec = 1 },
})
assert(ok, 'policy replacement failed: ' .. tostring(err))

local status = world:getRuntimeStatus()
assert(status.policy.policyId == 'genesis.experimental', 'policy id was not replaced')
assert(status.policy.rollback.previousPolicyId == 'genesis.default', 'rollback previous policy id missing')
assert(status.policy.lineage.parentPolicyId == 'genesis.default', 'policy lineage parent missing')
assert(type(status.policy.lineage.replacementHistory) == 'table' and #status.policy.lineage.replacementHistory >= 1, 'replacement history missing')

print('policy_lineage_test: ok')
