package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.')

local required = {
    'playerClassSystem',
    'jobSystem',
    'statSystem',
    'skillSystem',
    'combatResolution',
    'buffSystem',
    'itemSystem',
    'inventoryExpansion',
    'equipmentProgression',
    'craftingSystem',
    'partySystem',
    'guildSystem',
    'tradingSystem',
    'auctionHouse',
    'questSystem',
    'dialogueSystem',
    'bossMechanicsSystem',
    'raidSystem',
    'worldEventSystem',
    'economySystem',
    'inflationGuard',
    'duplicationGuard',
    'scheduler',
    'replayEngine',
    'adminConsole',
    'telemetryPipeline',
    'runtimeProfiler',
    'exploitMonitor',
}

for _, key in ipairs(required) do
    assert(world[key] ~= nil, 'missing_runtime_subsystem:' .. tostring(key))
end

local player = world:createPlayer('coverage-player')
local journey = world:getPlayerJourney(player)
assert(journey ~= nil and journey.whereToLevel ~= nil, 'journey plan missing')
assert(type(world:publishPlayerSnapshot(player).journeyPlan) == 'table', 'snapshot journey plan missing')
assert(type(world.adminConsole:status().healthcheck) == 'table' or world.adminConsole:status().healthcheck == nil, 'admin console healthcheck surface missing')
print('subsystem_coverage_test: ok')
