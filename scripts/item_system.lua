local ItemSystem = {}

local SLOT_BY_TYPE = {
    weapon = 'weapon',
    armor = 'overall',
    overall = 'overall',
    hat = 'hat',
    glove = 'glove',
    shoe = 'shoe',
    accessory = 'accessory',
}

local function isPositiveInteger(value)
    return type(value) == 'number' and value > 0 and value == math.floor(value)
end

local function markDirty(player)
    if not player then return end
    player.version = (tonumber(player.version) or 0) + 1
    player.dirty = true
end

local function observeInstanceId(player, instanceId)
    local suffix = type(instanceId) == 'string' and tonumber(instanceId:match('#(%d+)$')) or nil
    if suffix and suffix >= (tonumber(player.nextItemInstanceId) or 1) then
        player.nextItemInstanceId = suffix + 1
    end
end

function ItemSystem.new(config)
    local cfg = config or {}
    local self = {
        items = cfg.items or {},
        logger = cfg.logger,
        metrics = cfg.metrics,
        ledgerSink = cfg.ledgerSink,
        suspiciousItemQuantity = tonumber(cfg.suspiciousItemQuantity) or 1000,
    }
    setmetatable(self, { __index = ItemSystem })
    return self
end

function ItemSystem:createPlayerProfile(playerId)
    return {
        id = playerId,
        level = 1,
        maxLevel = 200,
        exp = 0,
        mesos = 0,
        stats = { str = 4, dex = 4, int = 4, luk = 4, hp = 50, mp = 25 },
        inventory = {},
        equipment = { weapon=nil, overall=nil, hat=nil, glove=nil, shoe=nil, accessory=nil },
        questState = {},
        killLog = {},
        flags = {},
        currentMapId = nil,
        nextItemInstanceId = 1,
        version = 0,
        dirty = true,
    }
end

function ItemSystem:_slotFor(itemDef)
    if not itemDef or itemDef.stackable then return nil end
    return SLOT_BY_TYPE[itemDef.type]
end

function ItemSystem:_emitLedger(event)
    if type(self.ledgerSink) ~= 'function' then return nil end
    return self.ledgerSink(event)
end

function ItemSystem:_makeInstance(player, itemId, template)
    template = template or {}
    local instanceId = template.instanceId
    if not instanceId or instanceId == '' then
        instanceId = tostring(itemId) .. '#' .. tostring(tonumber(player.nextItemInstanceId) or 1)
        player.nextItemInstanceId = (tonumber(player.nextItemInstanceId) or 1) + 1
    else
        observeInstanceId(player, instanceId)
    end
    local lineage = type(template.lineage) == 'table' and template.lineage or {}
    return {
        itemId = itemId,
        instanceId = instanceId,
        enhancement = tonumber(template.enhancement) or 0,
        lineage = {
            created_by_event = lineage.created_by_event or template.created_by_event,
            created_from_source = lineage.created_from_source or template.created_from_source,
            current_owner = lineage.current_owner or player.id,
            last_mutation_event = lineage.last_mutation_event,
            destruction_event = lineage.destruction_event,
        },
    }
end

