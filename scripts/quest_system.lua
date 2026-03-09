local QuestSystem = {}
local STARTER_SUPPLY_LEVEL_CAP = 15
local STARTER_SUPPLY_MESO_FLOOR = 120

local function markDirty(player)
    if not player then return end
    player.version = (tonumber(player.version) or 0) + 1
    player.dirty = true
end

local function starterSupplyEligible(player)
    if not player then return false end
    if (tonumber(player.level) or 1) > STARTER_SUPPLY_LEVEL_CAP then return false end
    local progression = player.progression or {}
    local milestones = progression.milestones or {}
    return milestones.starter_supply_stipend ~= true
end

local function markStarterSupplyGranted(player)
    if not player then return end
    player.progression = player.progression or {}
    player.progression.milestones = player.progression.milestones or {}
    player.progression.milestones.starter_supply_stipend = true
end

function QuestSystem.new(config)
    local cfg = config or {}
    local self = {
        quests = cfg.quests or {},
        itemSystem = cfg.itemSystem,
        economySystem = cfg.economySystem,
        expSystem = cfg.expSystem,
        logger = cfg.logger,
        metrics = cfg.metrics,
    }
    setmetatable(self, { __index = QuestSystem })
    return self
end

function QuestSystem:_syncCollectObjective(player, state, objective)
    local current = state.progress[objective.targetId] or 0
    local owned = self.itemSystem and self.itemSystem:countItem(player, objective.targetId) or 0
    local nextValue = math.min(objective.required, owned)
    if nextValue ~= current then
        state.progress[objective.targetId] = nextValue
        return true
    end
    return false
end

function QuestSystem:snapshotPlayer(player)
    local out = {}
    for questId, state in pairs((player and player.questState) or {}) do
        out[questId] = {
            accepted = state.accepted == true,
            completed = state.completed == true,
            progress = state.progress,
            ready = self:isComplete(player, questId),
            narrative = self.quests[questId] and self.quests[questId].narrative or nil,
            guidance = self.quests[questId] and self.quests[questId].guidance or nil,
            rewardSummary = self.quests[questId] and self.quests[questId].rewardSummary or nil,
        }
    end
    return out
end

function QuestSystem:accept(player, questId)
    local quest = self.quests[questId]
    if not quest then return false, 'unknown_quest' end
    if quest.requiredLevel and player.level < quest.requiredLevel then return false, 'level_too_low' end

    local state = player.questState[questId]
    if state and state.completed then return false, 'already_completed' end
    if state and state.accepted then return true, 'already_accepted' end

    state = { accepted = true, completed = false, progress = {} }
    for _, objective in ipairs(quest.objectives) do
        if objective.type == 'collect' then
            state.progress[objective.targetId] = math.min(objective.required, self.itemSystem and self.itemSystem:countItem(player, objective.targetId) or 0)
        end
    end
    player.questState[questId] = state
    markDirty(player)
    if self.metrics then self.metrics:increment('quest.accept', 1, { quest = questId }) end
    if self.logger and self.logger.info then self.logger:info('quest_accepted', { playerId = player.id, questId = questId }) end
    return true
end

function QuestSystem:onKill(player, mobId, quantity)
    local amount = math.floor(tonumber(quantity) or 1)
    if amount <= 0 then return false, 'invalid_quantity' end

    local changed = false
    for questId, state in pairs(player.questState) do
        if state.accepted and not state.completed then
            local quest = self.quests[questId]
            for _, objective in ipairs(quest.objectives) do
                if objective.type == 'kill' and objective.targetId == mobId then
                    local current = state.progress[mobId] or 0
                    local nextValue = math.min(objective.required, current + amount)
                    if nextValue ~= current then
                        state.progress[mobId] = nextValue
                        changed = true
                    end
                end
            end
        end
    end
    if changed then markDirty(player) end
    return changed
end

function QuestSystem:onItemChanged(player, itemId)
    local changed = false
    for questId, state in pairs(player.questState) do
        if state.accepted and not state.completed then
            local quest = self.quests[questId]
            for _, objective in ipairs(quest.objectives) do
                if objective.type == 'collect' and objective.targetId == itemId then
                    if self:_syncCollectObjective(player, state, objective) then changed = true end
                end
            end
        end
    end
    if changed then markDirty(player) end
    return changed
end

function QuestSystem:onItemAcquired(player, itemId, quantity)
    local amount = math.floor(tonumber(quantity) or 1)
    if amount <= 0 then return false, 'invalid_quantity' end
    return self:onItemChanged(player, itemId)
end

function QuestSystem:onItemRemoved(player, itemId, quantity)
    local amount = math.floor(tonumber(quantity) or 1)
    if amount <= 0 then return false, 'invalid_quantity' end
    return self:onItemChanged(player, itemId)
end

function QuestSystem:isComplete(player, questId)
    local state = player.questState[questId]
    local quest = self.quests[questId]
    if not state or not quest then return false end
    for _, objective in ipairs(quest.objectives) do
        if (state.progress[objective.targetId] or 0) < objective.required then return false end
    end
    return true
end

function QuestSystem:turnIn(player, questId)
    local quest = self.quests[questId]
    local state = player.questState[questId]
    if not quest or not state or state.completed or not self:isComplete(player, questId) then return false, 'not_ready' end

    local correlationId = string.format('quest_turnin:%s:%s:%s', tostring(player.id), tostring(questId), tostring(os.time()))
    for _, objective in ipairs(quest.objectives) do
        if objective.type == 'collect' then
            local ok = self.itemSystem:removeItem(player, objective.targetId, objective.required, nil, {
                source = 'quest_turnin_requirement',
                quest_id = questId,
                correlation_id = correlationId,
            })
            if not ok then return false, 'missing_required_items' end
            self:onItemRemoved(player, objective.targetId, objective.required)
        end
    end

    state.completed = true
    if quest.rewardMesos and quest.rewardMesos > 0 then
        if self.economySystem then
            self.economySystem:grantMesos(player, quest.rewardMesos, 'quest_reward', { questId = questId, correlationId = correlationId })
        else
            player.mesos = (player.mesos or 0) + quest.rewardMesos
        end
    end
    if quest.rewardItems then
        for _, reward in ipairs(quest.rewardItems) do
            self.itemSystem:addItem(player, reward.itemId, reward.quantity, nil, {
                source = 'quest_reward',
                quest_id = questId,
                correlation_id = correlationId,
            })
            self:onItemAcquired(player, reward.itemId, reward.quantity)
        end
    end
    if quest.rewardExp and quest.rewardExp > 0 then
        if self.expSystem then
            self.expSystem:grant(player, quest.rewardExp)
        else
            player.pendingQuestExp = (player.pendingQuestExp or 0) + quest.rewardExp
        end
    end
    if starterSupplyEligible(player) then
        local questMesos = math.max(0, math.floor(tonumber(quest.rewardMesos) or 0))
        local stipend = math.max(0, STARTER_SUPPLY_MESO_FLOOR - questMesos)
        if stipend > 0 then
            if self.economySystem then
                self.economySystem:grantMesos(player, stipend, 'starter_supply_stipend', { questId = questId, correlationId = correlationId })
            else
                player.mesos = (player.mesos or 0) + stipend
            end
        end
        markStarterSupplyGranted(player)
    end

    markDirty(player)
    if self.metrics then self.metrics:increment('quest.complete', 1, { quest = questId }) end
    if self.logger and self.logger.info then self.logger:info('quest_completed', { playerId = player.id, questId = questId }) end
    return true
end

return QuestSystem
