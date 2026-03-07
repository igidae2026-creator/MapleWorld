local WorldRepository = {}

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

local function readStorage(storage, key)
    local ok, first, second = pcall(function()
        return storage:GetAndWait(key)
    end)
    if not ok then return false, nil, tostring(first) end

    local errorCode, encoded = first, second
    if second == nil and type(first) ~= 'number' then
        errorCode = 0
        encoded = first
    end
    if type(errorCode) == 'number' and errorCode ~= 0 then
        return false, nil, 'error_code_' .. tostring(errorCode)
    end
    return true, encoded
end


local function isFiniteNumber(value)
    local n = tonumber(value)
    return n ~= nil and n == n and n ~= math.huge and n ~= -math.huge
end

local function normalizeRevision(value)
    if not isFiniteNumber(value) then return nil end
    return math.max(0, math.floor(tonumber(value) or 0))
end

local function writeStorage(storage, key, encoded)
    local ok, result = pcall(function()
        return storage:SetAndWait(key, encoded)
    end)
    if not ok then return false, tostring(result) end
    if type(result) == 'number' and result ~= 0 then
        return false, 'error_code_' .. tostring(result)
    end
    return true
end

function WorldRepository.newMemory(config)
    local cfg = config or {}
    local self = {
        state = deepcopy(cfg.state),
        metrics = cfg.metrics,
        logger = cfg.logger,
    }
    setmetatable(self, { __index = WorldRepository })
    return self
end

function WorldRepository.newMapleWorldsDataStorage(config)
    local cfg = config or {}
    local self = {
        metrics = cfg.metrics,
        logger = cfg.logger,
        runtimeAdapter = assert(cfg.runtimeAdapter or (require('ops.runtime_adapter').new({})), 'runtimeAdapter is required'),
        storageName = cfg.storageName or 'GenesisWorldState',
        key = cfg.key or 'state',
        reservedUserId = cfg.reservedUserId or '__world__',
        slotCount = math.max(2, math.floor(tonumber(cfg.slotCount) or 3)),
    }
    setmetatable(self, { __index = WorldRepository })
    return self
end

function WorldRepository:_storage()
    if not self.runtimeAdapter then return nil end
    local storage = self.runtimeAdapter:getSharedDataStorage(self.storageName)
    if storage then return storage end
    return self.runtimeAdapter:getUserDataStorage(self.reservedUserId, self.storageName)
end

function WorldRepository:_slotKey(index)
    return tostring(self.key) .. '__slot_' .. tostring(index)
end


function WorldRepository:_revisionKey(revision)
    return tostring(self.key) .. '__rev_' .. tostring(math.max(1, math.floor(tonumber(revision) or 1)))
end

function WorldRepository:_headKey()
    return tostring(self.key) .. '__head'
end

function WorldRepository:_shadowHeadKey()
    return tostring(self.key) .. '__head_shadow'
end

function WorldRepository:_headHistoryKey(index)
    return tostring(self.key) .. '__head_history_' .. tostring(index)
end

function WorldRepository:_commitKey(revision)
    return tostring(self.key) .. '__commit_' .. tostring(math.max(1, math.floor(tonumber(revision) or 1)))
end

function WorldRepository:_headHistorySize()
    return math.max(2, self.slotCount)
end

