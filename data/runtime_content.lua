local RuntimeContent = {}

local compiled = require('data.runtime_compiled_content')

local function clone(value, seen)
    if type(value) ~= 'table' then return value end
    local visited = seen or {}
    if visited[value] then return visited[value] end
    local copy = {}
    visited[value] = copy
    for key, item in pairs(value) do
        copy[clone(key, visited)] = clone(item, visited)
    end
    return copy
end

function RuntimeContent.load()
    return clone(compiled)
end

return RuntimeContent
