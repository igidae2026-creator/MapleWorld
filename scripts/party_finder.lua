local PartyFinder = {}

function PartyFinder.new()
    return setmetatable({ listings = {}, nextId = 1 }, { __index = PartyFinder })
end

function PartyFinder:list(player, detail)
    local id = 'lfg-' .. tostring(self.nextId)
    self.nextId = self.nextId + 1
    self.listings[id] = {
        id = id,
        playerId = player.id,
        mapId = player.currentMapId,
        role = detail and detail.role or 'open',
        objective = detail and detail.objective or 'questing',
        minLevel = detail and detail.minLevel or 1,
    }
    return self.listings[id]
end

function PartyFinder:find(filter)
    local out = {}
    for _, listing in pairs(self.listings) do
        if not filter or filter.mapId == nil or listing.mapId == filter.mapId then
            out[#out + 1] = listing
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

return PartyFinder
