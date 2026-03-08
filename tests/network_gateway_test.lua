package.path = package.path .. ';./?.lua;../?.lua'
require('msw.world_server_entry')

local component = {
    Name = 'GatewayRuntime',
    Entity = {
        Name = 'gateway_runtime',
    },
}

assert(type(HandleGatewayRequest) == 'function', 'entry HandleGatewayRequest is missing')

OnBeginPlay(component)
local bridge = component.serverBridge or component.__worldServerBridge
assert(bridge ~= nil, 'gateway bridge instance missing')
assert(bridge:onUserEnter({ userId = 'gateway_user', CurrentMapName = 'henesys_hunting_ground' }), 'gateway user enter failed')
bridge:tick(5)

local function decode(payload)
    return bridge.runtimeAdapter:decodeData(payload)
end

local mapState = decode(HandleGatewayRequest(bridge.runtimeAdapter:encodeData({
    requestId = 'req-1',
    protocolVersion = 1,
    packetType = 'request',
    operation = 'get_map_state',
    args = { 'gateway_user', 'henesys_hunting_ground' },
}), component))
assert(mapState and mapState.ok == true, 'gateway get_map_state failed')
assert(mapState.requestId == 'req-1', 'gateway request id missing')
assert(mapState.operation == 'get_map_state', 'gateway operation missing')
assert(mapState.protocol and mapState.protocol.name == 'mapleworld_gateway', 'gateway response protocol name missing')
assert(mapState.protocol.version == 1, 'gateway response protocol version missing')
assert(mapState.protocol.packetType == 'response', 'gateway response packet type missing')
assert(mapState.gateway and mapState.gateway.route == 'getMapState', 'gateway route metadata missing')
assert(mapState.data and mapState.data.mapId == 'henesys_hunting_ground', 'gateway routed wrong map state')

local unknown = decode(HandleGatewayRequest({
    requestId = 'req-2',
    operation = 'drop_database',
    args = {},
}, component))
assert(unknown and unknown.ok == false and unknown.error == 'unknown_gateway_operation', 'unknown gateway operation was not rejected')
assert(unknown.requestId == 'req-2', 'rejected gateway request id missing')

local malformed = decode(HandleGatewayRequest('not a valid envelope', component))
assert(malformed and malformed.ok == false and malformed.error == 'invalid_gateway_request', 'malformed gateway request was not rejected')

local badArgs = decode(HandleGatewayRequest(bridge.runtimeAdapter:encodeData({
    requestId = 'req-3',
    protocolVersion = 1,
    operation = 'get_map_state',
    args = {},
}), component))
assert(badArgs and badArgs.ok == false and badArgs.error == 'invalid_gateway_arg_count', 'gateway arg count validation did not reject malformed request')
assert(badArgs.requestId == 'req-3', 'arg-count rejection request id missing')
assert(badArgs.operation == 'get_map_state', 'arg-count rejection operation missing')
assert(badArgs.protocol and badArgs.protocol.version == 1, 'gateway rejection lost negotiated protocol version')

local badVersion = decode(HandleGatewayRequest(bridge.runtimeAdapter:encodeData({
    requestId = 'req-4',
    protocolVersion = 99,
    operation = 'get_map_state',
    args = { 'gateway_user' },
}), component))
assert(badVersion and badVersion.ok == false and badVersion.error == 'unsupported_gateway_protocol_version', 'unsupported protocol version was not rejected')
assert(badVersion.requestId == nil, 'decode-stage rejection should not echo request id')
assert(badVersion.protocol and badVersion.protocol.version == 1, 'unsupported version rejection did not advertise current protocol')

local badPacketType = decode(HandleGatewayRequest(bridge.runtimeAdapter:encodeData({
    requestId = 'req-5',
    protocolVersion = 1,
    packetType = 'response',
    operation = 'get_map_state',
    args = { 'gateway_user' },
}), component))
assert(badPacketType and badPacketType.ok == false and badPacketType.error == 'invalid_gateway_packet_type', 'invalid packet type was not rejected')
assert(badPacketType.protocol and badPacketType.protocol.version == 1, 'packet-type rejection lost protocol descriptor')

local blockedInternal = decode(HandleGatewayRequest(bridge.runtimeAdapter:encodeData({
    requestId = 'req-6',
    protocolVersion = 1,
    packetType = 'request',
    operation = 'admin_status',
    args = {},
}), component))
assert(blockedInternal and blockedInternal.ok == false and blockedInternal.error == 'gateway_operation_not_exposed', 'internal gateway operation was not rejected')
assert(blockedInternal.requestId == 'req-6', 'internal operation rejection request id missing')

local diagnostics = decode(GetBridgeDiagnostics(component))
assert(diagnostics and diagnostics.ok == true, 'gateway diagnostics request failed')
assert(diagnostics.data and diagnostics.data.metrics and diagnostics.data.metrics.gatewayRequests == 7, 'gateway request metrics mismatch')
assert(diagnostics.data.metrics.gatewaySucceeded == 1, 'gateway success metrics mismatch')
assert(diagnostics.data.metrics.gatewayRejected == 6, 'gateway rejection metrics mismatch')
assert(diagnostics.data.gateway and diagnostics.data.gateway.lastRequest and diagnostics.data.gateway.lastResponse, 'gateway state missing from diagnostics')
assert(diagnostics.data.gateway.lastRequest.routeError == 'gateway_operation_not_exposed', 'gateway diagnostics did not preserve latest route exposure failure')
assert(diagnostics.data.gateway.protocol and diagnostics.data.gateway.protocol.name == 'mapleworld_gateway', 'gateway diagnostics protocol descriptor missing')
assert(diagnostics.data.gateway.protocol.version == 1, 'gateway diagnostics protocol version mismatch')
assert(type(diagnostics.data.gateway.protocol.supportedVersions) == 'table' and diagnostics.data.gateway.protocol.supportedVersions[1] == 1, 'gateway diagnostics supported versions missing')
assert(type(diagnostics.data.gateway.supportedOperations) == 'table' and #diagnostics.data.gateway.supportedOperations >= 1, 'gateway operation catalog missing')
assert(diagnostics.data.gateway.routeCount == #diagnostics.data.gateway.supportedOperations, 'gateway route count mismatch')
assert(diagnostics.data.gateway.successCount == 1, 'gateway success count missing from diagnostics')
assert(diagnostics.data.gateway.rejectionCount == 6, 'gateway rejection count missing from diagnostics')

local getMapStateCatalog
local adminStatusCatalog
for _, entry in ipairs(diagnostics.data.gateway.supportedOperations) do
    if entry.operation == 'get_map_state' then
        getMapStateCatalog = entry
    elseif entry.operation == 'admin_status' then
        adminStatusCatalog = entry
    end
end
assert(getMapStateCatalog ~= nil, 'get_map_state missing from gateway catalog')
assert(getMapStateCatalog.route == 'getMapState', 'gateway catalog routed get_map_state incorrectly')
assert(getMapStateCatalog.minArgs == 1 and getMapStateCatalog.maxArgs == 2, 'gateway catalog arg bounds mismatch for get_map_state')
assert(getMapStateCatalog.exposure == 'session', 'gateway catalog exposure mismatch for get_map_state')
assert(adminStatusCatalog == nil, 'internal admin gateway operation leaked into public catalog')

print('network_gateway_test: ok')
