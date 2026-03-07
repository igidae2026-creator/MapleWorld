local DailyWeeklySystem = {}

function DailyWeeklySystem.new()
    return setmetatable({}, { __index = DailyWeeklySystem })
end

function DailyWeeklySystem:ensurePlayer(player)
    player.rotations = player.rotations or { daily = {}, weekly = {} }
    return player
end

function DailyWeeklySystem:mark(player, cadence, objective)
    self:ensurePlayer(player)
    player.rotations[cadence][objective] = true
    player.dirty = true
    return true
end

return DailyWeeklySystem
