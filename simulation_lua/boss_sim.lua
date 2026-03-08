local BossMechanicsSystem = require('shared_rules.boss_mechanics_system')

local BossSim = {}
local CLEAR_TIME_TARGET = 270

local function sorted_bosses(content)
    local bosses = {}
    for bossId, boss in pairs(content.content.bosses or {}) do
        bosses[#bosses + 1] = { boss_id = bossId, hp = boss.hp, mechanics = boss.mechanics or {} }
    end
    table.sort(bosses, function(a, b) return a.boss_id < b.boss_id end)
    return bosses
end

function BossSim.run(content)
    local mechanics = BossMechanicsSystem.new()
    local bosses = sorted_bosses(content)
    local totalTime = 0
    local clears = 0
    local failures = 0

    for index = 1, math.min(#bosses, 4) do
        local boss = bosses[index]
        local maxHp = tonumber(boss.hp) or 1
        local pressure = #boss.mechanics
        local encounter = {
            hp = maxHp * (0.72 - (index * 0.08)),
            maxHp = maxHp,
            currentMechanic = boss.mechanics[math.min(pressure, 1)] or {},
        }
        local phase = mechanics:phase(encounter)
        local clearTime = 150 + (pressure * 18) + (phase * 22) + (index * 7)
        totalTime = totalTime + clearTime
        if clearTime <= CLEAR_TIME_TARGET then
            clears = clears + 1
        else
            failures = failures + 1
        end
    end

    local attempts = math.max(1, clears + failures)
    return {
        avg_time_to_clear = totalTime / attempts,
        clear_rate = clears / attempts,
        failure_rate = failures / attempts,
    }
end

return BossSim
