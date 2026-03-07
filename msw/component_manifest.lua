return {
    singleton = {
        script = 'msw/world_server_entry',
        module = 'msw/world_server_component',
        bridge = 'msw/world_server_bridge',
        attachTo = '/server_runtime',
        attachToAliases = {
            'server_runtime',
            'common/server_runtime',
        },
        events = {
            { scope = 'Service', target = 'UserService', eventName = 'UserEnterEvent' },
            { scope = 'Service', target = 'UserService', eventName = 'UserLeaveEvent' },
        },
    },
    serverMethods = {
        'GetPlayerState',
        'GetMapState',
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
    },
}
