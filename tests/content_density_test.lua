package.path = package.path .. ';./?.lua;../?.lua'

local ContentLoader = require('data.content_loader')

local bundle = ContentLoader.load({ forceReload = true })
local counts = bundle.index.counts

assert(counts.maps >= 30, 'expected expanded map count')
assert(counts.mobs >= 40, 'expected expanded mob count')
assert(counts.bosses >= 12, 'expected expanded boss count')
assert(counts.items >= 80, 'expected expanded item count')
assert(counts.quests >= 35, 'expected expanded quest count')
assert(bundle.content.events.seasonal.lantern_festival ~= nil, 'seasonal event missing')
assert(bundle.content.events.invasion.shadow_breach ~= nil, 'invasion event missing')
assert(bundle.content.events.world_boss.clockwork_colossus ~= nil, 'world boss event missing')
print('content_density_test: ok')
