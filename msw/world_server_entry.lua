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
function GetPlayerState(requestContext)
    return dispatch('getPlayerState', requestContext)
end
--@ EndMethod
Entry.GetPlayerState = GetPlayerState

--@ BeginMethod
--@ MethodExecSpace=Server
function GetMapState(requestContext, mapId)
    return dispatch('getMapState', requestContext, mapId)
end
--@ EndMethod
Entry.GetMapState = GetMapState

--@ BeginMethod
--@ MethodExecSpace=Server
function AttackMob(requestContext, mapId, spawnId, requestedDamage)
    return dispatch('attackMob', requestContext, mapId, spawnId, requestedDamage)
end
--@ EndMethod
Entry.AttackMob = AttackMob

--@ BeginMethod
--@ MethodExecSpace=Server
function PickupDrop(requestContext, mapId, dropId)
    return dispatch('pickupDrop', requestContext, mapId, dropId)
end
--@ EndMethod
Entry.PickupDrop = PickupDrop

--@ BeginMethod
--@ MethodExecSpace=Server
function DamageBoss(requestContext, mapId, requestedDamage)
    return dispatch('damageBoss', requestContext, mapId, requestedDamage)
end
--@ EndMethod
Entry.DamageBoss = DamageBoss

--@ BeginMethod
--@ MethodExecSpace=Server
function AcceptQuest(requestContext, questId)
    return dispatch('acceptQuest', requestContext, questId)
end
--@ EndMethod
Entry.AcceptQuest = AcceptQuest

--@ BeginMethod
--@ MethodExecSpace=Server
function TurnInQuest(requestContext, questId)
    return dispatch('turnInQuest', requestContext, questId)
end
--@ EndMethod
Entry.TurnInQuest = TurnInQuest

--@ BeginMethod
--@ MethodExecSpace=Server
function BuyFromNpc(requestContext, itemId, quantity)
    return dispatch('buyFromNpc', requestContext, itemId, quantity)
end
--@ EndMethod
Entry.BuyFromNpc = BuyFromNpc

--@ BeginMethod
--@ MethodExecSpace=Server
function SellToNpc(requestContext, itemId, quantity)
    return dispatch('sellToNpc', requestContext, itemId, quantity)
end
--@ EndMethod
Entry.SellToNpc = SellToNpc

--@ BeginMethod
--@ MethodExecSpace=Server
function EquipItem(requestContext, itemId, instanceId)
    return dispatch('equipItem', requestContext, itemId, instanceId)
end
--@ EndMethod
Entry.EquipItem = EquipItem

--@ BeginMethod
--@ MethodExecSpace=Server
function UnequipItem(requestContext, slot)
    return dispatch('unequipItem', requestContext, slot)
end
--@ EndMethod
Entry.UnequipItem = UnequipItem

--@ BeginMethod
--@ MethodExecSpace=Server
function ChangeMap(requestContext, mapId)
    return dispatch('changeMap', requestContext, mapId)
end
--@ EndMethod
Entry.ChangeMap = ChangeMap

return Entry
