local MapEventSystem = {}

function MapEventSystem.new(config)
    local self = { maps = (config or {}).maps or {}, events = {} }
    setmetatable(self, { __index = MapEventSystem })
    return self
end

function MapEventSystem:activate(mapId, eventId, payload)
    self.events[mapId] = self.events[mapId] or {}
    self.events[mapId][eventId] = payload or { active = true }
    return self.events[mapId][eventId]
end

return MapEventSystem
