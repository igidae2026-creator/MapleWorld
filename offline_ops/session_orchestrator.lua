local SessionOrchestrator = {}

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

function SessionOrchestrator.new(config)
    local cfg = config or {}
    return setmetatable({
        sessions = {},
        time = cfg.time or os.time,
    }, { __index = SessionOrchestrator })
end

function SessionOrchestrator:bind(playerId, detail)
    local payload = deepcopy(detail or {})
    payload.playerId = playerId
    payload.updatedAt = math.floor(tonumber(self.time()) or os.time())
    local existing = self.sessions[playerId] or {}
    for k, v in pairs(existing) do
        if payload[k] == nil then payload[k] = deepcopy(v) end
    end
    self.sessions[playerId] = payload
    return deepcopy(payload)
end

function SessionOrchestrator:stageTransfer(playerId, transfer)
    local payload = deepcopy(transfer or {})
    payload.transferState = 'pending'
    payload.transferStartedAt = math.floor(tonumber(self.time()) or os.time())
    return self:bind(playerId, payload)
end

function SessionOrchestrator:completeTransfer(playerId, detail)
    local payload = deepcopy(detail or {})
    payload.transferState = 'committed'
    payload.transferCommittedAt = math.floor(tonumber(self.time()) or os.time())
    return self:bind(playerId, payload)
end

function SessionOrchestrator:clearTransfer(playerId)
    local session = self.sessions[playerId]
    if not session then return nil end
    session.pendingMapId = nil
    session.targetChannelId = nil
    session.sourceMapId = nil
    session.transferState = nil
    session.transferStartedAt = nil
    session.transferCommittedAt = nil
    session.updatedAt = math.floor(tonumber(self.time()) or os.time())
    return deepcopy(session)
end

function SessionOrchestrator:snapshot()
    return deepcopy(self.sessions)
end

function SessionOrchestrator:pendingTransferCount()
    local count = 0
    for _, session in pairs(self.sessions or {}) do
        if session and session.transferState == 'pending' then
            count = count + 1
        end
    end
    return count
end

return SessionOrchestrator
