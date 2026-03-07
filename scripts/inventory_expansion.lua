local InventoryExpansion = {}

function InventoryExpansion.new()
    return setmetatable({}, { __index = InventoryExpansion })
end

function InventoryExpansion:ensurePlayer(player)
    player.inventoryLimits = player.inventoryLimits or { slots = 48, storage = 24 }
    return player
end

function InventoryExpansion:expand(player, amount)
    self:ensurePlayer(player)
    amount = math.max(1, math.floor(tonumber(amount) or 1))
    player.inventoryLimits.slots = player.inventoryLimits.slots + amount
    player.dirty = true
    return player.inventoryLimits.slots
end

return InventoryExpansion
