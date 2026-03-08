local RuntimePolicyBundle = {}

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

local function merge(base, overlay)
    local out = deepcopy(base or {})
    for k, v in pairs(overlay or {}) do
        if type(v) == 'table' and type(out[k]) == 'table' then
            out[k] = merge(out[k], v)
        else
            out[k] = deepcopy(v)
        end
    end
    return out
end

function RuntimePolicyBundle.defaults(worldConfig)
    local runtime = worldConfig and worldConfig.runtime or {}
    return {
        policyId = tostring(runtime.policyBundleId or 'genesis.default'),
        policyVersion = tostring(runtime.policyBundleVersion or '1.0.0'),
        policyClass = tostring(runtime.policyBundleClass or 'stable'),
        lineage = {
            parentPolicyId = tostring(runtime.parentPolicyBundleId or ''),
            parentPolicyVersion = tostring(runtime.parentPolicyBundleVersion or ''),
            adoptedAt = 0,
            adoptionSource = 'boot_defaults',
            adoptionReason = 'boot_defaults',
            replacementHistory = {},
            rollbackHistory = {},
            mutationOf = nil,
        },
        activation = {
            startsAt = 0,
            endsAt = nil,
            adoptionWindow = 'runtime',
            runtimeScope = {
                worldId = tostring(runtime.worldId or 'world-1'),
                channelId = tostring(runtime.channelId or 'channel-1'),
                runtimeInstanceId = tostring(runtime.runtimeInstanceId or 'runtime-main'),
            },
        },
        rollback = {
            enabled = true,
            previousPolicyId = nil,
            previousPolicyVersion = nil,
            lastRollbackAt = nil,
            lastRollbackReason = nil,
        },
        evaluation = {
            enabled = true,
            archiveWindow = math.max(4, math.floor(tonumber(runtime.policyMetricArchiveWindow) or 16)),
            fitnessDimensions = {
                stability = true,
                rewardIntegrity = true,
                replayReliability = true,
                savePressure = true,
                exploitResistance = true,
                densityBalance = true,
                migrationCorrectness = true,
            },
            metricsArchive = {},
            latest = nil,
        },
        selection = {
            safeDefaultStability = true,
            controlledMutation = true,
            rollbackOnRegression = true,
            replacementMode = 'manual_or_governed',
        },
        pressureThresholds = {
            density = tonumber(runtime.pressureDensityThreshold) or 0.85,
            saveBacklog = tonumber(runtime.pressureSaveBacklogThreshold) or 50,
            rewardInflation = tonumber(runtime.pressureRewardInflationThreshold) or 12,
            replay = tonumber(runtime.pressureReplayThreshold) or 1,
            instability = tonumber(runtime.pressureInstabilityThreshold) or 3,
            lowDiversity = tonumber(runtime.pressureLowDiversityThreshold) or 4,
            ownershipConflict = tonumber(runtime.pressureOwnershipConflictThreshold) or 1,
            duplicateRisk = tonumber(runtime.pressureDuplicateRiskThreshold) or 1,
            farmRepetition = tonumber(runtime.pressureFarmRepetitionThreshold) or 8,
        },
        containment = {
            safeModeOnEscalation = tonumber(runtime.safeModeSeverityThreshold) or 3,
            rewardQuarantineOnEscalation = tonumber(runtime.rewardQuarantineSeverityThreshold) or 2,
            migrationBlockOnEscalation = tonumber(runtime.migrationBlockSeverityThreshold) or 2,
            replayOnlyOnEscalation = tonumber(runtime.replayOnlySeverityThreshold) or 4,
            persistenceQuarantineOnEscalation = tonumber(runtime.persistenceQuarantineSeverityThreshold) or 3,
        },
        spawnRegulation = {
            minTickScale = 0.5,
            maxTickScale = 2.0,
            densityThrottleThreshold = tonumber(runtime.pressureDensityThreshold) or 0.85,
            farmRepetitionThrottleThreshold = tonumber(runtime.pressureFarmRepetitionThreshold) or 8,
        },
        bossUniqueness = {
            defaultScope = tostring(runtime.defaultBossUniquenessScope or 'channel_unique'),
            worldUniqueThrottle = tonumber(runtime.pressureOwnershipConflictThreshold) or 2,
        },
        dropReservation = {
            ownerWindowSec = tonumber(runtime.dropOwnerWindowSec) or 2,
            rejectCrossScopeClaims = true,
        },
        routing = {
            requireScopeSource = true,
            rejectCrossRuntimeScope = true,
            topologyAwareMigration = true,
        },
        replayFallback = {
            failClosedOnInvariantViolation = true,
            restoreFromCheckpointOnly = false,
            replayRestoreOnInvalidState = true,
        },
        savePolicy = {
            forceImmediateWhenHighPressure = true,
            immediateWhenReplayPressure = true,
            immediateWhenOwnershipConflict = true,
            debounceSec = tonumber(runtime.worldStateSaveDebounceSec) or 5,
            backlogImmediateThreshold = tonumber(runtime.pressureSaveBacklogThreshold) or 50,
            mutationDensityThreshold = tonumber(runtime.saveMutationDensityThreshold) or 12,
            integrityCheckpointThreshold = tonumber(runtime.saveIntegrityCheckpointThreshold) or 2,
            replayAnchorThreshold = tonumber(runtime.saveReplayAnchorThreshold) or 1,
        },
        exploitResponse = {
            duplicateRiskEscalationThreshold = tonumber(runtime.pressureDuplicateRiskThreshold) or 1,
            rewardInflationEscalationThreshold = tonumber(runtime.pressureRewardInflationThreshold) or 12,
        },
        governance = {
            adaptiveOwnershipConflictThreshold = tonumber(runtime.pressureOwnershipConflictThreshold) or 1,
            repairReplayThreshold = tonumber(runtime.pressureReplayThreshold) or 1,
            quarantineAnomalyThreshold = tonumber(runtime.pressureDuplicateRiskThreshold) or 1,
            explorationLowDiversityThreshold = tonumber(runtime.pressureLowDiversityThreshold) or 4,
        },
        repair = {
            maxAutomaticRetries = math.max(1, math.floor(tonumber(runtime.repairMaxAutomaticRetries) or 3)),
            reopenCooldownSec = math.max(0, math.floor(tonumber(runtime.repairReopenCooldownSec) or 30)),
        },
        anomalyResponse = {
            quarantineOnDuplicateRisk = true,
            replayRestoreOnMigrationCorruption = true,
        },
        diversityPreservation = {
            enableExploration = true,
            lowDiversityThreshold = tonumber(runtime.pressureLowDiversityThreshold) or 4,
            repetitiveFarmingThreshold = tonumber(runtime.pressureFarmRepetitionThreshold) or 8,
        },
    }
