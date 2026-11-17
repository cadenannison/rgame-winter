--!strict
-- Server-authoritative crafting. Workbench tier comes from tagged workbench instances near the player.
-- start() also starts GatherService (init.server only wires Inventory/Crafting).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ItemCatalog = require(Shared.ItemCatalog)
local Crafting = require(Shared.logic.Crafting)
local Guard = require(script.Parent.Parent.Net.Guard)
local InventoryService = require(script.Parent.InventoryService)
local GatherService = require(script.Parent.GatherService)

local CraftingService = {}

local started = false

-- Marks an instance as a crafting station (Config.Craft.Stations key; placement code calls this).
function CraftingService.registerStation(instance: Instance, station: string, tier: number?)
	local def = Config.Craft.Stations[station]
	if def == nil then
		return
	end
	instance:SetAttribute(ItemCatalog.WorkbenchTierAttribute, tier or 1)
	CollectionService:AddTag(instance, def.Tag)
end

-- Marks an instance as a workbench.
function CraftingService.registerWorkbench(instance: Instance, tier: number?)
	CraftingService.registerStation(instance, "workbench", tier)
end

local function position(i: Instance): Vector3?
	if i:IsA("BasePart") then
		return i.Position
	elseif i:IsA("Model") then
		return i:GetPivot().Position
	end
	return nil
end

-- Stations within range of the player right now, keyed by Config.Craft.Stations name. Uses tagged
-- instances only; evaluated at the craft action so a stale client view never unlocks a recipe.
function CraftingService.nearStations(player: Player): Crafting.Near
	local near: Crafting.Near = {}
	local root = if player.Character
		then player.Character:FindFirstChild("HumanoidRootPart")
		else nil
	if root == nil or not root:IsA("BasePart") then
		return near
	end
	for name, station in Config.Craft.Stations do
		for _, instance in CollectionService:GetTagged(station.Tag) do
			local pos = position(instance)
			if pos and (pos - root.Position).Magnitude <= station.Range then
				near[name] = true
				break
			end
		end
	end
	return near
end

-- Highest workbench tier in range (0 = none); kept for older QA scripts.
function CraftingService.availableTier(player: Player): number
	return if CraftingService.nearStations(player).workbench then Config.Craft.MaxTier else 0
end

local function onCraft(player: Player, recipeId: unknown)
	if type(recipeId) ~= "string" or #recipeId > 32 or ItemCatalog.Recipes[recipeId] == nil then
		return
	end
	if not Guard.rateLimit(player, "Craft", Config.Net.CraftRateInterval) then
		return
	end
	local inv = InventoryService.get(player)
	if inv == nil then
		return
	end
	local ok, reason = Crafting.craft(inv, recipeId, CraftingService.nearStations(player))
	if ok then
		InventoryService.sync(player)
	else
		local text = reason
		local stationId = Crafting.requiredStation(recipeId)
		local station = if stationId then Config.Craft.Stations[stationId] else nil
		if reason == "NeedStation" and station then
			text = `Needs a {station.Label} nearby`
		end
		Remotes.event(Remotes.Notify):FireClient(player, "craft", text)
	end
end

-- Same path as CraftRequest (QA and server callers); runs the full validation.
CraftingService.handleCraft = onCraft

function CraftingService.start()
	if started then
		return
	end
	started = true
	InventoryService.start()
	GatherService.start()
	Remotes.event(Remotes.CraftRequest).OnServerEvent:Connect(onCraft)
end

return CraftingService
