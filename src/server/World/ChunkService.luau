--!strict
-- Builds the seeded 8x8 world layout and streams chunk models in/out around players.
-- Layout is pure (shared/logic/WorldLayout); this file only touches Roblox instances.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local WorldLayout = require(Shared:WaitForChild("logic"):WaitForChild("WorldLayout"))
local BiomeLogic = require(Shared:WaitForChild("logic"):WaitForChild("BiomeLogic"))
local PerfBudget = require(Shared:WaitForChild("logic"):WaitForChild("PerfBudget"))
local Biomes = require(Shared:WaitForChild("data"):WaitForChild("Biomes"))
local ItemCatalog = require(Shared:WaitForChild("ItemCatalog"))
local Server = ServerScriptService:WaitForChild("Server")
local DebugService = require(Server:WaitForChild("Debug"):WaitForChild("DebugService"))
local GatherService = require(Server:WaitForChild("Items"):WaitForChild("GatherService"))
local PoiService = require(script.Parent:WaitForChild("PoiService"))

local WORLD = Config.World
local SLOT_TAGS = WORLD.SlotTags
local ORE_TAG = Config.Biome.OreSlotTag
local GATHER = Config.Gather
local PERF = Config.Perf
local GROUND_THICKNESS = 1
local SLOT_SIZE = Vector3.new(2, 2, 2)
local TELEPORT_HEIGHT = 5
-- Block-out visuals for gatherable slots (Phase 4 replaces with art). Kind = ItemCatalog.Nodes key.
local NODE_SLOTS: { [string]: { kind: string, size: Vector3, color: Color3, material: Enum.Material } } =
	{
		[SLOT_TAGS.Tree] = {
			kind = "Tree",
			size = Vector3.new(2, 10, 2),
			color = Color3.fromRGB(96, 70, 48),
			material = Enum.Material.Wood,
		},
		[SLOT_TAGS.Rock] = {
			kind = "Rock",
			size = Vector3.new(4, 3, 4),
			color = Color3.fromRGB(128, 132, 140),
			material = Enum.Material.Slate,
		},
		[ORE_TAG] = {
			kind = "IronOre",
			size = Vector3.new(4, 3, 4),
			color = Color3.fromRGB(110, 92, 84),
			material = Enum.Material.Slate,
		},
	}
local CAMPFIRE_SIZE = Vector3.new(4, 1, 4)
local CAMPFIRE_COLOR = Color3.fromRGB(230, 120, 40)
local VARIANT_SHADE = { 1, 0.96, 0.92, 0.98 } -- per-variant brightness so repeats are less obvious

local ChunkService = {}

local layout: WorldLayout.Layout? = nil
local folder: Folder? = nil
local loaded: { [number]: Model } = {}
local keep: { [number]: boolean } = {}
local accumulator = 0
local partCounts: { [number]: number } = {} -- BaseParts per loaded chunk (for the live part cap)
local totalParts = 0
local loadedCount = 0
local heartbeatConn: RBXScriptConnection? = nil
local unregisterDebug: (() -> ())? = nil
local campFolder: Folder? = nil
local campFire: BasePart? = nil

-- Node state kept outside chunk models so depleted nodes stay depleted across unload/reload
-- (docs/KNOWN_ISSUES fix). key = "<chunkIndex>:<tag>:<i>".
type Pending = {
	part: BasePart,
	kind: string,
	key: string,
	at: number,
	transparency: number,
	canCollide: boolean,
}
local nodeMemory: { [string]: BiomeLogic.NodeMemo } = {}
local pendingByChunk: { [number]: { Pending } } = {}
local connsByChunk: { [number]: { RBXScriptConnection } } = {}

