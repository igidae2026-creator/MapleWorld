local ShardRegistry = {}

function ShardRegistry.new()
    return setmetatable({ shards = {} }, { __index = ShardRegistry })
end

function ShardRegistry:register(shardId, detail)
    self.shards[shardId] = detail
    return detail
end

return ShardRegistry