function WorldRepository:_headCandidates(storage)
    local candidates = { self:_headKey(), self:_shadowHeadKey() }
    for i = 1, self:_headHistorySize() do
        local head = self:_readHead(storage, self:_headHistoryKey(i))
        if type(head) == 'table' then
            candidates[#candidates + 1] = head
        end
    end
    return candidates
end

function WorldRepository:_decodeEnvelope(encoded)
    if encoded == nil or encoded == '' then return nil end
    local decoded = self.runtimeAdapter:decodeData(encoded)
    if decoded == nil then return nil end
    if type(decoded) == 'table' and decoded.value ~= nil and tonumber(decoded.revision) ~= nil then
        return decoded
    end
    return {
        revision = 0,
        savedAt = 0,
        value = decoded,
        legacy = true,
    }
end

function WorldRepository:_readEnvelope(storage, key)
    local ok, encoded, err = readStorage(storage, key)
    if not ok then return nil, err end
    return self:_decodeEnvelope(encoded)
end

function WorldRepository:_readHead(storage, key)
    local envelope, err = self:_readEnvelope(storage, key)
    if not envelope then return nil, err end
    if type(envelope.value) == 'table' and envelope.legacy ~= true then
        return envelope.value
    end
    if type(envelope) == 'table' and envelope.slot ~= nil then
        return envelope
    end
    return type(envelope) == 'table' and envelope.legacy == true and envelope.value or nil
end


function WorldRepository:_isValidEnvelope(envelope)
    if type(envelope) ~= 'table' then return false end
    if envelope.value == nil then return false end
    if envelope.legacy == true then return true end
    local revision = normalizeRevision(envelope.revision)
    if revision == nil or revision < 0 then return false end
    local savedAt = tonumber(envelope.savedAt)
    if savedAt ~= nil and not isFiniteNumber(savedAt) then return false end
    local previousRevision = normalizeRevision(envelope.previousRevision)
    if previousRevision ~= nil and previousRevision > revision then return false end
    return true
end

function WorldRepository:_isCommittedRevision(storage, revision)
    local normalized = normalizeRevision(revision)
    if normalized == nil or normalized <= 0 then return true end
    local envelope = self:_readEnvelope(storage, self:_commitKey(normalized))
    if type(envelope) ~= 'table' then return false end
    local value = envelope.value
    if type(value) ~= 'table' then return false end
    return normalizeRevision(value.revision) == normalized
end

function WorldRepository:load()
    if not self.runtimeAdapter then
        if self.state == nil then return nil end
        if self.metrics then self.metrics:increment('world_repository.load', 1, { status = 'hit', kind = 'memory' }) end
        return deepcopy(self.state)
    end

    local storage = self:_storage()
    if not storage then return nil, 'storage_unavailable' end

    local bestEnvelope = nil

    local prioritized = {}
    local highestRevision = 0
    for _, head in ipairs(self:_headCandidates(storage)) do
        if type(head) == 'table' and tonumber(head.slot) then
            prioritized[#prioritized + 1] = self:_slotKey(math.floor(tonumber(head.slot)))
        end
        if type(head) == 'table' and tonumber(head.revision) then
            highestRevision = math.max(highestRevision, math.floor(tonumber(head.revision) or 0))
        end
    end

    local revisionWindow = math.max(self.slotCount * 6, self:_headHistorySize() * 4)
    if highestRevision > 0 then
        for rev = highestRevision, math.max(1, highestRevision - revisionWindow), -1 do
            prioritized[#prioritized + 1] = self:_revisionKey(rev)
        end
    end

    for i = 1, self.slotCount do
        prioritized[#prioritized + 1] = self:_slotKey(i)
    end
    prioritized[#prioritized + 1] = self.key

    local seen = {}
    local loadErr = nil
    for _, key in ipairs(prioritized) do
        if not seen[key] then
            seen[key] = true
            local envelope, err = self:_readEnvelope(storage, key)
            if err then
                loadErr = loadErr or err
            elseif envelope and self:_isValidEnvelope(envelope) then
                local envelopeRevision = normalizeRevision(envelope.revision) or 0
                local bestRevision = normalizeRevision(bestEnvelope and bestEnvelope.revision) or 0
                local envelopeCommitted = self:_isCommittedRevision(storage, envelopeRevision)
                local bestCommitted = bestEnvelope and self:_isCommittedRevision(storage, bestRevision) or false
                if (not bestEnvelope) or (envelopeCommitted and not bestCommitted) or (envelopeCommitted == bestCommitted and envelopeRevision > bestRevision) then
                    bestEnvelope = envelope
                end
            end
        end
    end

    if not bestEnvelope then
        if loadErr then
            if self.metrics then self.metrics:increment('world_repository.load', 1, { status = 'error', kind = 'msw' }) end
            return nil, loadErr
        end
        if self.metrics then self.metrics:increment('world_repository.load', 1, { status = 'miss', kind = 'msw' }) end
        return nil
    end

    if self.metrics then
        self.metrics:increment('world_repository.load', 1, { status = 'hit', kind = 'msw' })
        self.metrics:gauge('world_repository.revision', tonumber(bestEnvelope.revision) or 0)
    end
    return deepcopy(bestEnvelope.value)
end

function WorldRepository:save(state)
    if not self.runtimeAdapter then
        self.state = deepcopy(state)
        if self.metrics then self.metrics:increment('world_repository.save', 1, { status = 'ok', kind = 'memory' }) end
        return true
    end

    local storage = self:_storage()
    if not storage then return false, 'storage_unavailable' end

    local currentHead = self:_readHead(storage, self:_headKey()) or self:_readHead(storage, self:_shadowHeadKey()) or { revision = 0, slot = 0 }
    local currentRevision = math.max(0, math.floor(tonumber(currentHead.revision) or 0))
    local nextRevision = currentRevision + 1
    local nextSlot = ((nextRevision - 1) % self.slotCount) + 1

    local envelope = {
        revision = nextRevision,
        savedAt = self.runtimeAdapter:now(),
        previousRevision = currentRevision,
        value = deepcopy(state),
    }

    local encodedEnvelope = self.runtimeAdapter:encodeData(envelope)
    local ok, err = writeStorage(storage, self:_revisionKey(nextRevision), encodedEnvelope)
    if not ok then return false, err end

    ok, err = writeStorage(storage, self:_slotKey(nextSlot), encodedEnvelope)
    if not ok then return false, err end

    local headSnapshot = {
        revision = nextRevision,
        slot = nextSlot,
        savedAt = envelope.savedAt,
    }

    writeStorage(storage, self:_shadowHeadKey(), self.runtimeAdapter:encodeData(currentHead))
    local historySlot = ((nextRevision - 1) % self:_headHistorySize()) + 1
    writeStorage(storage, self:_headHistoryKey(historySlot), self.runtimeAdapter:encodeData(headSnapshot))
    ok, err = writeStorage(storage, self:_headKey(), self.runtimeAdapter:encodeData(headSnapshot))
    if not ok then
        writeStorage(storage, self:_headKey(), self.runtimeAdapter:encodeData(currentHead))
        return false, err
    end

    local commitEnvelope = {
        revision = nextRevision,
        savedAt = envelope.savedAt,
        value = { revision = nextRevision, slot = nextSlot },
    }
    ok, err = writeStorage(storage, self:_commitKey(nextRevision), self.runtimeAdapter:encodeData(commitEnvelope))
    if not ok then return false, err end

    if self.metrics then
        self.metrics:increment('world_repository.save', 1, { status = 'ok', kind = 'msw' })
        self.metrics:gauge('world_repository.revision', nextRevision)
    end
    return true
end

return WorldRepository
