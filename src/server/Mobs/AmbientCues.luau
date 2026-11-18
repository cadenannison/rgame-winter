--!strict
-- Read-only server cues for ambient mobs (crows, wisps): the Stalker's hunting position and the warmth drain
-- on a wisp touch. Other systems are required lazily inside pcall so MobService never depends on them at
-- load time (and nothing breaks when horror / survival are not running).

local Server = script.Parent.Parent

local AmbientCues = {}

local stalker: any = nil
local survival: any = nil

local function load(path: Instance): any
	local ok, module = pcall(require, path)
	return if ok then module else nil
end

-- World position of the active Stalker hunt (nil when none). Server only; never replicated.
function AmbientCues.stalkerPosition(): Vector3?
	if stalker == nil then
		stalker = load(Server.Horror.StalkerService)
	end
	if stalker == nil or type(stalker.getHuntPosition) ~= "function" then
		return nil
	end
	local ok, position = pcall(stalker.getHuntPosition)
	return if ok and typeof(position) == "Vector3" then position else nil
end

-- Drains warmth (amount > 0). The amount is already capped by the Lure machine.
function AmbientCues.drainWarmth(player: Player, amount: number)
	if survival == nil then
		survival = load(Server.Survival.SurvivalService)
	end
	if survival ~= nil and amount > 0 then
		pcall(survival.warm, player, -amount)
	end
end

return AmbientCues