end

function RuntimePolicyBundle.new(worldConfig, override)
    local self = {
        active = merge(RuntimePolicyBundle.defaults(worldConfig), override or {}),
        history = {},
    }
    self.history[1] = deepcopy(self.active)
    setmetatable(self, { __index = RuntimePolicyBundle })
    return self
end

local function trimArchive(entries, cap)
    local limit = math.max(1, math.floor(tonumber(cap) or 1))
    while #entries > limit do table.remove(entries, 1) end
end

function RuntimePolicyBundle:replace(policy, metadata)
    if type(policy) ~= 'table' then return false, 'invalid_policy_bundle' end
    local meta = metadata or {}
    local previous = self:snapshot() or {}
    self.active = merge(self.active or {}, policy)
    self.active.lineage = self.active.lineage or {}
    self.active.lineage.parentPolicyId = previous.policyId
    self.active.lineage.parentPolicyVersion = previous.policyVersion
    self.active.lineage.adoptedAt = tonumber(meta.adoptedAt or self.active.lineage.adoptedAt) or os.time()
    self.active.lineage.adoptionSource = tostring(meta.adoptionSource or self.active.lineage.adoptionSource or policy.adoptionSource or 'runtime_replace')
    self.active.lineage.adoptionReason = tostring(meta.adoptionReason or policy.adoptionReason or self.active.lineage.adoptionReason or 'runtime_replace')
    self.active.lineage.mutationOf = meta.mutationOf or policy.mutationOf or nil
    self.active.lineage.replacementHistory = type(self.active.lineage.replacementHistory) == 'table' and self.active.lineage.replacementHistory or {}
    self.active.lineage.replacementHistory[#self.active.lineage.replacementHistory + 1] = {
        policyId = previous.policyId,
        policyVersion = previous.policyVersion,
        replacedByPolicyId = self.active.policyId,
        replacedByPolicyVersion = self.active.policyVersion,
        adoptedAt = self.active.lineage.adoptedAt,
        adoptionReason = self.active.lineage.adoptionReason,
        adoptionSource = self.active.lineage.adoptionSource,
    }
    self.active.rollback = self.active.rollback or {}
    self.active.rollback.previousPolicyId = previous.policyId
    self.active.rollback.previousPolicyVersion = previous.policyVersion
    self.active.activation = self.active.activation or {}
    self.active.activation.startsAt = tonumber(meta.startsAt or self.active.activation.startsAt) or self.active.lineage.adoptedAt
    self.active.activation.endsAt = meta.endsAt or self.active.activation.endsAt
    self.active.activation.adoptionWindow = tostring(meta.adoptionWindow or self.active.activation.adoptionWindow or 'runtime')
    self.active.evaluation = self.active.evaluation or {}
    self.active.evaluation.metricsArchive = type(self.active.evaluation.metricsArchive) == 'table' and self.active.evaluation.metricsArchive or {}
    self.history[#self.history + 1] = deepcopy(self.active)
    trimArchive(self.history, tonumber(self.active.evaluation.archiveWindow) or 16)
    return true
end

function RuntimePolicyBundle:evaluate(metrics)
    local evaluation = self.active.evaluation or {}
    evaluation.metricsArchive = type(evaluation.metricsArchive) == 'table' and evaluation.metricsArchive or {}
    local entry = deepcopy(metrics or {})
    entry.policyId = self.active.policyId
    entry.policyVersion = self.active.policyVersion
    entry.at = tonumber(entry.at) or os.time()
    evaluation.latest = deepcopy(entry)
    evaluation.metricsArchive[#evaluation.metricsArchive + 1] = deepcopy(entry)
    trimArchive(evaluation.metricsArchive, tonumber(evaluation.archiveWindow) or 16)
    self.active.evaluation = evaluation
    return deepcopy(entry)
end

function RuntimePolicyBundle:rollback(reason)
    local rollback = self.active.rollback or {}
    if rollback.enabled == false then return false, 'rollback_disabled' end
    if #self.history < 2 then return false, 'rollback_unavailable' end
    local current = self.history[#self.history]
    local previous = deepcopy(self.history[#self.history - 1])
    self.history[#self.history] = nil
    previous.rollback = previous.rollback or {}
    previous.rollback.previousPolicyId = current and current.policyId or previous.rollback.previousPolicyId
    previous.rollback.previousPolicyVersion = current and current.policyVersion or previous.rollback.previousPolicyVersion
    previous.rollback.lastRollbackAt = os.time()
    previous.rollback.lastRollbackReason = tostring(reason or 'runtime_rollback')
    previous.lineage = previous.lineage or {}
    previous.lineage.rollbackHistory = type(previous.lineage.rollbackHistory) == 'table' and previous.lineage.rollbackHistory or {}
    previous.lineage.rollbackHistory[#previous.lineage.rollbackHistory + 1] = {
        fromPolicyId = current and current.policyId or nil,
        fromPolicyVersion = current and current.policyVersion or nil,
        restoredPolicyId = previous.policyId,
        restoredPolicyVersion = previous.policyVersion,
        at = previous.rollback.lastRollbackAt,
        reason = previous.rollback.lastRollbackReason,
    }
    self.active = previous
    self.history[#self.history + 1] = deepcopy(self.active)
    return true, self:snapshot()
end

function RuntimePolicyBundle:historySnapshot()
    return deepcopy(self.history)
end

function RuntimePolicyBundle:snapshot()
    return deepcopy(self.active)
end

return RuntimePolicyBundle
