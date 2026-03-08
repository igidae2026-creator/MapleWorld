local forbiddenPublicMethods = {
    GetEconomyReport = true,
    AdminStatus = true,
    getEconomyReport = true,
    adminStatus = true,
}

local serverMethods = {
    'GetPlayerState',
    'GetMapState',
    'GetStateDelta',
    'DispatchRuntimeEvent',
    'RoutePlayerAction',
    'GetEventStream',
    'AttackMob',
    'PickupDrop',
    'DamageBoss',
    'AcceptQuest',
    'TurnInQuest',
    'BuyFromNpc',
    'SellToNpc',
    'EquipItem',
    'UnequipItem',
    'ChangeMap',
    'AllocateStat',
    'PromoteJob',
    'LearnSkill',
    'CastSkill',
    'EnhanceEquipment',
    'CreateParty',
    'CreateGuild',
    'AddFriend',
    'TradeMesos',
    'ListAuction',
    'CraftItem',
    'OpenDialogue',
    'ChannelTransfer',
    'GetRuntimeStatus',
    'GetBuildRecommendation',
    'GetTutorialState',
    'ListPartyFinder',
    'CreateRaid',
}

for _, methodName in ipairs(serverMethods) do
    assert(forbiddenPublicMethods[methodName] == nil, 'forbidden_manifest_server_method_' .. tostring(methodName))
end

return {
    singleton = {
        script = 'msw_runtime/entry/world_server_entry',
        module = 'msw_runtime/entry/world_server_component',
        attachTo = '/server_runtime',
        runtimeContract = {
            worldScope = 'msw_gameplay_runtime',
            ownership = 'gameplay_only',
            lifecycle = { 'bootstrap', 'tick', 'player_enter', 'player_leave' },
            bindings = { 'player', 'map', 'inventory', 'quest', 'combat' },
            sync = { 'server_authoritative_mutation' },
        },
        attachToAliases = {
            'server_runtime',
            'common/server_runtime',
        },
        events = {
            { scope = 'Service', target = 'UserService', eventName = 'UserEnterEvent' },
            { scope = 'Service', target = 'UserService', eventName = 'UserLeaveEvent' },
        },
    },
    serverMethods = serverMethods,
}
