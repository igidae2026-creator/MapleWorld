local AuditLog = {}

function AuditLog.new()
    return setmetatable({ entries = {} }, { __index = AuditLog })
end

function AuditLog:append(kind, payload)
    self.entries[#self.entries + 1] = { kind = kind, payload = payload, at = os.time() }
    return self.entries[#self.entries]
end

return AuditLog