function ItemSystem:sanitizePlayerProfile(player, playerId)
    local profile = player or self:createPlayerProfile(playerId)
    profile.id = profile.id or playerId
    profile.level = math.max(1, math.floor(tonumber(profile.level) or 1))
    profile.maxLevel = math.max(profile.level, math.floor(tonumber(profile.maxLevel) or 200))
    profile.exp = math.max(0, math.floor(tonumber(profile.exp) or 0))
    profile.mesos = math.max(0, math.floor(tonumber(profile.mesos) or 0))
    profile.stats = type(profile.stats) == 'table' and profile.stats or {}
    profile.stats.str = tonumber(profile.stats.str) or 4
    profile.stats.dex = tonumber(profile.stats.dex) or 4
    profile.stats.int = tonumber(profile.stats.int) or 4
    profile.stats.luk = tonumber(profile.stats.luk) or 4
    profile.stats.hp = tonumber(profile.stats.hp) or 50
    profile.stats.mp = tonumber(profile.stats.mp) or 25
    profile.inventory = type(profile.inventory) == 'table' and profile.inventory or {}
    profile.equipment = type(profile.equipment) == 'table' and profile.equipment or {}
    profile.questState = type(profile.questState) == 'table' and profile.questState or {}
    profile.killLog = type(profile.killLog) == 'table' and profile.killLog or {}
    profile.flags = type(profile.flags) == 'table' and profile.flags or {}
    profile.nextItemInstanceId = math.max(1, math.floor(tonumber(profile.nextItemInstanceId) or 1))
    profile.version = tonumber(profile.version) or 0
    profile.dirty = profile.dirty == true

    for itemId, entry in pairs(profile.inventory) do
        local itemDef = self.items[itemId]
        local quantity = math.floor(tonumber(entry and entry.quantity) or 0)
        if quantity <= 0 then
            profile.inventory[itemId] = nil
        else
            local normalized = { itemId = itemId, quantity = quantity, enhancement = tonumber(entry and entry.enhancement) or 0 }
            if itemDef and itemDef.stackable == false then
                normalized.instances = {}
                if type(entry.instances) == 'table' then
                    for _, instance in ipairs(entry.instances) do
                        if type(instance) == 'table' and instance.instanceId then
                            normalized.instances[#normalized.instances + 1] = self:_makeInstance(profile, itemId, instance)
                        end
                    end
                end
                while #normalized.instances < quantity do
                    normalized.instances[#normalized.instances + 1] = self:_makeInstance(profile, itemId, { enhancement = normalized.enhancement })
                end
                while #normalized.instances > quantity do table.remove(normalized.instances) end
                normalized.quantity = #normalized.instances
            end
            profile.inventory[itemId] = normalized
        end
    end

    for _, slot in pairs(SLOT_BY_TYPE) do
        local equipped = profile.equipment[slot]
        if equipped and equipped.itemId then
            profile.equipment[slot] = {
                itemId = equipped.itemId,
                instanceId = equipped.instanceId,
                enhancement = tonumber(equipped.enhancement) or 0,
                lineage = equipped.lineage,
            }
            if equipped.instanceId then observeInstanceId(profile, equipped.instanceId) end
        else
            profile.equipment[slot] = nil
        end
    end
    return profile
end

function ItemSystem:countItem(player, itemId)
    local entry = player and player.inventory and player.inventory[itemId] or nil
    return entry and math.floor(tonumber(entry.quantity) or 0) or 0
end

function ItemSystem:exportInventory(player)
    local out = {}
    for itemId, entry in pairs((player and player.inventory) or {}) do
        local copy = { itemId = itemId, quantity = math.floor(tonumber(entry.quantity) or 0), enhancement = tonumber(entry.enhancement) or 0 }
        if type(entry.instances) == 'table' then
            copy.instances = {}
            for i, instance in ipairs(entry.instances) do
                copy.instances[i] = {
                    itemId = instance.itemId,
                    instanceId = instance.instanceId,
                    enhancement = tonumber(instance.enhancement) or 0,
                    lineage = instance.lineage,
                }
            end
        end
        out[itemId] = copy
    end
    return out
end

function ItemSystem:addItem(player, itemId, quantity, metadata, context)
    local amount = math.floor(tonumber(quantity or 1) or 0)
    if not player then return false, 'invalid_player' end
    if not isPositiveInteger(amount) then return false, 'invalid_quantity' end

    local itemDef = self.items[itemId]
    if not itemDef then return false, 'unknown_item' end

    local ctx = type(context) == 'table' and context or {}
    local entry = player.inventory[itemId]
    if not entry then
        entry = { itemId = itemId, quantity = 0, enhancement = 0 }
        player.inventory[itemId] = entry
    end

    local createdInstances = {}
    if itemDef.stackable then
        local before = math.floor(tonumber(entry.quantity) or 0)
        entry.quantity = before + amount
        entry.enhancement = tonumber(entry.enhancement) or 0
        self:_emitLedger({
            event_type = 'item_grant', actor_id = player.id, player_id = player.id, source_system = 'item_system',
            correlation_id = ctx.correlation_id, source_event_id = ctx.source_event_id, item_id = itemId, quantity = amount,
            pre_state = { quantity = before }, post_state = { quantity = entry.quantity },
            idempotency_key = ctx.idempotency_key or string.format('item_add:%s:%s:%s', tostring(player.id), tostring(itemId), tostring(ctx.correlation_id or os.time())),
            metadata = { source = ctx.source or 'unknown', stackable = true },
        })
    else
        entry.instances = type(entry.instances) == 'table' and entry.instances or {}
        if type(metadata) == 'table' and type(metadata.instances) == 'table' then
            for _, instance in ipairs(metadata.instances) do
                local made = self:_makeInstance(player, itemId, instance)
                entry.instances[#entry.instances + 1] = made
                createdInstances[#createdInstances + 1] = made
            end
            while #createdInstances < amount do
                local made = self:_makeInstance(player, itemId, metadata)
                entry.instances[#entry.instances + 1] = made
                createdInstances[#createdInstances + 1] = made
            end
        else
            for _ = 1, amount do
                local made = self:_makeInstance(player, itemId, metadata)
                entry.instances[#entry.instances + 1] = made
                createdInstances[#createdInstances + 1] = made
            end
        end
        entry.quantity = #entry.instances
        for _, instance in ipairs(createdInstances) do
            local ledgerEntry = self:_emitLedger({
                event_type = 'item_create', actor_id = player.id, player_id = player.id, source_system = 'item_system',
                correlation_id = ctx.correlation_id, source_event_id = ctx.source_event_id, item_id = itemId,
                item_instance_id = instance.instanceId, quantity = 1, pre_state = { owner = nil }, post_state = { owner = player.id, location = 'inventory' },
                idempotency_key = string.format('item_create:%s:%s', tostring(player.id), tostring(instance.instanceId)),
                metadata = { source = ctx.source or 'unknown' },
            })
            instance.lineage.created_by_event = instance.lineage.created_by_event or (ledgerEntry and ledgerEntry.ledger_event_id)
            instance.lineage.created_from_source = instance.lineage.created_from_source or (ctx.source or 'unknown')
            instance.lineage.current_owner = player.id
            instance.lineage.last_mutation_event = ledgerEntry and ledgerEntry.ledger_event_id or instance.lineage.last_mutation_event
        end
    end

    if amount >= self.suspiciousItemQuantity then
        if self.metrics then self.metrics:increment('item.suspicious_grant', 1, { item = tostring(itemId) }) end
        if self.logger and self.logger.info then self.logger:info('item_suspicious_grant', { playerId = player.id, itemId = itemId, amount = amount }) end
    end

    markDirty(player)
    if self.metrics then self.metrics:increment('item.add', amount, { item = itemId }) end
    if self.logger and self.logger.info then self.logger:info('item_added', { playerId = player.id, itemId = itemId, quantity = amount }) end
    return true
end

function ItemSystem:removeItem(player, itemId, quantity, instanceId, context)
    local amount = math.floor(tonumber(quantity or 1) or 0)
    if not player then return false, 'invalid_player' end
    if not isPositiveInteger(amount) then return false, 'invalid_quantity' end

    local itemDef = self.items[itemId]
    local entry = player.inventory[itemId]
    if not entry then return false, 'insufficient_items' end

    local ctx = type(context) == 'table' and context or {}
    local removedInstances = {}
    if itemDef and itemDef.stackable == false and type(entry.instances) == 'table' then
        if entry.quantity < amount then return false, 'insufficient_items' end
        local removed = 0
        if instanceId then
            for index, instance in ipairs(entry.instances) do
                if instance.instanceId == instanceId then
                    removedInstances[#removedInstances + 1] = instance
                    table.remove(entry.instances, index)
                    removed = removed + 1
                    break
                end
            end
            if removed == 0 then return false, 'instance_not_found' end
        end
        while removed < amount do
            if #entry.instances == 0 then return false, 'insufficient_items' end
            removedInstances[#removedInstances + 1] = table.remove(entry.instances)
            removed = removed + 1
        end
        entry.quantity = #entry.instances
    else
        if entry.quantity < amount then return false, 'insufficient_items' end
        local before = entry.quantity
        entry.quantity = entry.quantity - amount
        self:_emitLedger({
            event_type = 'item_destroy', actor_id = player.id, player_id = player.id, source_system = 'item_system',
            correlation_id = ctx.correlation_id, source_event_id = ctx.source_event_id, item_id = itemId, quantity = amount,
            pre_state = { quantity = before }, post_state = { quantity = entry.quantity },
            idempotency_key = ctx.idempotency_key or string.format('item_remove:%s:%s:%s', tostring(player.id), tostring(itemId), tostring(ctx.correlation_id or os.time())),
            metadata = { source = ctx.source or 'unknown', stackable = true },
        })
    end

    for _, instance in ipairs(removedInstances) do
        local ledgerEntry = self:_emitLedger({
            event_type = 'item_destroy', actor_id = player.id, player_id = player.id, source_system = 'item_system',
            correlation_id = ctx.correlation_id, source_event_id = ctx.source_event_id, item_id = itemId, item_instance_id = instance.instanceId, quantity = 1,
            pre_state = { owner = player.id }, post_state = { owner = nil },
            idempotency_key = string.format('item_destroy:%s:%s:%s', tostring(player.id), tostring(instance.instanceId), tostring(ctx.correlation_id or os.time())),
            metadata = { source = ctx.source or 'unknown' },
        })
        instance.lineage = instance.lineage or {}
        instance.lineage.current_owner = nil
        instance.lineage.last_mutation_event = ledgerEntry and ledgerEntry.ledger_event_id or instance.lineage.last_mutation_event
        instance.lineage.destruction_event = ledgerEntry and ledgerEntry.ledger_event_id or instance.lineage.destruction_event
    end

    if entry.quantity <= 0 then player.inventory[itemId] = nil end
    if entry.quantity < 0 then return false, 'negative_inventory' end
    markDirty(player)
    if self.metrics then self.metrics:increment('item.remove', amount, { item = itemId }) end
    return true
end

function ItemSystem:_takeEquipInstance(player, itemId, instanceId)
    local entry = player.inventory[itemId]
    if not entry or entry.quantity <= 0 then return false, 'item_not_in_inventory' end
    local itemDef = self.items[itemId]
    if not itemDef or itemDef.stackable then return false, 'item_not_equippable' end
    if type(entry.instances) ~= 'table' then return false, 'inventory_state_invalid' end
    if #entry.instances ~= math.floor(tonumber(entry.quantity) or 0) then return false, 'inventory_state_invalid' end

    local chosen = nil
    if instanceId then
        for index, instance in ipairs(entry.instances) do
            if instance.instanceId == instanceId then
                chosen = instance
                table.remove(entry.instances, index)
                break
            end
        end
        if not chosen then return false, 'instance_not_found' end
    else
        chosen = table.remove(entry.instances)
    end
    entry.quantity = #entry.instances
    if not chosen then return false, 'instance_not_found' end
    if entry.quantity <= 0 then player.inventory[itemId] = nil end
    return true, chosen
end

function ItemSystem:_peekEquipInstance(player, itemId, instanceId)
    local entry = player.inventory[itemId]
    if not entry or entry.quantity <= 0 then return false, 'item_not_in_inventory' end
    local itemDef = self.items[itemId]
    if not itemDef or itemDef.stackable then return false, 'item_not_equippable' end
    if type(entry.instances) ~= 'table' then return false, 'inventory_state_invalid' end
    if #entry.instances ~= math.floor(tonumber(entry.quantity) or 0) then return false, 'inventory_state_invalid' end

    if instanceId then
        for _, instance in ipairs(entry.instances) do
            if instance.instanceId == instanceId then return true, instance end
        end
        return false, 'instance_not_found'
    end
    local selected = entry.instances[#entry.instances]
    if not selected then return false, 'instance_not_found' end
    return true, selected
end

function ItemSystem:equip(player, itemId, instanceId, context)
    if not player then return false, 'invalid_player' end

    local itemDef = self.items[itemId]
    if not itemDef then return false, 'unknown_item' end
    if itemDef.stackable then return false, 'item_not_equippable' end
    if not player.inventory[itemId] then return false, 'item_not_in_inventory' end

    local slot = self:_slotFor(itemDef)
    if not slot then return false, 'item_not_equippable' end
    if itemDef.requiredLevel and player.level < itemDef.requiredLevel then return false, 'level_too_low' end

    local previewOk, previewOrErr = self:_peekEquipInstance(player, itemId, instanceId)
    if not previewOk then return false, previewOrErr end
    local targetInstanceId = previewOrErr.instanceId

    local removed, instanceOrError = self:_takeEquipInstance(player, itemId, targetInstanceId)
    if not removed then return false, instanceOrError end

    local current = player.equipment[slot]
    if current then
        local ok, err = self:addItem(player, current.itemId, 1, { instances = { current } }, { source = 'unequip_swap' })
        if not ok then
            self:addItem(player, itemId, 1, { instances = { instanceOrError } }, { source = 'equip_rollback' })
            return false, err
        end
    end

    player.equipment[slot] = { itemId = itemId, instanceId = instanceOrError.instanceId, enhancement = tonumber(instanceOrError.enhancement) or 0, lineage = instanceOrError.lineage }
    local ledgerEntry = self:_emitLedger({
        event_type = 'item_transfer', actor_id = player.id, player_id = player.id, source_system = 'item_system',
        correlation_id = context and context.correlation_id, item_id = itemId, item_instance_id = instanceOrError.instanceId, quantity = 1,
        pre_state = { owner = player.id, location = 'inventory' }, post_state = { owner = player.id, location = 'equipment:' .. tostring(slot) },
        idempotency_key = string.format('equip:%s:%s', tostring(player.id), tostring(instanceOrError.instanceId)),
        metadata = { action = 'equip', slot = slot },
    })
    instanceOrError.lineage = instanceOrError.lineage or {}
    instanceOrError.lineage.current_owner = player.id
    instanceOrError.lineage.last_mutation_event = ledgerEntry and ledgerEntry.ledger_event_id or instanceOrError.lineage.last_mutation_event
    markDirty(player)
    if self.metrics then self.metrics:increment('item.equip', 1, { item = itemId, slot = slot }) end
    if self.logger and self.logger.info then self.logger:info('item_equipped', { playerId = player.id, itemId = itemId, slot = slot }) end
    return true
end

function ItemSystem:unequip(player, slot, context)
    if not player then return false, 'invalid_player' end
    local equipped = player.equipment[slot]
    if not equipped then return false, 'slot_empty' end
    local itemDef = self.items[equipped.itemId]
    if not itemDef or itemDef.stackable then return false, 'invalid_equipment_state' end
    local expectedSlot = self:_slotFor(itemDef)
    if expectedSlot ~= slot then return false, 'invalid_equipment_state' end

    local ok, err = self:addItem(player, equipped.itemId, 1, { instances = { equipped } }, { source = 'unequip', correlation_id = context and context.correlation_id })
    if not ok then return false, err end
    player.equipment[slot] = nil
    local ledgerEntry = self:_emitLedger({
        event_type = 'item_transfer', actor_id = player.id, player_id = player.id, source_system = 'item_system',
        correlation_id = context and context.correlation_id, item_id = equipped.itemId, item_instance_id = equipped.instanceId, quantity = 1,
        pre_state = { owner = player.id, location = 'equipment:' .. tostring(slot) }, post_state = { owner = player.id, location = 'inventory' },
        idempotency_key = string.format('unequip:%s:%s', tostring(player.id), tostring(equipped.instanceId)),
        metadata = { action = 'unequip', slot = slot },
    })
    equipped.lineage = equipped.lineage or {}
    equipped.lineage.last_mutation_event = ledgerEntry and ledgerEntry.ledger_event_id or equipped.lineage.last_mutation_event
    markDirty(player)
    if self.metrics then self.metrics:increment('item.unequip', 1, { slot = tostring(slot) }) end
    return true
end

function ItemSystem:getPower(player)
    local power = (tonumber(player and player.level) or 1) * 5
    local equipment = (player and player.equipment) or {}
    for _, equipped in pairs(equipment) do
        if equipped then
            local itemDef = self.items[equipped.itemId]
            if itemDef then
                power = power + (tonumber(itemDef.attack) or 0) + (tonumber(itemDef.defense) or 0) + (tonumber(equipped.enhancement) or 0)
            end
        end
    end
    return power
end

return ItemSystem