local function trackNode(index: number, part: BasePart, key: string)
	local conns = connsByChunk[index]
	if conns == nil then
		conns = {}
		connsByChunk[index] = conns
	end
	table.insert(
		conns,
		part:GetAttributeChangedSignal(ItemCatalog.NodeDepletedAttribute):Connect(function()
			if part:GetAttribute(ItemCatalog.NodeDepletedAttribute) == true then
				nodeMemory[key] = { depletedAt = os.clock() }
			else
				nodeMemory[key] = nil
			end
		end)
	)
	table.insert(
		conns,
		part:GetAttributeChangedSignal(ItemCatalog.NodeHitsAttribute):Connect(function()
			if part:GetAttribute(ItemCatalog.NodeDepletedAttribute) == true then
				return
			end
			local hits = part:GetAttribute(ItemCatalog.NodeHitsAttribute)
			if type(hits) == "number" and hits < GATHER.HitsToDeplete then
				nodeMemory[key] = { hits = hits }
			else
				nodeMemory[key] = nil
			end
		end)
	)
end

-- Tree/rock/ore slots are visible gather nodes registered with GatherService (tier and respawn come
-- from Config via ItemCatalog.Nodes); other slots are invisible markers. key is nil for markers.
local function newSlot(
	parent: Instance,
	tag: string,
	pos: WorldLayout.Vec2,
	index: number,
	key: string
)
	local node = NODE_SLOTS[tag]
	local size = if node then node.size else SLOT_SIZE
	local part = Instance.new("Part")
	part.Name = tag
	part.Size = size
	part.Position = Vector3.new(pos.x, size.Y / 2, pos.z)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	if node then
		part.Color = node.color
		part.Material = node.material
	else
		part.Transparency = 1
	end
	CollectionService:AddTag(part, tag)
	part.Parent = parent
	if not node then
		return
	end
	local state, remaining = BiomeLogic.nodeState(
		nodeMemory[key],
		os.clock(),
		GATHER.RespawnSeconds,
		GATHER.HitsToDeplete
	)
	if state == "depleted" then
		-- Still depleted from before the unload: hidden and unregistered until the timer runs out.
		local pending: Pending = {
			part = part,
			kind = node.kind,
			key = key,
			at = os.clock() + remaining,
			transparency = part.Transparency,
			canCollide = part.CanCollide,
		}
		part.Transparency = 1
		part:SetAttribute(ItemCatalog.NodeDepletedAttribute, true)
		local list = pendingByChunk[index]
		if list == nil then
			list = {}
			pendingByChunk[index] = list
		end
		table.insert(list, pending)
		return
	end
	if state == "full" then
		nodeMemory[key] = nil
	end
	GatherService.registerNode(part, node.kind)
	if state == "partial" then
		local memo = nodeMemory[key]
		if memo and memo.hits then
			part:SetAttribute(ItemCatalog.NodeHitsAttribute, memo.hits)
		end
	end
	trackNode(index, part, key)
end

-- Brings back nodes whose respawn time passed while their chunk was loaded.
local function releasePending()
	local now = os.clock()
	for index, list in pendingByChunk do
		for i = #list, 1, -1 do
			local p = list[i]
			if now >= p.at then
				table.remove(list, i)
				nodeMemory[p.key] = nil
				if p.part.Parent ~= nil then
					p.part.Transparency = p.transparency
					GatherService.registerNode(p.part, p.kind)
					trackNode(index, p.part, p.key)
				end
			end
		end
	end
end

