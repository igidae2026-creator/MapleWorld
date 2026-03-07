local ContentRegistry = require('data.content_registry')
local ContentIndex = require('data.content_index')
local ContentValidation = require('data.content_validation')
local BalanceTables = require('data.balance_tables')
local Seeds = require('data.content_generation_seed_sets')

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
        meta = {
            version = '2.0.0',
            generation = 'upper-bound-expansion-pass',
        },
    }
    return clone(cache)
end

return Loader
