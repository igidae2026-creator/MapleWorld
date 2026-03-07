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

return EntityIndex
