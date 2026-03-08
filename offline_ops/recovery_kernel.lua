local RecoveryKernel = {}

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

function RecoveryKernel.classifyLoadError(err)
    local msg = tostring(err or '')
    if msg == '' then return 'unknown_error' end
    if msg:find('storage_unavailable', 1, true) or msg:find('disk_offline', 1, true) then return 'storage_unavailable' end
    if msg:find('replay', 1, true) or msg:find('restore', 1, true) then return 'replay_recovery' end
    if msg:find('decode', 1, true) or msg:find('json', 1, true) or msg:find('invalid_world_snapshot', 1, true) then return 'corruption' end
    if msg:find('error_code_', 1, true) then return 'storage_error' end
    return 'storage_error'
end

function RecoveryKernel.verificationSummary(recovery, savePlan)
    local summary = {
        verdict = 'verified',
        confidence = 100,
        reasons = {},
        replayWatermark = deepcopy(recovery and recovery.watermark or {}),
        checkpointHealthScore = savePlan and savePlan.healthScore or 100,
    }
    if recovery and recovery.valid == false then
        summary.verdict = 'invalid'
        summary.confidence = summary.confidence - 60
        summary.reasons[#summary.reasons + 1] = 'recovery_invalid'
    end
    if recovery and recovery.divergence then
        summary.verdict = 'divergent'
        summary.confidence = summary.confidence - 40
        summary.reasons[#summary.reasons + 1] = 'replay_divergence'
    end
    if recovery and (recovery.divergenceCount or 0) > 0 then
        summary.confidence = summary.confidence - math.min(20, (recovery.divergenceCount or 0) * 5)
        summary.reasons[#summary.reasons + 1] = 'divergence_history'
    end
    if savePlan and savePlan.healthScore and savePlan.healthScore < 100 then
        summary.confidence = summary.confidence - math.floor((100 - savePlan.healthScore) / 4)
        summary.reasons[#summary.reasons + 1] = 'checkpoint_health_reduced'
    end
    if #summary.reasons == 0 then
        summary.reasons[1] = 'verified_clean'
    end
    summary.confidence = math.max(0, summary.confidence)
    return summary
end

return RecoveryKernel
