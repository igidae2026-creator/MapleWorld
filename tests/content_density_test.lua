package.path = package.path .. ';./?.lua;../?.lua'

local ContentLoader = require('content_build.content_loader')

local bundle = ContentLoader.load({ forceReload = true })
local counts = bundle.index.counts
local henesysQuestShapes = {}

for questId, quest in pairs(bundle.content.quests or {}) do
    if string.match(questId, '^henesys_story_0[1-6]$') then
        local parts = {}
        for _, objective in ipairs(quest.objectives or {}) do
            parts[#parts + 1] = tostring(objective.type)
        end
        henesysQuestShapes[table.concat(parts, '>')] = true
    end
end

local henesysShapeCount = 0
for _ in pairs(henesysQuestShapes) do
    henesysShapeCount = henesysShapeCount + 1
end

assert(counts.maps >= 120, 'expected expanded map count')
assert(counts.mobs >= 200, 'expected expanded mob count')
assert(counts.bosses >= 40, 'expected expanded boss count')
assert(counts.items >= 1200, 'expected expanded item count')
assert(counts.quests >= 300, 'expected expanded quest count')
assert(counts.dialogues >= 150, 'expected expanded dialogue count')
assert(henesysShapeCount >= 5, 'expected varied onboarding quest shapes in henesys 01-06 slice')
assert(bundle.content.events.seasonal.lantern_festival ~= nil, 'seasonal event missing')
assert(bundle.content.events.invasion.shadow_breach ~= nil, 'invasion event missing')
assert(bundle.content.events.world_boss.clockwork_colossus ~= nil, 'world boss event missing')
assert(bundle.content.maps.henesys_fields.chokePoints ~= nil, 'map tactical metadata missing')
assert(bundle.content.items.desert_bronze_blade ~= nil and bundle.content.items.desert_bronze_blade.dopamineTier ~= nil, 'item dopamine metadata missing')
print('content_density_test: ok')
