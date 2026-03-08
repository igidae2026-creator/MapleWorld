local LiveEventController = {}

function LiveEventController.new(config)
    local self = {
        world = (config or {}).world,
        activations = {},
        activeByKind = {},
    }
    setmetatable(self, { __index = LiveEventController })
    return self
end

function LiveEventController:activate(kind, eventId)
    local active = self.world:activateWorldEvent(kind, eventId)
    local record = { kind = kind, eventId = eventId, active = active, at = os.time() }
    self.activations[#self.activations + 1] = record
    self.activeByKind[tostring(kind)] = record
    while #self.activations > 64 do table.remove(self.activations, 1) end
    return record
end

function LiveEventController:deactivate(kind)
    self.activeByKind[tostring(kind)] = nil
    return true
end

function LiveEventController:status()
    return {
        activations = self.activations,
        active = self.world.worldEventSystem.active,
        activeByKind = self.activeByKind,
    }
end

return LiveEventController
