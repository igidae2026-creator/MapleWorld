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
        ledgerEntries = {},
        nextSeq = 1,
        nextLedgerEventId = 1,
        maxEntries = math.max(0, math.floor(tonumber(cfg.maxEntries) or 0)),
        maxLedgerEntries = math.max(0, math.floor(tonumber(cfg.maxLedgerEntries) or 0)),
        maxPayloadBytes = math.max(0, math.floor(tonumber(cfg.maxPayloadBytes) or 0)),
        time = cfg.time or os.time,
        metrics = cfg.metrics,
        logger = cfg.logger,
        onAppend = cfg.onAppend,
        onLedgerAppend = cfg.onLedgerAppend,
        droppedEntries = 0,
        droppedPayloadBytes = 0,
        ledgerIdempotency = {},
        nextEventId = 1,
    }
    setmetatable(self, { __index = EventJournal })
    return self
end

local function sanitizeString(value)
    if value == nil then return nil end
    return tostring(value)
end

function EventJournal:_trimLedger()
    local cap = math.max(0, math.floor(tonumber(self.maxLedgerEntries) or 0))
    if cap <= 0 then return end
    local excess = #self.ledgerEntries - cap
    if excess <= 0 then return end
    for _ = 1, excess do
        table.remove(self.ledgerEntries, 1)
    end
    self.ledgerIdempotency = {}
    for _, entry in ipairs(self.ledgerEntries) do
        if entry.idempotency_key and entry.idempotency_key ~= '' then
            self.ledgerIdempotency[entry.idempotency_key] = entry
        end
    end
    if self.metrics then self.metrics:increment('ledger.trimmed', excess) end
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
        event_id = self.nextEventId,
        seq = self.nextSeq,
        at = self.time(),
        event = eventType,
        payload = self:_clampPayload(payload),
    }
    self.entries[#self.entries + 1] = entry
    self.nextEventId = self.nextEventId + 1
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

function EventJournal:appendLedgerEvent(event)
    local payload = deepcopy(event or {})
    payload.event_type = sanitizeString(payload.event_type) or 'unknown_mutation'
    payload.source_system = sanitizeString(payload.source_system) or 'unknown'
    payload.idempotency_key = sanitizeString(payload.idempotency_key)

    if payload.idempotency_key and self.ledgerIdempotency[payload.idempotency_key] then
        if self.metrics then self.metrics:increment('ledger.duplicate_attempt', 1, { source = payload.source_system }) end
        return deepcopy(self.ledgerIdempotency[payload.idempotency_key]), true
    end

    local entry = {
        event_id = self.nextEventId,
        ledger_event_id = self.nextLedgerEventId,
        sequence = self.nextLedgerEventId,
        revision = self.nextLedgerEventId,
        timestamp = self.time(),
        event_type = payload.event_type,
        actor_id = sanitizeString(payload.actor_id),
        player_id = sanitizeString(payload.player_id),
        account_id = sanitizeString(payload.account_id),
        source_system = payload.source_system,
        source_event_id = sanitizeString(payload.source_event_id),
        correlation_id = sanitizeString(payload.correlation_id),
        map_id = sanitizeString(payload.map_id),
        channel_id = sanitizeString(payload.channel_id),
        runtime_instance_id = sanitizeString(payload.runtime_instance_id),
        world_id = sanitizeString(payload.world_id),
        owner_id = sanitizeString(payload.owner_id),
        runtime_epoch = tonumber(payload.runtime_epoch),
        coordinator_epoch = tonumber(payload.coordinator_epoch),
        boss_id = sanitizeString(payload.boss_id),
        quest_id = sanitizeString(payload.quest_id),
        npc_id = sanitizeString(payload.npc_id),
        item_instance_id = sanitizeString(payload.item_instance_id),
        item_id = sanitizeString(payload.item_id),
        quantity = tonumber(payload.quantity),
        mesos_delta = tonumber(payload.mesos_delta),
        lineage_reference = sanitizeString(payload.lineage_reference),
        pre_state = deepcopy(payload.pre_state),
        post_state = deepcopy(payload.post_state),
        idempotency_key = payload.idempotency_key,
        compensation_of = sanitizeString(payload.compensation_of),
        rollback_of = sanitizeString(payload.rollback_of),
        metadata = deepcopy(payload.metadata or {}),
    }
    self.ledgerEntries[#self.ledgerEntries + 1] = entry
    self.nextEventId = self.nextEventId + 1
    self.nextLedgerEventId = self.nextLedgerEventId + 1
    if entry.idempotency_key and entry.idempotency_key ~= '' then
        self.ledgerIdempotency[entry.idempotency_key] = entry
    end
    self:_trimLedger()

    if self.metrics then
        self.metrics:increment('ledger.append', 1, { event_type = tostring(entry.event_type), source = tostring(entry.source_system) })
        self.metrics:gauge('ledger.entries', #self.ledgerEntries)
    end
    if self.logger and self.logger.info then
        self.logger:info('ledger_append', { ledgerEventId = entry.ledger_event_id, eventType = entry.event_type, source = entry.source_system })
    end
    if type(self.onLedgerAppend) == 'function' then pcall(self.onLedgerAppend, entry) end
    return deepcopy(entry), false
end

function EventJournal:ledgerSnapshot(sinceLedgerEventId)
    local out = {}
    local minId = tonumber(sinceLedgerEventId) or 0
    for _, entry in ipairs(self.ledgerEntries) do
        if (tonumber(entry.ledger_event_id) or 0) > minId then
            out[#out + 1] = deepcopy(entry)
        end
    end
    return out
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
        ledgerEntries = self:ledgerSnapshot(),
        nextSeq = self.nextSeq,
        nextLedgerEventId = self.nextLedgerEventId,
        nextEventId = self.nextEventId,
        maxEntries = self.maxEntries,
        maxLedgerEntries = self.maxLedgerEntries,
        droppedEntries = self.droppedEntries,
        droppedPayloadBytes = self.droppedPayloadBytes,
    }
end

function EventJournal:restore(snapshot)
    self.entries = {}
    self.ledgerEntries = {}
    self.nextSeq = 1
    self.nextLedgerEventId = 1
    self.nextEventId = 1
    self.ledgerIdempotency = {}

    local entries = snapshot
    local nextSeq = nil
    local maxEntries = nil
    local maxLedgerEntries = nil
    if type(snapshot) == 'table' and snapshot.entries ~= nil then
        entries = snapshot.entries
        nextSeq = tonumber(snapshot.nextSeq)
        self.nextLedgerEventId = math.max(1, math.floor(tonumber(snapshot.nextLedgerEventId) or 1))
        self.nextEventId = math.max(1, math.floor(tonumber(snapshot.nextEventId) or 1))
        maxEntries = tonumber(snapshot.maxEntries)
        maxLedgerEntries = tonumber(snapshot.maxLedgerEntries)
        self.droppedEntries = math.max(0, math.floor(tonumber(snapshot.droppedEntries) or 0))
        self.droppedPayloadBytes = math.max(0, math.floor(tonumber(snapshot.droppedPayloadBytes) or 0))
    end

    if maxEntries ~= nil then
        self.maxEntries = math.max(0, math.floor(maxEntries))
    end
    if maxLedgerEntries ~= nil then
        self.maxLedgerEntries = math.max(0, math.floor(maxLedgerEntries))
    end

    local maxSeq = 0
    local dedupedBySeq = {}
    if type(entries) == 'table' then
        for _, entry in ipairs(entries) do
            if type(entry) == 'table' then
                local seq = math.max(1, math.floor(tonumber(entry.seq) or 1))
                local restored = {
                    event_id = math.max(1, math.floor(tonumber(entry.event_id) or seq)),
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

    local ledgerEntries = type(snapshot) == 'table' and snapshot.ledgerEntries or nil
    local maxLedgerId = 0
    if type(ledgerEntries) == 'table' then
        for _, entry in ipairs(ledgerEntries) do
            if type(entry) == 'table' then
                local restored = deepcopy(entry)
                restored.ledger_event_id = math.max(1, math.floor(tonumber(restored.ledger_event_id) or 1))
                restored.event_id = math.max(1, math.floor(tonumber(restored.event_id) or restored.ledger_event_id))
                restored.sequence = restored.ledger_event_id
                restored.revision = restored.ledger_event_id
                restored.timestamp = tonumber(restored.timestamp) or self.time()
                self.ledgerEntries[#self.ledgerEntries + 1] = restored
                if restored.idempotency_key and restored.idempotency_key ~= '' then
                    self.ledgerIdempotency[restored.idempotency_key] = restored
                end
                if restored.ledger_event_id > maxLedgerId then maxLedgerId = restored.ledger_event_id end
            end
        end
        table.sort(self.ledgerEntries, function(a, b) return (a.ledger_event_id or 0) < (b.ledger_event_id or 0) end)
    end
    self:_trimLedger()
    self.nextLedgerEventId = math.max(maxLedgerId + 1, self.nextLedgerEventId)
    local maxEventId = 0
    for _, entry in ipairs(self.entries) do
        maxEventId = math.max(maxEventId, math.floor(tonumber(entry.event_id) or 0))
    end
    for _, entry in ipairs(self.ledgerEntries) do
        maxEventId = math.max(maxEventId, math.floor(tonumber(entry.event_id) or 0))
    end
    self.nextEventId = math.max(maxEventId + 1, self.nextEventId)
end

function EventJournal:latest()
    return self.entries[#self.entries]
end

return EventJournal
