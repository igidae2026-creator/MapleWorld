local ChannelRouter = {}

local function deepcopy(value, seen)
    if type(value) ~= 'table' then return value end
    local visited = seen or {}
    if visited[value] then return visited[value] end
    local copy = {}
    visited[value] = copy
    for k, v in pairs(value) do
        copy[deepcopy(k, visited)] = deepcopy(v, visited)
    end
    return copy
end

function ChannelRouter.new(config)
    local cfg = config or {}
    local self = {
        cluster = cfg.cluster,
        congestionThreshold = tonumber(cfg.congestionThreshold) or 0.8,
        perChannelPlayerCap = math.max(1, math.floor(tonumber(cfg.perChannelPlayerCap) or 100)),
        decisions = {},
        maxDecisions = math.max(1, math.floor(tonumber(cfg.maxDecisions) or 64)),
    }
    setmetatable(self, { __index = ChannelRouter })
    return self
end

function ChannelRouter:_channelLoad(channel)
    local load = tonumber(channel and channel.load) or 0
    local cap = math.max(1, self.perChannelPlayerCap)
    local normalized = load / cap
    return load, normalized
end

function ChannelRouter:routeDecision(mapId)
    local decision = {
        mapId = mapId,
        chosenChannelId = nil,
        reason = 'channel_not_found',
        candidates = {},
    }
    local best = nil
    for _, channel in pairs((self.cluster and self.cluster.channels) or {}) do
        local servesMap = not next(channel.maps or {}) or channel.maps[mapId] == true
        if servesMap then
            local load, normalized = self:_channelLoad(channel)
            local candidate = {
                channelId = channel.id,
                load = load,
                normalizedLoad = normalized,
                servesMap = true,
                congested = normalized >= self.congestionThreshold,
            }
            decision.candidates[#decision.candidates + 1] = candidate
            if not best or normalized < best.normalizedLoad or (normalized == best.normalizedLoad and tostring(channel.id) < tostring(best.channelId)) then
                best = {
                    channel = channel,
                    channelId = channel.id,
                    load = load,
                    normalizedLoad = normalized,
                    congested = candidate.congested,
                }
            end
        end
    end

    if best then
        decision.chosenChannelId = best.channelId
        decision.reason = best.congested and 'least_congested_over_threshold' or 'least_loaded_owner'
    end

    self.decisions[#self.decisions + 1] = deepcopy(decision)
    while #self.decisions > self.maxDecisions do table.remove(self.decisions, 1) end
    return decision, best and best.channel or nil
end

function ChannelRouter:route(mapId)
    local _, channel = self:routeDecision(mapId)
    return channel
end

function ChannelRouter:latestDecision()
    return deepcopy(self.decisions[#self.decisions])
end

return ChannelRouter
