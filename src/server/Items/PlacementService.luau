--!strict
-- Server-authoritative structure placement (PlaceRequest): workbench and campfire, grid-snapped,
-- costs one placeable item from the inventory. Rules are pure in shared/logic/Placement.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ItemCatalog = require(Shared.ItemCatalog)
local Placement = require(Shared.logic.Placement)
local Guard = require(script.Parent.Parent.Net.Guard)
local InventoryService = require(script.Parent.InventoryService)
local CraftingService = require(script.Parent.CraftingService)
local FireService = require(script.Parent.Parent.Survival.FireService)
local StructureService = require(script.Parent.StructureService)

local B = Config.Build
local MAX_ID_LENGTH = 32
local MAX_ROTATION = 3600 -- degrees; anything beyond is junk input
local RATE_KEY = "Place"
-- Block-out colors per structure role (Phase 4 replaces with art).
local ROLE_COLORS: { [string]: Color3 } = {
	workbench = Color3.fromRGB(140, 100, 60),
	campfire = Color3.fromRGB(230, 120, 40),
	forge = Color3.fromRGB(90, 90, 100),
	cooking = Color3.fromRGB(170, 110, 70),
	storage = Color3.fromRGB(120, 80, 45),
	wall = Color3.fromRGB(150, 110, 70),
	door = Color3.fromRGB(110, 75, 45),
	trap = Color3.fromRGB(170, 170, 175),
	watchtower = Color3.fromRGB(125, 90, 55),
	bed = Color3.fromRGB(190, 70, 70),
	maptable = Color3.fromRGB(205, 185, 130),
}
local ROLE_MATERIALS: { [string]: Enum.Material } = {
	campfire = Enum.Material.Neon,
	forge = Enum.Material.Slate,
	trap = Enum.Material.Metal,
	bed = Enum.Material.Fabric,
}

local PlacementService = {}

local placed: { [Instance]: number } = {} -- structure -> owner UserId
local folder: Folder? = nil
local connections: { RBXScriptConnection } = {}
local started = false
local placedHandler: ((Player, string) -> ())? = nil

-- Wiring (Phase 4): told after every successful placement (structure id). Nil-safe.
function PlacementService.setPlacedHandler(fn: ((Player, string) -> ())?)
	placedHandler = fn
end

local function finiteVector(v: Vector3): boolean
	return Guard.isNumber(v.X) and Guard.isNumber(v.Y) and Guard.isNumber(v.Z)
end

local function pivotOf(i: Instance): Vector3?
	if i:IsA("BasePart") then
		return i.Position
	elseif i:IsA("Model") then
		return i:GetPivot().Position
	end
	return nil
end

-- Every existing structure-like instance (placed, campfires, workbenches) for spacing.
local function otherPoints(): { Placement.Point }
	local seen: { [Instance]: boolean } = {}
	local out: { Placement.Point } = {}
	local function addPoint(i: Instance)
		if seen[i] then
			return
		end
		seen[i] = true
		local p = pivotOf(i)
		if p then
			table.insert(out, { x = p.X, z = p.Z })
		end
	end
	for i in placed do
		addPoint(i)
	end
	for _, i in CollectionService:GetTagged(Config.Fire.Tag) do
		addPoint(i)
	end
	for _, i in CollectionService:GetTagged(ItemCatalog.WorkbenchTag) do
		addPoint(i)
	end
	return out
end

local function ownedCount(player: Player): number
	local n = 0
	for _, owner in placed do
		if owner == player.UserId then
			n += 1
		end
	end
	return n
end

-- Placed structures of one role (per-role caps: storage chests).
local function roleCount(role: string): number
	local n = 0
	for inst in placed do
		local id = inst:GetAttribute(B.StructureAttribute)
		local d = if type(id) == "string" then ItemCatalog.Structures[id] else nil
		if d and d.role == role then
			n += 1
		end
	end
	return n
end

local function groundY(x: number, z: number, nearY: number): number?
	local chunks = Workspace:FindFirstChild(Config.World.ChunkFolderName)
	if chunks == nil then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { chunks, Workspace.Terrain } -- ground is Terrain voxels plus POI floors
	local hit = Workspace:Raycast(
		Vector3.new(x, nearY + B.GroundRayHeight, z),
		Vector3.new(0, -B.GroundRayLength, 0),
		params
	)
	return if hit then hit.Position.Y else nil
end

local function notify(player: Player, text: string)
	Remotes.event(Remotes.Notify):FireClient(player, "build", text)
end

