local WorldEventSystem = {}

function WorldEventSystem.new(config)
    local self = { definitions = (config or {}).definitions or {}, active = {}, state = { lootMultiplier = 1.0, rareSpawnBonus = 0, bossSpawnBonus = 0 } }
    setmetatable(self, { __index = WorldEventSystem })
    return self
end

function WorldEventSystem:activate(kind, id)
    self.active[kind] = self.active[kind] or {}
    local entry = self.definitions[kind] and self.definitions[kind][id] or { cadence = kind }
    self.active[kind][id] = entry
    if kind == 'daily' then self.state.lootMultiplier = 1.15 end
    if kind == 'weekly' then self.state.bossSpawnBonus = self.state.bossSpawnBonus + 1 end
    return self.active[kind][id]
end

function WorldEventSystem:regional(mapId)
    return {
        mapId = mapId,
        rareMobChance = 0.08 + self.state.rareSpawnBonus,
        lootMultiplier = self.state.lootMultiplier,
    }
end

return WorldEventSystem
