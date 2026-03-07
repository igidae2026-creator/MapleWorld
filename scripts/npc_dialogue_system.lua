local DialogueSystem = {}

function DialogueSystem.new(config)
    local self = { dialogues = (config or {}).dialogues or {} }
    setmetatable(self, { __index = DialogueSystem })
    return self
end

function DialogueSystem:get(npcId)
    for _, dialogue in pairs(self.dialogues) do
        if dialogue.npc_id == npcId then return dialogue end
    end
    return nil
end

return DialogueSystem
