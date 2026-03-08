local BuffSystem = {}

function BuffSystem.new(config)
    local self = { time = (config or {}).time or os.time }
    setmetatable(self, { __index = BuffSystem })
    return self
end

function BuffSystem:ensurePlayer(player)
    player.activeEffects = player.activeEffects or {}
    return player
end

function BuffSystem:ensureEntity(entity)
    entity.activeEffects = entity.activeEffects or {}
    return entity
end

function BuffSystem:apply(player, effect)
    self:ensureEntity(player)
    local now = math.floor(tonumber(self.time()) or os.time())
    local copy = {}
    for k, v in pairs(effect or {}) do copy[k] = v end
    copy.appliedAt = now
    copy.expiresAt = now + math.max(1, math.floor(tonumber(copy.duration) or 1))
    player.activeEffects[#player.activeEffects + 1] = copy
    player.version = (tonumber(player.version) or 0) + 1
    player.dirty = true
    return copy
end

function BuffSystem:applyStatus(target, status)
    if not target then return nil end
    self:ensureEntity(target)
    if status.replaceByKind ~= false then
        local kept = {}
        for _, effect in ipairs(target.activeEffects) do
            if effect.kind ~= status.kind then kept[#kept + 1] = effect end
        end
        target.activeEffects = kept
    end
    return self:apply(target, status)
end

function BuffSystem:tick(player)
    self:ensureEntity(player)
    local now = math.floor(tonumber(self.time()) or os.time())
    local kept = {}
    for _, effect in ipairs(player.activeEffects) do
        if (tonumber(effect.expiresAt) or 0) > now then kept[#kept + 1] = effect end
    end
    player.activeEffects = kept
    return kept
end

function BuffSystem:snapshot(entity)
    self:ensureEntity(entity)
    local now = math.floor(tonumber(self.time()) or os.time())
    local active = self:tick(entity)
    local out = {}
    for _, effect in ipairs(active) do
        local copy = {}
        for k, v in pairs(effect) do copy[k] = v end
        copy.elapsedDuration = math.max(0, now - (tonumber(copy.appliedAt) or now))
        copy.remainingDuration = math.max(0, (tonumber(copy.expiresAt) or now) - now)
        out[#out + 1] = copy
    end
    table.sort(out, function(a, b)
        local aExpiry = tonumber(a.expiresAt) or 0
        local bExpiry = tonumber(b.expiresAt) or 0
        if aExpiry == bExpiry then return tostring(a.kind or '') < tostring(b.kind or '') end
        return aExpiry < bExpiry
    end)
    return out
end

return BuffSystem