local function build(
	player: Player,
	def: ItemCatalog.StructureDef,
	x: number,
	y: number,
	z: number,
	rotation: number
)
	local parent = folder
	if parent == nil then
		return
	end
	local part = Instance.new("Part")
	part.Name = def.id
	part.Size = Vector3.new(def.sizeX, def.sizeY, def.sizeZ)
	part.CFrame = CFrame.new(x, y + def.sizeY / 2, z) * CFrame.Angles(0, math.rad(rotation), 0)
	part.Anchored = true
	part.Color = ROLE_COLORS[def.role] or ROLE_COLORS.workbench
	part.Material = ROLE_MATERIALS[def.role] or Enum.Material.Wood
	part:SetAttribute(B.StructureAttribute, def.id)
	part:SetAttribute(B.OwnerAttribute, player.UserId)
	if def.role == "campfire" then
		CollectionService:AddTag(part, Config.Fire.Tag)
	end
	if def.station then
		CraftingService.registerStation(part, def.station, def.tier)
	end
	StructureService.onBuilt(part, def, player)
	placed[part] = player.UserId
	part.Destroying:Once(function()
		placed[part] = nil
	end)
	part.Parent = parent
	if def.role == "campfire" then
		FireService.register(part)
	end
end

-- Handler order: type-check -> range/sanity -> rate limit (Guard) -> state -> act.
local function onPlace(player: Player, structureId: unknown, position: unknown, rotationY: unknown)
	-- 1. type-check
	if
		type(structureId) ~= "string"
		or #structureId > MAX_ID_LENGTH
		or typeof(position) ~= "Vector3"
		or not Guard.isNumber(rotationY)
	then
		return
	end
	local id = structureId :: string
	local pos = position :: Vector3
	-- 2. range / sanity
	local def = ItemCatalog.Structures[id]
	if
		def == nil
		or not finiteVector(pos)
		or not Guard.inRange(rotationY, -MAX_ROTATION, MAX_ROTATION)
	then
		return
	end
	-- 3. rate limit
	if not Guard.rateLimit(player, RATE_KEY, Config.Net.PlaceRateInterval) then
		return
	end
	-- 4. state: alive, not downed, rules (range, spacing, caps, item), ground
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if humanoid == nil or root == nil or humanoid.Health <= 0 then
		return
	end
	if player:GetAttribute(Config.Downed.StateAttribute) == true then
		return
	end
	local snapped = Placement.snapPoint(pos.X, pos.Z, B.GridStep)
	local x, z = snapped.x, snapped.z
	local rotation = Placement.snapRotation(rotationY :: number, B.RotationStep)
	local litFires: { Placement.BuildFire } = {}
	for _, fire in FireService.getLitFires() do
		table.insert(litFires, { x = fire.x, z = fire.z, buildRadius = fire.buildRadius })
	end
	-- The same validator the client ghost runs; the server's inputs are its own data, never the client's.
	local result = Placement.validate({
		structureId = id,
		target = snapped,
		player = { x = root.Position.X, z = root.Position.Z },
		placeRange = B.PlaceRange,
		minSpacing = B.MinSpacing,
		others = otherPoints(),
		ownedCount = ownedCount(player),
		maxOwned = B.MaxStructuresPerPlayer,
		fireCount = FireService.count(),
		maxFires = Config.Fire.MaxPerTeam,
		itemCount = InventoryService.count(player, def.itemId),
		litFires = litFires,
		buildExempt = B.RangeExempt[def.id] == true,
		roleCount = if def.role == "storage" then roleCount("storage") else nil,
		roleMax = if def.role == "storage" then Config.Storage.MaxChestsPerRun else nil,
	})
	if not result.ok then
		notify(player, result.reason)
		return
	end
	local y = groundY(x, z, root.Position.Y)
	if y == nil then
		notify(player, "NoGround")
		return
	end
	-- 5. act: spend the item first; build only if it was spent
	if not InventoryService.remove(player, def.itemId, 1) then
		return
	end
	build(player, def, x, y, z, rotation)
	local handler = placedHandler
	if handler then
		task.spawn(handler, player, def.id)
	end
end

-- Same path as PlaceRequest (QA and server callers); runs the full validation.
PlacementService.handlePlace = onPlace

function PlacementService.start()
	if started then
		return
	end
	started = true
	local f = Instance.new("Folder")
	f.Name = B.FolderName
	f.Parent = Workspace
	folder = f
	table.insert(
		connections,
		Remotes.event(Remotes.PlaceRequest).OnServerEvent:Connect(
			function(player: Player, structureId: unknown, position: unknown, rotationY: unknown)
				if player.Parent ~= Players then
					return
				end
				onPlace(player, structureId, position, rotationY)
			end
		)
	)
end

function PlacementService.stop()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	if folder then
		folder:Destroy()
		folder = nil
	end
	table.clear(placed)
	started = false
end

return PlacementService
