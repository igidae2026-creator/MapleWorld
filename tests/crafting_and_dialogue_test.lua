package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')

local world = ServerBootstrap.boot('.')
local player = world:createPlayer('crafter')
world:grantItem(player, 'henesys_material_01', 2)
local craftOk = world:craftItem(player, 'bronze_reforge')
assert(craftOk, 'craft failed')
local dialogue = world:openDialogue('henesys_guide')
assert(dialogue and dialogue.nodes.start ~= nil, 'dialogue missing')
print('crafting_and_dialogue_test: ok')
