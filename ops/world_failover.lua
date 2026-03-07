local WorldFailover = {}

function WorldFailover.new(config)
    local self = { cluster = (config or {}).cluster, history = {} }
    setmetatable(self, { __index = WorldFailover })
    return self
end

function WorldFailover:promote(channelId)
    self.history[#self.history + 1] = channelId
    return { promoted = channelId, at = os.time() }
end

return WorldFailover
