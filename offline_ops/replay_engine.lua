local ReplayEngine = {}

function ReplayEngine.new()
    return setmetatable({}, { __index = ReplayEngine })
end

function ReplayEngine:replay(events)
    local digest = 0
    for _, event in ipairs(events or {}) do
        digest = digest + #(tostring(event.event or '')) + #(tostring(event.seq or ''))
    end
    return { digest = digest, count = #(events or {}) }
end

return ReplayEngine
