--!strict
-- Studio-only art review aid: "/debug gallery <set>" lays every asset of an art pass out in one labelled
-- row in front of the caller; "/debug gallery clear" removes it. Each pass adds a set to SETS (and its
-- name to Config.Art.GallerySets). Items are built detached and stripped of gameplay tags so they never
-- register as real pads.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local PoiPlan = require(ReplicatedStorage.Shared.logic.PoiPlan)
local Rarity = require(ReplicatedStorage.Shared.data.Rarity)
local ChestArt = require(script.Parent.ChestArt)
local SignArt = require(script.Parent.Structures.SignArt)
local PoiStructures = require(script.Parent.Parent.World.PoiStructures)
local HubProps = require(script.Parent.HubProps)
local WorldProps = require(script.Parent.WorldProps)
local WorldArt = require(script.Parent.WorldArt)

local Gallery = {}

local SPACING_PAD = 16 -- studs added to a structure footprint for the row spacing
local CHEST_WIDTH = 8
local SIGN_WIDTH = 12
local GALLERY_SEED = 1
local LABEL_W = 10
local LABEL_H = 2

type Item = { label: string, width: number, build: (parent: Instance, cf: CFrame) -> () }

local function hubItems(): { Item }
	local P = Config.Art.Hub.Tags
	return {
		{
			label = "Pine small",
			width = 14,
			build = function(parent, cf)
				HubProps.pine(parent, cf.Position, "HubPineSmall", 1.2, 0, false)
			end,
		},
		{
			label = "Pine large",
			width = 30,
			build = function(parent, cf)
				HubProps.pine(parent, cf.Position, "HubPineLarge", 0.9, 0, false)
			end,
		},
		{
			label = "Rock",
			width = 14,
			build = function(parent, cf)
				HubProps.rock(parent, cf.Position, Vector3.new(6, 5, 6), 0.4)
			end,
		},
		{
			label = "Drift",
			width = 20,
			build = function(parent, cf)
				HubProps.drift(parent, cf.Position, Vector3.new(14, 5, 10))
			end,
		},
		{
			label = "Lamp post",
			width = 10,
			build = function(parent, cf)
				HubProps.lampPost(parent, cf.Position, 10)
			end,
		},
		{
			label = "Fire pit",
			width = 26,
			build = function(parent, cf)
				HubProps.firePit(parent, cf.Position, false)
			end,
		},
		{
			label = "Bonfire",
			width = 34,
			build = function(parent, cf)
				HubProps.firePit(parent, cf.Position, true)
			end,
		},
		{
			label = "Pad 3",
			width = 26,
			build = function(parent, cf)
				HubProps.pad(parent, 3, cf)
			end,
		},
		{
			label = "Pad 6",
			width = 34,
			build = function(parent, cf)
				HubProps.pad(parent, 6, cf)
			end,
		},
		{
			label = "Board",
			width = 34,
			build = function(parent, cf)
				HubProps.board(parent, cf, P.Leaderboard, "BOARD")
			end,
		},
		{
			label = "Shop",
			width = 44,
			build = function(parent, cf)
				HubProps.shop(parent, cf)
			end,
		},
		{
			label = "Stats area",
			width = 34,
			build = function(parent, cf)
				HubProps.statsArea(parent, cf)
			end,
		},
		{
			label = "Mirror",
			width = 24,
			build = function(parent, cf)
				HubProps.mirror(parent, cf)
			end,
		},
		{
			label = "Mountain (small)",
			width = 70,
			build = function(parent, cf)
				HubProps.mountain(parent, cf.Position + Vector3.new(0, 30, 0), 40, 30, 36, 0)
			end,
		},
	}
end

