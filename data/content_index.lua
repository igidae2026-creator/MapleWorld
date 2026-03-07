local ContentIndex = {}

local function clone(value, seen)
    if type(value) ~= 'table' then return value end
    local visited = seen or {}
    if visited[value] then return visited[value] end
    local copy = {}
    visited[value] = copy
    for k, v in pairs(value) do copy[clone(k, visited)] = clone(v, visited) end
    return copy
end

function ContentIndex.build(content)
    local index = {
        counts = {},
        search = {},
        mapsByTheme = {},
        questsByArc = {},
        dropsByItem = {},
        skillsById = {},
    }

    for sectionName, section in pairs(content or {}) do
        if type(section) == 'table' then
            local count = 0
            for id, entry in pairs(section) do
                count = count + 1
                index.search[tostring(id)] = { section = sectionName, entry = clone(entry) }
                local name = type(entry) == 'table' and tostring(entry.name or entry.quest_id or entry.item_id or id):lower() or tostring(id):lower()
                index.search[name] = index.search[name] or { section = sectionName, entry = clone(entry) }
                if sectionName == 'maps' and type(entry.tags) == 'table' then
                    local theme = entry.tags[1] or 'misc'
                    index.mapsByTheme[theme] = index.mapsByTheme[theme] or {}
                    index.mapsByTheme[theme][#index.mapsByTheme[theme] + 1] = id
                elseif sectionName == 'quests' and type(entry) == 'table' then
                    local arc = entry.arc or 'misc'
                    index.questsByArc[arc] = index.questsByArc[arc] or {}
                    index.questsByArc[arc][#index.questsByArc[arc] + 1] = id
                elseif sectionName == 'drop_tables' and type(entry) == 'table' then
                    for _, row in ipairs(entry) do
                        index.dropsByItem[row.item_id] = index.dropsByItem[row.item_id] or {}
                        index.dropsByItem[row.item_id][#index.dropsByItem[row.item_id] + 1] = id
                    end
                elseif sectionName == 'skills' and type(entry) == 'table' then
                    for _, skill in ipairs(entry) do
                        index.skillsById[skill.id] = clone(skill)
                    end
                end
            end
            index.counts[sectionName] = count
        end
    end

    return index
end

return ContentIndex
