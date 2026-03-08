package.path = package.path .. ';./?.lua;../?.lua'

local function readFile(path)
    local handle = assert(io.open(path, 'r'))
    local content = handle:read('*a')
    handle:close()
    return content
end

local function moduleToPath(moduleName)
    return moduleName:gsub('%.', '/') .. '.lua'
end

local function collectRequires(content)
    local modules = {}
    for quote, moduleName in content:gmatch("require%s*%((['\"])(.-)%1%)") do
        modules[#modules + 1] = moduleName
    end
    return modules
end

local function isRuntimeReachable(moduleName)
    return moduleName:match('^scripts%.') ~= nil
        or moduleName:match('^shared_rules%.') ~= nil
        or moduleName:match('^msw_runtime%.') ~= nil
end

local forbiddenPatterns = {
    "require%(['\"]content_build[%.']",
    "require%(['\"]offline_ops[%.']",
    "require%(['\"]ai_evolution_offline[%.']",
    "require%(['\"]simulation_lua[%.']",
    "require%(['\"]simulation_py[%.']",
    "require%(['\"]metrics_engine[%.']",
}

local forbiddenRuntimeApis = {
    "io%.open%s*%(",
    "io%.popen%s*%(",
    "os%.execute%s*%(",
    "dofile%s*%(",
    "loadfile%s*%(",
    "package%.loadlib",
}

local componentManifest = dofile('msw_runtime/component_manifest.lua')
assert(type(componentManifest) == 'table', 'component manifest must return a table')
assert(type(componentManifest.singleton) == 'table', 'component manifest singleton missing')
assert(type(componentManifest.serverMethods) == 'table', 'component manifest serverMethods missing')

local function scriptPathToModule(scriptPath)
    return tostring(scriptPath):gsub('%.lua$', ''):gsub('/', '.')
end

local queue = {}
local rootModules = {
    scriptPathToModule(componentManifest.singleton.script),
    scriptPathToModule(componentManifest.singleton.module),
    'msw_runtime.state.gameplay_runtime',
    'msw_runtime.anti_abuse_runtime',
}

for _, moduleName in ipairs(rootModules) do
    queue[#queue + 1] = moduleName
end

local seenModules = {}
local reachableFiles = {}

while #queue > 0 do
    local moduleName = table.remove(queue, 1)
    if not seenModules[moduleName] then
        seenModules[moduleName] = true
        local path = moduleToPath(moduleName)
        local content = readFile(path)
        reachableFiles[#reachableFiles + 1] = path
        for _, dependency in ipairs(collectRequires(content)) do
            if isRuntimeReachable(dependency) and not seenModules[dependency] then
                queue[#queue + 1] = dependency
            end
        end
    end
end

local checkedFiles = {}
for _, path in ipairs(reachableFiles) do
    if path:match('^scripts/') or path:match('^shared_rules/') then
        checkedFiles[#checkedFiles + 1] = path
        local content = readFile(path)
        for _, pattern in ipairs(forbiddenPatterns) do
            assert(content:match(pattern) == nil, 'forbidden transitive runtime import in ' .. path .. ': ' .. pattern)
        end
        for _, pattern in ipairs(forbiddenRuntimeApis) do
            assert(content:match(pattern) == nil, 'forbidden runtime API in ' .. path .. ': ' .. pattern)
        end
    end
end

assert(#checkedFiles > 0, 'expected runtime-reachable gameplay modules to be checked')
assert(seenModules['msw_runtime.entry.world_server_entry'] == true, 'entry module must be included in transitive runtime boundary walk')
assert(seenModules['msw_runtime.entry.world_server_component'] == true, 'component module must be included in transitive runtime boundary walk')

print('msw_runtime_transitive_boundary_test: ok')
