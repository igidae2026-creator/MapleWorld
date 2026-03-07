local Component = require('msw.world_server_component')

local Entry = {}
local boundRuntimeComponent = nil

local function bindRuntimeComponent(component)
    if component ~= nil then
        boundRuntimeComponent = component
    end
    return boundRuntimeComponent
end

local function dispatch(methodName, component, ...)
    local resolved = bindRuntimeComponent(component)
    return Component.dispatch(resolved, methodName, ...)
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

--@ BeginMethod
--@ MethodExecSpace=Server
function GetPlayerState(requestContext, component)
    return dispatch('getPlayerState', component, requestContext)
end
--@ EndMethod
Entry.GetPlayerState = GetPlayerState

--@ BeginMethod
--@ MethodExecSpace=Server
function GetMapState(requestContext, mapId, component)
    return dispatch('getMapState', component, requestContext, mapId)
end
--@ EndMethod
Entry.GetMapState = GetMapState

--@ BeginMethod
--@ MethodExecSpace=Server
function AttackMob(requestContext, mapId, spawnId, requestedDamage, component)
    return dispatch('attackMob', component, requestContext, mapId, spawnId, requestedDamage)
end
--@ EndMethod
Entry.AttackMob = AttackMob

--@ BeginMethod
--@ MethodExecSpace=Server
function PickupDrop(requestContext, mapId, dropId, component)
    return dispatch('pickupDrop', component, requestContext, mapId, dropId)
end
--@ EndMethod
Entry.PickupDrop = PickupDrop

--@ BeginMethod
--@ MethodExecSpace=Server
function DamageBoss(requestContext, mapId, requestedDamage, component)
    return dispatch('damageBoss', component, requestContext, mapId, requestedDamage)
end
--@ EndMethod
Entry.DamageBoss = DamageBoss

--@ BeginMethod
--@ MethodExecSpace=Server
function AcceptQuest(requestContext, questId, component)
    return dispatch('acceptQuest', component, requestContext, questId)
end
--@ EndMethod
Entry.AcceptQuest = AcceptQuest

--@ BeginMethod
--@ MethodExecSpace=Server
function TurnInQuest(requestContext, questId, component)
    return dispatch('turnInQuest', component, requestContext, questId)
end
--@ EndMethod
Entry.TurnInQuest = TurnInQuest

--@ BeginMethod
--@ MethodExecSpace=Server
function BuyFromNpc(requestContext, npcId, itemId, quantity, component)
    return dispatch('buyFromNpc', component, requestContext, npcId, itemId, quantity)
end
--@ EndMethod
Entry.BuyFromNpc = BuyFromNpc

--@ BeginMethod
--@ MethodExecSpace=Server
function SellToNpc(requestContext, npcId, itemId, quantity, component)
    return dispatch('sellToNpc', component, requestContext, npcId, itemId, quantity)
end
--@ EndMethod
Entry.SellToNpc = SellToNpc

--@ BeginMethod
--@ MethodExecSpace=Server
function EquipItem(requestContext, itemId, instanceId, component)
    return dispatch('equipItem', component, requestContext, itemId, instanceId)
end
--@ EndMethod
Entry.EquipItem = EquipItem

--@ BeginMethod
--@ MethodExecSpace=Server
function UnequipItem(requestContext, slot, component)
    return dispatch('unequipItem', component, requestContext, slot)
end
--@ EndMethod
Entry.UnequipItem = UnequipItem

--@ BeginMethod
--@ MethodExecSpace=Server
function ChangeMap(requestContext, mapId, sourceMapId, component)
    return dispatch('changeMap', component, requestContext, mapId, sourceMapId)
end
--@ EndMethod
Entry.ChangeMap = ChangeMap

return Entry
