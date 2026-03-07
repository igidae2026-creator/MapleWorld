package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.')
local player = world:createPlayer('guide-player')
local snapshot = world:publishPlayerSnapshot(player)

assert(snapshot.tutorial ~= nil, 'tutorial guidance missing')
assert(snapshot.buildRecommendation ~= nil, 'build recommendation missing')
assert(snapshot.questGuidance ~= nil or snapshot.journeyPlan.nextObjective ~= nil, 'next objective guidance missing')
assert(snapshot.journeyPlan.gearFocus ~= nil, 'gear guidance missing')
assert(snapshot.journeyPlan.howToJoinGroupPlay ~= nil, 'party onboarding guidance missing')
assert(snapshot.journeyPlan.howToEarnCurrency ~= nil, 'economy onboarding guidance missing')
assert(snapshot.journeyPlan.howToFightBosses ~= nil, 'boss guidance missing')
print('player_experience_guidance_test: ok')
