--!strict
-- Relays an ACCEPTED swing to nearby clients so they can animate it (brief 20). Called once from
-- MobService.onAttack and GatherService.onGather after their own validation and rate limit pass, so the
-- accepted swing is the rate cap. Visual only: never changes game state; payload = the swinger's UserId.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local SwingRelay = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Send SwingBroadcast to every other player within Perf.SwingBroadcastRange of the swinger.
function SwingRelay.notify(player: Player)
	local origin = rootOf(player)
	if origin == nil then
		return
	end
	local event = Remotes.event(Remotes.SwingBroadcast)
	local range = Config.Perf.SwingBroadcastRange
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local root = rootOf(other)
			if root and (root.Position - origin.Position).Magnitude <= range then
				event:FireClient(other, { userId = player.UserId })
			end
		end
	end
end

return SwingRelay
