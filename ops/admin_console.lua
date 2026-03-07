local AdminConsole = {}

function AdminConsole.new(config)
    local self = { world = (config or {}).world }
    setmetatable(self, { __index = AdminConsole })
    return self
end

function AdminConsole:status()
    if not self.world then return {} end
    return {
        runtime = self.world:getRuntimeStatus(),
        stability = self.world:getStabilityReport and self.world:getStabilityReport() or nil,
        control = self.world:getControlPlaneReport and self.world:getControlPlaneReport() or nil,
    }
end

return AdminConsole
