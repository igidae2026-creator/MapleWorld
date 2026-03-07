package.path = package.path .. ';./?.lua;../?.lua'

local manifest = require('msw.component_manifest')

local required = {
    AllocateStat = true,
    PromoteJob = true,
    LearnSkill = true,
    CastSkill = true,
    GetEconomyReport = true,
    AdminStatus = true,
}

local seen = {}
for _, method in ipairs(manifest.serverMethods or {}) do seen[method] = true end
for method in pairs(required) do
    assert(seen[method], 'missing manifest method: ' .. method)
end
assert(manifest.singleton.runtimeContract ~= nil, 'missing runtime contract')
print('msw_manifest_expansion_test: ok')
