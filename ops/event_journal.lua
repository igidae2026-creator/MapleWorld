local EventJournal = {}

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

function EventJournal.new(config)
    local cfg = config or {}
    local self = {
        entries = {},
        nextSeq = 1,
        maxEntries = math.max(0, math.floor(tonumber(cfg.maxEntries) or 0)),
        time = cfg.time or os.time,
        metrics = cfg.metrics,
        logger = cfg.logger,
        onAppend = cfg.onAppend,
    }
    setmetatable(self, { __index = EventJournal })
    return self
end

function EventJournal:_trim()
    local cap = math.max(0, math.floor(tonumber(self.maxEntries) or 0))
    if cap <= 0 then return end
    local excess = #self.entries - cap
    if excess <= 0 then return end
    for _ = 1, excess do
        table.remove(self.entries, 1)
    end
    if self.metrics then self.metrics:increment('journal.trimmed', excess) end
end

function EventJournal:append(eventType, payload)
    local entry = {
        seq = self.nextSeq,
        at = self.time(),
        event = eventType,
        payload = deepcopy(payload or {}),
    }
    self.entries[#self.entries + 1] = entry
    self.nextSeq = self.nextSeq + 1
    self:_trim()

    if self.metrics then self.metrics:increment('journal.append', 1, { event = tostring(eventType) }) end
    if self.logger and self.logger.info then self.logger:info('journal_append', { event = eventType, seq = entry.seq }) end
    if type(self.onAppend) == 'function' then
        pcall(self.onAppend, entry)
    end
    return entry
end

function EventJournal:snapshot(sinceSeq)
    local out = {}
    local minSeq = tonumber(sinceSeq) or 0
    for _, entry in ipairs(self.entries) do
        if entry.seq > minSeq then out[#out + 1] = deepcopy(entry) end
    end
    return out
end

function EventJournal:serialize()
    return {
        entries = self:snapshot(),
        nextSeq = self.nextSeq,
        maxEntries = self.maxEntries,
    }
end

function EventJournal:restore(snapshot)
    self.entries = {}
    self.nextSeq = 1

    local entries = snapshot
    local nextSeq = nil
    local maxEntries = nil
    if type(snapshot) == 'table' and snapshot.entries ~= nil then
        entries = snapshot.entries
        nextSeq = tonumber(snapshot.nextSeq)
        maxEntries = tonumber(snapshot.maxEntries)
    end

    if maxEntries ~= nil then
        self.maxEntries = math.max(0, math.floor(maxEntries))
    end

    local maxSeq = 0
    local dedupedBySeq = {}
    if type(entries) == 'table' then
        for _, entry in ipairs(entries) do
            if type(entry) == 'table' then
                local seq = math.max(1, math.floor(tonumber(entry.seq) or 1))
                local restored = {
                    seq = seq,
                    at = tonumber(entry.at) or self.time(),
                    event = entry.event,
                    payload = deepcopy(entry.payload or {}),
                }
                if restored.event ~= nil then
                    dedupedBySeq[seq] = restored
                    if seq > maxSeq then maxSeq = seq end
                end
            end
        end
    end

    for _, restored in pairs(dedupedBySeq) do
        self.entries[#self.entries + 1] = restored
    end
    table.sort(self.entries, function(a, b) return a.seq < b.seq end)
    self:_trim()
    local floorNext = (self.entries[#self.entries] and (self.entries[#self.entries].seq + 1)) or 1
    self.nextSeq = math.max(floorNext, maxSeq + 1, nextSeq or 1)
end

function EventJournal:latest()
    return self.entries[#self.entries]
end

return EventJournal
