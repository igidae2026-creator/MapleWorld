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

local function shallowSize(value)
    if type(value) ~= 'table' then return #tostring(value) end
    local total = 2
    for k, v in pairs(value) do
        total = total + #tostring(k) + #tostring(v)
    end
    return total
end

function EventJournal.new(config)
    local cfg = config or {}
    local self = {
        entries = {},
        nextSeq = 1,
        maxEntries = math.max(0, math.floor(tonumber(cfg.maxEntries) or 0)),
        maxPayloadBytes = math.max(0, math.floor(tonumber(cfg.maxPayloadBytes) or 0)),
        time = cfg.time or os.time,
        metrics = cfg.metrics,
        logger = cfg.logger,
        onAppend = cfg.onAppend,
        droppedEntries = 0,
        droppedPayloadBytes = 0,
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
    self.droppedEntries = self.droppedEntries + excess
    if self.metrics then self.metrics:increment('journal.trimmed', excess) end
end

function EventJournal:_clampPayload(payload)
    local cloned = deepcopy(payload or {})
    local cap = math.max(0, math.floor(tonumber(self.maxPayloadBytes) or 0))
    if cap <= 0 then return cloned end
    local bytes = shallowSize(cloned)
    if bytes <= cap then return cloned end

    self.droppedPayloadBytes = self.droppedPayloadBytes + math.max(0, bytes - cap)
    local sanitized = {
        truncated = true,
        estimateBytes = bytes,
    }

    for key, value in pairs(cloned) do
        if shallowSize(sanitized) >= cap then break end
        if type(value) ~= 'table' then
            local trimmed = tostring(value)
            local remaining = cap - shallowSize(sanitized) - #tostring(key)
            if remaining > 0 then
                if #trimmed > remaining then trimmed = string.sub(trimmed, 1, remaining) end
                sanitized[key] = trimmed
            end
        end
    end

    if self.metrics then self.metrics:increment('journal.payload_truncated', 1) end
    return sanitized
end

function EventJournal:append(eventType, payload)
    local entry = {
        seq = self.nextSeq,
        at = self.time(),
        event = eventType,
        payload = self:_clampPayload(payload),
    }
    self.entries[#self.entries + 1] = entry
    self.nextSeq = self.nextSeq + 1
    self:_trim()

    if self.metrics then
        self.metrics:increment('journal.append', 1, { event = tostring(eventType) })
        self.metrics:gauge('journal.entries', #self.entries)
        self.metrics:gauge('journal.dropped_entries', self.droppedEntries)
        self.metrics:gauge('journal.dropped_payload_bytes', self.droppedPayloadBytes)
    end
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
        droppedEntries = self.droppedEntries,
        droppedPayloadBytes = self.droppedPayloadBytes,
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
        self.droppedEntries = math.max(0, math.floor(tonumber(snapshot.droppedEntries) or 0))
        self.droppedPayloadBytes = math.max(0, math.floor(tonumber(snapshot.droppedPayloadBytes) or 0))
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
