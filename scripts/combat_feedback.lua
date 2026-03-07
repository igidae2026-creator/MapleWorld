local CombatFeedback = {}

function CombatFeedback.new()
    return setmetatable({}, { __index = CombatFeedback })
end

function CombatFeedback:skillCast(player, skill, result)
    return {
        actorId = player.id,
        skillId = skill.id,
        role = skill.role or 'damage',
        visual = skill.visual or 'default_arc',
        sfx = skill.sfx or 'skill_hit',
        result = result,
    }
end

function CombatFeedback:lootDrop(drop)
    return {
        itemId = drop.itemId,
        rarity = drop.rarity,
        anticipation = drop.anticipation,
        excitement = drop.excitement,
        beam = ({
            common = 'white',
            uncommon = 'green',
            rare = 'blue',
            epic = 'gold',
        })[drop.rarity or 'common'] or 'white',
    }
end

return CombatFeedback
