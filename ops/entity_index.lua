local EntityIndex = {}

function EntityIndex.new()
    return setmetatable({ byMap = {}, byType = {} }, { __index = EntityIndex })
end

function EntityIndex:index(kind, mapId, id, payload)
    self.byMap[mapId] = self.byMap[mapId] or {}
    self.byMap[mapId][kind] = self.byMap[mapId][kind] or {}
    self.byMap[mapId][kind][id] = payload
    self.byType[kind] = self.byType[kind] or {}
    self.byType[kind][id] = payload
end

function EntityIndex:remove(kind, mapId, id)
    if self.byMap[mapId] and self.byMap[mapId][kind] then self.byMap[mapId][kind][id] = nil end
    if self.byType[kind] then self.byType[kind][id] = nil end
end

function EntityIndex:mapSummary(mapId)
    local kinds = self.byMap[mapId] or {}
    local summary = {}
    for kind, entries in pairs(kinds) do
        local count = 0
        for _ in pairs(entries or {}) do count = count + 1 end
        summary[kind] = count
    end
    return summary
end

return EntityIndex
