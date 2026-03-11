package.path = package.path .. ';./?.lua;../?.lua'

local RuntimeContent = require('data.runtime_content')

local function readCsv(path)
    local handle = assert(io.open(path, 'r'))
    local rows = {}
    local headers = nil
    for line in handle:lines() do
        local cols = {}
        for value in string.gmatch(line, '([^,]+)') do
            cols[#cols + 1] = value
        end
        if not headers then
            headers = cols
        else
            local row = {}
            for idx, header in ipairs(headers) do
                row[header] = cols[idx]
            end
            rows[#rows + 1] = row
        end
    end
    handle:close()
    return rows
end

local function chanceKey(value)
    return string.format('%.6f', tonumber(value) or 0)
end

local sourceRows = readCsv('data/balance/drops/drop_table.csv')
local runtimeRowsByMonster = RuntimeContent.load().content.drop_tables or {}

local sourceByKey = {}
local runtimeByKey = {}
local sourceChanceByMonster = {}
local runtimeChanceByMonster = {}
local runtimeRowCount = 0

for _, row in ipairs(sourceRows) do
    local key = table.concat({
        tostring(row.monster_id),
        tostring(row.item_id),
        tostring(row.rarity_band),
        chanceKey(row.drop_rate),
    }, '|')
    sourceByKey[key] = (sourceByKey[key] or 0) + 1
    sourceChanceByMonster[row.monster_id] = (sourceChanceByMonster[row.monster_id] or 0) + (tonumber(row.drop_rate) or 0)
end

for monsterId, rows in pairs(runtimeRowsByMonster) do
    for _, row in ipairs(rows) do
        runtimeRowCount = runtimeRowCount + 1
        local key = table.concat({
            tostring(monsterId),
            tostring(row.item_id),
            tostring(row.rarity),
            chanceKey(row.chance),
        }, '|')
        runtimeByKey[key] = (runtimeByKey[key] or 0) + 1
        runtimeChanceByMonster[monsterId] = (runtimeChanceByMonster[monsterId] or 0) + (tonumber(row.chance) or 0)
    end
end

local missingRows = 0
local extraRows = 0
local pressureDriftedOwners = 0

for key, sourceCount in pairs(sourceByKey) do
    if runtimeByKey[key] ~= sourceCount then
        missingRows = missingRows + sourceCount
    end
end

for key, runtimeCount in pairs(runtimeByKey) do
    if sourceByKey[key] ~= runtimeCount then
        extraRows = extraRows + runtimeCount
    end
end

for monsterId, sourceChance in pairs(sourceChanceByMonster) do
    local runtimeChance = runtimeChanceByMonster[monsterId]
    if runtimeChance == nil or math.abs(runtimeChance - sourceChance) >= 0.000001 then
        pressureDriftedOwners = pressureDriftedOwners + 1
    end
end

local runtimeCoverage = 0
if #sourceRows > 0 then
    runtimeCoverage = runtimeRowCount / #sourceRows
end

print('runtime_drop_parity_validation')
print('status=' .. ((missingRows == 0 and extraRows == 0 and pressureDriftedOwners == 0) and 'allow' or 'reject'))
print('source_rows=' .. tostring(#sourceRows))
print('runtime_rows=' .. tostring(runtimeRowCount))
print('runtime_row_coverage=' .. string.format('%.4f', runtimeCoverage))
print('missing_or_mismatched_source_rows=' .. tostring(missingRows))
print('stale_or_extra_runtime_rows=' .. tostring(extraRows))
print('pressure_drifted_owners=' .. tostring(pressureDriftedOwners))

if missingRows ~= 0 or extraRows ~= 0 or pressureDriftedOwners ~= 0 then
    os.exit(2)
end
