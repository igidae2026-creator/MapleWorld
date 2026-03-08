local SnapshotManager = {}

local function deepcopy(value, seen)
    if type(value) ~= 'table' then return value end
    local visited = seen or {}
    if visited[value] then return visited[value] end
    local copy = {}
    visited[value] = copy
    for k, v in pairs(value) do
        copy[deepcopy(k, visited)] = deepcopy(v, visited)
    end
    return copy
end

function SnapshotManager.new(config)
    local cfg = config or {}
    return setmetatable({
        snapshots = {},
        order = {},
        nextId = 1,
        maxSnapshots = math.max(1, math.floor(tonumber(cfg.maxSnapshots) or 8)),
        time = cfg.time or os.time,
    }, { __index = SnapshotManager })
end

function SnapshotManager:capture(state, metadata)
    local id = 'snapshot-' .. tostring(self.nextId)
    self.nextId = self.nextId + 1
    local entry = {
        id = id,
        capturedAt = math.floor(tonumber(self.time()) or os.time()),
        state = deepcopy(state),
        metadata = deepcopy(metadata or {}),
    }
    self.snapshots[id] = entry
    self.order[#self.order + 1] = id
    while #self.order > self.maxSnapshots do
        local expired = table.remove(self.order, 1)
        self.snapshots[expired] = nil
    end
    return id, deepcopy(entry)
end

function SnapshotManager:get(id)
    local entry = self.snapshots[id]
    if not entry then return nil end
    return deepcopy(entry)
end

function SnapshotManager:latest()
    local id = self.order[#self.order]
    if not id then return nil end
    return self:get(id)
end

function SnapshotManager:summary()
    return {
        count = #self.order,
        latest = self:latest(),
    }
end

return SnapshotManager
