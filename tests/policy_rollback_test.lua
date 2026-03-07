package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.', {
    autoPickupDrops = false,
    rng = function() return 0 end,
})

local ok, err = world:replacePolicyBundle({
    policyId = 'genesis.experimental.rollback',
    policyVersion = '3.0.0',
    adoptionReason = 'policy_rollback_test',
    savePolicy = { debounceSec = 1 },
}, {
    adoptionSource = 'test',
    adoptionReason = 'policy_rollback_test',
})
assert(ok, 'policy replacement failed: ' .. tostring(err))

local rollbackOk, restored = world:rollbackPolicyBundle('policy_regression')
assert(rollbackOk, 'policy rollback failed')
assert(restored.policyId == 'genesis.default', 'rollback did not restore prior policy')
assert(restored.rollback.lastRollbackReason == 'policy_regression', 'rollback reason missing')

local status = world:getRuntimeStatus()
assert(type(status.policyHistory) == 'table' and #status.policyHistory >= 2, 'policy history missing')
assert(type(status.policy.lineage.rollbackHistory) == 'table' and #status.policy.lineage.rollbackHistory >= 1, 'rollback history missing')

print('policy_rollback_test: ok')
