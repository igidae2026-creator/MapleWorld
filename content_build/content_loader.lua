local ContentRegistry = require('content_build.content_registry')
local ContentIndex = require('content_build.content_index')
local ContentValidation = require('content_build.content_validation')
local BalanceTables = require('data.balance_tables')
local Seeds = require('data.content_generation_seed_sets')
local RegionalProgression = require('data.regional_progression_tables')
local RareSpawnTables = require('data.rare_spawn_tables')

local Loader = {}

local cache = nil

local function clone(value, seen)
    if type(value) ~= 'table' then return value end
    local visited = seen or {}
    if visited[value] then return visited[value] end
    local copy = {}
    visited[value] = copy
    for k, v in pairs(value) do copy[clone(k, visited)] = clone(v, visited) end
    return copy
end

function Loader.load(options)
    if cache and not (options and options.forceReload) then return clone(cache) end
    local content = ContentRegistry.load()
    local validation = ContentValidation.validate(content)
    local index = ContentIndex.build(content)
    cache = {
        content = content,
        index = index,
        validation = validation,
        balance = clone(BalanceTables),
        seeds = clone(Seeds),
        regionalProgression = clone(RegionalProgression),
        rareSpawns = clone(RareSpawnTables),
        meta = {
            version = '3.0.0',
            generation = 'content-volume-expansion-pass',
        },
    }
    return clone(cache)
end

return Loader
