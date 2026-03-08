local AdminConsole = {}

function AdminConsole.new(config)
    local self = {
        world = (config or {}).world,
        adminTools = (config or {}).adminTools,
        healthcheck = (config or {}).healthcheck,
    }
    setmetatable(self, { __index = AdminConsole })
    return self
end

function AdminConsole:status()
    if not self.world then return {} end
    local operator = self.adminTools and self.adminTools.getOperatorSnapshot and self.adminTools:getOperatorSnapshot(self.world) or nil
    local runtime = operator and operator.runtimeStatus or self.world:getRuntimeStatus()
    local control = self.adminTools and self.adminTools.getControlPlaneReport and self.adminTools:getControlPlaneReport(self.world, { operator = operator }) or nil
    return {
        runtime = runtime,
        stability = operator and operator.stability or (self.world.getStabilityReport and self.world:getStabilityReport() or nil),
        policy = operator and operator.policy or nil,
        control = control,
        healthcheck = self.healthcheck and self.healthcheck.latest or nil,
    }
end

return AdminConsole
