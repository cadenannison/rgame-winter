--!strict
-- Boot for client loot chest visuals and the Open prompt (run mode only).

local ChestPrompt = require(script.Parent.ChestPrompt)
local ChestVisuals = require(script.Parent.ChestVisuals)

local ChestClient = {}

function ChestClient.start()
	ChestVisuals.start()
	ChestPrompt.start()
end

return ChestClient
