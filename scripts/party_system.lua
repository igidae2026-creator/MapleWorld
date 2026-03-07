local PartySystem = {}

function PartySystem.new()
    return setmetatable({ parties = {}, nextId = 1, finder = {} }, { __index = PartySystem })
end

function PartySystem:create(leader)
    local id = 'party-' .. tostring(self.nextId)
    self.nextId = self.nextId + 1
    self.parties[id] = { id = id, leader = leader.id, members = { [leader.id] = true }, lootRule = 'round_robin', xpMode = 'shared' }
    leader.partyId = id
    return self.parties[id]
end

function PartySystem:join(player, partyId)
    local party = self.parties[partyId]
    if not party then return false, 'party_not_found' end
    party.members[player.id] = true
    player.partyId = partyId
    return true
end

function PartySystem:members(partyId, world)
    local party = self.parties[partyId]
    local out = {}
    for playerId in pairs(party and party.members or {}) do
        if world.players[playerId] then out[#out + 1] = world.players[playerId] end
    end
    return out
end

function PartySystem:shareRewards(world, sourcePlayer, expAmount, mesosAmount)
    local partyId = sourcePlayer and sourcePlayer.partyId
    if not partyId then return { sourcePlayer } end
    local members = self:members(partyId, world)
    local shareCount = math.max(1, #members)
    for _, member in ipairs(members) do
        world.expSystem:grant(member, math.max(1, math.floor((expAmount or 0) / shareCount)))
        world.economySystem:grantMesos(member, math.max(1, math.floor((mesosAmount or 0) / shareCount)), 'party_share')
    end
    return members
end

return PartySystem
