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
    }
    return self.raids[id]
end

function RaidSystem:join(raidId, player)
    local raid = self.raids[raidId]
    if not raid then return false, 'raid_not_found' end
    raid.members[player.id] = true
    return true
end

return RaidSystem
