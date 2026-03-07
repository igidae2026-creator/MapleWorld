local Validator = {}

function Validator.new(config)
    local self = { replayEngine = (config or {}).replayEngine }
    setmetatable(self, { __index = Validator })
    return self
end

function Validator:validate(events)
    local first = self.replayEngine:replay(events)
    local second = self.replayEngine:replay(events)
    return first.digest == second.digest, { first = first, second = second }
end

return Validator
