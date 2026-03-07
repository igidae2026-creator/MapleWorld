package.path = package.path .. ';./?.lua;../?.lua'

local ServerBootstrap = require('scripts.server_bootstrap')
local RuntimeAdapter = require('ops.runtime_adapter')

local reportType = arg and arg[1] or 'status'
local world = ServerBootstrap.boot('.', { autoPickupDrops = false })
local admin = world.adminTools
local adapter = RuntimeAdapter.new({})

local reports = {
    status = function() return admin:getRuntimeStatus(world) end,
    replay = function() return admin:getReplayStatus(world) end,
    topology = function() return admin:getOwnershipTopology(world) end,
    pressure = function() return admin:getPressureMatrix(world) end,
    policies = function() return admin:getPolicyVersions(world) end,
    repairs = function() return admin:getRepairHistory(world) end,
    lineage = function() return admin:getCheckpointLineage(world) end,
    health = function() return admin:getRuntimeHealthSummary(world) end,
    events = function() return admin:getEventTruth(world, {}) end,
    control = function() return admin:getControlPlaneReport(world) end,
}

local selected = reports[reportType]
assert(selected, 'unknown_report:' .. tostring(reportType))
print(adapter:encodeData(selected()))
