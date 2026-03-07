local JobSystem = {}

function JobSystem.new(config)
    local cfg = config or {}
    local self = {
        jobs = cfg.jobs or {},
        metrics = cfg.metrics,
    }
    setmetatable(self, { __index = JobSystem })
    return self
end

function JobSystem:ensurePlayer(player)
    player.jobId = player.jobId or 'beginner'
    player.jobHistory = player.jobHistory or { player.jobId }
    return player
end

function JobSystem:promote(player, jobId)
    self:ensurePlayer(player)
    local current = self.jobs[player.jobId] or {}
    if player.jobId == jobId then return true end
    local allowed = false
    for _, branch in ipairs(current.branches or {}) do
        if branch == jobId then allowed = true break end
    end
    if not allowed then return false, 'job_transition_blocked' end
    player.jobId = jobId
    player.jobHistory[#player.jobHistory + 1] = jobId
    player.sp = (tonumber(player.sp) or 0) + 3
    player.version = (tonumber(player.version) or 0) + 1
    player.dirty = true
    return true
end

return JobSystem
