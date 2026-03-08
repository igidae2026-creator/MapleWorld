package.path = package.path .. ';./?.lua;../?.lua'

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

local sinkRows = readCsv('data/balance/economy/sinks.csv')
assert(#sinkRows == 24, 'expected one sink row per level band window')

local seenSinkIds = {}
local seenRowKeys = {}
local seenLevelBands = {}
local bossEntryBands = {}
for _, row in ipairs(sinkRows) do
    assert(seenSinkIds[row.sink_id] == nil, 'duplicate sink id: ' .. tostring(row.sink_id))
    seenSinkIds[row.sink_id] = true

    local rowKey = table.concat({
        tostring(row.sink_id),
        tostring(row.sink_type),
        tostring(row.level_band),
        tostring(row.meso_cost),
        tostring(row.sink_weight),
        tostring(row.trigger_window),
    }, '|')
    assert(seenRowKeys[rowKey] == nil, 'duplicate sink row: ' .. rowKey)
    seenRowKeys[rowKey] = true

    local levelBand = tonumber(row.level_band)
    assert(levelBand ~= nil and levelBand >= 1 and levelBand <= 24, 'invalid sink level band')
    assert(seenLevelBands[levelBand] == nil, 'duplicate sink level band: ' .. tostring(levelBand))
    seenLevelBands[levelBand] = true
    if row.sink_type == 'boss_entry_ticket' then
        bossEntryBands[#bossEntryBands + 1] = levelBand
    end
end

for expectedLevelBand = 1, 24 do
    assert(seenLevelBands[expectedLevelBand] == true, 'missing sink level band: ' .. tostring(expectedLevelBand))
end

table.sort(bossEntryBands)
assert(#bossEntryBands == 2, 'expected exactly two boss entry ticket sinks')
assert(bossEntryBands[1] == 9 and bossEntryBands[2] == 21, 'boss entry ticket sinks should stay on lv081-090 and lv201-210 windows')

print('economy_balance_table_test: ok')
