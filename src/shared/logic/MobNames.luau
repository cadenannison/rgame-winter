--!strict
-- Player-facing mob names (no Roblox APIs): Config.Mobs.DisplayNames override, else the PascalCase id is
-- split into words ("RimeWolverine" -> "Rime Wolverine"). Used by prompts, the HUD target line and any feed.

local Config = require("../Config")

local MobNames = {}

-- "RimeWolverine" -> "Rime Wolverine"; ids with digits or acronyms keep their run together.
function MobNames.split(id: string): string
	local spaced = string.gsub(id, "(%l)(%u)", "%1 %2")
	spaced = string.gsub(spaced, "(%u)(%u%l)", "%1 %2")
	return spaced
end

function MobNames.display(id: string): string
	local override = Config.Mobs.DisplayNames[id]
	if override ~= nil then
		return override
	end
	return MobNames.split(id)
end

return MobNames
