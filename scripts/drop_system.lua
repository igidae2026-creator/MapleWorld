local DropSystem = {}

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

function DropSystem.new(config)
    local cfg = config or {}
    local self = {
        dropTable = cfg.dropTable or {},
        items = cfg.items or {},
        logger = cfg.logger,
        metrics = cfg.metrics,
        rng = cfg.rng or math.random,
        time = cfg.time or os.time,
        activeDrops = {},
        dropsByMap = {},
        nextDropId = 1,
        dropExpireSec = tonumber(cfg.dropExpireSec) or 90,
        ownerWindowSec = tonumber(cfg.ownerWindowSec) or 2,
        maxActivePerMap = tonumber(cfg.maxActivePerMap) or 250,
    }
    setmetatable(self, { __index = DropSystem })
    return self
end

function DropSystem:_now()
    return math.floor(tonumber(self.time()) or os.time())
end

local function rollChance(rng, chance)
    local roll = tonumber(rng()) or 0
    return roll <= chance
end

function DropSystem:rollDrops(mob, player)
    local mobId = mob and mob.mobId or nil
    local entries = self.dropTable[mobId] or {}
    local drops = {}
    for _, entry in ipairs(entries) do
        local chance = tonumber(entry.chance) or 0
        local minQty = math.floor(tonumber(entry.minQty) or 1)
        local maxQty = math.floor(tonumber(entry.maxQty) or minQty)
        local itemDef = self.items[entry.itemId]
        if itemDef and chance > 0 and chance <= 1 and minQty > 0 and maxQty >= minQty and rollChance(self.rng, chance) then
            local quantity = minQty
            if maxQty > minQty then
                quantity = minQty + math.floor((tonumber(self.rng()) or 0) * (maxQty - minQty + 1))
                if quantity > maxQty then quantity = maxQty end
            end
            drops[#drops + 1] = {
                itemId = entry.itemId,
                quantity = quantity,
                sourceMob = mobId,
                bindOnPickup = entry.bindOnPickup or false,
                rarity = entry.rarity or 'common',
            }
            if self.metrics then self.metrics:increment('drop.item', quantity, { item = entry.itemId, mob = tostring(mobId) }) end
        end
    end
    if self.logger and self.logger.info then
        self.logger:info('drops_rolled', { playerId = player and player.id or nil, mobId = mobId, dropCount = #drops })
    end
    return drops
end

function DropSystem:_mapDrops(mapId)
    local mapDrops = self.dropsByMap[mapId]
    if not mapDrops then
        mapDrops = {}
        self.dropsByMap[mapId] = mapDrops
    end
    return mapDrops
end

function DropSystem:_trimOverflow(mapId)
    if self.maxActivePerMap <= 0 then return end
    local mapDrops = self.dropsByMap[mapId] or {}
    local ordered = {}
    for _, record in pairs(mapDrops) do ordered[#ordered + 1] = record end
    if #ordered < self.maxActivePerMap then return end

    table.sort(ordered, function(a, b)
        local aExpire = tonumber(a.expiresAt) or math.huge
        local bExpire = tonumber(b.expiresAt) or math.huge
        if aExpire == bExpire then return (tonumber(a.dropId) or 0) < (tonumber(b.dropId) or 0) end
        return aExpire < bExpire
    end)

    while #ordered >= self.maxActivePerMap do
        local victim = table.remove(ordered, 1)
        if victim then self:_removeDrop(victim) end
    end
end

function DropSystem:registerDrops(mapId, source, drops, context)
    local mapDrops = self:_mapDrops(mapId)
    local cfg = context or {}
    local now = math.floor(tonumber(cfg.now) or self:_now())
    local ownerId = cfg.ownerId
    local ownerWindow = tonumber(cfg.ownerWindowSec) or self.ownerWindowSec
    local position = source and (source.position or source) or {}
    local x = tonumber(position.x) or tonumber(source and source.x) or 0
    local y = tonumber(position.y) or tonumber(source and source.y) or 0
    local z = tonumber(position.z) or tonumber(source and source.z) or 0
    local registered = {}

    for _, drop in ipairs(drops or {}) do
        self:_trimOverflow(mapId)
        local dropId = self.nextDropId
        self.nextDropId = self.nextDropId + 1
        local record = {
            dropId = dropId,
            mapId = mapId,
            itemId = drop.itemId,
            quantity = drop.quantity,
            rarity = drop.rarity,
            bindOnPickup = drop.bindOnPickup,
            sourceMob = drop.sourceMob,
            ownerId = ownerId,
            ownerUntil = ownerId and (now + ownerWindow) or nil,
            x = x,
            y = y,
            z = z,
            createdAt = now,
            expiresAt = now + self.dropExpireSec,
        }
        self.activeDrops[dropId] = record
        mapDrops[dropId] = record
        registered[#registered + 1] = record
    end

    if self.metrics then self.metrics:gauge('drop.active', self:activeCount()) end
    return registered
end

function DropSystem:getDrop(dropId)
    return self.activeDrops[dropId]
end

function DropSystem:listDrops(mapId)
    local out = {}
    local mapDrops = self.dropsByMap[mapId] or {}
    for _, drop in pairs(mapDrops) do out[#out + 1] = drop end
    table.sort(out, function(a, b) return a.dropId < b.dropId end)
    return out
end

function DropSystem:listAllDrops()
    local out = {}
    for _, record in pairs(self.activeDrops) do out[#out + 1] = record end
    table.sort(out, function(a, b) return a.dropId < b.dropId end)
    return out
end

function DropSystem:activeCount(mapId)
    if mapId then
        local count = 0
        for _ in pairs(self.dropsByMap[mapId] or {}) do count = count + 1 end
        return count
    end
    local count = 0
    for _ in pairs(self.activeDrops) do count = count + 1 end
    return count
end

function DropSystem:_removeDrop(record)
    if not record then return nil end
    self.activeDrops[record.dropId] = nil
    local mapDrops = self.dropsByMap[record.mapId]
    if mapDrops then mapDrops[record.dropId] = nil end
    if self.metrics then self.metrics:gauge('drop.active', self:activeCount()) end
    return record
end

function DropSystem:pickupDrop(player, mapId, dropId, itemSystem, context)
    local record = self.activeDrops[dropId]
    if not record or record.mapId ~= mapId then return false, 'drop_not_found' end
    local cfg = context or {}
    local now = math.floor(tonumber(cfg.now) or self:_now())
    if record.ownerId and record.ownerUntil and now < record.ownerUntil and player and player.id ~= record.ownerId then
        return false, 'drop_reserved'
    end
    local added, err = itemSystem:addItem(player, record.itemId, record.quantity)
    if not added then return false, err end
    record.pickedBy = player and player.id or nil
    record.pickedAt = now
    self:_removeDrop(record)
    if self.metrics then self.metrics:increment('drop.pickup', record.quantity, { item = record.itemId }) end
    return true, record
end

function DropSystem:expireDrops(now)
    local expired = {}
    local current = math.floor(tonumber(now) or self:_now())
    for _, record in pairs(self.activeDrops) do
        if (tonumber(record.expiresAt) or current) <= current then
            expired[#expired + 1] = self:_removeDrop(record)
        end
    end
    return expired
end

function DropSystem:snapshot()
    local dropsByMap = {}
    for mapId, records in pairs(self.dropsByMap) do
        local bucket = {}
        for _, record in pairs(records) do
            bucket[#bucket + 1] = deepcopy(record)
        end
        table.sort(bucket, function(a, b) return (tonumber(a.dropId) or 0) < (tonumber(b.dropId) or 0) end)
        dropsByMap[mapId] = bucket
    end
    return {
        nextDropId = self.nextDropId,
        drops = deepcopy(self:listAllDrops()),
        dropsByMap = dropsByMap,
    }
end

function DropSystem:restore(snapshot)
    self.activeDrops = {}
    self.dropsByMap = {}
    self.nextDropId = 1

    local restoredNext = tonumber(snapshot and snapshot.nextDropId) or 1
    local now = self:_now()
    local highest = 0
    local records = {}
    if type(snapshot and snapshot.dropsByMap) == 'table' then
        for mapId, mapRecords in pairs(snapshot.dropsByMap) do
            if type(mapRecords) == 'table' then
                for _, record in ipairs(mapRecords) do
                    local copy = deepcopy(record)
                    if copy and copy.mapId == nil then copy.mapId = mapId end
                    records[#records + 1] = copy
                end
            end
        end
    end
    for _, record in ipairs((snapshot and snapshot.drops) or {}) do
        records[#records + 1] = record
    end

    local seenDropIds = {}
    table.sort(records, function(a, b)
        return (tonumber(a and a.dropId) or 0) < (tonumber(b and b.dropId) or 0)
    end)
    for _, record in ipairs(records) do
        if type(record) == 'table' then
            local copy = deepcopy(record)
            local dropId = math.floor(tonumber(copy.dropId) or 0)
            local mapId = copy.mapId
            local expiresAt = tonumber(copy.expiresAt) or 0
            if dropId > 0 and mapId and expiresAt > now and not seenDropIds[dropId] then
                seenDropIds[dropId] = true
                self.activeDrops[dropId] = copy
                self:_mapDrops(mapId)[dropId] = copy
                if dropId > highest then highest = dropId end
            end
        end
    end
    self.nextDropId = math.max(restoredNext, highest + 1)
    if self.metrics then self.metrics:gauge('drop.active', self:activeCount()) end
end

return DropSystem
