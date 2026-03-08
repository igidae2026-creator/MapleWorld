package.path = package.path .. ';./?.lua;../?.lua'

local outputPath = 'offline_ops/codex_state/simulation_runs/lua_simulation_latest.json'
local exitCode = os.execute('lua simulation_lua/run_all.lua > /tmp/mapleworld_sim_lua_smoke.log')

assert(exitCode == 0, 'lua simulation runner failed')

local handle = assert(io.open(outputPath, 'r'))
local content = handle:read('*a')
handle:close()

assert(content:match('"combat"') ~= nil, 'combat output missing')
assert(content:match('"progression"') ~= nil, 'progression output missing')
assert(content:match('"drops"') ~= nil, 'drop output missing')
assert(content:match('"boss"') ~= nil, 'boss output missing')

print('simulation_lua_smoke_test: ok')
