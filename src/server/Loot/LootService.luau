--!strict
-- World loot chests. Chests come from structure slots (data only), are seeded from the run seed and rolled on
-- the server (shared/logic/LootChests + server/Loot/LootTables, which never replicate). One opening per chest
-- per run: items go to the opener's inventory, overflow is dropped at their feet, and the chest stays open
-- and empty. Distinct from the party storage chest (Items/StorageService). Art is a replaceable hook.
-- Open handler order: type -> range -> rate limit (Guard) -> state (alive, registered, unlooted) -> act.
-- Cleanup: PlayerRemoving (their drops, rate-limit entry), chest Destroying, ResetRun (everything).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemCatalog = require(Shared.ItemCatalog)
local Remotes = require(Shared.Remotes)
local LootChests = require(Shared.logic.LootChests)
local LootRoll = require(Shared.logic.LootRoll)
local Guard = require(script.Parent.Parent.Net.Guard)
local InventoryService = require(script.Parent.Parent.Items.InventoryService)
local LootTables = require(script.Parent.LootTables)

local L = Config.Loot
local RATE_KEY = "LootOpen"
local DROP_LIFETIME = 120 -- seconds an overflow drop lasts
local MAX_DROPS = 24 -- live overflow drops (oldest removed first); keeps the part budget safe
local DROP_PICKUP_RANGE = 12 -- server re-check for picking up an overflow drop
local DROP_SIZE = Vector3.new(1.2, 1.2, 1.2)
local DROP_BELOW_ROOT = 2.5 -- studs under the player's root part: at their feet
local DROP_SPREAD = 2.5 -- studs between drops of one overflow
local DEFAULT_BODY_SIZE = Vector3.new(3, 2, 2)

export type Slot = {
	Position: Vector3,
	Depth: number, -- depth tier 0..Config.Loot.MaxDepthTier
	StructureType: string,
	Ring: number?, -- biome ring 0..3 (default 0)
	Index: number?, -- chest index inside the structure
	ChunkKey: string?, -- owning chunk (informational)
}
export type ArtBuilder = (slot: Slot, rarity: string, parent: Instance) -> Instance

type Record = {
	slot: Slot,
	rarity: string,
	items: { LootRoll.Stack }, -- cleared on open
	opened: boolean,
	destroying: RBXScriptConnection?,
}

local LootService = {}

local pool = LootRoll.buildPool(ItemCatalog.Items :: any)
local chests: { [Instance]: Record } = {}
local drops: { Instance } = {}
local dropOwner: { [Instance]: number } = {}
local connections: { RBXScriptConnection } = {}
local runSeed: number? = nil
local started = false

local function defaultBuilder(slot: Slot, _rarity: string, parent: Instance): Instance
	local body = Instance.new("Part")
	body.Name = "LootChest"
	body.Size = DEFAULT_BODY_SIZE
	body.Anchored = true
	body.CanCollide = true
	body.Material = Enum.Material.Wood
	body.Color = Color3.fromRGB(120, 85, 50)
	body.CFrame = CFrame.new(slot.Position)
	body.Parent = parent
	return body
end

local artBuilder: ArtBuilder = defaultBuilder

-- Art hook (agent I): replace the chest body. The returned instance (Part or Model) gets the tag and attributes.
function LootService.SetArtBuilder(fn: ArtBuilder?)
	artBuilder = fn or defaultBuilder
end

local function currentSeed(): number
	if runSeed then
		return runSeed
	end
	local attr = Workspace:GetAttribute(Config.World.SeedAttribute)
	return if type(attr) == "number" then attr else Config.World.DefaultSeed
end

function LootService.SetSeed(seed: number)
	runSeed = seed
end

local function pivotOf(chest: Instance): Vector3?
	if chest:IsA("BasePart") then
		return chest.Position
	elseif chest:IsA("Model") then
		return chest:GetPivot().Position
	end
	return nil
end

function LootService.UnregisterChest(chest: Instance)
	local rec = chests[chest]
	if rec == nil then
		return
	end
	chests[chest] = nil
	if rec.destroying then
		rec.destroying:Disconnect()
	end
	if chest.Parent ~= nil then
		CollectionService:RemoveTag(chest, L.ChestTag)
		chest:Destroy()
	end
end

function LootService.RegisterChest(slot: Slot, parent: Instance): Instance
	local plan = LootChests.plan(LootTables, pool, currentSeed(), {
		x = slot.Position.X,
		y = slot.Position.Y,
		z = slot.Position.Z,
		depth = math.clamp(slot.Depth, 0, L.MaxDepthTier),
		structureType = slot.StructureType,
		ring = slot.Ring or 0,
		index = slot.Index,
	})
	local chest = artBuilder(slot, plan.rarity, parent)
	chest:SetAttribute(L.ChestRarityAttribute, plan.rarity)
	chest:SetAttribute(L.ChestStructureAttribute, slot.StructureType)
	chest:SetAttribute(L.ChestDepthAttribute, math.clamp(slot.Depth, 0, L.MaxDepthTier))
	chest:SetAttribute(L.ChestOpenedAttribute, false)
	local rec: Record = { slot = slot, rarity = plan.rarity, items = plan.items, opened = false }
	rec.destroying = chest.Destroying:Connect(function()
		LootService.UnregisterChest(chest)
	end)
	chests[chest] = rec
	CollectionService:AddTag(chest, L.ChestTag)
	return chest
