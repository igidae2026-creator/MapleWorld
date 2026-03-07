local StatSystem = {}

local function floor(value, fallback)
    return math.floor(tonumber(value) or fallback or 0)
end

function StatSystem.new(config)
    local cfg = config or {}
    local self = {
        jobs = cfg.jobs or {},
        metrics = cfg.metrics,
    }
    setmetatable(self, { __index = StatSystem })
    return self
end

function StatSystem:ensurePlayer(player)
    player.ap = floor(player.ap, 0)
    player.sp = floor(player.sp, 0)
    player.jobId = player.jobId or 'beginner'
    player.statProfile = player.statProfile or { allocated = { str = 0, dex = 0, int = 0, luk = 0 } }
    return player
end

function StatSystem:allocate(player, stat, amount)
    self:ensurePlayer(player)
    amount = floor(amount, 0)
    if amount <= 0 or player.ap < amount then return false, 'insufficient_ap' end
    if not player.stats[stat] then return false, 'unknown_stat' end
    player.stats[stat] = floor(player.stats[stat], 4) + amount
    player.ap = player.ap - amount
    player.statProfile.allocated[stat] = floor(player.statProfile.allocated[stat], 0) + amount
    player.version = floor(player.version, 0) + 1
    player.dirty = true
    return true
end

function StatSystem:derived(player, itemSystem, buffs)
    self:ensurePlayer(player)
    local stats = player.stats or {}
    local equipmentPower = itemSystem and itemSystem:getPower(player) or 0
    local buffAttack = 0
    local buffDefense = 0
    for _, effect in ipairs(buffs or {}) do
        if effect.stat == 'attack' then buffAttack = buffAttack + floor(effect.amount, 0) end
        if effect.stat == 'defense' then buffDefense = buffDefense + floor(effect.amount, 0) end
    end
    return {
        attack = floor(stats.str, 4) + math.floor(floor(stats.dex, 4) * 0.4) + equipmentPower + buffAttack,
        magic = floor(stats.int, 4) * 2 + math.floor(floor(stats.luk, 4) * 0.3) + buffAttack,
        defense = floor(stats.dex, 4) + floor(stats.luk, 4) + buffDefense + math.floor(equipmentPower * 0.2),
        maxHp = floor(stats.hp, 50) + (floor(player.level, 1) * 8),
        maxMp = floor(stats.mp, 25) + (floor(player.level, 1) * 4),
    }
end

return StatSystem