-- World set (art pass 2): every tree/rock/ore/decor kind, one mini-scene per biome, every POI.
local function worldItems(): { Item }
	local items: { Item } = {}
	local function add(label: string, width: number, build: (Instance, CFrame) -> ())
		table.insert(items, { label = label, width = width, build = build })
	end
	local rng = Random.new(1)
	for _, kind in { "PineTall", "PineFat", "PineYoung", "PineFrost", "DeadTree", "DeadTwisted" } do
		add(kind, 18, function(parent, cf)
			WorldProps.tree(parent, CFrame.new(cf.Position), kind)
		end)
	end
	add("Stump (tree depleted)", 10, function(parent, cf)
		WorldProps.stump(parent, CFrame.new(cf.Position))
	end)
	for _, kind in { "Boulder", "Slab", "IceRock", "DarkBoulder", "DarkSlab" } do
		add(kind, 14, function(parent, cf)
			WorldProps.rock(parent, CFrame.new(cf.Position), kind)
		end)
	end
	add("Iron ore", 14, function(parent, cf)
		WorldProps.ore(parent, CFrame.new(cf.Position))
	end)
	add("Rubble (rock depleted)", 10, function(parent, cf)
		WorldProps.rubbleSmall(parent, CFrame.new(cf.Position), nil)
	end)
	for _, kind in
		{ "Drift", "Bush", "Tuft", "Reeds", "Shard", "Crack", "Crystal", "Scree", "Rubble" }
	do
		add(`Decor: {kind}`, 16, function(parent, cf)
			WorldProps.decor(parent, CFrame.new(cf.Position), kind, rng)
		end)
	end
	for _, biome in { "SnowyForest", "FrozenLake", "MountainsCaves", "DeepTundra" } do
		add(`Biome: {biome}`, 56, function(parent, cf)
			local art = Config.Art.World.Biomes[biome]
			local ground = Instance.new("Part")
			ground.Name = "GroundSample"
			ground.Anchored = true
			ground.CanCollide = false
			ground.Size = Vector3.new(50, 1, 50)
			ground.CFrame = CFrame.new(cf.Position - Vector3.new(0, 0.5, 0))
			WorldArt.styleGround(ground, biome, 1)
			ground.Parent = parent
			WorldArt.decorChunk(parent :: Model, biome, cf.Position.X, cf.Position.Z, Random.new(5))
			WorldProps.tree(
				parent,
				CFrame.new(cf.Position + Vector3.new(-14, 0, -10)),
				art.TreeSet[1]
			)
			WorldProps.tree(
				parent,
				CFrame.new(cf.Position + Vector3.new(0, 0, -14)),
				art.TreeSet[#art.TreeSet]
			)
			WorldProps.rock(
				parent,
				CFrame.new(cf.Position + Vector3.new(14, 0, -8)),
				art.RockSet[1]
			)
		end)
	end
	local function poi(label: string, width: number, kind: string)
		add(label, width, function(parent, cf)
			WorldProps.poi(parent, kind, cf * CFrame.Angles(0, math.pi, 0))
		end)
	end
	poi("POI: Cabin", 34, "cabin")
	poi("POI: Crashed plane", 34, "plane")
	poi("POI: Cave", 30, "cave")
	poi("POI: Ruin", 34, "ruin")
	poi("POI: Campsite", 26, "campsite")
	add("POI: Hot spring", 34, function(parent, cf)
		local spring = Instance.new("Part")
		spring.Name = "HotSpring"
		spring.Anchored = true
		spring.CanCollide = false
		spring.Shape = Enum.PartType.Cylinder
		spring.Size = Vector3.new(0.5, 16, 16)
		spring.CFrame = CFrame.new(cf.Position + Vector3.new(0, 0.25, 0))
			* CFrame.Angles(0, 0, math.pi / 2)
		spring.Color = Color3.fromRGB(110, 190, 220)
		spring.Material = Enum.Material.Glass
		spring.Transparency = 0.3
		WorldArt.dressSpring(spring)
		spring.Parent = parent
		WorldProps.poi(parent, "hotspring", CFrame.new(cf.Position))
	end)
	return items
end

-- Structures set (art pass 4): every enterable POI kind x variant from PoiPlan (new variants auto-appear).
local function structureItems(): { Item }
	local items: { Item } = {}
	for _, kind in PoiPlan.EnterableKinds do
		for _, variant in PoiPlan.allVariants(kind) do
			local plan = PoiPlan.build(kind, variant, 0, 0)
			if plan then
				table.insert(items, {
					label = `{kind}: {variant}`,
					width = math.ceil(plan.radius * 2) + SPACING_PAD,
					build = function(parent, cf)
						PoiStructures.build(parent, plan, cf * CFrame.Angles(0, math.pi, 0))
					end,
				})
			end
		end
	end
	return items
end

-- Chests set: every rarity closed and opened (ChestArt.build / setOpened).
local function chestItems(): { Item }
	local items: { Item } = {}
	for _, rarity in Rarity.List do
		for _, opened in { false, true } do
			table.insert(items, {
				label = `{rarity}{if opened then " (opened)" else ""}`,
				width = CHEST_WIDTH,
				build = function(parent, cf)
					local chest = ChestArt.build(rarity, CFrame.new(cf.Position), parent)
					for _, d in chest:GetDescendants() do
						if d:IsA("ProximityPrompt") then
							d.Enabled = false -- inert: not registered with LootService
						end
					end
					if opened then
						ChestArt.setOpened(chest, true)
					end
				end,
			})
		end
	end
	return items
end

-- Signs set: a room sign and a note, fixed in the world (SurfaceGui on the part itself).
local function signItems(): { Item }
	return {
		{
			label = "Room sign",
			width = SIGN_WIDTH,
			build = function(parent, cf)
				local part = Instance.new("Part")
				part.Name = "Sign"
				part.Anchored = true
				part.Size = Vector3.new(6.4, 1.8, 0.2)
				part.Material = Enum.Material.Metal
				part.Color = Color3.fromRGB(40, 44, 52)
				part.CFrame = CFrame.new(cf.Position + Vector3.new(0, 6, 0))
					* CFrame.Angles(0, math.pi, 0)
				SignArt.attach(part, "SAMPLE WING", false, nil)
				part.Parent = parent
			end,
		},
		{
			label = "Note",
			width = SIGN_WIDTH,
			build = function(parent, cf)
				local part = Instance.new("Part")
				part.Name = "Note"
				part.Anchored = true
				part.Size = Vector3.new(1.4, 0.15, 1.8)
				part.Material = Enum.Material.Fabric
				part.Color = Color3.fromRGB(200, 190, 160)
				part.CFrame = CFrame.new(cf.Position + Vector3.new(0, 0.3, 0))
				SignArt.attach(part, "Sample note", true, "Top")
				part.Parent = parent
			end,
		},
	}
end

-- Massive set: ONE massive structure at a time (part cap). Builders are enumerated from the Structures folder
-- (any module with a build function, excluding the StructureKit adapters), so new ones auto-appear; each
-- `/debug gallery massive` call builds the next one. Needs terrain under the caller (it carves/levels it).
local massiveIndex = 0
local massiveHandle: { Destroy: () -> () }? = nil
local massiveToken = 0

local function massiveBuilders(): { { id: string, build: (Vector3, number, Instance) -> any } }
	local out: { { id: string, build: (Vector3, number, Instance) -> any } } = {}
	local folder = script.Parent.Parent.World:FindFirstChild("Structures")
	if not folder then
		return out
	end
	local ids: { string } = {}
	local byId: { [string]: (Vector3, number, Instance) -> any } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") and not string.find(child.Name, "^StructureKit") then
			local ok, mod = pcall(require, child)
			if ok and type(mod) == "table" and type((mod :: any).build) == "function" then
				local id = (mod :: any).Id or child.Name
				if type(id) == "string" then
					byId[id] = (mod :: any).build
					table.insert(ids, id)
				end
			end
		end
	end
	for _, id in Config.Massive.Ids do -- configured order first
		if byId[id] then
			table.insert(out, { id = id, build = byId[id] })
			byId[id] = nil
		end
	end
	table.sort(ids)
	for _, id in ids do
		if byId[id] then
			table.insert(out, { id = id, build = byId[id] })
		end
	end
	return out
end

local function destroyMassive()
	massiveToken += 1
	local handle = massiveHandle
	massiveHandle = nil
	if handle then
		pcall(handle.Destroy)
	end
end

local function massiveItems(): { Item }
	local builders = massiveBuilders()
	if #builders == 0 then
		return {}
	end
	massiveIndex = massiveIndex % #builders + 1
	local entry = builders[massiveIndex]
	local rule = Config.Massive.Structures[entry.id]
	local width = if rule
		then math.max(rule.MinFootprintX, rule.MinFootprintZ) + SPACING_PAD
		else 120
	return {
		{
			label = `{entry.id} ({massiveIndex}/{#builders})`,
			width = width,
			build = function(parent, cf)
				local ok, handle = pcall(entry.build, cf.Position, GALLERY_SEED, parent)
				if not ok or type(handle) ~= "table" then
					warn(`[Gallery] {entry.id} build failed: {handle}`)
					return
				end
				massiveHandle = handle
				massiveToken += 1
				local token = massiveToken
				task.spawn(function()
					while token == massiveToken and massiveHandle == handle do
						local positions: { Vector3 } = {}
						for _, pl in Players:GetPlayers() do
							local root = pl.Character
								and pl.Character:FindFirstChild("HumanoidRootPart")
							if root and root:IsA("BasePart") then
								table.insert(positions, root.Position)
							end
						end
						pcall(handle.Update, positions)
						task.wait(Config.Massive.DressingCheckInterval)
					end
				end)
			end,
		},
	}
end

local SETS: { [string]: () -> { Item } } = {
	hub = hubItems,
	world = worldItems,
	structures = structureItems,
	chests = chestItems,
	signs = signItems,
	massive = massiveItems,
}

local function clear()
	destroyMassive()
	local folder = Workspace:FindFirstChild(Config.Art.GalleryRoot)
	if folder then
		folder:Destroy()
	end
end

-- DebugService handler: (player, setName).
function Gallery.handle(player: Player, arg: unknown)
	clear()
	if arg == "clear" or type(arg) ~= "string" then
		return
	end
	local make = SETS[arg]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (make and root and root:IsA("BasePart")) then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = Config.Art.GalleryRoot
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local right = flat:Cross(Vector3.yAxis)
	local ground = Vector3.new(root.Position.X, root.Position.Y - 3, root.Position.Z)
		+ flat * Config.Art.GalleryDistance
	local items = make()
	local total = 0
	for _, item in items do
		total += item.width
	end
	local cursor = -total / 2
	for _, item in items do
		local pos = ground + right * (cursor + item.width / 2)
		cursor += item.width
		local cf = CFrame.lookAt(pos, Vector3.new(root.Position.X, pos.Y, root.Position.Z))
		local holder = Instance.new("Model")
		holder.Name = item.label
		item.build(holder, cf)
		local tag = Instance.new("Part") -- fixed label plate (SurfaceGui on the part, faces the row's front)
		tag.Name = "Label"
		tag.Anchored = true
		tag.CanCollide = false
		tag.CanQuery = false
		tag.Size = Vector3.new(LABEL_W, LABEL_H, 0.2)
		tag.Material = Enum.Material.SmoothPlastic
		tag.Color = Color3.fromRGB(18, 28, 40)
		tag.CFrame = CFrame.lookAt(pos + Vector3.new(0, 1, 0), pos + Vector3.new(0, 1, 0) - flat)
		SignArt.attach(tag, item.label, false, "Front")
		tag.Parent = holder
		holder.Parent = folder
	end
	for _, d in folder:GetDescendants() do
		CollectionService:RemoveTag(d, Config.Lobby.PadTag)
	end
	folder.Parent = Workspace
end

function Gallery.clear()
	clear()
end

return Gallery
