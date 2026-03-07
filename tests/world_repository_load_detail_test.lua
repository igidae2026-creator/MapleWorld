package.path = package.path .. ';./?.lua;../?.lua'
local WorldRepository = require('ops.world_repository')

local memoryRepo = WorldRepository.newMemory({})
local value, status, err = memoryRepo:loadDetailed()
assert(value == nil and status == 'not_found' and err == nil, 'memory world repo miss classification incorrect')

local brokenRepo = {
    load = function() return nil, 'storage_unavailable' end,
}
setmetatable(brokenRepo, { __index = WorldRepository })
local _, brokenStatus, brokenErr = brokenRepo:loadDetailed()
assert(brokenStatus == 'storage_unavailable' and brokenErr == 'storage_unavailable', 'storage unavailable classification incorrect')

print('world_repository_load_detail_test: ok')
