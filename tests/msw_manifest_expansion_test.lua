package.path = package.path .. ';./?.lua;../?.lua'

local manifest = require('msw.component_manifest')

local required = {
    AllocateStat = true,
    PromoteJob = true,
    LearnSkill = true,
    CastSkill = true,
    GetEconomyReport = true,
    AdminStatus = true,
    GetStateDelta = true,
    GetBridgeDiagnostics = true,
    ReconcileRuntimeState = true,
    DispatchRuntimeEvent = true,
    RoutePlayerAction = true,
    GetEventStream = true,
}

local seen = {}
for _, method in ipairs(manifest.serverMethods or {}) do seen[method] = true end
for method in pairs(required) do
    assert(seen[method], 'missing manifest method: ' .. method)
end
assert(manifest.singleton.runtimeContract ~= nil, 'missing runtime contract')
assert(type(manifest.singleton.runtimeContract.sync) == 'table', 'missing runtime sync contract')
print('msw_manifest_expansion_test: ok')
