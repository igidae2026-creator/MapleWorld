local Component = require('msw.world_server_component')

local Entry = {}

local function runtimeComponent()
    return rawget(_G, 'self')
end

local function dispatch(methodName, ...)
    return Component.dispatch(runtimeComponent(), methodName, ...)
end

--@ BeginMethod
--@ MethodExecSpace=ServerOnly
function OnBeginPlay()
    return dispatch('bootstrap')
end
--@ EndMethod
Entry.OnBeginPlay = OnBeginPlay

--@ BeginMethod
--@ MethodExecSpace=ServerOnly
function OnUpdate(delta)
    return dispatch('tick', delta)
end
--@ EndMethod
Entry.OnUpdate = OnUpdate

--@ BeginEntityEventHandler
--@ Scope=Service
--@ Target=UserService
--@ EventName=UserEnterEvent
function HandleUserEnterEvent(event)
    return dispatch('onUserEnter', event)
end
--@ EndEntityEventHandler
Entry.HandleUserEnterEvent = HandleUserEnterEvent

--@ BeginEntityEventHandler
--@ Scope=Service
--@ Target=UserService
--@ EventName=UserLeaveEvent
function HandleUserLeaveEvent(event)
    return dispatch('onUserLeave', event)
end
--@ EndEntityEventHandler
Entry.HandleUserLeaveEvent = HandleUserLeaveEvent

--@ BeginMethod
--@ MethodExecSpace=Server
function GetPlayerState(requestContext, senderUserId)
    return dispatch('getPlayerState', requestContext, senderUserId)
end
--@ EndMethod
Entry.GetPlayerState = GetPlayerState

--@ BeginMethod
--@ MethodExecSpace=Server
function GetMapState(mapId, senderUserId)
    return dispatch('getMapState', mapId, senderUserId)
end
--@ EndMethod
Entry.GetMapState = GetMapState

--@ BeginMethod
--@ MethodExecSpace=Server
function AttackMob(requestContext, mapId, spawnId, requestedDamage, senderUserId)
    return dispatch('attackMob', requestContext, mapId, spawnId, requestedDamage, senderUserId)
end
--@ EndMethod
Entry.AttackMob = AttackMob

--@ BeginMethod
--@ MethodExecSpace=Server
function PickupDrop(requestContext, mapId, dropId, senderUserId)
    return dispatch('pickupDrop', requestContext, mapId, dropId, senderUserId)
end
--@ EndMethod
Entry.PickupDrop = PickupDrop

--@ BeginMethod
--@ MethodExecSpace=Server
function DamageBoss(requestContext, mapId, requestedDamage, senderUserId)
    return dispatch('damageBoss', requestContext, mapId, requestedDamage, senderUserId)
end
--@ EndMethod
Entry.DamageBoss = DamageBoss

--@ BeginMethod
--@ MethodExecSpace=Server
function AcceptQuest(requestContext, questId, senderUserId)
    return dispatch('acceptQuest', requestContext, questId, senderUserId)
end
--@ EndMethod
Entry.AcceptQuest = AcceptQuest

--@ BeginMethod
--@ MethodExecSpace=Server
function TurnInQuest(requestContext, questId, senderUserId)
    return dispatch('turnInQuest', requestContext, questId, senderUserId)
end
--@ EndMethod
Entry.TurnInQuest = TurnInQuest

--@ BeginMethod
--@ MethodExecSpace=Server
function BuyFromNpc(requestContext, itemId, quantity, senderUserId)
    return dispatch('buyFromNpc', requestContext, itemId, quantity, senderUserId)
end
--@ EndMethod
Entry.BuyFromNpc = BuyFromNpc

--@ BeginMethod
--@ MethodExecSpace=Server
function SellToNpc(requestContext, itemId, quantity, senderUserId)
    return dispatch('sellToNpc', requestContext, itemId, quantity, senderUserId)
end
--@ EndMethod
Entry.SellToNpc = SellToNpc

--@ BeginMethod
--@ MethodExecSpace=Server
function EquipItem(requestContext, itemId, instanceId, senderUserId)
    return dispatch('equipItem', requestContext, itemId, instanceId, senderUserId)
end
--@ EndMethod
Entry.EquipItem = EquipItem

--@ BeginMethod
--@ MethodExecSpace=Server
function UnequipItem(requestContext, slot, senderUserId)
    return dispatch('unequipItem', requestContext, slot, senderUserId)
end
--@ EndMethod
Entry.UnequipItem = UnequipItem

--@ BeginMethod
--@ MethodExecSpace=Server
function ChangeMap(requestContext, mapId, senderUserId)
    return dispatch('changeMap', requestContext, mapId, senderUserId)
end
--@ EndMethod
Entry.ChangeMap = ChangeMap

return Entry
