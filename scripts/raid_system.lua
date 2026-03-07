local RaidSystem = {}

function RaidSystem.new()
    return setmetatable({ raids = {}, nextId = 1 }, { __index = RaidSystem })
end

function RaidSystem:create(bossId, leader, partyId)
    local id = 'raid-' .. tostring(self.nextId)
    self.nextId = self.nextId + 1
    self.raids[id] = {
        id = id,
        bossId = bossId,
        leaderId = leader.id,
        partyId = partyId,
        members = { [leader.id] = true },
        startedAt = os.time(),
        phase = 'forming',
        coordination = { marks = {}, objectives = { 'survive_opening', 'handle_telegraph', 'secure_burst_window' } },
        rewardTier = 1,
    }
    return self.raids[id]
end

function RaidSystem:join(raidId, player)
    local raid = self.raids[raidId]
    if not raid then return false, 'raid_not_found' end
    raid.members[player.id] = true
    return true
end

function RaidSystem:syncWithParty(raidId, world)
    local raid = self.raids[raidId]
    if not raid then return false, 'raid_not_found' end
    local party = raid.partyId and world.partySystem.parties[raid.partyId] or nil
    if party then
        for memberId in pairs(party.members or {}) do raid.members[memberId] = true end
        raid.phase = 'ready'
        raid.rewardTier = math.max(1, math.floor((world.partySystem:refreshSynergy(raid.partyId, world) and 2) or 1))
    end
    return true, raid
end

function RaidSystem:complete(raidId, world)
    local raid = self.raids[raidId]
    if not raid then return false, 'raid_not_found' end
    raid.phase = 'cleared'
    raid.clearedAt = os.time()
    for memberId in pairs(raid.members or {}) do
        local player = world.players[memberId]
        if player then
            player.raidProgress = player.raidProgress or { clears = 0, rewardTier = 0 }
            player.raidProgress.clears = player.raidProgress.clears + 1
            player.raidProgress.rewardTier = math.max(player.raidProgress.rewardTier, raid.rewardTier)
        end
    end
    return true, raid
end

return RaidSystem
