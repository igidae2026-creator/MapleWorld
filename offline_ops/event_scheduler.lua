local Scheduler = {}

function Scheduler.new(config)
    local cfg = config or {}
    local self = {
        now = 0,
        jobs = {},
        metrics = cfg.metrics,
        maxRunsPerTick = cfg.maxRunsPerTick or 5,
    }
    setmetatable(self, { __index = Scheduler })
    return self
end

function Scheduler:every(name, intervalSec, callback)
    local interval = tonumber(intervalSec)
    assert(interval and interval > 0, 'intervalSec must be positive')
    self.jobs[name] = {
        name = name,
        intervalSec = interval,
        nextRun = self.now + interval,
        callback = callback,
    }
end

function Scheduler:tick(deltaSec)
    local delta = tonumber(deltaSec) or 0
    if delta < 0 then delta = 0 end
    self.now = self.now + delta
    for _, job in pairs(self.jobs) do
        local runs = 0
        while self.now >= job.nextRun do
            runs = runs + 1
            if runs > self.maxRunsPerTick then
                job.nextRun = self.now + job.intervalSec
                if self.metrics then
                    self.metrics:increment('scheduler.catchup_skipped', 1, { job = job.name })
                    self.metrics:error('scheduler_catchup_skipped', { job = job.name, now = self.now })
                end
                break
            end

            local started = os.clock()
            local ok, err = pcall(job.callback)
            local durationMs = math.floor((os.clock() - started) * 1000)
            if self.metrics then
                self.metrics:time('scheduler.job', durationMs, { job = job.name })
                if not ok then
                    self.metrics:increment('scheduler.job_error', 1, { job = job.name })
                    self.metrics:error('scheduler_job_failed', { job = job.name, error = tostring(err) })
                end
            end
            job.nextRun = job.nextRun + job.intervalSec
        end
    end
end

return Scheduler
