local EventBatcher = {}

function EventBatcher.new(config)
    local self = {
        maxBatch = (config or {}).maxBatch or 32,
        queue = {},
        flushed = {},
    }
    setmetatable(self, { __index = EventBatcher })
    return self
end

function EventBatcher:push(event)
    self.queue[#self.queue + 1] = event
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
    return batch
end

return EventBatcher
