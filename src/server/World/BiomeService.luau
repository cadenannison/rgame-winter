--!strict
-- Keeps each player's BiomeRing attribute current (HUD, survival drain, mobs read it). Owner: brief 13.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local BiomeLogic = require(Shared:WaitForChild("logic"):WaitForChild("BiomeLogic"))
local Biomes = require(Shared:WaitForChild("data"):WaitForChild("Biomes"))

local ATTRIBUTE = Config.Biome.RingAttribute

local BiomeService = {}

local lastRing: { [Player]: number } = {}
local callbacks: { (Player, number) -> () } = {}
local heartbeatConn: RBXScriptConnection? = nil
local removingConn: RBXScriptConnection? = nil
local accumulator = 0

local function ringOfPlayer(player: Player): number?
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return BiomeLogic.ringAt(hrp.Position.X, hrp.Position.Z)
	end
	return nil
end

-- Ring the player stands in (0 = start forest). Nil while they have no character.
function BiomeService.getRing(player: Player): number?
	local ring = ringOfPlayer(player)
	if ring ~= nil and lastRing[player] ~= ring then
		lastRing[player] = ring
		player:SetAttribute(ATTRIBUTE, ring)
	end
	return ring
end

function BiomeService.getBiome(player: Player): string?
	local ring = ringOfPlayer(player)
	return if ring then Biomes.forRing(ring).id else nil
end

function BiomeService.onRingChanged(cb: (Player, number) -> ())
	table.insert(callbacks, cb)
end

local function update()
	for _, player in Players:GetPlayers() do
		local before = lastRing[player]
		local ring = BiomeService.getRing(player)
		if ring ~= nil and ring ~= before then
			for _, cb in callbacks do
				if not pcall(cb, player, ring) then
					warn("[BiomeService] ring callback failed")
				end
			end
		end
	end
end

function BiomeService.start()
	if heartbeatConn then
		return
	end
	heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < Config.Biome.UpdateInterval then
			return
		end
		accumulator = 0
		update()
	end)
	removingConn = Players.PlayerRemoving:Connect(function(player)
		lastRing[player] = nil
	end)
end

function BiomeService.stop()
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
	if removingConn then
		removingConn:Disconnect()
		removingConn = nil
	end
	table.clear(lastRing)
end

return BiomeService
