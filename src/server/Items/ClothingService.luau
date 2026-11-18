--!strict
-- Sets Player ColdResistance (Config.Biome.ColdResistanceAttribute) from the clothing a player carries:
-- best piece per slot, capped (shared/logic/ClothingLogic). One loop for all players. Brief 13/18 read the
-- attribute for biome drain; the client HUD shows it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ClothingLogic = require(Shared.logic.ClothingLogic)
local InventoryService = require(script.Parent.InventoryService)

local ClothingService = {}

local connections: { RBXScriptConnection } = {}
local started = false
local accumulator = 0.0

function ClothingService.get(player: Player): number
	local v = player:GetAttribute(Config.Biome.ColdResistanceAttribute)
	return if type(v) == "number" then v else 0
end

local function refresh(player: Player)
	local inv = InventoryService.get(player)
	local counts: { [string]: number } = {}
	if inv then
		for i = 1, inv.size do
			local stack = inv.slots[i]
			if stack then
				counts[stack.id] = (counts[stack.id] or 0) + stack.count
			end
		end
	end
	local value = ClothingLogic.resistance(counts)
	if player:GetAttribute(Config.Biome.ColdResistanceAttribute) ~= value then
		player:SetAttribute(Config.Biome.ColdResistanceAttribute, value)
	end
end

function ClothingService.start()
	if started then
		return
	end
	started = true
	local function onAdded(player: Player)
		player:SetAttribute(Config.Biome.ColdResistanceAttribute, 0)
	end
	table.insert(connections, Players.PlayerAdded:Connect(onAdded))
	for _, player in Players:GetPlayers() do
		onAdded(player)
	end
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt: number)
			accumulator += dt
			if accumulator < Config.Biome.UpdateInterval then
				return
			end
			accumulator = 0
			for _, player in Players:GetPlayers() do
				refresh(player)
			end
		end)
	)
end

function ClothingService.stop()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	started = false
end

return ClothingService
