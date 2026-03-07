local PartySystem = {}

function PartySystem.new()
    return setmetatable({ parties = {}, nextId = 1, finder = {} }, { __index = PartySystem })
end

function PartySystem:create(leader)
    local id = 'party-' .. tostring(self.nextId)
    self.nextId = self.nextId + 1
    self.parties[id] = {
        id = id,
        leader = leader.id,
        members = { [leader.id] = true },
        lootRule = 'round_robin',
        xpMode = 'shared',
        synergy = { support = 0, frontline = 0, damage = 0, hybrid = 0 },
        raidReady = false,
    }
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

function PartySystem:refreshSynergy(partyId, world)
    local party = self.parties[partyId]
    if not party then return nil end
    party.synergy = { support = 0, frontline = 0, damage = 0, hybrid = 0 }
    for _, member in ipairs(self:members(partyId, world)) do
        local role = ((((member.classProfile or {}).buildFocus or {}).role) or (((member.progression or {}).archetype) or 'hybrid'))
        if role == 'support' then party.synergy.support = party.synergy.support + 1
        elseif role == 'tank' or role == 'frontline' then party.synergy.frontline = party.synergy.frontline + 1
        elseif role == 'damage' or role == 'ranged_damage' then party.synergy.damage = party.synergy.damage + 1
        else party.synergy.hybrid = party.synergy.hybrid + 1 end
    end
    party.raidReady = party.synergy.frontline >= 1 and party.synergy.damage >= 1 and (party.synergy.support >= 1 or party.synergy.hybrid >= 1)
    return party.synergy
end

function PartySystem:shareRewards(world, sourcePlayer, expAmount, mesosAmount)
    local partyId = sourcePlayer and sourcePlayer.partyId
    if not partyId then return { sourcePlayer } end
    local members = self:members(partyId, world)
    local shareCount = math.max(1, #members)
    local synergy = self:refreshSynergy(partyId, world) or {}
    local synergyBonus = 1.0 + math.min(0.35, ((synergy.support or 0) * 0.08) + ((synergy.frontline or 0) * 0.05) + ((synergy.damage or 0) * 0.04))
    for _, member in ipairs(members) do
        world.expSystem:grant(member, math.max(1, math.floor(((expAmount or 0) / shareCount) * synergyBonus)))
        world.economySystem:grantMesos(member, math.max(1, math.floor(((mesosAmount or 0) / shareCount) * math.min(1.2, synergyBonus))), 'party_share')
        member.partyBuffs = {
            synergyBonus = synergyBonus,
            support = synergy.support or 0,
            frontline = synergy.frontline or 0,
            damage = synergy.damage or 0,
        }
    end
    return members
end

return PartySystem
