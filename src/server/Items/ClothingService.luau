--!strict
-- Sets Player ColdResistance (Config.Biome.ColdResistanceAttribute) from the gear a player WEARS (equipment
-- slots, not the carried grid), capped (shared/logic/ClothingLogic). One loop for all players. Brief 13/18 read the
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

-- Only worn (equipped) pieces count; carried gear in the grid does nothing.
local function refresh(player: Player)
	local equip = InventoryService.getEquipment(player)
	local value = if equip then ClothingLogic.equipped(equip) else 0
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
	InventoryService.onEquipmentChanged(refresh) -- immediate on equip/unequip and on profile load
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
