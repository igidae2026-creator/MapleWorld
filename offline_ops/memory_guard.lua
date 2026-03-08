local MemoryGuard = {}

function MemoryGuard.new(config)
    local cfg = config or {}
    local self = {
        softLimitKb = tonumber(cfg.softLimitKb) or 262144,
        hardLimitKb = tonumber(cfg.hardLimitKb) or 393216,
        history = {},
        lastAction = 'observe',
    }
    setmetatable(self, { __index = MemoryGuard })
    return self
end

function MemoryGuard:inspect(currentKb)
    local kb = math.max(0, tonumber(currentKb) or 0)
    local state = 'normal'
    local action = 'observe'
    if kb >= self.hardLimitKb then
        state = 'hard_limit'
        action = 'shed_load'
    elseif kb >= self.softLimitKb then
        state = 'soft_limit'
        action = 'collect'
    end
    self.lastAction = action
    local report = {
        memoryKb = kb,
        state = state,
        action = action,
        softLimitKb = self.softLimitKb,
        hardLimitKb = self.hardLimitKb,
    }
    self.history[#self.history + 1] = report
    while #self.history > 32 do table.remove(self.history, 1) end
    return report
end

return MemoryGuard
