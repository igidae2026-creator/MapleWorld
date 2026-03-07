local PlayerRepository = {}

local function deepcopy(value, seen)
    if type(value) ~= 'table' then return value end
    if seen and seen[value] then return seen[value] end
    local visited = seen or {}
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

function PlayerRepository.newMemory(config)
    local cfg = config or {}
    local self = {
        data = cfg.data or {},
        metrics = cfg.metrics,
        logger = cfg.logger,
    }
    setmetatable(self, { __index = PlayerRepository })
    return self
end

function PlayerRepository.newMapleWorldsDataStorage(config)
    local cfg = config or {}
    local self = {
        metrics = cfg.metrics,
        logger = cfg.logger,
        runtimeAdapter = assert(cfg.runtimeAdapter or (require('ops.runtime_adapter').new({})), 'runtimeAdapter is required'),
        storageName = cfg.storageName,
        key = cfg.key or 'profile',
        slotCount = math.max(2, math.floor(tonumber(cfg.slotCount) or 2)),
    }
    setmetatable(self, { __index = PlayerRepository })
    return self
end

function PlayerRepository:load(playerId)
    local data = self.data and self.data[playerId] or nil
    if data == nil then return nil end
    if self.metrics then self.metrics:increment('repository.load', 1, { status = 'hit', kind = 'memory' }) end
    return deepcopy(data)
end

function PlayerRepository:save(player)
    if not player or not player.id then return false, 'invalid_player' end
    self.data[player.id] = deepcopy(player)
    if self.metrics then self.metrics:increment('repository.save', 1, { status = 'ok', kind = 'memory' }) end
    return true
end

function PlayerRepository:_storage(playerId)
    return self.runtimeAdapter:getUserDataStorage(playerId, self.storageName)
end

function PlayerRepository:_slotKey(index)
    return tostring(self.key) .. '__slot_' .. tostring(index)
end

function PlayerRepository:_headKey()
    return tostring(self.key) .. '__head'
end

function PlayerRepository:_shadowHeadKey()
    return tostring(self.key) .. '__head_shadow'
end

function PlayerRepository:_headHistoryKey(index)
    return tostring(self.key) .. '__head_history_' .. tostring(index)
end

function PlayerRepository:_headHistorySize()
    return math.max(2, self.slotCount)
end

function PlayerRepository:_headCandidates(storage)
    local candidates = { self:_headKey(), self:_shadowHeadKey() }
    for i = 1, self:_headHistorySize() do
        local head = self:_readHead(storage, self:_headHistoryKey(i))
        if type(head) == 'table' then
            candidates[#candidates + 1] = head
        end
    end
    return candidates
end

function PlayerRepository:_decodeEnvelope(encoded)
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

function PlayerRepository:_readEnvelope(storage, key)
    local ok, encoded, err = readStorage(storage, key)
    if not ok then return nil, err end
    return self:_decodeEnvelope(encoded)
end

function PlayerRepository:_readHead(storage, key)
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

function PlayerRepository:_candidateKeys()
    local keys = {
        self:_headKey(),
        self:_shadowHeadKey(),
    }
    for i = 1, self.slotCount do
        keys[#keys + 1] = self:_slotKey(i)
    end
    keys[#keys + 1] = self.key
    return keys
end

function PlayerRepository:_loadFromStorage(playerId)
    local storage = self:_storage(playerId)
    if not storage then return nil, 'storage_unavailable' end

    local bestEnvelope = nil
    local bestKey = nil

    local prioritized = {}

    for _, head in ipairs(self:_headCandidates(storage)) do
        if type(head) == 'table' and tonumber(head.slot) then
            prioritized[#prioritized + 1] = self:_slotKey(math.floor(tonumber(head.slot)))
        end
    end
    for _, key in ipairs(self:_candidateKeys()) do
        prioritized[#prioritized + 1] = key
    end

    local seen = {}
    for _, key in ipairs(prioritized) do
        if not seen[key] then
            seen[key] = true
            local envelope = self:_readEnvelope(storage, key)
            if envelope and envelope.value ~= nil then
                if not bestEnvelope or (tonumber(envelope.revision) or 0) > (tonumber(bestEnvelope.revision) or 0) then
                    bestEnvelope = envelope
                    bestKey = key
                end
            end
        end
    end

    if not bestEnvelope then
        if self.metrics then self.metrics:increment('repository.load', 1, { status = 'miss', kind = 'msw' }) end
        return nil
    end

    if self.metrics then
        self.metrics:increment('repository.load', 1, { status = 'hit', kind = 'msw' })
        self.metrics:gauge('repository.load_revision', tonumber(bestEnvelope.revision) or 0, { key = tostring(bestKey) })
    end
    return deepcopy(bestEnvelope.value)
end

function PlayerRepository:_saveToStorage(player)
    local storage = self:_storage(player.id)
    if not storage then return false, 'storage_unavailable' end

    local currentHead = self:_readHead(storage, self:_headKey()) or { revision = 0, slot = 0 }
    local currentRevision = math.max(0, math.floor(tonumber(currentHead.revision) or 0))
    local nextRevision = currentRevision + 1
    local nextSlot = ((nextRevision - 1) % self.slotCount) + 1

    local envelope = {
        revision = nextRevision,
        savedAt = self.runtimeAdapter:now(),
        previousRevision = currentRevision,
        value = deepcopy(player),
    }

    local encodedEnvelope = self.runtimeAdapter:encodeData(envelope)
    local ok, err = writeStorage(storage, self:_slotKey(nextSlot), encodedEnvelope)
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

    if self.metrics then
        self.metrics:increment('repository.save', 1, { status = 'ok', kind = 'msw' })
        self.metrics:gauge('repository.save_revision', nextRevision)
    end
    return true
end

function PlayerRepository:loadMapleWorlds(playerId)
    return self:_loadFromStorage(playerId)
end

function PlayerRepository:saveMapleWorlds(player)
    return self:_saveToStorage(player)
end

local memoryLoad = PlayerRepository.load
local memorySave = PlayerRepository.save

function PlayerRepository:load(playerId)
    if self.runtimeAdapter then return self:_loadFromStorage(playerId) end
    return memoryLoad(self, playerId)
end

function PlayerRepository:save(player)
    if self.runtimeAdapter then return self:_saveToStorage(player) end
    return memorySave(self, player)
end

return PlayerRepository
