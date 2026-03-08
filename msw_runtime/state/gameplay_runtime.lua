local RuntimeTables = require('data.runtime_tables')
local BossCatalog = require('data.bosses.catalog')
local DialogueCatalog = require('data.dialogues.catalog')
local DropTableCatalog = require('data.drop_tables.catalog')
local EventCatalog = require('data.events.catalog')
local ItemCatalog = require('data.items.catalog')
local JobCatalog = require('data.jobs.catalog')
local MapCatalog = require('data.maps.catalog')
local MobCatalog = require('data.mobs.catalog')
local NpcCatalog = require('data.npcs.catalog')
local QuestCatalog = require('data.quests.catalog')
local SkillCatalog = require('data.skills.catalog')

local ItemSystem = require('scripts.item_system')
local EconomySystem = require('scripts.economy_system')
local ExpSystem = require('scripts.exp_system')
local StatSystem = require('scripts.stat_system')
local JobSystem = require('scripts.job_system')
local BuildRecommendationSystem = require('scripts.build_recommendation_system')
local PlayerClassSystem = require('scripts.player_class_system')
local ProgressionSystem = require('scripts.progression_system')
local InventoryExpansion = require('scripts.inventory_expansion')
local SkillSystem = require('scripts.skill_system')
local BuffSystem = require('scripts.buff_debuff_system')
local CombatResolution = require('scripts.combat_resolution')
local DropSystem = require('scripts.drop_system')
local SpawnSystem = require('scripts.spawn_system')
local QuestSystem = require('scripts.quest_system')
local BossSystem = require('scripts.boss_system')
local PartySystem = require('scripts.party_system')
local GuildSystem = require('scripts.guild_system')
local SocialSystem = require('scripts.social_system')
local TradingSystem = require('scripts.trading_system')
local AuctionHouse = require('scripts.auction_house')
local CraftingSystem = require('scripts.crafting_system')
local DialogueSystem = require('scripts.npc_dialogue_system')
local TutorialSystem = require('scripts.tutorial_system')
local RaidSystem = require('scripts.raid_system')
local AntiAbuseRuntime = require('msw_runtime.anti_abuse_runtime')

local GameplayRuntime = {}

local function deepcopy(value, seen)
    if type(value) ~= 'table' then return value end
    local visited = seen or {}
    if visited[value] then return visited[value] end
    local copy = {}
    visited[value] = copy
    for k, v in pairs(value) do
        copy[deepcopy(k, visited)] = deepcopy(v, visited)
    end
    return copy
end

local function countKeys(tbl)
    local total = 0
    for _ in pairs(tbl or {}) do
        total = total + 1
    end
    return total
end

