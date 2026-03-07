package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.', {
    worldConfig = {
        runtime = {
            defaultMapId = 'henesys_hunting_ground',
            policyBundleId = 'genesis.default',
            policyBundleVersion = '1.0.0',
            pressureDuplicateRiskThreshold = 1,
            pressureOwnershipConflictThreshold = 1,
            safeModeSeverityThreshold = 3,
            rewardQuarantineSeverityThreshold = 2,
            migrationBlockSeverityThreshold = 2,
            replayOnlySeverityThreshold = 4,
            persistenceQuarantineSeverityThreshold = 3,
            autoPickupDrops = false,
        },
        combat = {},
        actionBoundaries = {},
        actionRateLimits = {},
        maps = {
            henesys_hunting_ground = { spawnPosition = { x = 0, y = 0, z = 0 }, spawnGroups = {} },
        },
        bosses = {},
        drops = {},
        quests = { npcBindings = {} },
    },
})

local replaced = world:replacePolicyBundle({
    policyId = 'genesis.override',
    policyVersion = '2.0.0',
    savePolicy = { debounceSec = 1 },
})
assert(replaced, 'policy replacement failed')
assert(world:getRuntimeStatus().policy.policyId == 'genesis.override', 'policy id not replaced')

world:appendLedgerEvent({
    event_type = 'synthetic_mutation',
    actor_id = 'tester',
    source_system = 'test',
    idempotency_key = 'dup-risk-1',
})
world:appendLedgerEvent({
    event_type = 'synthetic_mutation',
    actor_id = 'tester',
    source_system = 'test',
    idempotency_key = 'dup-risk-1',
})
assert((world:getRuntimeStatus().pressure.duplicateRiskPressure or 0) >= 1, 'duplicate risk pressure not raised')
assert((world:getRuntimeStatus().escalation.level or 0) >= 1, 'duplicate risk did not escalate')

print('policy_pressure_test: ok')
