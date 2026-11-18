--!strict
-- The only place that calls TeleportService. Real impl: run mode reserves a private server of this place
-- (reserved server = run server, see init.server); lobby mode teleports to a public server of this place.
-- Tests and Studio use a fake (setImpl, or the Studio recorder). The real path is hand-tested on a
-- published place.

local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local TeleportData = require(game:GetService("ReplicatedStorage").Shared.logic.TeleportData)

export type Impl = (players: { Player }, data: TeleportData.TeleportData) -> (boolean, string?)
export type StudioCall = { userIds: { number }, data: TeleportData.TeleportData }

local TeleportAdapter = {}

local studioLog: { StudioCall } = {}

local function realImpl(players: { Player }, data: TeleportData.TeleportData): (boolean, string?)
	local ok, result = pcall(function()
		local options = Instance.new("TeleportOptions")
		if data.mode == Config.Teleport.ModeRun then
			local code = TeleportService:ReserveServer(game.PlaceId)
			local settable: any = options
			settable.ReservedServerAccessCode = code
		end
		options:SetTeleportData(data)
		TeleportService:TeleportAsync(game.PlaceId, players, options)
		options:Destroy()
	end)
	if not ok then
		return false, tostring(result)
	end
	return true, nil
end

-- Studio cannot teleport: record the call and succeed without moving anyone (QA reads the log).
local function studioImpl(players: { Player }, data: TeleportData.TeleportData): (boolean, string?)
	local ids: { number } = {}
	for _, player in players do
		table.insert(ids, player.UserId)
	end
	table.insert(studioLog, { userIds = ids, data = data })
	if #studioLog > Config.Debug.TeleportLogMax then
		table.remove(studioLog, 1)
	end
	return true, nil
end

local impl: Impl = if RunService:IsStudio() then studioImpl else realImpl

function TeleportAdapter.setImpl(fake: Impl?)
	impl = fake or (if RunService:IsStudio() then studioImpl else realImpl)
end

-- Studio fake's recorded calls (copy), oldest first. Always empty outside Studio.
function TeleportAdapter.getStudioLog(): { StudioCall }
	return table.clone(studioLog)
end

function TeleportAdapter.clearStudioLog()
	table.clear(studioLog)
end

-- Teleports the party. Never throws. Returns ok, error text.
function TeleportAdapter.teleportParty(
	players: { Player },
	data: TeleportData.TeleportData
): (boolean, string?)
	if #players == 0 then
		return false, "no players"
	end
	local ok, success, reason = pcall(impl, players, data)
	if not ok then
		return false, tostring(success)
	end
	return success :: boolean, reason :: string?
end

return TeleportAdapter
