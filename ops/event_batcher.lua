local EventBatcher = {}

function EventBatcher.new(config)
    local self = {
        maxBatch = (config or {}).maxBatch or 32,
        queue = {},
        flushed = {},
        totalQueued = 0,
        totalFlushed = 0,
        lastFlushSize = 0,
    }
    setmetatable(self, { __index = EventBatcher })
    return self
end

function EventBatcher:push(event)
    self.queue[#self.queue + 1] = event
    self.totalQueued = self.totalQueued + 1
    if #self.queue >= self.maxBatch then
        return self:flush()
    end
    return nil
end

function EventBatcher:flush()
    if #self.queue == 0 then return {} end
    local batch = self.queue
    self.queue = {}
    self.flushed[#self.flushed + 1] = batch
    self.totalFlushed = self.totalFlushed + #batch
    self.lastFlushSize = #batch
    while #self.flushed > 32 do table.remove(self.flushed, 1) end
    return batch
end

return EventBatcher
