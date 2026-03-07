local RuntimeAdapter = {}

local function safeGet(source, key)
    if source == nil then return nil end
    local ok, value = pcall(function() return source[key] end)
    if ok then return value end
    return nil
end

local function isArray(value)
    if type(value) ~= 'table' then return false end
    local count = 0
    for key, _ in pairs(value) do
        if type(key) ~= 'number' or key <= 0 or key ~= math.floor(key) then return false end
        count = count + 1
    end
    return count == #value
end

local function serialize(value)
    local valueType = type(value)
    if valueType == 'nil' then return 'nil' end
    if valueType == 'number' or valueType == 'boolean' then return tostring(value) end
    if valueType == 'string' then return string.format('%q', value) end
    if valueType == 'table' then
        local out = {}
        if isArray(value) then
            for i = 1, #value do out[#out + 1] = serialize(value[i]) end
            return '{' .. table.concat(out, ',') .. '}'
        end
        for k, v in pairs(value) do
            out[#out + 1] = '[' .. serialize(k) .. ']=' .. serialize(v)
        end
        return '{' .. table.concat(out, ',') .. '}'
    end
    return 'nil'
end

local function deserialize(serialized)
    if type(serialized) ~= 'string' or serialized == '' then return nil end
    local chunk, err = load('return ' .. serialized)
    if not chunk then return nil, err end
    local ok, value = pcall(chunk)
    if not ok then return nil, value end
    return value
end

local function pick(source, path)
    local current = source
    for i = 1, #path do
        if current == nil then return nil end
        current = safeGet(current, path[i])
    end
    return current
end

local function first(source, paths)
    for _, path in ipairs(paths or {}) do
        local value = pick(source, path)
        if value ~= nil then return value end
    end
    return nil
end

local function normalizeScalar(value)
    if value == nil then return nil end
    if type(value) == 'number' then return value end
    local numeric = tonumber(value)
    if numeric ~= nil then return numeric end
    return nil
end

local function normalizeUserId(value)
    if value == nil then return nil end
    if type(value) ~= 'string' and type(value) ~= 'number' then return nil end
    local userId = tostring(value)
    if userId == '' then return nil end
    return userId
end

local function resolveGlobalService(names)
    for _, name in ipairs(names or {}) do
        local value = rawget(_G, name)
        if value ~= nil then return value end
    end
    return nil
end

function RuntimeAdapter.new(config)
    local cfg = config or {}
    local explicitServices = cfg.services or {}
    local self = {
        metrics = cfg.metrics,
        logger = cfg.logger,
        time = cfg.time or os.time,
        services = {
            UserService = explicitServices.UserService or resolveGlobalService({ '_UserService', 'UserService' }),
            DataStorageService = explicitServices.DataStorageService or resolveGlobalService({ '_DataStorageService', 'DataStorageService' }),
            HttpService = explicitServices.HttpService or resolveGlobalService({ '_HttpService', 'HttpService' }),
            SpawnService = explicitServices.SpawnService or resolveGlobalService({ '_SpawnService', 'SpawnService' }),
            EntityService = explicitServices.EntityService or resolveGlobalService({ '_EntityService', 'EntityService' }),
        },
    }
    setmetatable(self, { __index = RuntimeAdapter })
    return self
end

function RuntimeAdapter:isLive()
    for _, service in pairs(self.services) do
        if service ~= nil then return true end
    end
    return false
end

function RuntimeAdapter:hasDataStorage()
    return self.services.DataStorageService ~= nil
end

function RuntimeAdapter:now()
    return math.floor(tonumber(self.time and self.time()) or os.time())
end

function RuntimeAdapter:encodeData(value)
    local http = self.services.HttpService
    if http and http.JSONEncode then
        local ok, encoded = pcall(function() return http:JSONEncode(value) end)
        if ok then return encoded end
    end
    return serialize(value)
end

function RuntimeAdapter:decodeData(encoded)
    if encoded == nil or encoded == '' then return nil end
    local http = self.services.HttpService
    if http and http.JSONDecode then
        local ok, decoded = pcall(function() return http:JSONDecode(encoded) end)
        if ok then return decoded end
    end
    return deserialize(encoded)
end

function RuntimeAdapter:isAuthoritativeSource(source)
    if source == nil then return false end
    local sourceType = type(source)
    if sourceType == 'userdata' then return true end
    if sourceType ~= 'table' then return false end
    if rawget(source, '__runtime_authoritative') == true or rawget(source, '__authoritative') == true then
        return true
    end
    local mt = getmetatable(source)
    return mt ~= nil
end

function RuntimeAdapter:getUserEntityByUserId(userId)
    local normalized = normalizeUserId(userId)
    if not normalized then return nil end
    local userService = self.services.UserService
    if not userService then return nil end

    local attempts = {
        function() return userService:GetUserEntityByUserId(normalized) end,
        function() return userService:GetUserEntityByUserID(normalized) end,
        function() return userService:GetUserByUserId(normalized) end,
        function() return userService:GetUserByUserID(normalized) end,
        function() return userService:FindUserEntityByUserId(normalized) end,
        function() return userService:FindUserEntityByUserID(normalized) end,
    }
    for _, attempt in ipairs(attempts) do
        local ok, entity = pcall(attempt)
        if ok and entity ~= nil then return entity end
    end
    return nil
end

function RuntimeAdapter:getUserId(source, options)
    local opts = options or {}
    local authoritativeOnly = opts.authoritativeOnly
    if authoritativeOnly == nil then authoritativeOnly = self:isLive() end

    if source == nil then return nil end
    if not authoritativeOnly and (type(source) == 'string' or type(source) == 'number') then
        return normalizeUserId(source)
    end

    if authoritativeOnly and not self:isAuthoritativeSource(source) then
        return nil
    end

    local trusted = {
        { 'SenderUserId' },
        { 'senderUserId' },
        { 'UserId' },
        { 'UserID' },
        { 'PlayerComponent', 'UserId' },
        { 'PlayerComponent', 'UserID' },
        { 'Entity', 'PlayerComponent', 'UserId' },
        { 'Entity', 'PlayerComponent', 'UserID' },
        { 'UserEntity', 'PlayerComponent', 'UserId' },
        { 'UserEntity', 'PlayerComponent', 'UserID' },
        { 'Entity', 'UserId' },
        { 'Entity', 'UserID' },
        { 'UserEntity', 'UserId' },
        { 'UserEntity', 'UserID' },
        { 'Player', 'UserId' },
        { 'Player', 'UserID' },
        { 'User', 'UserId' },
        { 'User', 'UserID' },
    }
    local value = first(source, trusted)
    if value ~= nil then return normalizeUserId(value) end

    if not authoritativeOnly then
        value = first(source, {
            { 'userId' },
            { 'playerId' },
            { 'PlayerComponent', 'userId' },
            { 'User', 'Id' },
        })
        if value ~= nil then return normalizeUserId(value) end
    end
    return nil
end

function RuntimeAdapter:getMapId(source, options)
    local opts = options or {}
    local authoritativeOnly = opts.authoritativeOnly
    if authoritativeOnly == nil then authoritativeOnly = self:isLive() end
    if source == nil then return nil end
    if authoritativeOnly and not self:isAuthoritativeSource(source) then return nil end

    local trusted = {
        { 'CurrentMapName' },
        { 'CurrentMapId' },
        { 'CurrentMapID' },
        { 'MapName' },
        { 'MapId' },
        { 'MapID' },
        { 'MapComponent', 'Name' },
        { 'MapComponent', 'Id' },
        { 'MapComponent', 'ID' },
        { 'Entity', 'CurrentMapName' },
        { 'Entity', 'CurrentMapId' },
        { 'Entity', 'MapComponent', 'Name' },
        { 'Entity', 'MapComponent', 'Id' },
        { 'UserEntity', 'CurrentMapName' },
        { 'UserEntity', 'CurrentMapId' },
        { 'UserEntity', 'MapComponent', 'Name' },
        { 'UserEntity', 'MapComponent', 'Id' },
        { 'PlayerComponent', 'CurrentMapName' },
        { 'PlayerComponent', 'CurrentMapId' },
    }
    local value = first(source, trusted)
    if value ~= nil then return tostring(value) end

    if not authoritativeOnly then
        value = first(source, {
            { 'mapId' },
            { 'currentMapId' },
        })
        if value ~= nil then return tostring(value) end
    end
    return nil
end

function RuntimeAdapter:normalizePosition(value)
    if value == nil then return nil end
    local x = normalizeScalar(safeGet(value, 'x') or safeGet(value, 'X') or safeGet(value, 1))
    local y = normalizeScalar(safeGet(value, 'y') or safeGet(value, 'Y') or safeGet(value, 2))
    local z = normalizeScalar(safeGet(value, 'z') or safeGet(value, 'Z') or safeGet(value, 3)) or 0
    if x == nil or y == nil then return nil end
    return { x = x, y = y, z = z }
end

function RuntimeAdapter:getPosition(source, options)
    local opts = options or {}
    local authoritativeOnly = opts.authoritativeOnly
    if authoritativeOnly == nil then authoritativeOnly = self:isLive() end
    if source == nil then return nil end
    if authoritativeOnly and not self:isAuthoritativeSource(source) then return nil end

    local value = first(source, {
        { 'Position' },
        { 'Transform', 'Position' },
        { 'TransformComponent', 'Position' },
        { 'Entity', 'Position' },
        { 'Entity', 'Transform', 'Position' },
        { 'Entity', 'TransformComponent', 'Position' },
        { 'UserEntity', 'Position' },
        { 'UserEntity', 'Transform', 'Position' },
        { 'UserEntity', 'TransformComponent', 'Position' },
        { 'PlayerComponent', 'Position' },
        { 'TransformComponent', 'WorldPosition' },
    })
    if not authoritativeOnly then
        value = value or first(source, {
            { 'position' },
        })
    end
    return self:normalizePosition(value)
end

function RuntimeAdapter:resolveActorContext(source, options)
    local opts = options or {}
    local authoritativeOnly = opts.authoritativeOnly
    if authoritativeOnly == nil then authoritativeOnly = self:isLive() end

    if authoritativeOnly then
        local senderUserId = normalizeUserId(opts.senderUserId)
        local userId = senderUserId
        local entity = senderUserId and self:getUserEntityByUserId(senderUserId) or nil
        if not userId then
            userId = self:getUserId(source, { authoritativeOnly = true })
        end
        if not entity and userId then
            entity = self:getUserEntityByUserId(userId)
        end
        if not userId and entity then
            userId = self:getUserId(entity, { authoritativeOnly = true })
        end
        if not userId then return nil, 'invalid_user' end

        local mapId = self:getMapId(entity, { authoritativeOnly = true }) or self:getMapId(source, { authoritativeOnly = true })
        local position = self:getPosition(entity, { authoritativeOnly = true }) or self:getPosition(source, { authoritativeOnly = true })
        return {
            userId = userId,
            senderUserId = senderUserId,
            entity = entity,
            mapId = mapId,
            position = position,
            authoritative = true,
        }
    end

    local userId = self:getUserId(source, { authoritativeOnly = false })
    if not userId then return nil, 'invalid_user' end
    return {
        userId = userId,
        mapId = self:getMapId(source, { authoritativeOnly = false }),
        position = self:getPosition(source, { authoritativeOnly = false }),
        authoritative = false,
    }
end

function RuntimeAdapter:distanceSquared(a, b)
    local left = self:normalizePosition(a)
    local right = self:normalizePosition(b)
    if not left or not right then return nil end
    local dx = left.x - right.x
    local dy = left.y - right.y
    local dz = (left.z or 0) - (right.z or 0)
    return (dx * dx) + (dy * dy) + (dz * dz)
end

function RuntimeAdapter:getUserDataStorage(userId, storageName)
    local dataStorageService = self.services.DataStorageService
    if not dataStorageService or not userId then return nil end

    if storageName and storageName ~= '' then
        local attempts = {
            function() return dataStorageService:GetUserDataStorage(storageName, userId) end,
            function() return dataStorageService:GetUserDataStorage(userId, storageName) end,
        }
        for _, attempt in ipairs(attempts) do
            local ok, storage = pcall(attempt)
            if ok and storage ~= nil then return storage end
        end
    end

    local ok, storage = pcall(function() return dataStorageService:GetUserDataStorage(userId) end)
    if ok and storage ~= nil then return storage end
    return nil
end

function RuntimeAdapter:getSharedDataStorage(storageName)
    local dataStorageService = self.services.DataStorageService
    if not dataStorageService or not storageName or storageName == '' then return nil end

    local attempts = {
        function() return dataStorageService:GetSharedDataStorage(storageName) end,
        function() return dataStorageService:GetGlobalDataStorage(storageName) end,
        function() return dataStorageService:GetDataStorage(storageName) end,
        function() return dataStorageService:GetDataStorageByName(storageName) end,
        function() return dataStorageService:GetUserDataStorage(storageName, '__world__') end,
        function() return dataStorageService:GetUserDataStorage('__world__', storageName) end,
    }
    for _, attempt in ipairs(attempts) do
        local ok, storage = pcall(attempt)
        if ok and storage ~= nil then return storage end
    end
    return nil
end

local function pathVariants(path)
    local normalized = tostring(path or '')
    if normalized == '' then return {} end
    local stripped = normalized:gsub('^/+', '')
    local slash = '/' .. stripped
    local variants = { normalized }
    if stripped ~= normalized then variants[#variants + 1] = stripped end
    if slash ~= normalized then variants[#variants + 1] = slash end
    return variants
end

function RuntimeAdapter:findEntityByPath(path)
    local entityService = self.services.EntityService
    if not entityService or not path or path == '' then return nil end

    local attempts = {}
    for _, candidate in ipairs(pathVariants(path)) do
        attempts[#attempts + 1] = function() return entityService:GetEntityByPath(candidate) end
        attempts[#attempts + 1] = function() return entityService:FindEntityByPath(candidate) end
        attempts[#attempts + 1] = function() return entityService:GetEntity(candidate) end
        attempts[#attempts + 1] = function() return entityService:FindEntity(candidate) end
    end

    for _, attempt in ipairs(attempts) do
        local ok, entity = pcall(attempt)
        if ok and entity ~= nil then return entity end
    end
    return nil
end

function RuntimeAdapter:getComponentEntity(component)
    if component == nil then return nil end
    return safeGet(component, 'Entity') or safeGet(component, 'entity') or nil
end

function RuntimeAdapter:makeVector3(x, y, z)
    local ctor = rawget(_G, 'Vector3')
    if type(ctor) == 'function' then
        local ok, value = pcall(ctor, tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0)
        if ok then return value end
    end
    return { x = tonumber(x) or 0, y = tonumber(y) or 0, z = tonumber(z) or 0 }
end

function RuntimeAdapter:setEntityPosition(entity, position)
    local normalized = self:normalizePosition(position)
    if not entity or not normalized then return false end
    local vector = self:makeVector3(normalized.x, normalized.y, normalized.z or 0)
    local attempts = {
        function()
            local transformComponent = safeGet(entity, 'TransformComponent')
            if transformComponent then transformComponent.Position = vector return true end
        end,
        function()
            local transform = safeGet(entity, 'Transform')
            if transform then transform.Position = vector return true end
        end,
        function()
            entity.Position = vector
            return true
        end,
        function()
            if entity.SetPosition then entity:SetPosition(vector) return true end
        end,
    }
    for _, attempt in ipairs(attempts) do
        local ok, applied = pcall(attempt)
        if ok and applied then return true end
    end
    return false
end

function RuntimeAdapter:spawnModel(modelId, name, position, parent)
    local spawnService = self.services.SpawnService
    if not spawnService or not modelId or modelId == '' then return nil end

    local spawnName = name or 'SpawnedEntity'
    local spawnPosition = self:normalizePosition(position) or { x = 0, y = 0, z = 0 }
    local vector = self:makeVector3(spawnPosition.x, spawnPosition.y, spawnPosition.z)
    local attempts = {
        function() return spawnService:SpawnByModelId(modelId, spawnName, vector, parent) end,
        function() return spawnService:SpawnByModelID(modelId, spawnName, vector, parent) end,
        function() return spawnService:SpawnEntityByModelId(modelId, spawnName, vector, parent) end,
        function() return spawnService:SpawnEntityByModelID(modelId, spawnName, vector, parent) end,
        function() return spawnService:SpawnByTemplateId(modelId, spawnName, vector, parent) end,
        function() return spawnService:SpawnByAssetId(modelId, spawnName, vector, parent) end,
        function() return spawnService:SpawnByModelId(modelId, vector, parent) end,
        function() return spawnService:SpawnByModelId(modelId, parent, vector) end,
    }

    for _, attempt in ipairs(attempts) do
        local ok, entity = pcall(attempt)
        if ok and entity ~= nil then
            self:setEntityPosition(entity, spawnPosition)
            return entity
        end
    end
    return nil
end

function RuntimeAdapter:destroyEntity(entity)
    if entity == nil then return false end
    local entityService = self.services.EntityService
    if entityService then
        local attempts = {
            function() if entityService.Destroy then entityService:Destroy(entity) return true end end,
            function() if entityService.DestroyEntity then entityService:DestroyEntity(entity) return true end end,
            function() if entityService.RemoveEntity then entityService:RemoveEntity(entity) return true end end,
        }
        for _, attempt in ipairs(attempts) do
            local ok, removed = pcall(attempt)
            if ok and removed then return true end
        end
    end
    if type(entity) == 'table' then
        local attempts = {
            function() if entity.Destroy then entity:Destroy() return true end end,
            function() if entity.Remove then entity:Remove() return true end end,
        }
        for _, attempt in ipairs(attempts) do
            local ok, removed = pcall(attempt)
            if ok and removed then return true end
        end
    end
    return false
end

return RuntimeAdapter
