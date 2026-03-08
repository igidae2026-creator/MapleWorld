package.path = package.path .. ';./?.lua;../?.lua'

local function readFile(path)
    local handle = assert(io.open(path, 'r'))
    local content = handle:read('*a')
    handle:close()
    return content
end

local files = {}
local pipe = assert(io.popen("find msw_runtime -type f -name '*.lua' | sort", 'r'))
for path in pipe:lines() do
    files[#files + 1] = path
end
pipe:close()

assert(#files > 0, 'msw_runtime lua files missing')

local forbiddenPatterns = {
    "require%(['\"]content_build[%.']",
    "require%(['\"]offline_ops[%.']",
    "require%(['\"]ai_evolution_offline[%.']",
    "require%(['\"]simulation_lua[%.']",
    "require%(['\"]simulation_py[%.']",
    "require%(['\"]metrics_engine[%.']",
}

for _, path in ipairs(files) do
    local content = readFile(path)
    for _, pattern in ipairs(forbiddenPatterns) do
        assert(content:match(pattern) == nil, 'forbidden runtime import in ' .. path .. ': ' .. pattern)
    end
end

local runtimeDependencyFiles = {
    'data/runtime_tables.lua',
    'data/bosses/catalog.lua',
    'data/dialogues/catalog.lua',
    'data/drop_tables/catalog.lua',
    'data/economy/catalog.lua',
    'data/events/catalog.lua',
    'data/items/catalog.lua',
    'data/jobs/catalog.lua',
    'data/maps/catalog.lua',
    'data/mobs/catalog.lua',
    'data/npcs/catalog.lua',
    'data/quests/catalog.lua',
    'data/skills/catalog.lua',
    'data/runtime_content.lua',
}

for _, path in ipairs(runtimeDependencyFiles) do
    local content = readFile(path)
    for _, pattern in ipairs(forbiddenPatterns) do
        assert(content:match(pattern) == nil, 'forbidden transitive runtime dependency in ' .. path .. ': ' .. pattern)
    end
end

local antiAbuseRuntime = readFile('msw_runtime/anti_abuse_runtime.lua')
assert(antiAbuseRuntime:match("require%(['\"]scripts[%.']") == nil, 'anti_abuse_runtime must not import legacy scripts/* modules')

local gameplayRuntime = readFile('msw_runtime/state/gameplay_runtime.lua')
assert(gameplayRuntime:match("require%(['\"]scripts%.anti_abuse_gameplay_hooks['\"]%)") == nil, 'gameplay_runtime must not import legacy anti-abuse hooks')
assert(gameplayRuntime:match("require%(['\"]scripts%.world_event_system['\"]%)") == nil, 'gameplay_runtime must not import legacy world event system')

local manifest = readFile('msw_runtime/component_manifest.lua')
assert(manifest:match("ownership%s*=%s*'gameplay_only'") ~= nil, 'manifest ownership must stay gameplay_only')
assert(manifest:match("worldScope%s*=%s*'msw_gameplay_runtime'") ~= nil, 'manifest worldScope drifted')
assert(manifest:match("'GetEconomyReport'") == nil, 'manifest must not export economy report control-plane method')
assert(manifest:match("'AdminStatus'") == nil, 'manifest must not export admin status control-plane method')
assert(manifest:match("'getEconomyReport'") == nil, 'manifest must not expose lower-case economy report control-plane method')
assert(manifest:match("'adminStatus'") == nil, 'manifest must not expose lower-case admin status control-plane method')
assert(manifest:match("forbiddenPublicMethods") ~= nil, 'manifest must hard-fail if forbidden control-plane methods are re-exported')

local entry = readFile('msw_runtime/entry/world_server_entry.lua')
assert(entry:match("GetEconomyReport%s*=") == nil, 'world_server_entry must not export economy report control-plane method')
assert(entry:match("AdminStatus%s*=") == nil, 'world_server_entry must not export admin status control-plane method')
assert(entry:match("getEconomyReport") ~= nil, 'world_server_entry must explicitly reject economy report control-plane routes')
assert(entry:match("adminStatus") ~= nil, 'world_server_entry must explicitly reject admin status control-plane routes')
assert(entry:match("forbidden_public_entry_") ~= nil, 'world_server_entry must hard-fail if forbidden control-plane methods are re-exported')

local readme = readFile('msw_runtime/README.md')
assert(readme:match('gameplay code') ~= nil, 'runtime README should declare gameplay-only scope')
assert(readme:match('Forbidden:') ~= nil, 'runtime README should declare forbidden scope')
assert(readme:match('control plane') ~= nil, 'runtime README should forbid control-plane logic')

print('msw_runtime_boundary_test: ok')
