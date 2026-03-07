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
function DamageBoss(requestContext, mapId, bossId, requestedDamage, component)
    return dispatch('damageBoss', component, requestContext, mapId, bossId, requestedDamage)
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

--@ BeginMethod
--@ MethodExecSpace=Server
function AllocateStat(requestContext, stat, amount, component)
    return dispatch('allocateStat', component, requestContext, stat, amount)
end
--@ EndMethod
Entry.AllocateStat = AllocateStat

--@ BeginMethod
--@ MethodExecSpace=Server
function PromoteJob(requestContext, jobId, component)
    return dispatch('promoteJob', component, requestContext, jobId)
end
--@ EndMethod
Entry.PromoteJob = PromoteJob

--@ BeginMethod
--@ MethodExecSpace=Server
function LearnSkill(requestContext, skillId, component)
    return dispatch('learnSkill', component, requestContext, skillId)
end
--@ EndMethod
Entry.LearnSkill = LearnSkill

--@ BeginMethod
--@ MethodExecSpace=Server
function CastSkill(requestContext, skillId, target, component)
    return dispatch('castSkill', component, requestContext, skillId, target)
end
--@ EndMethod
Entry.CastSkill = CastSkill

--@ BeginMethod
--@ MethodExecSpace=Server
function EnhanceEquipment(requestContext, slot, component)
    return dispatch('enhanceEquipment', component, requestContext, slot)
end
--@ EndMethod
Entry.EnhanceEquipment = EnhanceEquipment

--@ BeginMethod
--@ MethodExecSpace=Server
function CreateParty(requestContext, component)
    return dispatch('createParty', component, requestContext)
end
--@ EndMethod
Entry.CreateParty = CreateParty

--@ BeginMethod
--@ MethodExecSpace=Server
function CreateGuild(requestContext, name, component)
    return dispatch('createGuild', component, requestContext, name)
end
--@ EndMethod
Entry.CreateGuild = CreateGuild

--@ BeginMethod
--@ MethodExecSpace=Server
function AddFriend(requestContext, otherId, component)
    return dispatch('addFriend', component, requestContext, otherId)
end
--@ EndMethod
Entry.AddFriend = AddFriend

--@ BeginMethod
--@ MethodExecSpace=Server
function TradeMesos(requestContext, targetPlayerId, amount, component)
    return dispatch('tradeMesos', component, requestContext, targetPlayerId, amount)
end
--@ EndMethod
Entry.TradeMesos = TradeMesos

--@ BeginMethod
--@ MethodExecSpace=Server
function ListAuction(requestContext, itemId, quantity, price, component)
    return dispatch('listAuction', component, requestContext, itemId, quantity, price)
end
--@ EndMethod
Entry.ListAuction = ListAuction

--@ BeginMethod
--@ MethodExecSpace=Server
function CraftItem(requestContext, recipeId, component)
    return dispatch('craftItem', component, requestContext, recipeId)
end
--@ EndMethod
Entry.CraftItem = CraftItem

--@ BeginMethod
--@ MethodExecSpace=Server
function OpenDialogue(npcId, component)
    return dispatch('openDialogue', component, npcId)
end
--@ EndMethod
Entry.OpenDialogue = OpenDialogue

--@ BeginMethod
--@ MethodExecSpace=Server
function ChannelTransfer(requestContext, mapId, component)
    return dispatch('channelTransfer', component, requestContext, mapId)
end
--@ EndMethod
Entry.ChannelTransfer = ChannelTransfer

--@ BeginMethod
--@ MethodExecSpace=Server
function GetEconomyReport(component)
    return dispatch('getEconomyReport', component)
end
--@ EndMethod
Entry.GetEconomyReport = GetEconomyReport

--@ BeginMethod
--@ MethodExecSpace=Server
function AdminStatus(component)
    return dispatch('adminStatus', component)
end
--@ EndMethod
Entry.AdminStatus = AdminStatus

--@ BeginMethod
--@ MethodExecSpace=Server
function GetBuildRecommendation(requestContext, component)
    return dispatch('getBuildRecommendation', component, requestContext)
end
--@ EndMethod
Entry.GetBuildRecommendation = GetBuildRecommendation

--@ BeginMethod
--@ MethodExecSpace=Server
function GetTutorialState(requestContext, component)
    return dispatch('getTutorialState', component, requestContext)
end
--@ EndMethod
Entry.GetTutorialState = GetTutorialState

--@ BeginMethod
--@ MethodExecSpace=Server
function ListPartyFinder(requestContext, component)
    return dispatch('listPartyFinder', component, requestContext)
end
--@ EndMethod
Entry.ListPartyFinder = ListPartyFinder

--@ BeginMethod
--@ MethodExecSpace=Server
function CreateRaid(requestContext, bossId, component)
    return dispatch('createRaid', component, requestContext, bossId)
end
--@ EndMethod
Entry.CreateRaid = CreateRaid

return Entry
