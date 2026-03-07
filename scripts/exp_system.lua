local ExpSystem = {}

local function markDirty(player)
    if not player then return end
    player.version = (tonumber(player.version) or 0) + 1
    player.dirty = true
end

function ExpSystem.new(config)
    local cfg = config or {}
    local self = {
        curve = cfg.curve or {},
        logger = cfg.logger,
        metrics = cfg.metrics,
        extrapolated = {},
        maxDefinedLevel = 0,
        maxDefinedExp = 0,
    }
    for level, required in pairs(self.curve) do
        local numericLevel = math.floor(tonumber(level) or 0)
        local numericRequired = math.max(1, math.floor(tonumber(required) or 0))
        if numericLevel > 0 and numericRequired > 0 then
            if numericLevel > self.maxDefinedLevel then
                self.maxDefinedLevel = numericLevel
                self.maxDefinedExp = numericRequired
            elseif numericLevel == self.maxDefinedLevel and numericRequired > self.maxDefinedExp then
                self.maxDefinedExp = numericRequired
            end
        end
    end
    setmetatable(self, { __index = ExpSystem })
    return self
end

function ExpSystem:requiredFor(level)
    local numericLevel = math.max(1, math.floor(tonumber(level) or 1))
    if self.curve[numericLevel] then return self.curve[numericLevel] end
    if self.extrapolated[numericLevel] then return self.extrapolated[numericLevel] end

    local maxLevel = math.max(1, self.maxDefinedLevel)
    local required = math.max(10, self.maxDefinedExp or 10)
    if numericLevel <= maxLevel then return required end

    for current = maxLevel + 1, numericLevel do
        local previous = self.curve[current - 1] or self.extrapolated[current - 1] or required
        local growth = 1.10 + math.min(0.10, math.max(0, current - maxLevel) * 0.0025)
        local nextValue = math.max(previous + 1, math.floor(previous * growth))
        self.extrapolated[current] = nextValue
        required = nextValue
    end
    return self.extrapolated[numericLevel]
end

function ExpSystem:grant(player, amount)
    local gain = math.floor(tonumber(amount) or 0)
    if not player then return false, 'invalid_player' end
    if gain <= 0 then return false, 'invalid_amount' end

    player.maxLevel = tonumber(player.maxLevel) or 200
    if player.level >= player.maxLevel then
        player.exp = 0
        markDirty(player)
        return false
    end

    player.exp = (tonumber(player.exp) or 0) + gain
    local leveled = false
    while player.level < player.maxLevel do
        local required = self:requiredFor(player.level)
        if player.exp < required then break end
        player.exp = player.exp - required
        player.level = player.level + 1
        player.stats.str = player.stats.str + 1
        player.stats.dex = player.stats.dex + 1
        player.stats.int = player.stats.int + 1
        player.stats.luk = player.stats.luk + 1
        player.stats.hp = player.stats.hp + 12
        player.stats.mp = player.stats.mp + 6
        leveled = true
        if self.metrics then self.metrics:increment('exp.level_up', 1, { level = player.level }) end
        if self.logger and self.logger.info then self.logger:info('player_level_up', { playerId = player.id, level = player.level }) end
    end

    if player.level >= player.maxLevel then player.exp = 0 end
    markDirty(player)
    if self.metrics then self.metrics:increment('exp.gained', gain, { player = tostring(player.id) }) end
    return leveled
end

return ExpSystem
