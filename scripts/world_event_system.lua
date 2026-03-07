local WorldEventSystem = {}

function WorldEventSystem.new(config)
    local self = {
        definitions = (config or {}).definitions or {},
        active = {},
        state = {
            lootMultiplier = 1.0,
            rareSpawnBonus = 0,
            bossSpawnBonus = 0,
            invasionPressure = 0,
            regionalBonus = {},
        },
    }
    setmetatable(self, { __index = WorldEventSystem })
    return self
end

function WorldEventSystem:activate(kind, id)
    self.active[kind] = self.active[kind] or {}
    local entry = self.definitions[kind] and self.definitions[kind][id] or { cadence = kind }
    self.active[kind][id] = entry
    if kind == 'daily' then self.state.lootMultiplier = 1.15 end
    if kind == 'weekly' then self.state.bossSpawnBonus = self.state.bossSpawnBonus + 1 end
    if kind == 'seasonal' then
        self.state.lootMultiplier = math.max(self.state.lootMultiplier, 1.25)
        self.state.rareSpawnBonus = self.state.rareSpawnBonus + 0.04
    end
    if kind == 'invasion' then
        self.state.rareSpawnBonus = self.state.rareSpawnBonus + 0.08
        self.state.bossSpawnBonus = self.state.bossSpawnBonus + 1
        self.state.invasionPressure = self.state.invasionPressure + 1
    end
    if kind == 'world_boss' then
        self.state.bossSpawnBonus = self.state.bossSpawnBonus + 2
    end
    if entry.map then
        self.state.regionalBonus[entry.map] = self.state.regionalBonus[entry.map] or { loot = 1.0, rare = 0, pressure = 0 }
        self.state.regionalBonus[entry.map].loot = math.max(self.state.regionalBonus[entry.map].loot, self.state.lootMultiplier)
        self.state.regionalBonus[entry.map].rare = self.state.regionalBonus[entry.map].rare + self.state.rareSpawnBonus
        self.state.regionalBonus[entry.map].pressure = self.state.regionalBonus[entry.map].pressure + self.state.bossSpawnBonus
    end
    return self.active[kind][id]
end

function WorldEventSystem:regional(mapId)
    local regional = self.state.regionalBonus[mapId] or {}
    return {
        mapId = mapId,
        rareMobChance = 0.08 + self.state.rareSpawnBonus + (regional.rare or 0),
        lootMultiplier = math.max(self.state.lootMultiplier, regional.loot or 1.0),
        bossPressure = self.state.bossSpawnBonus + (regional.pressure or 0),
        invasionPressure = self.state.invasionPressure,
        active = self.active,
    }
end

return WorldEventSystem
