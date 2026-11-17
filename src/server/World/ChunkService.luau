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
local Server = ServerScriptService:WaitForChild("Server")
local DebugService = require(Server:WaitForChild("Debug"):WaitForChild("DebugService"))
local GatherService = require(Server:WaitForChild("Items"):WaitForChild("GatherService"))

local WORLD = Config.World
local SLOT_TAGS = WORLD.SlotTags
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
	}
local CAMPFIRE_SIZE = Vector3.new(4, 1, 4)
local CAMPFIRE_COLOR = Color3.fromRGB(230, 120, 40)
local VARIANT_COLORS = {
	Color3.fromRGB(226, 234, 240),
	Color3.fromRGB(214, 225, 235),
	Color3.fromRGB(232, 238, 244),
}

local ChunkService = {}

local layout: WorldLayout.Layout? = nil
local folder: Folder? = nil
local loaded: { [number]: Model } = {}
local keep: { [number]: boolean } = {}
local accumulator = 0
local heartbeatConn: RBXScriptConnection? = nil
local unregisterDebug: (() -> ())? = nil
local campFolder: Folder? = nil
local campFire: BasePart? = nil

-- Tree/rock slots are visible gather nodes registered with GatherService (tier and respawn come
-- from Config via ItemCatalog.Nodes); other slots are invisible markers.
local function newSlot(parent: Instance, tag: string, pos: WorldLayout.Vec2)
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
	if node then
		GatherService.registerNode(part, node.kind)
	end
end

local function buildChunk(chunk: WorldLayout.Chunk, root: Folder)
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
	ground.Color = VARIANT_COLORS[chunk.variant] or VARIANT_COLORS[1]
	ground.Material = Enum.Material.Snow
	ground.Parent = model

	for _, p in chunk.trees do
		newSlot(model, SLOT_TAGS.Tree, p)
	end
	for _, p in chunk.rocks do
		newSlot(model, SLOT_TAGS.Rock, p)
	end
	for _, p in chunk.food do
		newSlot(model, SLOT_TAGS.Food, p)
	end
	for _, p in chunk.spawnZones do
		newSlot(model, SLOT_TAGS.SpawnZone, p)
	end

	CollectionService:AddTag(model, WORLD.ChunkTag)
	model.Parent = root
	loaded[chunk.index] = model
end

local function unloadChunk(index: number)
	local model = loaded[index]
	loaded[index] = nil
	if model then
		model:Destroy()
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

local function applyDiff(positions: { WorldLayout.Vec2 })
	local l, root = layout, folder
	if not l or not root then
		return
	end
	local toLoad, toUnload = WorldLayout.streamDiff(l, WORLD, positions, loaded :: any, keep)
	for _, index in toLoad do
		buildChunk(l.chunks[index], root)
	end
	for _, index in toUnload do
		unloadChunk(index)
	end
end

-- Synchronously make sure chunks around a world position exist (spawn, teleport).
function ChunkService.ensureLoadedAround(x: number, z: number)
	applyDiff({ { x = x, z = z } })
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
		local positions = playerPositions()
		if #positions > 0 then
			applyDiff(positions)
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
	layout = nil
end

return ChunkService
