local GuildSystem = {}

function GuildSystem.new()
    return setmetatable({ guilds = {}, nextId = 1 }, { __index = GuildSystem })
end

function GuildSystem:create(owner, name)
    local id = 'guild-' .. tostring(self.nextId)
    self.nextId = self.nextId + 1
    self.guilds[id] = { id = id, name = name, members = { [owner.id] = 'master' }, vault = 0, skills = {}, level = 1, xp = 0, benefits = { attack = 2, defense = 2 } }
    owner.guildId = id
    return self.guilds[id]
end

function GuildSystem:grantXp(guildId, amount)
    local guild = self.guilds[guildId]
    if not guild then return false, 'guild_not_found' end
    guild.xp = guild.xp + math.max(0, math.floor(tonumber(amount) or 0))
    while guild.xp >= guild.level * 1000 do
        guild.xp = guild.xp - (guild.level * 1000)
        guild.level = guild.level + 1
        guild.benefits.attack = guild.benefits.attack + 1
        guild.benefits.defense = guild.benefits.defense + 1
    end
    return true, guild
end

return GuildSystem
