--!strict
-- Thin debug facade over EventService for the blizzard (the orchestrator wires /debug blizzard ...).
-- The schedule, modifiers and visible attributes (Blizzard, BlizzardIntensity) live in EventService;
-- clients render snow and whiteout from those attributes (client/Atmosphere/BlizzardFx). Studio/debug only.

local EventService = require(script.Parent.EventService)

local BlizzardService = {}

-- Starts a blizzard immediately (no warning). Returns false while another event runs.
function BlizzardService.DebugStart(): boolean
	return EventService.startBlizzardNow()
end

-- Ends the blizzard (or cancels a pending warning).
function BlizzardService.DebugStop()
	EventService.stopBlizzardNow()
end

-- Pins intensity 0..1 (starts a blizzard first if none is active); nil releases the pin.
function BlizzardService.DebugSetIntensity(value: number?)
	if value ~= nil then
		if type(value) ~= "number" or value ~= value then
			return
		end
		if not EventService.isBlizzard() then
			EventService.startBlizzardNow()
		end
	end
	EventService.setIntensityOverride(value)
end

return BlizzardService
