--!strict
-- Server-authoritative crafting. Workbench tier comes from tagged workbench instances near the player.
-- start() also starts GatherService (init.server only wires Inventory/Crafting).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ItemCatalog = require(Shared.ItemCatalog)
local Crafting = require(Shared.logic.Crafting)
local WorkbenchTier = require(Shared.logic.WorkbenchTier)
local Guard = require(script.Parent.Parent.Net.Guard)
local InventoryService = require(script.Parent.InventoryService)
local GatherService = require(script.Parent.GatherService)

local CraftingService = {}

local started = false
local craftedHandler: ((Player, string) -> ())? = nil

-- Wiring (Phase 4): told after every successful craft (meta "crafted" stat). Nil-safe.
function CraftingService.setCraftedHandler(fn: ((Player, string) -> ())?)
	craftedHandler = fn
end

-- Party-wide workbench tier (Workspace attribute Config.Workbench.TierAttribute; 1 until upgraded).
function CraftingService.partyTier(): number
	return WorkbenchTier.clamp(Workspace:GetAttribute(Config.Workbench.TierAttribute))
end

-- Original look of a workbench, kept so a tier's Scale/Color is always applied to the base, never compounded.
local baseSize: { [Instance]: Vector3 } = setmetatable({}, { __mode = "k" }) :: any
local baseColor: { [Instance]: Color3 } = setmetatable({}, { __mode = "k" }) :: any

-- Sets the tier attribute on a workbench and applies the tier's visual change (size, tint) from Config.
local function applyBenchTier(instance: Instance, tier: number)
	instance:SetAttribute(Config.Workbench.TierAttribute, tier)
	local def = Config.Workbench.Tiers[tier]
	if def == nil then
		return
	end
	if instance:IsA("BasePart") then
		local size = instance.Size
		if (baseSize :: { [Instance]: Vector3? })[instance] == nil then
			baseSize[instance] = size
			baseColor[instance] = instance.Color
		end
		local base = baseSize[instance]
		local newSize = base * def.Scale
		local lift = (newSize.Y - instance.Size.Y) / 2 -- keep the bench sitting on the ground
		instance.Size = newSize
		instance.CFrame = instance.CFrame * CFrame.new(0, lift, 0)
		local c = def.Color
		instance.Color = if c then Color3.fromRGB(c[1], c[2], c[3]) else baseColor[instance]
	elseif instance:IsA("Model") then
		instance:ScaleTo(def.Scale)
	end
end

-- Marks an instance as a crafting station (Config.Craft.Stations key; placement code calls this).
function CraftingService.registerStation(instance: Instance, station: string, tier: number?)
	local def = Config.Craft.Stations[station]
	if def == nil then
		return
	end
	if station == "workbench" then
		applyBenchTier(instance, CraftingService.partyTier()) -- new benches join at the party tier
	else
		instance:SetAttribute(ItemCatalog.WorkbenchTierAttribute, tier or 1)
	end
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
	local ok, reason = Crafting.craft(
		inv,
		recipeId,
		CraftingService.nearStations(player),
		CraftingService.partyTier()
	)
	if ok then
		InventoryService.sync(player)
		local handler = craftedHandler
		if handler then
			task.spawn(handler, player, recipeId)
		end
	else
		local text = reason
		local stationId = Crafting.requiredStation(recipeId)
		local station = if stationId then Config.Craft.Stations[stationId] else nil
		if reason == "NeedStation" and station then
			text = `Needs a {station.Label} nearby`
		elseif reason == "NeedBenchTier" then
			text = "Upgrade the workbench to craft that"
		end
		Remotes.event(Remotes.Notify):FireClient(player, "craft", text)
	end
end

-- UpgradeWorkbench: type-check -> sanity -> Guard rate limit -> state (near a bench, below max, has the cost) -> act.
-- The cost is recomputed here from Config.Workbench; the client sends nothing but the intent.
local function onUpgrade(player: Player)
	-- 1. type-check: the remote carries no payload; anything extra is ignored, never trusted
	-- 2. sanity
	local char = player.Character
	local humanoid = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if humanoid == nil or humanoid.Health <= 0 then
		return
	end
	-- 3. rate limit
	if not Guard.rateLimit(player, "UpgradeWorkbench", Config.Workbench.UpgradeRateInterval) then
		return
	end
	-- 4. state
	local inv = InventoryService.get(player)
	if inv == nil then
		return
	end
	local tier = CraftingService.partyTier()
	local nearBench = CraftingService.nearStations(player).workbench == true
	-- 5. act (atomic spend; inventory untouched on any failure)
	local ok, reason, newTier = WorkbenchTier.upgrade(inv, tier, nearBench)
	if not ok then
		local text = if reason == "MaxTier"
			then "The workbench is fully upgraded"
			elseif reason == "NeedStation" then "Needs a workbench nearby"
			else "Not enough materials"
		Remotes.event(Remotes.Notify):FireClient(player, "craft", text)
		return
	end
	Workspace:SetAttribute(Config.Workbench.TierAttribute, newTier)
	for _, bench in CollectionService:GetTagged(Config.Craft.Stations.workbench.Tag) do
		applyBenchTier(bench, newTier)
	end
	InventoryService.sync(player)
	Remotes.event(Remotes.Notify)
		:FireClient(player, "craft", `{WorkbenchTier.labelOf(newTier)} unlocked`)
end

CraftingService.handleUpgrade = onUpgrade

-- Same path as CraftRequest (QA and server callers); runs the full validation.
CraftingService.handleCraft = onCraft

function CraftingService.start()
	if started then
		return
	end
	started = true
	InventoryService.start()
	GatherService.start()
	if Workspace:GetAttribute(Config.Workbench.TierAttribute) == nil then
		Workspace:SetAttribute(Config.Workbench.TierAttribute, 1)
	end
	Remotes.event(Remotes.CraftRequest).OnServerEvent:Connect(onCraft)
	Remotes.event(Remotes.UpgradeWorkbench).OnServerEvent:Connect(onUpgrade)
end

return CraftingService