local function buildChunk(chunk: WorldLayout.Chunk, root: Folder): number
	local model = Instance.new("Model")
	model.Name = `Chunk_{chunk.cx}_{chunk.cy}`
	model:SetAttribute("ChunkIndex", chunk.index)
	model:SetAttribute("Ring", chunk.ring)
	model:SetAttribute("Variant", chunk.variant)
	model:SetAttribute("Rotation", chunk.rotation)

	local ground = Instance.new("Part")
	ground.Name = "Ground"
	ground.Size = Vector3.new(WORLD.ChunkSize, GROUND_THICKNESS, WORLD.ChunkSize)
	ground.CFrame = CFrame.new(chunk.center.x, -GROUND_THICKNESS / 2, chunk.center.z)
		* CFrame.Angles(0, math.rad(90 * chunk.rotation), 0)
	ground.Anchored = true
	local biome = Biomes.ById[chunk.biome]
	local rgb = biome.color
	local shade = VARIANT_SHADE[chunk.variant] or 1
	ground.Color = Color3.fromRGB(rgb[1] * shade, rgb[2] * shade, rgb[3] * shade)
	ground.Material = if chunk.biome == "FrozenLake" then Enum.Material.Ice else Enum.Material.Snow
	ground.Parent = model

	local function fill(tag: string, list: { WorldLayout.Vec2 })
		for i, p in list do
			newSlot(model, tag, p, chunk.index, `{chunk.index}:{tag}:{i}`)
		end
	end
	fill(SLOT_TAGS.Tree, chunk.trees)
	fill(SLOT_TAGS.Rock, chunk.rocks)
	fill(ORE_TAG, chunk.ore)
	fill(SLOT_TAGS.Food, chunk.food)
	fill(SLOT_TAGS.SpawnZone, chunk.spawnZones)
	for _, poi in chunk.pois do
		PoiService.build(model, poi, chunk.index)
	end
	model:SetAttribute("Biome", chunk.biome)
	model:SetAttribute("VariantId", chunk.variantId)

	CollectionService:AddTag(model, WORLD.ChunkTag)
	model.Parent = root
	loaded[chunk.index] = model
	local parts = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	partCounts[chunk.index] = parts
	totalParts += parts
	loadedCount += 1
	return parts
end

local function unloadChunk(index: number)
	local model = loaded[index]
	loaded[index] = nil
	pendingByChunk[index] = nil
	local conns = connsByChunk[index]
	if conns then
		for _, c in conns do
			c:Disconnect()
		end
		connsByChunk[index] = nil
	end
	if model then
		model:Destroy()
		totalParts -= partCounts[index] or 0
		partCounts[index] = nil
		loadedCount -= 1
	end
end

local function playerPositions(): { WorldLayout.Vec2 }
	local out: { WorldLayout.Vec2 } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			table.insert(out, { x = hrp.Position.X, z = hrp.Position.Z })
		end
	end
	return out
end

-- budgeted = streaming tick: at most Perf.ChunkLoadBudgetPerFrame chunks / ChunkPartBudgetPerFrame parts
-- per tick, nearest first, and none past Perf.MaxLiveParts. Unloads run first to free headroom. Forced
-- loads (spawn, teleport) are not budgeted.
local function applyDiff(positions: { WorldLayout.Vec2 }, budgeted: boolean)
	local l, root = layout, folder
	if not l or not root then
		return
	end
	local toLoad, toUnload = WorldLayout.streamDiff(l, WORLD, positions, loaded :: any, keep)
	for _, index in toUnload do
		unloadChunk(index)
	end
	if not budgeted then
		for _, index in toLoad do
			buildChunk(l.chunks[index], root)
		end
		return
	end
	local function nearest(index: number): number
		local best = math.huge
		for _, pos in positions do
			best = math.min(best, WorldLayout.distanceToChunk(l, l.chunks[index], pos))
		end
		return best
	end
	table.sort(toLoad, function(a, b)
		return nearest(a) < nearest(b)
	end)
	local average = if loadedCount > 0
		then totalParts / loadedCount
		else PERF.ChunkPartBudgetPerFrame
	local allowance = PerfBudget.chunkAllowance(
		PERF.ChunkLoadBudgetPerFrame,
		totalParts,
		PERF.MaxLiveParts,
		average
	)
	local builtParts = 0
	for _, index in PerfBudget.take(toLoad, allowance) do
		if builtParts >= PERF.ChunkPartBudgetPerFrame then
			break
		end
		builtParts += buildChunk(l.chunks[index], root)
	end
end

-- Server stats for tools/qa/perf.luau (Studio sampling): loaded chunks and tracked chunk parts.
function ChunkService.getStats(): { chunks: number, parts: number }
	return { chunks = loadedCount, parts = totalParts }
end

