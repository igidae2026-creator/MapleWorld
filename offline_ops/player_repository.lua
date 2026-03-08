local PlayerRepository = {}

local NOT_FOUND_ERROR_CODES = {
    [404] = true,
    [1004] = true,
    [1005] = true,
    [1010] = true,
}

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
        if NOT_FOUND_ERROR_CODES[math.floor(errorCode)] then
            return true, nil
        end
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


local function classifyLoadError(err)
    local msg = tostring(err or '')
    if msg == '' then return 'unknown_error' end
    if msg:find('storage_unavailable', 1, true) then return 'storage_unavailable' end
    if msg:find('replay', 1, true) or msg:find('restore', 1, true) then return 'replay_recovery' end
    if msg:find('decode', 1, true) or msg:find('json', 1, true) then return 'corrupted_envelope' end
    if msg:find('error_code_', 1, true) then return 'storage_error' end
    return 'storage_error'
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
        runtimeAdapter = assert(cfg.runtimeAdapter or (require('offline_ops.runtime_adapter').new({})), 'runtimeAdapter is required'),
        storageName = cfg.storageName,
        key = cfg.key or 'profile',
        slotCount = math.max(2, math.floor(tonumber(cfg.slotCount) or 2)),
        maxRevisions = math.max(0, math.floor(tonumber(cfg.maxRevisions) or 16)),
        maxCommits = math.max(0, math.floor(tonumber(cfg.maxCommits) or (math.max(0, math.floor(tonumber(cfg.maxRevisions) or 16)) * 2))),
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


function PlayerRepository:_revisionKey(index)
    return tostring(self.key) .. '__rev_' .. tostring(math.max(1, math.floor(tonumber(index) or 1)))
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

function PlayerRepository:_commitKey(revision)
    return tostring(self.key) .. '__commit_' .. tostring(math.max(1, math.floor(tonumber(revision) or 1)))
end

function PlayerRepository:_stageKey(revision)
    return tostring(self.key) .. '__stage_' .. tostring(math.max(1, math.floor(tonumber(revision) or 1)))
end

function PlayerRepository:_finalizeKey(revision)
    return tostring(self.key) .. '__finalize_' .. tostring(math.max(1, math.floor(tonumber(revision) or 1)))
end

function PlayerRepository:_headHistorySize()
    return math.max(2, self.slotCount)
end

function PlayerRepository:_oldCommitKey(revision)
    local maxCommits = math.max(0, math.floor(tonumber(self.maxCommits) or 0))
    local normalized = math.max(0, math.floor(tonumber(revision) or 0))
    if maxCommits <= 0 or normalized <= maxCommits then return nil end
    return self:_commitKey(normalized - maxCommits)
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


function PlayerRepository:_oldRevisionKey(revision)
    local maxRevisions = math.max(0, math.floor(tonumber(self.maxRevisions) or 0))
    local normalized = math.max(0, math.floor(tonumber(revision) or 0))
    if maxRevisions <= 0 or normalized <= maxRevisions then return nil end
    return self:_revisionKey(normalized - maxRevisions)
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

function PlayerRepository:_isCommittedRevision(storage, revision)
    local normalized = math.max(0, math.floor(tonumber(revision) or 0))
    if normalized <= 0 then return true end
    local envelope = self:_readEnvelope(storage, self:_commitKey(normalized))
    if type(envelope) ~= 'table' then return false end
    local value = envelope.value
    if type(value) ~= 'table' then return false end
    return math.max(0, math.floor(tonumber(value.revision) or 0)) == normalized
end

function PlayerRepository:_isFinalizedRevision(storage, revision)
    local normalized = math.max(0, math.floor(tonumber(revision) or 0))
    if normalized <= 0 then return true end
    local envelope = self:_readEnvelope(storage, self:_finalizeKey(normalized))
    if type(envelope) ~= 'table' then return false end
    local value = envelope.value
    if type(value) ~= 'table' then return false end
    return math.max(0, math.floor(tonumber(value.revision) or 0)) == normalized
        and tostring(value.phase or '') == 'finalized'
end

