local SessionOrchestrator = {}

function SessionOrchestrator.new()
    return setmetatable({ sessions = {} }, { __index = SessionOrchestrator })
end

function SessionOrchestrator:bind(playerId, detail)
    self.sessions[playerId] = detail
    return detail
end

return SessionOrchestrator