local function sortedPairs(tbl, keyField)
    local rows = {}
    for _, value in pairs(tbl or {}) do
        rows[#rows + 1] = value
    end
    table.sort(rows, function(a, b)
        return tostring(a[keyField]) < tostring(b[keyField])
    end)
    return rows
end

local function noop() end

local function makeLogger()
    return {
        info = noop,
        error = noop,
    }
end

local function makeMetrics()
    return {
        increment = noop,
        gauge = noop,
        error = noop,
    }
end

local function cloneResult(result)
    if type(result) ~= 'table' then return result end
    return deepcopy(result)
end

local function normalizeItems(items)
    local out = {}
    for itemId, item in pairs(items or {}) do
        out[itemId] = {
            itemId = item.item_id or itemId,
            name = item.name,
            type = item.type,
            stackable = item.stackable == true,
            requiredLevel = tonumber(item.required_level) or 1,
            attack = tonumber(item.attack) or 0,
            defense = tonumber(item.defense) or 0,
            npcPrice = tonumber(item.npc_price) or 0,
            rarity = item.rarity,
        }
    end
    return out
end

local function normalizeMobs(mobs)
    local out = {}
    for mobId, mob in pairs(mobs or {}) do
        out[mobId] = {
            mobId = mob.mob_id or mobId,
            name = mob.name,
            level = tonumber(mob.level) or 1,
            hp = tonumber(mob.hp) or 1,
            exp = tonumber(mob.exp) or 1,
            mesos_min = tonumber(mob.mesos_min) or 0,
            mesos_max = tonumber(mob.mesos_max) or tonumber(mob.mesos_min) or 0,
            map_pool = mob.map_pool,
            respawn_sec = tonumber(mob.respawn_sec) or 8,
            role = mob.role,
            hitReaction = mob.hitReaction,
        }
    end
    return out
end

local function normalizeQuests(quests)
    local out = {}
    for questId, quest in pairs(quests or {}) do
        local objectives = {}
        for _, objective in ipairs(quest.objectives or {}) do
            objectives[#objectives + 1] = {
                type = objective.type,
                targetId = objective.targetId,
                required = tonumber(objective.required) or 1,
            }
        end
        local rewardItems = {}
        for _, reward in ipairs(quest.reward_items or {}) do
            rewardItems[#rewardItems + 1] = {
                itemId = reward.itemId,
                quantity = tonumber(reward.quantity) or 1,
            }
        end
        out[questId] = {
            questId = quest.quest_id or questId,
            name = quest.name,
            requiredLevel = tonumber(quest.required_level) or 1,
            objectives = objectives,
            rewardMesos = tonumber(quest.reward_mesos) or 0,
            rewardExp = tonumber(quest.reward_exp) or 0,
            rewardItems = rewardItems,
            startNpc = quest.start_npc,
            endNpc = quest.end_npc,
            narrative = quest.narrative,
            guidance = quest.guidance,
            rewardSummary = quest.reward_summary,
        }
    end
    return out
end

local function normalizeBosses(bosses)
    local out = {}
    for bossId, boss in pairs(bosses or {}) do
        out[bossId] = {
            bossId = boss.boss_id or bossId,
            name = boss.name,
            mapId = boss.map_id,
            hp = tonumber(boss.hp) or 1,
            cooldownSec = tonumber(boss.cooldown_sec) or 0,
            trigger = boss.trigger or 'scheduled_window',
            mechanics = deepcopy(boss.mechanics),
            raid = boss.raid == true,
            uniqueness = boss.uniqueness,
            position = { x = 0, y = 0, z = 0 },
        }
    end
    return out
end

local function normalizeDropTables(dropTables)
    local out = {}
    for ownerId, rows in pairs(dropTables or {}) do
        out[ownerId] = {}
        for _, row in ipairs(rows) do
            out[ownerId][#out[ownerId] + 1] = {
                itemId = row.item_id,
                chance = tonumber(row.chance) or 0,
                minQty = tonumber(row.min_qty) or 1,
                maxQty = tonumber(row.max_qty) or tonumber(row.min_qty) or 1,
                rarity = row.rarity,
                bindOnPickup = row.bind_on_pickup == true,
                anticipation = row.anticipation,
            }
        end
    end
    return out
end

local function buildExpCurve(runtimeTables)
    local curve = {}
    for _, row in ipairs((runtimeTables or {}).exp_curve or {}) do
        local level = tonumber(row.level)
        if level then
            curve[level] = tonumber(row.exp_to_next) or 1
        end
    end
    return curve
end

local function buildRecipes(items)
    local stackable = {}
    local craftable = {}
    for itemId, item in pairs(items or {}) do
        if item.stackable == true then
            stackable[#stackable + 1] = itemId
        elseif item.type == 'weapon' or item.type == 'armor' or item.type == 'accessory' then
            craftable[#craftable + 1] = itemId
        end
    end
    table.sort(stackable)
    table.sort(craftable)
    local recipes = {}
    if #stackable >= 2 and #craftable >= 1 then
        recipes.starter_upgrade = {
            id = 'starter_upgrade',
            ingredients = {
                { itemId = stackable[1], quantity = 2 },
                { itemId = stackable[2], quantity = 1 },
            },
            result = { itemId = craftable[1], quantity = 1 },
        }
    end
    return recipes
end

local function firstKey(tbl)
    local keys = {}
    for key in pairs(tbl or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys[1]
end

local function selectQuestId(quests, maxLevel)
    local chosenId, chosenLevel = nil, math.huge
    for questId, quest in pairs(quests or {}) do
        local required = tonumber(quest.requiredLevel) or math.huge
        if required <= (maxLevel or math.huge) then
            if required < chosenLevel then
                chosenId, chosenLevel = questId, required
            elseif required == chosenLevel and tostring(questId) < tostring(chosenId or '') then
                chosenId = questId
            end
        end
    end
    return chosenId
end

local function selectStarterWeapon(items)
    local chosen = nil
    for itemId, item in pairs(items or {}) do
        if item.stackable == false and item.type == 'weapon' and (tonumber(item.requiredLevel) or 1) <= 10 then
            if chosen == nil or tostring(itemId) < tostring(chosen) then
                chosen = itemId
            end
        end
    end
    return chosen
end

local function selectStarterMap(maps)
    local chosenId, chosenLevel = nil, math.huge
    for mapId, map in pairs(maps or {}) do
        local level = tonumber(map.recommended_level) or 9999
        if level < chosenLevel then
            chosenId, chosenLevel = mapId, level
        elseif level == chosenLevel and tostring(mapId) < tostring(chosenId or '') then
            chosenId = mapId
        end
    end
    return chosenId
end

local function buildSpawnGroups(content)
    local byMap = {}
    local mapOrder = {}
    for mapId, _ in pairs(content.maps or {}) do
        byMap[mapId] = {}
    end
    for mobId, mob in pairs(content.mobs or {}) do
        local mapId = mob.map_pool
        if byMap[mapId] then
            mapOrder[mapId] = (mapOrder[mapId] or 0) + 1
            local map = content.maps[mapId] or {}
            local base = map.spawnPosition or { x = 0, y = 0, z = 0 }
            local offset = mapOrder[mapId] * 6
            byMap[mapId][#byMap[mapId] + 1] = {
                id = string.format('%s_spawn_%02d', tostring(mapId), mapOrder[mapId]),
                mobId = mobId,
                maxAlive = mob.role == 'elite' and 1 or mob.role == 'captain' and 1 or 2,
                respawnSec = tonumber(mob.respawn_sec) or 8,
                clusterRole = mob.role or 'lane',
                chokePoint = ((map.chokePoints or {})[1]),
                mobilityAdvantage = ((map.mobilityAdvantageZones or {})[1]),
                points = {
                    { x = tonumber(base.x) or 0, y = (tonumber(base.y) or 0) + offset },
                    { x = (tonumber(base.x) or 0) + 12, y = (tonumber(base.y) or 0) + offset + 4 },
                },
            }
        end
    end
    return byMap
end

local function snapshotPlayer(runtime, player)
    local derived = runtime.statSystem:derived(player, runtime.itemSystem, runtime.buffSystem:tick(player))
    return {
        id = player.id,
        level = player.level,
        exp = player.exp,
        mesos = player.mesos,
        mapId = player.currentMapId,
        channelId = player.channelId,
        jobId = player.jobId,
        stats = deepcopy(player.stats),
        derived = derived,
        inventory = runtime.itemSystem:exportInventory(player),
        equipment = deepcopy(player.equipment),
        questState = runtime.questSystem:snapshotPlayer(player),
        skills = deepcopy(player.skills),
        cooldowns = runtime.skillSystem:getCooldownState(player),
        social = deepcopy(player.social),
        progression = deepcopy(player.progression),
        tutorial = deepcopy(player.tutorial),
        classProfile = deepcopy(player.classProfile),
        activeEffects = runtime.buffSystem:snapshot(player),
        ledger = deepcopy(player.economyLedger),
    }
end

function GameplayRuntime._emit(runtime, kind, payload)
    runtime.eventSeq = runtime.eventSeq + 1
    runtime.eventStream[#runtime.eventStream + 1] = {
        seq = runtime.eventSeq,
        kind = kind,
        payload = deepcopy(payload),
    }
    while #runtime.eventStream > runtime.maxEvents do
        table.remove(runtime.eventStream, 1)
    end
end

function GameplayRuntime._grantExp(runtime, player, amount, reason)
    local beforeLevel = tonumber(player.level) or 1
    local leveled = runtime.expSystem:grant(player, amount)
    local afterLevel = tonumber(player.level) or beforeLevel
    if afterLevel > beforeLevel then
        for _ = beforeLevel + 1, afterLevel do
            runtime.progressionSystem:onLevelUp(player)
        end
        runtime.playerClassSystem:refresh(player)
        runtime.tutorialSystem:advance(player, 'combat')
    end
    if amount and amount > 0 then
        GameplayRuntime._emit(runtime, 'exp_granted', {
            playerId = player.id,
            amount = amount,
            reason = reason,
            beforeLevel = beforeLevel,
            afterLevel = afterLevel,
            leveled = leveled == true,
        })
    end
    return leveled
end

function GameplayRuntime._resolvePlayer(runtime, playerId)
    local resolvedId = tostring(playerId or '')
    local player = runtime.players[resolvedId]
    if not player then
        return nil, 'player_not_found'
    end
    return player
end

function GameplayRuntime._ensureBooted(runtime)
    if runtime.booted ~= true then
        return false, 'runtime_not_booted'
    end
    return true
end

function GameplayRuntime._coerceRequest(...)
    if select('#', ...) == 1 and type((...)) == 'table' then
        return (...)
    end
    return nil
end

function GameplayRuntime._bootstrap(runtime)
    if runtime.booted == true then
        return {
            ok = true,
            runtime = 'msw_runtime',
            booted = true,
            players = countKeys(runtime.players),
        }
    end
    for mapId, groups in pairs(runtime.spawnGroupsByMap) do
        runtime.spawnSystem:registerMap(mapId, groups)
    end
    runtime.booted = true
    GameplayRuntime._emit(runtime, 'runtime_booted', {
        maps = countKeys(runtime.content.maps),
        mobs = countKeys(runtime.normalized.mobs),
        bosses = countKeys(runtime.normalized.bosses),
        quests = countKeys(runtime.normalized.quests),
    })
    return {
        ok = true,
        runtime = 'msw_runtime',
        booted = true,
        players = 0,
    }
end

function GameplayRuntime._createPlayer(runtime, playerId)
    local player = runtime.itemSystem:createPlayerProfile(playerId)
    player = runtime.itemSystem:sanitizePlayerProfile(player, playerId)
    player.currentMapId = runtime.starterMapId
    player.channelId = 1
    player.mapVisitCounts = {}
    runtime.jobSystem:ensurePlayer(player)
    runtime.statSystem:ensurePlayer(player)
    runtime.skillSystem:ensurePlayer(player)
    runtime.socialSystem:ensurePlayer(player)
    runtime.progressionSystem:ensurePlayer(player)
    runtime.playerClassSystem:ensurePlayer(player)
    runtime.tutorialSystem:ensurePlayer(player)
    runtime.worldEventMarks:ensurePlayer(player)
    runtime.achievementsSystem:ensurePlayer(player)
    runtime.economySystem:grantMesos(player, 500, 'starter_seed')
    if runtime.starterWeaponId then
        runtime.itemSystem:addItem(player, runtime.starterWeaponId, 1, nil, { source = 'starter_seed' })
    end
    runtime.players[player.id] = player
    GameplayRuntime._emit(runtime, 'player_created', {
        playerId = player.id,
        mapId = player.currentMapId,
        starterWeaponId = runtime.starterWeaponId,
    })
    return player
end

function GameplayRuntime._enterPlayer(runtime, event)
    local playerId = tostring(event and (event.UserId or event.userId or event.playerId) or 'unknown')
    local player = runtime.players[playerId] or GameplayRuntime._createPlayer(runtime, playerId)
    player.online = true
    runtime.spawnSystem:tickMap(player.currentMapId)
    GameplayRuntime._emit(runtime, 'player_enter', {
        playerId = player.id,
        mapId = player.currentMapId,
    })
    return {
        ok = true,
        playerId = player.id,
        state = snapshotPlayer(runtime, player),
    }
end

function GameplayRuntime._leavePlayer(runtime, event)
    local playerId = tostring(event and (event.UserId or event.userId or event.playerId) or 'unknown')
    local player = runtime.players[playerId]
    if player then
        player.online = false
    end
    GameplayRuntime._emit(runtime, 'player_leave', { playerId = playerId })
    return {
        ok = true,
        playerId = playerId,
    }
end

function GameplayRuntime._tick(runtime, delta)
    runtime.ticks = runtime.ticks + 1
    runtime.lastDelta = tonumber(delta) or 0
    runtime.spawnSystem:tick()
    runtime.dropSystem:expireDrops()
    runtime.bossSystem:tick(runtime)
    return {
        ok = true,
        ticks = runtime.ticks,
        delta = runtime.lastDelta,
        players = countKeys(runtime.players),
        activeDrops = runtime.dropSystem:activeCount(),
    }
end

function GameplayRuntime:new()
    local content = {
        bosses = BossCatalog,
        dialogues = DialogueCatalog,
        drop_tables = DropTableCatalog,
        events = EventCatalog,
        items = ItemCatalog,
        jobs = JobCatalog,
        maps = MapCatalog,
        mobs = MobCatalog,
        npcs = NpcCatalog,
        quests = QuestCatalog,
        skills = SkillCatalog,
    }
    local runtime = {
        booted = false,
        ticks = 0,
        lastDelta = 0,
        eventSeq = 0,
        maxEvents = 256,
        eventStream = {},
        processedNpcBuyRequests = {},
        processedNpcBuyRequestOrder = {},
        processedTradeRequests = {},
        processedTradeRequestOrder = {},
        maxProcessedNpcBuyRequests = 128,
        maxProcessedTradeRequests = 128,
        logger = makeLogger(),
        metrics = makeMetrics(),
        content = content,
        normalized = {
            items = normalizeItems(content.items),
            mobs = normalizeMobs(content.mobs),
            quests = normalizeQuests(content.quests),
            bosses = normalizeBosses(content.bosses),
            dropTables = normalizeDropTables(content.drop_tables),
        },
        players = {},
    }
    setmetatable(runtime, { __index = GameplayRuntime })

    local expCurve = buildExpCurve(RuntimeTables)
    runtime.inventoryExpansion = InventoryExpansion.new()
    runtime.itemSystem = ItemSystem.new({
        items = runtime.normalized.items,
        logger = runtime.logger,
        metrics = runtime.metrics,
    })
    runtime.economySystem = EconomySystem.new({
        itemSystem = runtime.itemSystem,
        logger = runtime.logger,
        metrics = runtime.metrics,
    })
    runtime.expSystem = ExpSystem.new({
        curve = expCurve,
        logger = runtime.logger,
        metrics = runtime.metrics,
    })
    runtime.statSystem = StatSystem.new({
        jobs = content.jobs,
        metrics = runtime.metrics,
    })
    runtime.jobSystem = JobSystem.new({
        jobs = content.jobs,
        metrics = runtime.metrics,
    })
    runtime.buildRecommendationSystem = BuildRecommendationSystem.new({
        jobs = content.jobs,
        skills = content.skills,
    })
    runtime.playerClassSystem = PlayerClassSystem.new({
        jobSystem = runtime.jobSystem,
        statSystem = runtime.statSystem,
        buildRecommendationSystem = runtime.buildRecommendationSystem,
    })
    runtime.progressionSystem = ProgressionSystem.new({
        jobSystem = runtime.jobSystem,
        statSystem = runtime.statSystem,
        inventoryExpansion = runtime.inventoryExpansion,
    })
    runtime.buffSystem = BuffSystem.new()
    runtime.combatSystem = CombatResolution.new({
        statSystem = runtime.statSystem,
        buffSystem = runtime.buffSystem,
        itemSystem = runtime.itemSystem,
        rng = function() return 0.99 end,
    })
    runtime.skillSystem = SkillSystem.new({
        skillTrees = content.skills,
        buffSystem = runtime.buffSystem,
        combat = runtime.combatSystem,
        time = os.time,
    })
    runtime.dropSystem = DropSystem.new({
        dropTable = runtime.normalized.dropTables,
        items = runtime.normalized.items,
        logger = runtime.logger,
        metrics = runtime.metrics,
        rng = function() return 0.01 end,
    })
    runtime.questSystem = QuestSystem.new({
        quests = runtime.normalized.quests,
        itemSystem = runtime.itemSystem,
        economySystem = runtime.economySystem,
        expSystem = {
            grant = function(_, player, amount)
                return GameplayRuntime._grantExp(runtime, player, amount, 'quest_reward')
            end,
        },
        logger = runtime.logger,
        metrics = runtime.metrics,
    })
    runtime.bossSystem = BossSystem.new({
        bossTable = runtime.normalized.bosses,
        dropSystem = runtime.dropSystem,
        logger = runtime.logger,
        metrics = runtime.metrics,
    })
    runtime.spawnGroupsByMap = buildSpawnGroups(content)
    runtime.spawnSystem = SpawnSystem.new({
        mobs = runtime.normalized.mobs,
        metrics = runtime.metrics,
        logger = runtime.logger,
    })
    runtime.partySystem = PartySystem.new()
    runtime.guildSystem = GuildSystem.new()
    runtime.socialSystem = SocialSystem.new()
    runtime.tradingSystem = TradingSystem.new({
        itemSystem = runtime.itemSystem,
        economySystem = runtime.economySystem,
    })
    runtime.auctionHouse = AuctionHouse.new({
        economy = runtime.economySystem,
    })
    runtime.craftingRecipes = buildRecipes(runtime.normalized.items)
    runtime.craftingSystem = CraftingSystem.new({
        itemSystem = runtime.itemSystem,
        recipes = runtime.craftingRecipes,
    })
    runtime.dialogueSystem = DialogueSystem.new({
        dialogues = content.dialogues,
    })
    runtime.tutorialSystem = TutorialSystem.new()
    runtime.raidSystem = RaidSystem.new()
    runtime.antiAbuseRuntime = AntiAbuseRuntime.new({
        definitions = content.events,
    })
    runtime.worldEventMarks = require('scripts.daily_weekly_system').new()
    runtime.achievementsSystem = require('scripts.achievements_system').new()

    runtime.starterMapId = selectStarterMap(content.maps)
    runtime.starterWeaponId = selectStarterWeapon(runtime.normalized.items)
    runtime.defaultQuestId = selectQuestId(runtime.normalized.quests, 10) or firstKey(runtime.normalized.quests)
    runtime.defaultBossId = firstKey(runtime.normalized.bosses)
    return runtime
end

function GameplayRuntime:getActivePlayerCount()
    local total = 0
    for _, player in pairs(self.players) do
        if player.online ~= false then total = total + 1 end
    end
    return total
end

function GameplayRuntime:getMapPopulation(mapId)
    local total = 0
    for _, player in pairs(self.players) do
        if player.currentMapId == mapId and player.online ~= false then total = total + 1 end
    end
    return total
end

function GameplayRuntime:bootstrap()
    return GameplayRuntime._bootstrap(self)
end

function GameplayRuntime:tick(delta)
    return GameplayRuntime._tick(self, delta)
end

function GameplayRuntime:onUserEnter(event)
    return GameplayRuntime._enterPlayer(self, event)
end

function GameplayRuntime:onUserLeave(event)
    return GameplayRuntime._leavePlayer(self, event)
end

function GameplayRuntime:getPlayerState(playerId)
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end
    return {
        ok = true,
        player = snapshotPlayer(self, player),
    }
end

function GameplayRuntime:getMapState(mapIdOrPlayerId)
    local mapId = mapIdOrPlayerId
    if self.players[tostring(mapIdOrPlayerId or '')] then
        mapId = self.players[tostring(mapIdOrPlayerId)].currentMapId
    end
    mapId = mapId or self.starterMapId
    self.spawnSystem:tickMap(mapId)
    local map = self.content.maps[mapId]
    if not map then return { ok = false, error = 'map_not_found' } end
    local mobs = {}
    for _, mob in pairs((self.spawnSystem.maps[mapId] or {}).active or {}) do
        mobs[#mobs + 1] = deepcopy(mob)
    end
    table.sort(mobs, function(a, b) return tonumber(a.spawnId) < tonumber(b.spawnId) end)
    return {
        ok = true,
        map = deepcopy(map),
        population = self:getMapPopulation(mapId),
        mobs = mobs,
        drops = self.dropSystem:listDrops(mapId),
        boss = deepcopy(self.bossSystem:getEncounter(mapId)),
        regionalEvent = self.antiAbuseRuntime:regionalState(mapId),
    }
end

function GameplayRuntime:getStateDelta(sinceSeq)
    local baseline = math.floor(tonumber(sinceSeq) or 0)
    local events = {}
    for _, event in ipairs(self.eventStream) do
        if event.seq > baseline then
            events[#events + 1] = deepcopy(event)
        end
    end
    return {
        ok = true,
        latestSeq = self.eventSeq,
        events = events,
    }
end

function GameplayRuntime:getEventStream(sinceSeq)
    return self:getStateDelta(sinceSeq)
end

function GameplayRuntime:dispatchRuntimeEvent(eventName, payload)
    if eventName == 'activate_world_event' and type(payload) == 'table' then
        local activated = self.antiAbuseRuntime:activateWorldEvent(payload.kind or 'daily', payload.id)
        GameplayRuntime._emit(self, 'world_event_activated', { kind = payload.kind, id = payload.id })
        return { ok = true, event = activated }
    end
    if eventName == 'advance_tutorial' and type(payload) == 'table' then
        local player, err = GameplayRuntime._resolvePlayer(self, payload.playerId)
        if not player then return { ok = false, error = err } end
        local ok, nextStep = self.tutorialSystem:advance(player, payload.stepId)
        return { ok = ok == true, nextStep = nextStep, error = ok and nil or nextStep }
    end
    return { ok = false, error = 'unknown_runtime_event' }
end

function GameplayRuntime:routePlayerAction(action, payload)
    local routes = {
        attack_mob = 'attackMob',
        pickup_drop = 'pickupDrop',
        accept_quest = 'acceptQuest',
        turn_in_quest = 'turnInQuest',
        equip_item = 'equipItem',
        unequip_item = 'unequipItem',
        change_map = 'changeMap',
        allocate_stat = 'allocateStat',
        promote_job = 'promoteJob',
        learn_skill = 'learnSkill',
        cast_skill = 'castSkill',
    }
    local methodName = routes[action]
    if not methodName or type(self[methodName]) ~= 'function' then
        return { ok = false, error = 'unknown_player_action' }
    end
    payload = payload or {}
    return self[methodName](self, payload.playerId, payload.a, payload.b, payload.c)
end

function GameplayRuntime:changeMap(playerId, mapId)
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end
    if self.content.maps[mapId] == nil then
        return { ok = false, error = 'map_not_found' }
    end
    player.currentMapId = mapId
    player.mapVisitCounts[mapId] = (player.mapVisitCounts[mapId] or 0) + 1
    self.spawnSystem:tickMap(mapId)
    self.tutorialSystem:advance(player, 'move')
    GameplayRuntime._emit(self, 'map_changed', { playerId = player.id, mapId = mapId })
    return {
        ok = true,
        mapId = mapId,
        mapState = self:getMapState(mapId),
    }
end

function GameplayRuntime:allocateStat(playerId, stat, amount)
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end
    local ok, allocErr = self.statSystem:allocate(player, stat, amount)
    if not ok then return { ok = false, error = allocErr } end
    self.progressionSystem:refresh(player)
    self.playerClassSystem:refresh(player)
    return { ok = true, player = snapshotPlayer(self, player) }
end

function GameplayRuntime:promoteJob(playerId, jobId)
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end
    local ok, result = self.playerClassSystem:promote(player, jobId)
    if not ok then return { ok = false, error = result } end
    self.skillSystem:ensurePlayer(player)
    GameplayRuntime._emit(self, 'job_promoted', { playerId = player.id, jobId = jobId })
    return { ok = true, classProfile = deepcopy(result), player = snapshotPlayer(self, player) }
end

function GameplayRuntime:learnSkill(playerId, skillId)
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end
    local ok, learnErr = self.skillSystem:learn(player, skillId)
    if not ok then return { ok = false, error = learnErr } end
    self.playerClassSystem:refresh(player)
    return { ok = true, skills = deepcopy(player.skills) }
end

function GameplayRuntime:_attackResolved(player, mob, amount, source)
    local ok, entity, killed = self.spawnSystem:damageMob(player.currentMapId, mob.spawnId, amount)
    if not ok then return { ok = false, error = entity } end
    if killed then
        local expGain = tonumber(mob.template and mob.template.exp) or tonumber(mob.exp) or 1
        local mesosMin = tonumber(mob.template and mob.template.mesos_min) or 0
        local mesosMax = tonumber(mob.template and mob.template.mesos_max) or mesosMin
        local mesosGain = math.max(mesosMin, math.floor((mesosMin + mesosMax) / 2))
        GameplayRuntime._grantExp(self, player, expGain, 'mob_kill')
        self.economySystem:grantMesos(player, mesosGain, 'mob_drop')
        self.questSystem:onKill(player, mob.mobId, 1)
        self.antiAbuseRuntime:observe(player, 'mob_kill', 1)
        local drops = self.dropSystem:rollDrops(mob, player)
        local registered = self.dropSystem:registerDrops(player.currentMapId, mob, drops, {
            ownerId = player.id,
            ownerScope = 'player',
            sourceSystem = source or 'combat',
        })
        self.tutorialSystem:advance(player, 'combat')
        GameplayRuntime._emit(self, 'mob_killed', {
            playerId = player.id,
            mobId = mob.mobId,
            spawnId = mob.spawnId,
            exp = expGain,
            mesos = mesosGain,
            dropCount = #registered,
        })
        return {
            ok = true,
            killed = true,
            mob = deepcopy(entity),
            drops = deepcopy(registered),
            player = snapshotPlayer(self, player),
        }
    end
    GameplayRuntime._emit(self, 'mob_damaged', {
        playerId = player.id,
        mobId = mob.mobId,
        spawnId = mob.spawnId,
        amount = amount,
        remainingHp = entity.hp,
    })
    return {
        ok = true,
        killed = false,
        mob = deepcopy(entity),
        player = snapshotPlayer(self, player),
    }
end

function GameplayRuntime:attackMob(playerId, spawnId)
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end
    local mob = self.spawnSystem:getMob(player.currentMapId, tonumber(spawnId))
    if not mob then return { ok = false, error = 'mob_not_found' } end
    local damage = self.combatSystem:resolveSkillDamage(player, mob, {
        id = 'basic_attack',
        ratio = 1.0,
        comboChain = 1,
        usesMagic = player.jobId == 'magician',
    }, { hitRoll = 0.99, critRoll = 0.99 })
    return self:_attackResolved(player, mob, math.max(1, tonumber(damage.amount) or 1), 'basic_attack')
end

function GameplayRuntime:pickupDrop(playerId, dropId)
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end
    local ok, recordOrErr = self.dropSystem:pickupDrop(player, player.currentMapId, tonumber(dropId), self.itemSystem)
    if not ok then return { ok = false, error = recordOrErr } end
    self.questSystem:onItemAcquired(player, recordOrErr.itemId, recordOrErr.quantity)
    self.tutorialSystem:advance(player, 'equip')
    GameplayRuntime._emit(self, 'drop_picked', {
        playerId = player.id,
        dropId = recordOrErr.dropId,
        itemId = recordOrErr.itemId,
        quantity = recordOrErr.quantity,
    })
    return {
        ok = true,
        record = deepcopy(recordOrErr),
        player = snapshotPlayer(self, player),
    }
end

function GameplayRuntime:acceptQuest(playerId, questId)
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end
    questId = questId or self.defaultQuestId
    local ok, acceptErr = self.questSystem:accept(player, questId)
    if not ok then return { ok = false, error = acceptErr } end
    GameplayRuntime._emit(self, 'quest_accepted', { playerId = player.id, questId = questId })
    return { ok = true, quests = self.questSystem:snapshotPlayer(player) }
end

function GameplayRuntime:turnInQuest(playerId, questId)
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end
    local ok, turnErr = self.questSystem:turnIn(player, questId)
    if not ok then return { ok = false, error = turnErr } end
    GameplayRuntime._emit(self, 'quest_completed', { playerId = player.id, questId = questId })
    return { ok = true, player = snapshotPlayer(self, player) }
end

function GameplayRuntime:buyFromNpc(playerId, itemId, quantity, npcId)
    local request = nil
    if type(playerId) == 'table' and itemId == nil and quantity == nil and npcId == nil then
        request = playerId
    else
        request = GameplayRuntime._coerceRequest(playerId, itemId, quantity, npcId)
    end
    if request then
        playerId = request.playerId
        itemId = request.itemId
        quantity = request.quantity
        npcId = request.npcId
    end
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end
    local requestId = request and request.requestId or nil
    if requestId ~= nil then
        local prior = self.processedNpcBuyRequests[tostring(requestId)]
        if prior then
            GameplayRuntime._emit(self, 'npc_buy_deduped', {
                requestId = tostring(requestId),
                playerId = player.id,
                itemId = prior.itemId,
                quantity = prior.quantity,
                npcId = prior.npcId,
                outcome = prior.kind,
            })
            local replay = cloneResult(prior.result)
            replay.deduped = true
            replay.requestId = tostring(requestId)
            return replay
        end
    end
    local ok, buyErr = self.economySystem:buyFromNpc(player, itemId, quantity or 1, {
        npcId = npcId,
        mapId = player.currentMapId,
        correlationId = requestId,
    })
    if not ok then return { ok = false, error = buyErr } end
    self.questSystem:onItemAcquired(player, itemId, quantity or 1)
    local result = {
        ok = true,
        requestId = requestId and tostring(requestId) or nil,
        player = snapshotPlayer(self, player),
    }
    if requestId ~= nil then
        local key = tostring(requestId)
        self.processedNpcBuyRequests[key] = {
            kind = 'accepted',
            itemId = itemId,
            quantity = math.max(1, math.floor(tonumber(quantity) or 0)),
            npcId = npcId,
            result = cloneResult(result),
        }
        self.processedNpcBuyRequestOrder[#self.processedNpcBuyRequestOrder + 1] = key
        while #self.processedNpcBuyRequestOrder > self.maxProcessedNpcBuyRequests do
            local evicted = table.remove(self.processedNpcBuyRequestOrder, 1)
            self.processedNpcBuyRequests[evicted] = nil
        end
    end
    GameplayRuntime._emit(self, 'npc_buy_applied', {
        requestId = requestId and tostring(requestId) or nil,
        playerId = player.id,
        itemId = itemId,
        quantity = math.max(1, math.floor(tonumber(quantity) or 0)),
        npcId = npcId,
    })
    return result
end

function GameplayRuntime:sellToNpc(playerId, itemId, quantity, npcId)
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end
    local ok, sellErr = self.economySystem:sellToNpc(player, itemId, quantity or 1, {
        npcId = npcId,
        mapId = player.currentMapId,
    })
    if not ok then return { ok = false, error = sellErr } end
    self.questSystem:onItemRemoved(player, itemId, quantity or 1)
    return { ok = true, player = snapshotPlayer(self, player) }
end

function GameplayRuntime:equipItem(playerId, itemId, instanceId)
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end
    local ok, equipErr = self.itemSystem:equip(player, itemId, instanceId)
    if not ok then return { ok = false, error = equipErr } end
    return { ok = true, player = snapshotPlayer(self, player) }
end

function GameplayRuntime:unequipItem(playerId, slot)
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end
    local ok, unequipErr = self.itemSystem:unequip(player, slot)
    if not ok then return { ok = false, error = unequipErr } end
    return { ok = true, player = snapshotPlayer(self, player) }
end

function GameplayRuntime:castSkill(playerId, skillId, targetSpawnId)
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end
    local target = nil
    if targetSpawnId ~= nil then
        target = self.spawnSystem:getMob(player.currentMapId, tonumber(targetSpawnId))
        if not target then return { ok = false, error = 'mob_not_found' } end
    end
    local ok, resultOrErr = self.skillSystem:cast(player, skillId, target)
    if not ok then return { ok = false, error = resultOrErr } end
    if resultOrErr.type == 'damage' and target then
        local resolved = self:_attackResolved(player, target, math.max(1, tonumber(resultOrErr.amount) or 1), 'skill_cast')
        resolved.cast = deepcopy(resultOrErr)
        return resolved
    end
    GameplayRuntime._emit(self, 'skill_cast', {
        playerId = player.id,
        skillId = skillId,
        resultType = resultOrErr.type,
    })
    return { ok = true, cast = deepcopy(resultOrErr), player = snapshotPlayer(self, player) }
end

function GameplayRuntime:enhanceEquipment(playerId, itemId, slotOrInstanceId)
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end

    local target = nil
    for slot, equipped in pairs(player.equipment or {}) do
        if equipped and equipped.itemId == itemId then
            if slotOrInstanceId == nil or slotOrInstanceId == slot or slotOrInstanceId == equipped.instanceId then
                target = equipped
                break
            end
        end
    end
    if target == nil then
        local entry = player.inventory[itemId]
        if entry and type(entry.instances) == 'table' then
            for _, instance in ipairs(entry.instances) do
                if slotOrInstanceId == nil or slotOrInstanceId == instance.instanceId then
                    target = instance
                    break
                end
            end
        end
    end
    if target == nil then
        return { ok = false, error = 'equipment_target_not_found' }
    end

    local current = math.max(0, math.floor(tonumber(target.enhancement) or 0))
    if current >= 15 then
        return { ok = false, error = 'enhancement_cap_reached' }
    end
    local cost = math.max(100, (current + 1) * 100)
    local ok, spendErr = self.economySystem:spendMesos(player, cost, 'equipment_enhancement', {
        itemId = itemId,
        quantity = 1,
    })
    if not ok then return { ok = false, error = spendErr } end
    target.enhancement = current + 1
    player.dirty = true
    GameplayRuntime._emit(self, 'equipment_enhanced', {
        playerId = player.id,
        itemId = itemId,
        enhancement = target.enhancement,
        cost = cost,
    })
    return {
        ok = true,
        itemId = itemId,
        enhancement = target.enhancement,
        player = snapshotPlayer(self, player),
    }
end

function GameplayRuntime:damageBoss(playerId, amount)
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end
    local encounter = self.bossSystem:getEncounter(player.currentMapId)
    if not encounter then
        local bossId = nil
        for candidateId, def in pairs(self.normalized.bosses) do
            if def.mapId == player.currentMapId then
                bossId = candidateId
                break
            end
        end
        if bossId then
            encounter = self.bossSystem:spawnEncounter(bossId, player.currentMapId)
        end
    end
    if type(encounter) ~= 'table' then
        return { ok = false, error = 'no_active_encounter' }
    end
    local ok, rewardBundles, updated = self.bossSystem:damage(player.currentMapId, player, amount)
    if not ok then return { ok = false, error = rewardBundles } end
    local drops = {}
    if updated and updated.resolved == true then
        for _, bundle in ipairs(rewardBundles or {}) do
            local registered = self.dropSystem:registerDrops(player.currentMapId, updated.position or { x = 0, y = 0, z = 0 }, bundle.drops, {
                ownerId = bundle.playerId,
                ownerScope = 'player',
                sourceSystem = 'boss_encounter',
                bossId = updated.bossId,
                sourceEventId = tostring(updated.bossId) .. ':' .. tostring(updated.killedAt or self.ticks),
            })
            for _, record in ipairs(registered or {}) do
                drops[#drops + 1] = record
            end
            local contributor = self.players[tostring(bundle.playerId)]
            if contributor then
                self.progressionSystem:grantRaidProgress(contributor, 1)
                self.achievementsSystem:unlock(contributor, 'raid_clear')
            end
        end
        GameplayRuntime._emit(self, 'boss_killed', {
            playerId = player.id,
            bossId = updated.bossId,
            dropCount = #drops,
            contributorCount = #((updated.rewardDistribution or {}).eligibleContributors or {}),
        })
    end
    return {
        ok = true,
        boss = deepcopy(updated),
        drops = deepcopy(drops),
        player = snapshotPlayer(self, player),
    }
end

function GameplayRuntime:createParty(playerId)
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end
    local party = self.partySystem:create(player)
    GameplayRuntime._emit(self, 'party_created', { playerId = player.id, partyId = party.id })
    return { ok = true, party = deepcopy(party) }
end

function GameplayRuntime:createGuild(playerId, name)
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end
    local guild = self.guildSystem:create(player, name or ('Guild ' .. tostring(player.id)))
    GameplayRuntime._emit(self, 'guild_created', { playerId = player.id, guildId = guild.id })
    return { ok = true, guild = deepcopy(guild) }
end

function GameplayRuntime:addFriend(playerId, otherPlayerId)
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end
    local ok = self.socialSystem:addFriend(player, tostring(otherPlayerId))
    return { ok = ok == true, social = deepcopy(player.social) }
end

function GameplayRuntime:tradeMesos(fromPlayerId, toPlayerId, amount)
    local request = nil
    if type(fromPlayerId) == 'table' and toPlayerId == nil and amount == nil then
        request = fromPlayerId
    else
        request = GameplayRuntime._coerceRequest(fromPlayerId, toPlayerId, amount)
    end
    if request then
        fromPlayerId = request.fromPlayerId
        toPlayerId = request.toPlayerId
        amount = request.amount
    end
    local fromPlayer, err = GameplayRuntime._resolvePlayer(self, fromPlayerId)
    if not fromPlayer then return { ok = false, error = err } end
    local toPlayer, toErr = GameplayRuntime._resolvePlayer(self, toPlayerId)
    if not toPlayer then return { ok = false, error = toErr } end
    local requestId = request and request.requestId or nil
    if requestId ~= nil then
        local prior = self.processedTradeRequests[tostring(requestId)]
        if prior then
            GameplayRuntime._emit(self, 'trade_mesos_deduped', {
                requestId = tostring(requestId),
                fromPlayerId = fromPlayer.id,
                toPlayerId = toPlayer.id,
                amount = prior.amount,
                outcome = prior.kind,
            })
            local replay = cloneResult(prior.result)
            replay.deduped = true
            replay.requestId = tostring(requestId)
            return replay
        end
    end
    local ok, tradeErr = self.tradingSystem:tradeMesos(fromPlayer, toPlayer, amount, {
        requestId = requestId,
        correlationId = requestId,
    })
    if not ok then return { ok = false, error = tradeErr } end
    local result = {
        ok = true,
        requestId = requestId and tostring(requestId) or nil,
        from = snapshotPlayer(self, fromPlayer),
        to = snapshotPlayer(self, toPlayer),
    }
    if requestId ~= nil then
        local key = tostring(requestId)
        self.processedTradeRequests[key] = {
            kind = 'accepted',
            amount = math.max(1, math.floor(tonumber(amount) or 0)),
            result = cloneResult(result),
        }
        self.processedTradeRequestOrder[#self.processedTradeRequestOrder + 1] = key
        while #self.processedTradeRequestOrder > self.maxProcessedTradeRequests do
            local evicted = table.remove(self.processedTradeRequestOrder, 1)
            self.processedTradeRequests[evicted] = nil
        end
    end
    GameplayRuntime._emit(self, 'trade_mesos_applied', {
        requestId = requestId and tostring(requestId) or nil,
        fromPlayerId = fromPlayer.id,
        toPlayerId = toPlayer.id,
        amount = math.max(1, math.floor(tonumber(amount) or 0)),
    })
    return result
end

function GameplayRuntime:listAuction(playerId, itemId, quantity, price)
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end
    local listingFee = self.economySystem:quoteAuctionListingFee(player, itemId, quantity or 1, price or 1, {
        mapId = player.currentMapId,
    })
    local ok, spendErr = self.economySystem:spendMesos(player, listingFee, 'auction_listing_fee', {
        itemId = itemId,
        quantity = quantity or 1,
    })
    if not ok then return { ok = false, error = spendErr } end
    local removed, removeErr = self.itemSystem:removeItem(player, itemId, quantity or 1)
    if not removed then
        self.economySystem:grantMesos(player, listingFee, 'auction_listing_fee_rollback')
        return { ok = false, error = removeErr }
    end
    local listing = self.auctionHouse:listItem(player, itemId, quantity or 1, price or 1)
    return { ok = true, listing = deepcopy(listing), player = snapshotPlayer(self, player) }
end

function GameplayRuntime:craftItem(playerId, recipeId)
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end
    local recipe = self.craftingRecipes[recipeId]
    if not recipe then return { ok = false, error = 'recipe_not_found' } end
    local ok, resultOrErr = self.craftingSystem:craft(player, recipe)
    if not ok then return { ok = false, error = resultOrErr } end
    return { ok = true, crafted = deepcopy(resultOrErr), player = snapshotPlayer(self, player) }
end

function GameplayRuntime:openDialogue(playerId, npcId)
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end
    local dialogue = self.dialogueSystem:get(npcId)
    if not dialogue then return { ok = false, error = 'dialogue_not_found' } end
    return {
        ok = true,
        playerId = player.id,
        dialogue = deepcopy(dialogue),
    }
end

function GameplayRuntime:channelTransfer(playerId, channelId)
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end
    player.channelId = math.max(1, math.floor(tonumber(channelId) or 1))
    GameplayRuntime._emit(self, 'channel_transfer', {
        playerId = player.id,
        channelId = player.channelId,
        mapId = player.currentMapId,
    })
    return { ok = true, channelId = player.channelId }
end

function GameplayRuntime:getRuntimeStatus()
    return {
        ok = true,
        runtime = 'msw_runtime',
        booted = self.booted == true,
        ticks = self.ticks,
        playerCount = countKeys(self.players),
        onlineCount = self:getActivePlayerCount(),
        mapCount = countKeys(self.content.maps),
        activeDrops = self.dropSystem:activeCount(),
    }
end

function GameplayRuntime:getEconomyReport()
    return {
        ok = true,
        report = self.economySystem:controlReport(),
    }
end

function GameplayRuntime:adminStatus()
    return {
        ok = true,
        runtime = self:getRuntimeStatus(),
        events = self:getStateDelta(math.max(0, self.eventSeq - 10)),
        economy = self.economySystem:snapshot(),
    }
end

function GameplayRuntime:getBuildRecommendation(playerId)
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end
    return {
        ok = true,
        build = self.buildRecommendationSystem:recommend(player),
    }
end

function GameplayRuntime:getTutorialState(playerId)
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end
    return {
        ok = true,
        tutorial = deepcopy(player.tutorial),
        current = deepcopy(self.tutorialSystem:getCurrent(player)),
    }
end

function GameplayRuntime:listPartyFinder()
    local entries = {}
    for _, party in pairs(self.partySystem.parties) do
        entries[#entries + 1] = {
            partyId = party.id,
            leaderId = party.leader,
            raidReady = party.raidReady == true,
            memberCount = countKeys(party.members),
            synergy = deepcopy(party.synergy),
        }
    end
    table.sort(entries, function(a, b) return tostring(a.partyId) < tostring(b.partyId) end)
    return {
        ok = true,
        parties = entries,
    }
end

function GameplayRuntime:createRaid(playerId, bossId, partyId)
    local player, err = GameplayRuntime._resolvePlayer(self, playerId)
    if not player then return { ok = false, error = err } end
    local raid = self.raidSystem:create(bossId or self.defaultBossId, player, partyId or player.partyId)
    local _, synced = self.raidSystem:syncWithParty(raid.id, self)
    return { ok = true, raid = deepcopy(synced or raid) }
end

return GameplayRuntime