function PlayerRepository:_loadFromStorage(playerId)
    local storage = self:_storage(playerId)
    if not storage then return nil, 'storage_unavailable' end

    local bestEnvelope = nil
    local bestKey = nil

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

    for _, key in ipairs(self:_candidateKeys()) do
        prioritized[#prioritized + 1] = key
    end

    local seen = {}
    local loadErr = nil
    for _, key in ipairs(prioritized) do
        if not seen[key] then
            seen[key] = true
            local envelope, err = self:_readEnvelope(storage, key)
            if err then
                loadErr = loadErr or err
            elseif envelope and envelope.value ~= nil then
                local envelopeRevision = math.max(0, math.floor(tonumber(envelope.revision) or 0))
                local bestRevision = math.max(0, math.floor(tonumber(bestEnvelope and bestEnvelope.revision) or 0))
                local envelopeCommitted = self:_isCommittedRevision(storage, envelopeRevision)
                local envelopeFinalized = self:_isFinalizedRevision(storage, envelopeRevision)
                local bestCommitted = bestEnvelope and self:_isCommittedRevision(storage, bestRevision) or false
                local bestFinalized = bestEnvelope and self:_isFinalizedRevision(storage, bestRevision) or false
                if (not bestEnvelope)
                    or (envelopeFinalized and not bestFinalized)
                    or (envelopeFinalized == bestFinalized and envelopeCommitted and not bestCommitted)
                    or (envelopeFinalized == bestFinalized and envelopeCommitted == bestCommitted and envelopeRevision > bestRevision) then
                    bestEnvelope = envelope
                    bestKey = key
                end
            end
        end
    end

    if not bestEnvelope then
        if loadErr then
            if self.metrics then self.metrics:increment('repository.load', 1, { status = 'error', kind = 'msw' }) end
            return nil, loadErr
        end
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
        phase = 'staged',
        value = deepcopy(player),
    }

    local encodedEnvelope = self.runtimeAdapter:encodeData(envelope)
    local ok, err = writeStorage(storage, self:_stageKey(nextRevision), encodedEnvelope)
    if not ok then return false, err end
    ok, err = writeStorage(storage, self:_revisionKey(nextRevision), encodedEnvelope)
    if not ok then return false, err end

    ok, err = writeStorage(storage, self:_slotKey(nextSlot), encodedEnvelope)
    if not ok then return false, err end

    local observedHead = self:_readHead(storage, self:_headKey()) or self:_readHead(storage, self:_shadowHeadKey()) or { revision = 0, slot = 0 }
    local observedRevision = math.max(0, math.floor(tonumber(observedHead.revision) or 0))
    if observedRevision ~= currentRevision then
        if self.metrics then self.metrics:increment('repository.save', 1, { status = 'head_conflict', kind = 'msw' }) end
        return false, 'player_head_conflict'
    end

    local commitEnvelope = {
        revision = nextRevision,
        savedAt = envelope.savedAt,
        phase = 'committed',
        value = { revision = nextRevision, slot = nextSlot, previousRevision = currentRevision },
    }
    ok, err = writeStorage(storage, self:_commitKey(nextRevision), self.runtimeAdapter:encodeData(commitEnvelope))
    if not ok then return false, err end

    local headSnapshot = {
        revision = nextRevision,
        slot = nextSlot,
        savedAt = envelope.savedAt,
    }

    local shadowOk
    shadowOk, err = writeStorage(storage, self:_shadowHeadKey(), self.runtimeAdapter:encodeData(currentHead))
    if not shadowOk then return false, err end
    local historySlot = ((nextRevision - 1) % self:_headHistorySize()) + 1
    local historyOk
    historyOk, err = writeStorage(storage, self:_headHistoryKey(historySlot), self.runtimeAdapter:encodeData(headSnapshot))
    if not historyOk then return false, err end
    ok, err = writeStorage(storage, self:_headKey(), self.runtimeAdapter:encodeData(headSnapshot))
    if not ok then
        writeStorage(storage, self:_headKey(), self.runtimeAdapter:encodeData(currentHead))
        return false, err
    end

    local finalizeEnvelope = {
        revision = nextRevision,
        savedAt = envelope.savedAt,
        phase = 'finalized',
        value = { revision = nextRevision, slot = nextSlot, previousRevision = currentRevision, phase = 'finalized' },
    }
    ok, err = writeStorage(storage, self:_finalizeKey(nextRevision), self.runtimeAdapter:encodeData(finalizeEnvelope))
    if not ok then return false, err end

    local trimKey = self:_oldRevisionKey(nextRevision)
    if trimKey ~= nil then
        writeStorage(storage, trimKey, '')
        if self.metrics then self.metrics:increment('repository.trimmed_revision', 1, { kind = 'msw' }) end
    end

    local oldCommitKey = self:_oldCommitKey(nextRevision)
    if oldCommitKey ~= nil then
        writeStorage(storage, oldCommitKey, '')
        if self.metrics then self.metrics:increment('repository.trimmed_commit', 1, { kind = 'msw' }) end
    end

    local oldStageKey = self:_oldCommitKey(nextRevision)
    if oldStageKey ~= nil then
        writeStorage(storage, self:_stageKey(nextRevision - self.maxCommits), '')
        writeStorage(storage, self:_finalizeKey(nextRevision - self.maxCommits), '')
    end

    if self.metrics then
        self.metrics:increment('repository.save', 1, { status = 'ok', kind = 'msw' })
        self.metrics:gauge('repository.save_revision', nextRevision)
        self.metrics:gauge('repository.retained_revisions', math.min(nextRevision, math.max(1, self.maxRevisions)))
        self.metrics:gauge('repository.retained_commits', math.min(nextRevision, math.max(1, self.maxCommits)))
    end
    return true
end

function PlayerRepository:loadMapleWorlds(playerId)
    return self:_loadFromStorage(playerId)
end

function PlayerRepository:loadDetailed(playerId)
    local value, err = self:load(playerId)
    if err then
        return nil, classifyLoadError(err), err
    end
    if value == nil then
        return nil, 'not_found', nil
    end
    return deepcopy(value), 'ok', nil
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
