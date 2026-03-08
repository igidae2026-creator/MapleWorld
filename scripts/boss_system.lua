local BossSystem = {}

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

function BossSystem.new(config)
    local cfg = config or {}
    local self = {
        bossTable = cfg.bossTable or {},
        dropSystem = cfg.dropSystem,
        logger = cfg.logger,
        metrics = cfg.metrics,
        encounters = {},
        cooldowns = {},
        time = cfg.time or os.time,
    }
    setmetatable(self, { __index = BossSystem })
    return self
end

function BossSystem:_eligibleContributors(encounter, killerId)
    local contributions = encounter and encounter.contributors or {}
    local totalDamage = 0
    local out = {}
    for _, damage in pairs(contributions) do
        totalDamage = totalDamage + math.max(0, math.floor(tonumber(damage) or 0))
    end
    local threshold = math.max(1, math.floor((tonumber(encounter and encounter.maxHp) or 1) * 0.05))
    for playerId, damage in pairs(contributions) do
        if math.max(0, math.floor(tonumber(damage) or 0)) >= threshold then
            out[#out + 1] = tostring(playerId)
        end
    end
    if killerId ~= nil then
        local normalizedKillerId = tostring(killerId)
        local seen = false
        for _, playerId in ipairs(out) do
            if playerId == normalizedKillerId then
                seen = true
                break
            end
        end
        if not seen and contributions[normalizedKillerId] ~= nil then
            out[#out + 1] = normalizedKillerId
        end
    end
    table.sort(out)
    return out, totalDamage, threshold
end

function BossSystem:_now()
    return math.floor(tonumber(self.time()) or os.time())
end

function BossSystem:canSpawn(bossId, mapId)
    local def = self.bossTable[bossId]
    if not def then return false, 'unknown_boss' end
    if def.mapId and def.mapId ~= mapId then return false, 'invalid_map' end

    local encounter = self.encounters[mapId]
    if encounter and encounter.alive then return false, 'encounter_active' end

    local now = self:_now()
    local readyAt = tonumber(self.cooldowns[mapId]) or 0
    if readyAt <= now then
        self.cooldowns[mapId] = nil
        readyAt = 0
    end
    if readyAt > now then return false, 'cooldown_active', readyAt - now end

    return true
end

function BossSystem:spawnEncounter(bossId, mapId)
    local ok, err, remaining = self:canSpawn(bossId, mapId)
    if not ok then return false, err, remaining end

    local def = self.bossTable[bossId]
    local encounter = {
        bossId = bossId,
        mapId = mapId,
        hp = def.hp,
        maxHp = def.hp,
        phase = 1,
        alive = true,
        enraged = false,
        resolved = false,
        mechanics = deepcopy(def.mechanics or {
            [1] = { pattern = 'summon_wave', hazard = 'frontal_slam' },
            [2] = { pattern = 'arena_pulse', hazard = 'meteor_lane' },
            [3] = { pattern = 'desperation', hazard = 'mapwide_burst' },
        }),
        raid = def.raid == true,
        triggeredAt = self:_now(),
        updatedAt = self:_now(),
        contributors = {},
        position = deepcopy(def.position),
        uniqueness = def.uniqueness or 'channel_unique',
        telegraphState = {
            pattern = (def.mechanics and def.mechanics[1] and def.mechanics[1].pattern) or 'opening_read',
            text = (def.mechanics and def.mechanics[1] and def.mechanics[1].text) or 'Read the opening pattern.',
            punishWindow = (def.mechanics and def.mechanics[1] and def.mechanics[1].punishWindow) or 'short',
        },
    }
    encounter.currentMechanic = encounter.mechanics[1]
    self.encounters[mapId] = encounter
    if self.metrics then self.metrics:increment('boss.spawn', 1, { boss = bossId, map = mapId }) end
    if self.logger and self.logger.info then self.logger:info('boss_spawned', { bossId = bossId, mapId = mapId }) end
    return encounter
end

function BossSystem:getEncounter(mapId)
    local encounter = self.encounters[mapId]
    if encounter and encounter.alive then return encounter end
    return nil
end

function BossSystem:shouldAutoSpawn(world, bossId, def)
    local ok = self:canSpawn(bossId, def.mapId)
    if not ok then return false end

    if def.trigger == 'channel_presence' then
        return world and world:getMapPopulation(def.mapId) > 0
    end
    if def.trigger == 'scheduled_window' then
        return world and world:getActivePlayerCount() > 0
    end
    return world and world:getActivePlayerCount() > 0
end

function BossSystem:tick(world)
    local spawned = 0
    for bossId, def in pairs(self.bossTable) do
        if self:shouldAutoSpawn(world, bossId, def) then
            local encounter = self:spawnEncounter(bossId, def.mapId)
            if type(encounter) == 'table' then spawned = spawned + 1 end
        end
    end
    return spawned
end

function BossSystem:damage(mapId, player, amount)
    local damage = math.floor(tonumber(amount) or 0)
    if damage <= 0 then return false, 'invalid_amount' end

    local encounter = self.encounters[mapId]
    if not encounter or not encounter.alive or encounter.resolved then return false, 'no_active_encounter' end

    encounter.hp = math.max(0, encounter.hp - damage)
    encounter.updatedAt = self:_now()
    if player and player.id then
        encounter.contributors[player.id] = (encounter.contributors[player.id] or 0) + damage
    end

    local ratio = encounter.hp / math.max(1, encounter.maxHp)
    if ratio <= 0.7 and encounter.phase < 2 then
        encounter.phase = 2
        encounter.currentMechanic = encounter.mechanics[2]
        encounter.telegraphState = {
            pattern = encounter.currentMechanic.pattern,
            text = encounter.currentMechanic.text,
            punishWindow = encounter.currentMechanic.punishWindow or 'medium',
        }
    end
    if ratio <= 0.35 and encounter.phase < 3 then
        encounter.phase = 3
        encounter.currentMechanic = encounter.mechanics[3]
        encounter.telegraphState = {
            pattern = encounter.currentMechanic.pattern,
            text = encounter.currentMechanic.text,
            punishWindow = encounter.currentMechanic.punishWindow or 'short',
        }
    end
    if encounter.hp <= encounter.maxHp * 0.4 and not encounter.enraged then
        encounter.enraged = true
        encounter.currentMechanic = encounter.mechanics[encounter.phase]
        encounter.telegraphState = {
            pattern = encounter.currentMechanic.pattern,
            text = encounter.currentMechanic.text,
            punishWindow = 'tight',
        }
        if self.metrics then self.metrics:increment('boss.enrage', 1, { boss = encounter.bossId }) end
    end

    if encounter.hp == 0 then
        encounter.alive = false
        encounter.resolved = true
        encounter.killedAt = self:_now()
        encounter.killedBy = player and player.id or nil

        local def = self.bossTable[encounter.bossId] or {}
        self.cooldowns[mapId] = encounter.killedAt + (def.cooldownSec or 0)

        local position = encounter.position or { x = 0, y = 0, z = 0 }
        local bossLikeMob = { mobId = encounter.bossId, x = position.x or 0, y = position.y or 0, z = position.z or 0, mapId = mapId }
        local eligibleContributors, totalDamage, threshold = self:_eligibleContributors(encounter, encounter.killedBy)
        local rewardBundles = {}
        if self.dropSystem then
            for _, contributorId in ipairs(eligibleContributors) do
                rewardBundles[#rewardBundles + 1] = {
                    playerId = contributorId,
                    drops = self.dropSystem:rollDrops(bossLikeMob, { id = contributorId }),
                }
            end
        end
        encounter.rewardDistribution = {
            eligibleContributors = deepcopy(eligibleContributors),
            minimumDamage = threshold,
            totalDamage = totalDamage,
        }
        if self.metrics then self.metrics:increment('boss.kill', 1, { boss = encounter.bossId }) end
        if self.logger and self.logger.info then self.logger:info('boss_killed', { bossId = encounter.bossId, playerId = player and player.id or nil }) end
        encounter.currentMechanic = encounter.mechanics[encounter.phase]
        return true, rewardBundles, encounter
    end
    encounter.currentMechanic = encounter.mechanics[encounter.phase]
    return true, nil, encounter
end

function BossSystem:snapshot()
    return {
        cooldowns = deepcopy(self.cooldowns),
        encounters = deepcopy(self.encounters),
    }
end

function BossSystem:restore(snapshot)
    self.cooldowns = {}
    self.encounters = {}
    local now = self:_now()

    for mapId, readyAt in pairs((snapshot and snapshot.cooldowns) or {}) do
        local when = math.floor(tonumber(readyAt) or 0)
        if when > now then self.cooldowns[mapId] = when end
    end

    for mapId, encounter in pairs((snapshot and snapshot.encounters) or {}) do
        if type(encounter) == 'table' then
            local def = self.bossTable[encounter.bossId]
            local restored = deepcopy(encounter)
            restored.mapId = restored.mapId or mapId
            restored.maxHp = math.max(1, math.floor(tonumber(restored.maxHp) or tonumber(def and def.hp) or 1))
            restored.hp = math.max(0, math.floor(tonumber(restored.hp) or restored.maxHp))
            restored.phase = math.max(1, math.floor(tonumber(restored.phase) or 1))
            restored.enraged = restored.enraged == true
            restored.resolved = restored.resolved == true or restored.hp <= 0
            restored.alive = restored.alive == true and not restored.resolved and restored.hp > 0
            restored.contributors = type(restored.contributors) == 'table' and restored.contributors or {}
            restored.updatedAt = math.floor(tonumber(restored.updatedAt) or now)
            if restored.alive and def and restored.mapId == mapId then
                self.encounters[mapId] = restored
            end
        end
    end
end

return BossSystem
