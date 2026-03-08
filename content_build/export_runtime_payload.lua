package.path = package.path .. ';./?.lua;./?/init.lua'

local ContentLoader = require('content_build.content_loader')

local function isIdentifier(value)
    return type(value) == 'string' and value:match('^[A-Za-z_][A-Za-z0-9_]*$') ~= nil
end

local function isArray(tbl)
    if type(tbl) ~= 'table' then return false end
    local maxIndex = 0
    local count = 0
    for key in pairs(tbl) do
        if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then
            return false
        end
        if key > maxIndex then maxIndex = key end
        count = count + 1
    end
    return count == maxIndex
end

local function sortedKeys(tbl)
    local keys = {}
    for key in pairs(tbl) do
        local keyType = type(key)
        if keyType == 'number' or keyType == 'string' then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys, function(a, b)
        if type(a) == type(b) then
            return a < b
        end
        return type(a) < type(b)
    end)
    return keys
end

local function serialize(value, indent)
    indent = indent or ''
    local nextIndent = indent .. '    '
    local valueType = type(value)

    if valueType == 'nil' then return 'nil' end
    if valueType == 'boolean' then return value and 'true' or 'false' end
    if valueType == 'number' then return tostring(value) end
    if valueType == 'string' then return string.format('%q', value) end
    assert(valueType == 'table', 'unsupported value type: ' .. valueType)

    local lines = { '{' }
    if isArray(value) then
        for index = 1, #value do
            local item = value[index]
            local itemType = type(item)
            if itemType == 'nil' or itemType == 'boolean' or itemType == 'number' or itemType == 'string' or itemType == 'table' then
                lines[#lines + 1] = nextIndent .. serialize(item, nextIndent) .. ','
            end
        end
    else
        for _, key in ipairs(sortedKeys(value)) do
            local item = value[key]
            local itemType = type(item)
            if itemType == 'nil' or itemType == 'boolean' or itemType == 'number' or itemType == 'string' or itemType == 'table' then
                local renderedKey
                if isIdentifier(key) then
                    renderedKey = key
                else
                    renderedKey = '[' .. serialize(key, nextIndent) .. ']'
                end
                lines[#lines + 1] = nextIndent .. renderedKey .. ' = ' .. serialize(item, nextIndent) .. ','
            end
        end
    end
    lines[#lines + 1] = indent .. '}'
    return table.concat(lines, '\n')
end

local loaded = ContentLoader.load()
local outputPath = 'data/runtime_compiled_content.lua'
local handle = assert(io.open(outputPath, 'w'))
handle:write('return ')
handle:write(serialize({ content = loaded.content }))
handle:write('\n')
handle:close()

print('exported ' .. outputPath)
