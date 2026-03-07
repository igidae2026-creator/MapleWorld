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

function BuffSystem:apply(player, effect)
    self:ensurePlayer(player)
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

function BuffSystem:tick(player)
    self:ensurePlayer(player)
    local now = math.floor(tonumber(self.time()) or os.time())
    local kept = {}
    for _, effect in ipairs(player.activeEffects) do
        if (tonumber(effect.expiresAt) or 0) > now then kept[#kept + 1] = effect end
    end
    player.activeEffects = kept
    return kept
end

return BuffSystem
