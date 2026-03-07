local ActionGuard = {}

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

function ActionGuard.new(config)
    local cfg = config or {}
    local self = {
        limits = cfg.limits or {},
        buckets = {},
        time = cfg.time or os.time,
        metrics = cfg.metrics,
        logger = cfg.logger,
        bucketTtlSec = tonumber(cfg.bucketTtlSec) or 300,
        maxBuckets = tonumber(cfg.maxBuckets) or 20000,
    }
    setmetatable(self, { __index = ActionGuard })
    return self
end

function ActionGuard:_bucketKey(actorId, action)
    return tostring(actorId) .. '|' .. tostring(action)
end

function ActionGuard:_limit(action)
    local limit = self.limits[action]
    if type(limit) ~= 'table' then return nil end
    local tokens = tonumber(limit.tokens) or 0
    local recharge = tonumber(limit.recharge) or 0
    if tokens <= 0 then return nil end
    return { tokens = tokens, recharge = recharge }
end

function ActionGuard:_prune(now)
    local current = tonumber(now) or 0
    local ttl = math.max(0, tonumber(self.bucketTtlSec) or 0)
    local total = 0
    local oldestKey, oldestAt = nil, nil

    for key, bucket in pairs(self.buckets) do
        total = total + 1
        local bucketAt = tonumber(bucket.at) or current
        local capacity = tonumber(bucket.capacity) or 0
        local tokens = tonumber(bucket.tokens) or 0
        if ttl > 0 and (current - bucketAt) >= ttl and tokens >= capacity then
            self.buckets[key] = nil
            total = total - 1
        else
            if oldestAt == nil or bucketAt < oldestAt then
                oldestAt = bucketAt
                oldestKey = key
            end
        end
    end

    while self.maxBuckets > 0 and total > self.maxBuckets and oldestKey ~= nil do
        self.buckets[oldestKey] = nil
        total = total - 1
        oldestKey, oldestAt = nil, nil
        for key, bucket in pairs(self.buckets) do
            local bucketAt = tonumber(bucket.at) or current
            if oldestAt == nil or bucketAt < oldestAt then
                oldestAt = bucketAt
                oldestKey = key
            end
        end
    end
end

function ActionGuard:check(actorId, action, cost)
    local limit = self:_limit(action)
    if not limit or actorId == nil then return true end

    local spend = clamp(math.floor(tonumber(cost) or 1), 1, limit.tokens)
    local key = self:_bucketKey(actorId, action)
    local now = tonumber(self.time()) or 0
    self:_prune(now)
    local bucket = self.buckets[key]

    if not bucket then
        bucket = { tokens = limit.tokens, at = now, capacity = limit.tokens }
        self.buckets[key] = bucket
    else
        local elapsed = math.max(0, now - (tonumber(bucket.at) or now))
        bucket.tokens = clamp((tonumber(bucket.tokens) or 0) + (elapsed * limit.recharge), 0, limit.tokens)
        bucket.at = now
        bucket.capacity = limit.tokens
    end

    if bucket.tokens < spend then
        if self.metrics then self.metrics:increment('action_guard.block', 1, { action = tostring(action) }) end
        if self.logger and self.logger.error then
            self.logger:error('action_rate_limited', { actorId = tostring(actorId), action = tostring(action), tokens = bucket.tokens })
        end
        return false, 'rate_limited', bucket.tokens
    end

    bucket.tokens = bucket.tokens - spend
    if self.metrics then self.metrics:increment('action_guard.allow', 1, { action = tostring(action) }) end
    return true, nil, bucket.tokens
end

return ActionGuard
