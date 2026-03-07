local SocialSystem = {}

function SocialSystem.new()
    return setmetatable({}, { __index = SocialSystem })
end

function SocialSystem:ensurePlayer(player)
    player.social = player.social or { friends = {}, blocked = {}, notes = {} }
    return player
end

function SocialSystem:addFriend(player, otherId)
    self:ensurePlayer(player)
    player.social.friends[otherId] = true
    return true
end

return SocialSystem
