--!strict
-- Client adapter: the live Players state that feeds the pure DeathPanelState (shared by DownedUi and
-- SummaryScreen so both always agree which single panel shows).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DeathPanelInputs = {}

-- Other players still alive: not RunDead and a living Humanoid.
function DeathPanelInputs.aliveTeammates(): number
	local count = 0
	for _, other in Players:GetPlayers() do
		if
			other ~= Players.LocalPlayer
			and other:GetAttribute(Config.Downed.DeadAttribute) ~= true
		then
			local character = other.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				count += 1
			end
		end
	end
	return count
end

-- LocalPlayer attribute written by SummaryScreen ("" none, "open", "dismissed") so DownedUi can tell
-- whether the run summary is showing without a second remote.
function DeathPanelInputs.summaryState(): string
	local value = Players.LocalPlayer:GetAttribute(Config.Run.SummaryStateAttribute)
	return if type(value) == "string" then value else ""
end

return DeathPanelInputs
