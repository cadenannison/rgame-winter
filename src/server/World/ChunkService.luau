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
local DebugService = require(
	ServerScriptService:WaitForChild("Server"):WaitForChild("Debug"):WaitForChild("DebugService")
)

local WORLD = Config.World
local CHUNK_FOLDER_NAME = "Chunks"
local SEED_ATTRIBUTE = "WorldSeed"
local CAMP_ATTRIBUTE = "CampPosition"
local GROUND_THICKNESS = 1
local SLOT_SIZE = Vector3.new(2, 2, 2)
local TELEPORT_HEIGHT = 5
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

local function newSlot(parent: Instance, tag: string, pos: WorldLayout.Vec2)
	local part = Instance.new("Part")
	part.Name = tag
	part.Size = SLOT_SIZE
	part.Position = Vector3.new(pos.x, SLOT_SIZE.Y / 2, pos.z)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	CollectionService:AddTag(part, tag)
	part.Parent = parent
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
		newSlot(model, WorldLayout.SlotKinds.Tree, p)
	end
	for _, p in chunk.rocks do
		newSlot(model, WorldLayout.SlotKinds.Rock, p)
	end
	for _, p in chunk.food do
		newSlot(model, WorldLayout.SlotKinds.Food, p)
	end
	for _, p in chunk.spawnZones do
		newSlot(model, WorldLayout.SlotKinds.SpawnZone, p)
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
	local attr = Workspace:GetAttribute(SEED_ATTRIBUTE)
	local seed = if type(attr) == "number"
		then attr
		elseif RunService:IsStudio() then WORLD.DefaultSeed
		else os.time()
	local l = WorldLayout.generate(seed, WORLD)
	layout = l
	Workspace:SetAttribute(SEED_ATTRIBUTE, seed)

	local root = Instance.new("Folder")
	root.Name = CHUNK_FOLDER_NAME
	root.Parent = Workspace
	folder = root

	keep[l.camp.chunkIndex] = true
	Workspace:SetAttribute(CAMP_ATTRIBUTE, Vector3.new(l.camp.position.x, 0, l.camp.position.z))
	ChunkService.ensureLoadedAround(l.camp.position.x, l.camp.position.z)

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
	layout = nil
end

return ChunkService
