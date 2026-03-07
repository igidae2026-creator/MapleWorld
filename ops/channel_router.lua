local ChannelRouter = {}

function ChannelRouter.new(config)
    local self = { cluster = (config or {}).cluster }
    setmetatable(self, { __index = ChannelRouter })
    return self
end

function ChannelRouter:route(mapId)
    local best = nil
    for _, channel in pairs(self.cluster.channels or {}) do
        if not next(channel.maps) or channel.maps[mapId] then
            if not best or channel.load < best.load then best = channel end
        end
    end
    return best
end

return ChannelRouter
