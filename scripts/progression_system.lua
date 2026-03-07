local ProgressionSystem = {}

function ProgressionSystem.new(config)
    local self = {
        jobSystem = (config or {}).jobSystem,
        statSystem = (config or {}).statSystem,
        inventoryExpansion = (config or {}).inventoryExpansion,
    }
    setmetatable(self, { __index = ProgressionSystem })
    return self
end

function ProgressionSystem:ensurePlayer(player)
    player.progression = player.progression or {
        milestones = {},
        mastery = 0,
        prestige = 0,
        prestigePoints = 0,
        specialization = 'generalist',
        archetype = 'adventurer',
        raidTier = 0,
        synergy = {},
    }
    return player
end

function ProgressionSystem:refresh(player)
    self:ensurePlayer(player)
    local allocated = ((player.statProfile or {}).allocated) or {}
    local highestStat, highestValue = 'str', -1
    for _, stat in ipairs({ 'str', 'dex', 'int', 'luk' }) do
        local value = tonumber(allocated[stat]) or 0
        if value > highestValue then
            highestStat, highestValue = stat, value
        end
    end
    player.progression.specialization = ({
        str = 'bruiser',
        dex = 'precision',
        int = 'channeler',
        luk = 'trickster',
    })[highestStat] or 'generalist'
    player.progression.archetype = ({
        warrior = 'frontline',
        magician = 'support_caster',
        bowman = 'ranged_damage',
        thief = 'burst_skirmisher',
        pirate = 'hybrid_raider',
    })[player.jobId or 'beginner'] or 'adventurer'
    return player.progression
end

function ProgressionSystem:onLevelUp(player)
    self:refresh(player)
    player.ap = (tonumber(player.ap) or 0) + 5
    player.sp = (tonumber(player.sp) or 0) + 3
    player.progression.mastery = (tonumber(player.progression.mastery) or 0) + 1
    if (tonumber(player.level) or 1) % 20 == 0 then
        self.inventoryExpansion:expand(player, 4)
        player.progression.milestones['level_' .. tostring(player.level)] = true
    end
    if (tonumber(player.level) or 1) >= 100 and ((tonumber(player.level) or 1) % 10 == 0) then
        player.progression.prestige = (tonumber(player.progression.prestige) or 0) + 1
        player.progression.prestigePoints = (tonumber(player.progression.prestigePoints) or 0) + 1
        player.progression.raidTier = math.max(tonumber(player.progression.raidTier) or 0, math.floor((tonumber(player.level) or 1) / 20))
    end
    player.dirty = true
    return true
end

function ProgressionSystem:grantRaidProgress(player, amount)
    self:refresh(player)
    local value = math.max(1, math.floor(tonumber(amount) or 1))
    player.progression.raidTier = (tonumber(player.progression.raidTier) or 0) + value
    player.progression.milestones['raid_tier_' .. tostring(player.progression.raidTier)] = true
    player.dirty = true
    return player.progression.raidTier
end

return ProgressionSystem
