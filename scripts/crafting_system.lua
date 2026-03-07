local CraftingSystem = {}

function CraftingSystem.new(config)
    local self = {
        itemSystem = (config or {}).itemSystem,
        recipes = (config or {}).recipes or {},
    }
    setmetatable(self, { __index = CraftingSystem })
    return self
end

function CraftingSystem:craft(player, recipe)
    player.craftingProfile = player.craftingProfile or { level = 1, mastery = 0, discoveries = {} }
    for _, ingredient in ipairs(recipe.ingredients or {}) do
        local ok = self.itemSystem:removeItem(player, ingredient.itemId, ingredient.quantity, nil, { source = 'crafting' })
        if not ok then return false, 'missing_ingredient' end
    end
    local crafted, err = self.itemSystem:addItem(player, recipe.result.itemId, recipe.result.quantity or 1, nil, { source = 'crafting' })
    if not crafted then return false, err end
    player.craftingProfile.mastery = player.craftingProfile.mastery + 1
    if player.craftingProfile.mastery % 5 == 0 then player.craftingProfile.level = player.craftingProfile.level + 1 end
    player.craftingProfile.discoveries[recipe.result.itemId] = true
    return true, {
        result = recipe.result.itemId,
        quantity = recipe.result.quantity or 1,
        mastery = player.craftingProfile.mastery,
        level = player.craftingProfile.level,
    }
end

return CraftingSystem
