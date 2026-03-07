local DuplicationGuard = {}

function DuplicationGuard.new()
    return setmetatable({ incidents = {}, recentClaims = {} }, { __index = DuplicationGuard })
end

function DuplicationGuard:recordClaim(key)
    key = tostring(key or 'unknown')
    self.recentClaims[key] = (self.recentClaims[key] or 0) + 1
    return self.recentClaims[key]
end

function DuplicationGuard:inspect(world)
    local issues = {}
    local duplicateInstances = {}
    local ownersByInstance = {}

    for playerId, player in pairs((world and world.players) or {}) do
        local ok, err = world.itemSystem:validatePlayerItemTopology(player)
        if not ok then issues[#issues + 1] = 'player_topology:' .. tostring(playerId) .. ':' .. tostring(err) end

        for itemId, entry in pairs((player and player.inventory) or {}) do
            for _, instance in ipairs((entry and entry.instances) or {}) do
                local owner = ownersByInstance[instance.instanceId]
                local nextOwner = 'inventory:' .. tostring(playerId) .. ':' .. tostring(itemId)
                if owner and owner ~= nextOwner then
                    duplicateInstances[#duplicateInstances + 1] = tostring(instance.instanceId)
                    issues[#issues + 1] = 'duplicate_instance:' .. tostring(instance.instanceId)
                end
                ownersByInstance[instance.instanceId] = nextOwner
            end
        end

        for slot, equipped in pairs((player and player.equipment) or {}) do
            if equipped and equipped.instanceId then
                local owner = ownersByInstance[equipped.instanceId]
                local nextOwner = 'equipment:' .. tostring(playerId) .. ':' .. tostring(slot)
                if owner and owner ~= nextOwner then
                    duplicateInstances[#duplicateInstances + 1] = tostring(equipped.instanceId)
                    issues[#issues + 1] = 'duplicate_instance:' .. tostring(equipped.instanceId)
                end
                ownersByInstance[equipped.instanceId] = nextOwner
            end
        end
    end

    for claimKey, count in pairs(self.recentClaims or {}) do
        if count > 1 then
            issues[#issues + 1] = 'duplicate_claim:' .. tostring(claimKey)
        end
    end

    local report = {
        ok = #issues == 0,
        issues = issues,
        duplicateRisk = world.pressure and world.pressure.duplicateRiskPressure or 0,
        duplicateInstances = duplicateInstances,
        claimHotspots = self.recentClaims,
    }
    self.incidents[#self.incidents + 1] = report
    while #self.incidents > 32 do table.remove(self.incidents, 1) end
    return report
end

return DuplicationGuard