-- Synchronously make sure chunks around a world position exist (spawn, teleport).
function ChunkService.ensureLoadedAround(x: number, z: number)
	applyDiff({ { x = x, z = z } }, false)
end

function ChunkService.getCampPosition(): Vector3?
	local l = layout
	if not l then
		return nil
	end
	return Vector3.new(l.camp.position.x, TELEPORT_HEIGHT, l.camp.position.z)
end

-- Ground-level spawn point beside the camp fire (inside its warm radius). Nil until start().
function ChunkService.getCampSpawnPosition(): Vector3?
	local l = layout
	if not l then
		return nil
	end
	return Vector3.new(l.camp.position.x + WORLD.CampSpawnOffset, 0, l.camp.position.z)
end

-- The camp campfire (tagged Config.Fire.Tag; FireService registers it from the tag).
function ChunkService.getCampFire(): BasePart?
	return campFire
end

function ChunkService.getSeed(): number?
	return if layout then layout.seed else nil
end

local function teleportRing(player: Player, arg: unknown)
	local l = layout
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not l or type(arg) ~= "number" or not (hrp and hrp:IsA("BasePart")) then
		return
	end
	-- Debug ring 1 = start forest, then outward; clamped to the outermost ring.
	local ring = math.min(WORLD.StartForestRing + (arg - 1), WorldLayout.maxRing(l.gridSize))
	local pos = WorldLayout.ringPosition(l, ring)
	ChunkService.ensureLoadedAround(pos.x, pos.z)
	hrp.CFrame = CFrame.new(pos.x, TELEPORT_HEIGHT, pos.z)
end

function ChunkService.start()
	if layout then
		return
	end
	local attr = Workspace:GetAttribute(WORLD.SeedAttribute)
	local seed = if type(attr) == "number"
		then attr
		elseif RunService:IsStudio() then WORLD.DefaultSeed
		else os.time()
	local l = WorldLayout.generate(seed, WORLD)
	layout = l
	Workspace:SetAttribute(WORLD.SeedAttribute, seed)
	PoiService.start(seed)

	local root = Instance.new("Folder")
	root.Name = WORLD.ChunkFolderName
	root.Parent = Workspace
	folder = root

	keep[l.camp.chunkIndex] = true
	Workspace:SetAttribute(
		WORLD.CampAttribute,
		Vector3.new(l.camp.position.x, 0, l.camp.position.z)
	)
	ChunkService.ensureLoadedAround(l.camp.position.x, l.camp.position.z)

	-- Camp campfire: outside the chunk models so streaming never removes it.
	local camp = Instance.new("Folder")
	camp.Name = WORLD.CampFolderName
	local fire = Instance.new("Part")
	fire.Name = Config.Fire.Tag
	fire.Size = CAMPFIRE_SIZE
	fire.Position = Vector3.new(l.camp.position.x, CAMPFIRE_SIZE.Y / 2, l.camp.position.z)
	fire.Anchored = true
	fire.Color = CAMPFIRE_COLOR
	fire.Material = Enum.Material.Neon
	CollectionService:AddTag(fire, Config.Fire.Tag)
	fire.Parent = camp
	camp.Parent = Workspace
	campFolder = camp
	campFire = fire

	heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < WORLD.StreamInterval then
			return
		end
		accumulator = 0
		releasePending()
		local positions = playerPositions()
		if #positions > 0 then
			applyDiff(positions, true)
		end
	end)

	unregisterDebug = DebugService.register("teleportRing", teleportRing)
end

function ChunkService.stop()
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
	if unregisterDebug then
		unregisterDebug()
		unregisterDebug = nil
	end
	for index in table.clone(loaded) do
		unloadChunk(index)
	end
	if folder then
		folder:Destroy()
		folder = nil
	end
	if campFolder then
		campFolder:Destroy()
		campFolder = nil
		campFire = nil
	end
	table.clear(nodeMemory)
	table.clear(partCounts)
	totalParts, loadedCount = 0, 0
	table.clear(pendingByChunk)
	PoiService.stop()
	layout = nil
end

return ChunkService
