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
        lineage = {
            parentPolicyId = tostring(runtime.parentPolicyBundleId or ''),
            parentPolicyVersion = tostring(runtime.parentPolicyBundleVersion or ''),
            adoptedAt = 0,
            adoptionSource = 'boot_defaults',
            replacementHistory = {},
        },
        activation = {
            startsAt = 0,
            endsAt = nil,
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
            },
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
        },
        replayFallback = {
            failClosedOnInvariantViolation = true,
            restoreFromCheckpointOnly = false,
        },
        savePolicy = {
            forceImmediateWhenHighPressure = true,
            immediateWhenReplayPressure = true,
            immediateWhenOwnershipConflict = true,
            debounceSec = tonumber(runtime.worldStateSaveDebounceSec) or 5,
            backlogImmediateThreshold = tonumber(runtime.pressureSaveBacklogThreshold) or 50,
            mutationDensityThreshold = tonumber(runtime.saveMutationDensityThreshold) or 12,
            integrityCheckpointThreshold = tonumber(runtime.saveIntegrityCheckpointThreshold) or 2,
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
    }
end

function RuntimePolicyBundle.new(worldConfig, override)
    local self = {
        active = merge(RuntimePolicyBundle.defaults(worldConfig), override or {}),
    }
    setmetatable(self, { __index = RuntimePolicyBundle })
    return self
end

function RuntimePolicyBundle:replace(policy)
    if type(policy) ~= 'table' then return false, 'invalid_policy_bundle' end
    local previous = self:snapshot() or {}
    self.active = merge(self.active or {}, policy)
    self.active.lineage = self.active.lineage or {}
    self.active.lineage.parentPolicyId = previous.policyId
    self.active.lineage.parentPolicyVersion = previous.policyVersion
    self.active.lineage.adoptedAt = tonumber(self.active.lineage.adoptedAt) or os.time()
    self.active.lineage.adoptionSource = tostring(self.active.lineage.adoptionSource or policy.adoptionSource or 'runtime_replace')
    self.active.lineage.replacementHistory = type(self.active.lineage.replacementHistory) == 'table' and self.active.lineage.replacementHistory or {}
    self.active.lineage.replacementHistory[#self.active.lineage.replacementHistory + 1] = {
        policyId = previous.policyId,
        policyVersion = previous.policyVersion,
        replacedByPolicyId = self.active.policyId,
        replacedByPolicyVersion = self.active.policyVersion,
        adoptedAt = self.active.lineage.adoptedAt,
    }
    self.active.rollback = self.active.rollback or {}
    self.active.rollback.previousPolicyId = previous.policyId
    self.active.rollback.previousPolicyVersion = previous.policyVersion
    return true
end

function RuntimePolicyBundle:snapshot()
    return deepcopy(self.active)
end

return RuntimePolicyBundle
