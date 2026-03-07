local ProgressionSystem = {}

function ProgressionSystem.new(config)
    local self = {
        jobSystem = (config or {}).jobSystem,
        statSystem = (config or {}).statSystem,
        inventoryExpansion = (config or {}).inventoryExpansion,
    }
    setmetatable(self, { __index = ProgressionSystem })
    return self
end

function ProgressionSystem:ensurePlayer(player)
    player.progression = player.progression or { milestones = {}, mastery = 0 }
    return player
end

function ProgressionSystem:onLevelUp(player)
    self:ensurePlayer(player)
    player.ap = (tonumber(player.ap) or 0) + 5
    player.sp = (tonumber(player.sp) or 0) + 3
    player.progression.mastery = (tonumber(player.progression.mastery) or 0) + 1
    if (tonumber(player.level) or 1) % 20 == 0 then
        self.inventoryExpansion:expand(player, 4)
    end
    return true
end

return ProgressionSystem
