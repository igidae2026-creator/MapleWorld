local AntiAbuseHooks = {}

function AntiAbuseHooks.new()
    return setmetatable({ flags = {} }, { __index = AntiAbuseHooks })
end

function AntiAbuseHooks:observe(player, action, magnitude)
    local key = tostring(player and player.id or 'system') .. ':' .. tostring(action)
    self.flags[key] = (self.flags[key] or 0) + math.max(1, math.floor(tonumber(magnitude) or 1))
    return self.flags[key]
end

return AntiAbuseHooks
