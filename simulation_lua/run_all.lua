package.path = package.path .. ';./?.lua'

local Loader = require('content_build.content_loader')
local CombatSim = require('simulation_lua.combat_sim')
local ProgressionSim = require('simulation_lua.progression_sim')
local DropSim = require('simulation_lua.drop_sim')
local BossSim = require('simulation_lua.boss_sim')

local OUTPUT_PATH = 'offline_ops/codex_state/simulation_runs/lua_simulation_latest.json'

local function is_array(value)
    if type(value) ~= 'table' then return false end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= 'number' then return false end
        count = count + 1
    end
    return count == #value
end

local function encode(value)
    local valueType = type(value)
    if valueType == 'nil' then return 'null' end
    if valueType == 'number' then return tostring(value) end
    if valueType == 'boolean' then return value and 'true' or 'false' end
    if valueType == 'string' then
        local escaped = value
            :gsub('\\', '\\\\')
            :gsub('"', '\\"')
            :gsub('\n', '\\n')
        return '"' .. escaped .. '"'
    end
    if valueType == 'table' then
        if is_array(value) then
            local parts = {}
            for index = 1, #value do
                parts[#parts + 1] = encode(value[index])
            end
            return '[' .. table.concat(parts, ',') .. ']'
        end
        local keys = {}
        for key in pairs(value) do
            keys[#keys + 1] = key
        end
        table.sort(keys)
        local parts = {}
        for _, key in ipairs(keys) do
            parts[#parts + 1] = encode(tostring(key)) .. ':' .. encode(value[key])
        end
        return '{' .. table.concat(parts, ',') .. '}'
    end
    error('unsupported json type: ' .. valueType)
end

local function write_output(path, payload)
    local handle = assert(io.open(path, 'w'))
    handle:write(encode(payload))
    handle:write('\n')
    handle:close()
end

os.execute('mkdir -p offline_ops/codex_state/simulation_runs')

local content = Loader.load()
local payload = {
    generator = 'simulation_lua.run_all',
    deterministic = true,
    combat = CombatSim.run(content),
    progression = ProgressionSim.run(content),
    drops = DropSim.run(content),
    boss = BossSim.run(content),
}

write_output(OUTPUT_PATH, payload)
print(OUTPUT_PATH)
