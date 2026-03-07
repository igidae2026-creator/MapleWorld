local Healthcheck = {}

function Healthcheck.new(config)
    local cfg = config or {}
    local self = {
        metrics = cfg.metrics,
        scheduler = cfg.scheduler,
        world = cfg.world,
        latest = { ok = true, checks = {} },
    }
    setmetatable(self, { __index = Healthcheck })
    return self
end

function Healthcheck:run()
    local jobsRegistered = self.scheduler and self.scheduler.jobs and next(self.scheduler.jobs) ~= nil or false
    local playerCount = 0
    if self.world and self.world.players then
        for _ in pairs(self.world.players) do playerCount = playerCount + 1 end
    end

    local runtimeStatus = self.world and self.world.getRuntimeStatus and self.world:getRuntimeStatus() or nil
    local checks = {
        scheduler_available = self.scheduler ~= nil,
        scheduler_advancing = self.scheduler and self.scheduler.now >= 0 or false,
        jobs_registered = jobsRegistered,
        metrics_available = self.metrics ~= nil,
        player_count_valid = playerCount >= 0,
        recovery_valid = runtimeStatus == nil or (runtimeStatus.recovery and runtimeStatus.recovery.valid ~= false),
        containment_safe_mode = runtimeStatus == nil or (runtimeStatus.containment and runtimeStatus.containment.safeMode ~= true),
    }

    local ok = true
    for _, value in pairs(checks) do
        if not value then ok = false break end
    end

    self.latest = { ok = ok, checks = checks, at = os.time(), playerCount = playerCount, runtimeStatus = runtimeStatus }
    if self.metrics then
        self.metrics:gauge('health.ok', ok and 1 or 0)
        self.metrics:gauge('health.players', playerCount)
        if ok then self.metrics:info('healthcheck_ok', checks) else self.metrics:error('healthcheck_failed', checks) end
    end
    return self.latest
end

return Healthcheck
