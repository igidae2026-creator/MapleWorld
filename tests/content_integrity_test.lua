package.path = package.path .. ';./?.lua;../?.lua'

local ContentLoader = require('content_build.content_loader')
local ContentValidation = require('content_build.content_validation')
local ContentRegistry = require('content_build.content_registry')

local bundle = ContentLoader.load({ forceReload = true })
assert(bundle.validation.ok, table.concat(bundle.validation.errors, '\n'))
local directValidation = ContentValidation.validate(ContentRegistry)
assert(directValidation.ok, table.concat(directValidation.errors, '\n'))
assert(bundle.index.counts.maps >= 20, 'expected broad map coverage')
assert(bundle.index.counts.items >= 50, 'expected broad item coverage')
assert(bundle.index.counts.quests >= 20, 'expected broad quest coverage')
assert(bundle.index.skillsById.power_strike ~= nil, 'expected indexed skills')
assert(bundle.regionalProgression.desert ~= nil, 'expected regional progression tables')
assert(bundle.rareSpawns.desert_fields ~= nil, 'expected rare spawn table coverage')
assert(bundle.index.mapsByRole['boss prep'] ~= nil and #bundle.index.mapsByRole['boss prep'] >= 6, 'expected boss route indexing')
print('content_integrity_test: ok')
