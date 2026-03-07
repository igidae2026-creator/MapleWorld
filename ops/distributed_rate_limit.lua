local DistributedRateLimit = {}

function DistributedRateLimit.new()
    return setmetatable({ buckets = {} }, { __index = DistributedRateLimit })
end

function DistributedRateLimit:check(key, tokens)
    local now = os.time()
    local bucket = self.buckets[key] or { value = 0, at = now }
    if now ~= bucket.at then bucket.value = 0 bucket.at = now end
    bucket.value = bucket.value + math.max(1, math.floor(tonumber(tokens) or 1))
    self.buckets[key] = bucket
    return bucket.value <= 20, bucket.value
end

return DistributedRateLimit