end

local function removeDrop(drop: Instance)
	dropOwner[drop] = nil
	local i = table.find(drops, drop)
	if i then
		table.remove(drops, i)
	end
	drop:Destroy()
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	return nil
end

local function isAlive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function makeDrop(player: Player, stack: LootRoll.Stack, at: Vector3)
	while #drops >= MAX_DROPS do
		removeDrop(drops[1])
	end
	local def = ItemCatalog.Items[stack.id]
	local part = Instance.new("Part")
	part.Name = "LootDrop"
	part.Size = DROP_SIZE
	part.Position = at
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.fromRGB(230, 230, 240)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = `{if def then def.name else stack.id} x{stack.count}`
	prompt.MaxActivationDistance = L.OpenRange
	prompt.Parent = part
	local id, count = stack.id, stack.count
	prompt.Triggered:Connect(function(taker: Player)
		local root = rootOf(taker)
		if root == nil or not isAlive(taker) or part.Parent == nil then
			return
		end
		if (root.Position - part.Position).Magnitude > DROP_PICKUP_RANGE then
			return
		end
		local left = InventoryService.add(taker, id, count)
		if left <= 0 then
			removeDrop(part)
		elseif left < count then
			count = left
			prompt.ObjectText = `{if def then def.name else id} x{left}`
		end
	end)
	table.insert(drops, part)
	dropOwner[part] = player.UserId
	part.Parent = Workspace
	Debris:AddItem(part, DROP_LIFETIME)
end

local function onOpen(player: Player, payload: unknown)
	-- type
	if type(payload) ~= "table" then
		return
	end
	local chest = (payload :: { [string]: unknown }).chest
	if typeof(chest) ~= "Instance" then
		return
	end
	local rec = chests[chest]
	if rec == nil or not CollectionService:HasTag(chest, L.ChestTag) then
		return
	end
	-- range / sanity
	local root = rootOf(player)
	local pos = pivotOf(chest)
	if root == nil or pos == nil or (root.Position - pos).Magnitude > L.ServerOpenRange then
		return
	end
	-- rate limit
	if not Guard.rateLimit(player, RATE_KEY, L.OpenRateInterval) then
		return
	end
	-- state
	if rec.opened or not isAlive(player) then
		return
	end
	-- act: mark opened first (no yield between check and set), then grant
	rec.opened = true
	local items = rec.items
	rec.items = {}
	chest:SetAttribute(L.ChestOpenedAttribute, true)
	local overflow = false
	local dropAt = root.Position - Vector3.new(0, DROP_BELOW_ROOT, 0)
	local granted: { Remotes.ItemStack } = {}
	local dropped = 0
	for _, stack in items do
		local left = InventoryService.add(player, stack.id, stack.count)
		if stack.count - left > 0 then
			table.insert(granted, { id = stack.id, count = stack.count - left })
		end
		if left > 0 then
			overflow = true
			makeDrop(
				player,
				{ id = stack.id, count = left },
				dropAt + Vector3.new(dropped * DROP_SPREAD, 0, 0)
			)
			dropped += 1
		end
	end
	Remotes.event(Remotes.LootOpened):FireClient(player, {
		chest = chest,
		rarity = rec.rarity,
		items = granted,
		overflow = overflow,
	})
end

-- Removes every chest and drop; optionally sets the next run's seed. Call at run start/end.
function LootService.ResetRun(seed: number?)
	local all: { Instance } = {}
	for chest in chests do
		table.insert(all, chest)
	end
	for _, chest in all do
		LootService.UnregisterChest(chest)
	end
	for i = #drops, 1, -1 do
		removeDrop(drops[i])
	end
	runSeed = seed
end

function LootService.ChestCount(): number
	local n = 0
	for _ in chests do
		n += 1
	end
	return n
end

local function onPlayerRemoving(player: Player)
	Guard.cleanup(player)
	for i = #drops, 1, -1 do
		local drop = drops[i]
		if dropOwner[drop] == player.UserId then
			removeDrop(drop)
		end
	end
end

function LootService.start()
	if started then
		return
	end
	started = true
	table.insert(connections, Remotes.event(Remotes.LootOpenRequest).OnServerEvent:Connect(onOpen))
	table.insert(connections, Players.PlayerRemoving:Connect(onPlayerRemoving))
end

function LootService.stop()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	LootService.ResetRun(nil)
	started = false
end

return LootService
