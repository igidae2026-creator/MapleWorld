local WorldCluster = {}

function WorldCluster.new(config)
    local self = {
        worldId = (config or {}).worldId or 'world-alpha',
        channels = {},
        shards = {},
    }
    setmetatable(self, { __index = WorldCluster })
    return self
end

function WorldCluster:registerChannel(channelId, maps)
    self.channels[channelId] = { id = channelId, maps = maps or {}, load = 0 }
    return self.channels[channelId]
end

return WorldCluster
