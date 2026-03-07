local TutorialSystem = {}

function TutorialSystem.new(config)
    local self = {
        steps = (config or {}).steps or {
            { id = 'move', title = 'Move Through Town', hint = 'Follow the route markers to the field gate.' },
            { id = 'combat', title = 'Clear the First Hunt', hint = 'Use your core skill and loot the drop beam.' },
            { id = 'equip', title = 'Equip an Upgrade', hint = 'Open equipment and equip the recommended weapon.' },
            { id = 'party', title = 'Join a Party', hint = 'Party play shares progression and improves survival.' },
        },
    }
    setmetatable(self, { __index = TutorialSystem })
    return self
end

function TutorialSystem:ensurePlayer(player)
    player.tutorial = player.tutorial or { current = 1, completed = {}, dismissed = false }
    return player.tutorial
end

function TutorialSystem:getCurrent(player)
    local state = self:ensurePlayer(player)
    return self.steps[state.current]
end

function TutorialSystem:advance(player, stepId)
    local state = self:ensurePlayer(player)
    local current = self.steps[state.current]
    if current and (stepId == nil or current.id == stepId) then
        state.completed[current.id] = true
        state.current = math.min(#self.steps + 1, state.current + 1)
        player.dirty = true
        return true, self.steps[state.current]
    end
    return false, 'tutorial_step_mismatch'
end

return TutorialSystem
