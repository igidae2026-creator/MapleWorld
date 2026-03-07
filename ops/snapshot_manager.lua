local SnapshotManager = {}

function SnapshotManager.new()
    return setmetatable({ snapshots = {}, nextId = 1 }, { __index = SnapshotManager })
end

function SnapshotManager:capture(state)
    local id = 'snapshot-' .. tostring(self.nextId)
    self.nextId = self.nextId + 1
    self.snapshots[id] = state
    return id
end

return SnapshotManager
