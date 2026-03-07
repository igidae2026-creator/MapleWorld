package.path = package.path .. ';./?.lua;../?.lua'

local ContentLoader = require('data.content_loader')

local bundle = ContentLoader.load({ forceReload = true })
local counts = bundle.index.counts

assert(counts.maps >= 120, 'expected expanded map count')
assert(counts.mobs >= 200, 'expected expanded mob count')
assert(counts.bosses >= 40, 'expected expanded boss count')
assert(counts.items >= 1200, 'expected expanded item count')
assert(counts.quests >= 300, 'expected expanded quest count')
assert(counts.dialogues >= 150, 'expected expanded dialogue count')
assert(bundle.content.events.seasonal.lantern_festival ~= nil, 'seasonal event missing')
assert(bundle.content.events.invasion.shadow_breach ~= nil, 'invasion event missing')
assert(bundle.content.events.world_boss.clockwork_colossus ~= nil, 'world boss event missing')
assert(bundle.content.maps.henesys_fields.chokePoints ~= nil, 'map tactical metadata missing')
assert(bundle.content.items.desert_bronze_blade ~= nil and bundle.content.items.desert_bronze_blade.dopamineTier ~= nil, 'item dopamine metadata missing')
print('content_density_test: ok')
