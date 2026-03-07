local AdminConsole = {}

function AdminConsole.new(config)
    local self = { world = (config or {}).world }
    setmetatable(self, { __index = AdminConsole })
    return self
end

function AdminConsole:status()
    return self.world and self.world:getRuntimeStatus() or {}
end

return AdminConsole
