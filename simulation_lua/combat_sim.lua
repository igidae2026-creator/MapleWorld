local DamageFormula = require('shared_rules.damage_formula')

local CombatSim = {}

local function sample_profiles(content)
    local skills = content.content.skills or {}
    return {
        {
            derived = { attack = 84, magic = 12 },
            skill = assert(skills.warrior and skills.warrior[1], 'missing warrior skill'),
            target = { defense = 14, evasion = 0.08 },
        },
        {
            derived = { attack = 62, magic = 96 },
            skill = assert(skills.magician and skills.magician[1], 'missing magician skill'),
            target = { defense = 11, evasion = 0.12 },
        },
        {
            derived = { attack = 91, magic = 18 },
            skill = assert(skills.thief and skills.thief[1], 'missing thief skill'),
            target = { defense = 16, evasion = 0.15 },
        },
    }
end

function CombatSim.run(content)
    local profiles = sample_profiles(content)
    local totalDamage = 0
    local totalHits = 0
    local totalCrits = 0
    local totalAttempts = 0

    for profileIndex, profile in ipairs(profiles) do
        for iteration = 1, 24 do
            local critical = ((iteration + profileIndex) % 2) == 0
            local hitRoll = (((iteration * 13) + (profileIndex * 7)) % 100) / 100
            local result = DamageFormula.resolve({
                derived = profile.derived,
                skill = profile.skill,
                target = profile.target,
                targetState = profile.target,
                critical = critical,
                hitRoll = hitRoll,
            })
            totalAttempts = totalAttempts + 1
            totalDamage = totalDamage + (result.amount or 0)
            if not result.evaded then
                totalHits = totalHits + 1
            end
            if result.isCritical then
                totalCrits = totalCrits + 1
            end
        end
    end

    return {
        avg_damage = totalDamage / math.max(1, totalAttempts),
        crit_rate_observed = totalCrits / math.max(1, totalAttempts),
        hit_rate_observed = totalHits / math.max(1, totalAttempts),
    }
end

return CombatSim
