local CraftingSystem = {}

function CraftingSystem.new(config)
    local self = {
        itemSystem = (config or {}).itemSystem,
    }
    setmetatable(self, { __index = CraftingSystem })
    return self
end

function CraftingSystem:craft(player, recipe)
    for _, ingredient in ipairs(recipe.ingredients or {}) do
        local ok = self.itemSystem:removeItem(player, ingredient.itemId, ingredient.quantity, nil, { source = 'crafting' })
        if not ok then return false, 'missing_ingredient' end
    end
    return self.itemSystem:addItem(player, recipe.result.itemId, recipe.result.quantity or 1, nil, { source = 'crafting' })
end

return CraftingSystem
