package.path = package.path .. ';./?.lua;../?.lua'

local ContentLoader = require('data.content_loader')

local bundle = ContentLoader.load({ forceReload = true })
assert(bundle.validation.ok, table.concat(bundle.validation.errors, '\n'))
assert(bundle.index.counts.maps >= 20, 'expected broad map coverage')
assert(bundle.index.counts.items >= 50, 'expected broad item coverage')
assert(bundle.index.counts.quests >= 20, 'expected broad quest coverage')
assert(bundle.index.skillsById.power_strike ~= nil, 'expected indexed skills')
print('content_integrity_test: ok')
