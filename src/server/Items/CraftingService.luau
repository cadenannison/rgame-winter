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

-- Marks an instance as a workbench (call from the placement code). Tier defaults to 1.
function CraftingService.registerWorkbench(instance: Instance, tier: number?)
	instance:SetAttribute(ItemCatalog.WorkbenchTierAttribute, tier or 1)
	CollectionService:AddTag(instance, ItemCatalog.WorkbenchTag)
end

local function position(i: Instance): Vector3?
	if i:IsA("BasePart") then
		return i.Position
	elseif i:IsA("Model") then
		return i:GetPivot().Position
	end
	return nil
end

-- Highest workbench tier within range of the player (0 = by hand). Uses tagged instances only.
function CraftingService.availableTier(player: Player): number
	local root = if player.Character
		then player.Character:FindFirstChild("HumanoidRootPart")
		else nil
	if root == nil or not root:IsA("BasePart") then
		return 0
	end
	local best = 0
	for _, bench in CollectionService:GetTagged(ItemCatalog.WorkbenchTag) do
		local pos = position(bench)
		if pos and (pos - root.Position).Magnitude <= Config.Craft.WorkbenchRange then
			local tier = bench:GetAttribute(ItemCatalog.WorkbenchTierAttribute)
			best = math.max(best, if type(tier) == "number" then tier else 1)
		end
	end
	return math.min(best, Config.Craft.MaxTier)
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
	local ok, reason = Crafting.craft(inv, recipeId, CraftingService.availableTier(player))
	if ok then
		InventoryService.sync(player)
	else
		Remotes.event(Remotes.Notify):FireClient(player, "craft", reason)
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
