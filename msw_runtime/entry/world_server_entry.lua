local Component = require('msw_runtime.entry.world_server_component')

local Entry = {}
local boundRuntimeComponent = nil
local forbiddenPublicMethods = {
    getEconomyReport = true,
    adminStatus = true,
}

local function bindRuntimeComponent(component)
    if component ~= nil then
        boundRuntimeComponent = component
    end
    return boundRuntimeComponent
end

local function dispatch(methodName, component, ...)
    return Component.dispatch(bindRuntimeComponent(component), methodName, ...)
end

--@ BeginMethod
--@ MethodExecSpace=ServerOnly
function OnBeginPlay(component)
    return dispatch('bootstrap', component)
end
--@ EndMethod
Entry.OnBeginPlay = OnBeginPlay

--@ BeginMethod
--@ MethodExecSpace=ServerOnly
function OnUpdate(delta, component)
    return dispatch('tick', component, delta)
end
--@ EndMethod
Entry.OnUpdate = OnUpdate

--@ BeginEntityEventHandler
--@ Scope=Service
--@ Target=UserService
--@ EventName=UserEnterEvent
function HandleUserEnterEvent(event, component)
    return dispatch('onUserEnter', component, event)
end
--@ EndEntityEventHandler
Entry.HandleUserEnterEvent = HandleUserEnterEvent

--@ BeginEntityEventHandler
--@ Scope=Service
--@ Target=UserService
--@ EventName=UserLeaveEvent
function HandleUserLeaveEvent(event, component)
    return dispatch('onUserLeave', component, event)
end
--@ EndEntityEventHandler
Entry.HandleUserLeaveEvent = HandleUserLeaveEvent

local routes = {
    GetPlayerState = 'getPlayerState',
    GetMapState = 'getMapState',
    GetStateDelta = 'getStateDelta',
    DispatchRuntimeEvent = 'dispatchRuntimeEvent',
    RoutePlayerAction = 'routePlayerAction',
    GetEventStream = 'getEventStream',
    AttackMob = 'attackMob',
    PickupDrop = 'pickupDrop',
    DamageBoss = 'damageBoss',
    AcceptQuest = 'acceptQuest',
    TurnInQuest = 'turnInQuest',
    BuyFromNpc = 'buyFromNpc',
    SellToNpc = 'sellToNpc',
    EquipItem = 'equipItem',
    UnequipItem = 'unequipItem',
    ChangeMap = 'changeMap',
    AllocateStat = 'allocateStat',
    PromoteJob = 'promoteJob',
    LearnSkill = 'learnSkill',
    CastSkill = 'castSkill',
    EnhanceEquipment = 'enhanceEquipment',
    CreateParty = 'createParty',
    CreateGuild = 'createGuild',
    AddFriend = 'addFriend',
    TradeMesos = 'tradeMesos',
    ListAuction = 'listAuction',
    CraftItem = 'craftItem',
    OpenDialogue = 'openDialogue',
    ChannelTransfer = 'channelTransfer',
    GetRuntimeStatus = 'getRuntimeStatus',
    GetBuildRecommendation = 'getBuildRecommendation',
    GetTutorialState = 'getTutorialState',
    ListPartyFinder = 'listPartyFinder',
    CreateRaid = 'createRaid',
}

for exportedName, methodName in pairs(routes) do
    assert(forbiddenPublicMethods[exportedName] == nil, 'forbidden_public_entry_export_' .. tostring(exportedName))
    assert(forbiddenPublicMethods[methodName] == nil, 'forbidden_public_entry_route_' .. tostring(methodName))
    local fn = function(...)
        local args = { ... }
        local component = args[#args]
        return dispatch(methodName, component, table.unpack(args, 1, #args - 1))
    end
    Entry[exportedName] = fn
    _G[exportedName] = fn
end

return Entry
