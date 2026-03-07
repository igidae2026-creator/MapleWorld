local EquipmentProgression = {}

function EquipmentProgression.new(config)
    local self = { itemSystem = (config or {}).itemSystem }
    setmetatable(self, { __index = EquipmentProgression })
    return self
end

function EquipmentProgression:enhance(player, slot)
    local equipped = player and player.equipment and player.equipment[slot] or nil
    if not equipped then return false, 'slot_empty' end
    equipped.enhancement = (tonumber(equipped.enhancement) or 0) + 1
    player.dirty = true
    player.version = (tonumber(player.version) or 0) + 1
    return true, equipped.enhancement
end

return EquipmentProgression
