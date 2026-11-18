--!strict
-- Builds the forest of one chunk from ForestPlacement. Each tree is Config.Forest.MaxPartsPerTree parts:
-- a tall bare trunk Part (the gather node: solid, CastShadow) with two foliage Parts parented under it
-- near the top (CanCollide/CanQuery/CanTouch off; they cast shadows only for big canopies). GatherService hides every descendant
-- part when the node is depleted, so the whole tree vanishes and returns with the node.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ArtKit = require(Shared:WaitForChild("ArtKit"))
local ForestPlacement = require(Shared:WaitForChild("logic"):WaitForChild("ForestPlacement"))
local TreeRules = require(Shared:WaitForChild("logic"):WaitForChild("TreeRules"))
local WorldLayout = require(Shared:WaitForChild("logic"):WaitForChild("WorldLayout"))

local F = Config.Forest
local W = Config.Art.World
local P = ArtKit.palette(W.Palette)

local TreeBuilder = {}

local UPPER_TIER_WIDTH = 0.55 -- of the lower tier width
local UPPER_YAW = math.rad(45)
local SHADE_STEP = 0.1

local function needleColor(biome: string): Color3
	local art = W.Biomes[biome] or W.Biomes.SnowyForest
	local first = art.TreeSet[1]
	if first == "PineFrost" then
		return P.NeedleFrost
	elseif first == "PineFat" then
		return P.NeedleDeep
	end
	return P.Needle
end

local function shade(c: Color3, f: number): Color3
	return Color3.new(
		math.clamp(c.R * f, 0, 1),
		math.clamp(c.G * f, 0, 1),
		math.clamp(c.B * f, 0, 1)
	)
end

local function foliage(
	parent: Part,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	casts: boolean
)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = Enum.Material.Grass
	part.Anchored = true
	part.CanCollide = TreeRules.FOLIAGE_FLAGS.CanCollide
	part.CanQuery = TreeRules.FOLIAGE_FLAGS.CanQuery
	part.CanTouch = TreeRules.FOLIAGE_FLAGS.CanTouch
	part.CastShadow = casts
	part.Parent = parent
end

-- One tree at its ground point: a tall bare trunk (solid, the gather node) with foliage only near the top
-- (TreeRules.shape; lowest foliage >= head + clearance, so players walk under the canopy). Returns the
-- trunk (not yet parented).
function TreeBuilder.createTree(tree: ForestPlacement.Tree, biome: string): Part
	local h = tree.height
	local shape = TreeRules.shape(h)
	local trunkH = shape.trunkHeight
	local d = tree.trunkRadius * 2
	local base = CFrame.new(tree.x, tree.y, tree.z) * CFrame.Angles(0, tree.yaw, 0)
	local trunk = Instance.new("Part")
	trunk.Name = "Tree"
	trunk.Size = Vector3.new(d, trunkH, d)
	trunk.CFrame = base * CFrame.new(0, trunkH / 2, 0)
	trunk.Color = P.Bark
	trunk.Material = Enum.Material.Wood
	trunk.Anchored = true
	trunk.CanCollide = TreeRules.TRUNK_FLAGS.CanCollide
	trunk.CanTouch = TreeRules.TRUNK_FLAGS.CanTouch
	trunk.CastShadow = true
	trunk:SetAttribute(F.TagAttribute, tree.classId)

	local casts = tree.canopyRadius >= Config.Shadows.CanopyShadowMinRadius
		and Config.Shadows.TreesCastShadows
	local needle = needleColor(biome)
	local w = tree.canopyRadius * 2
	foliage(
		trunk,
		"FoliageLow",
		Vector3.new(w, shape.lowerHeight, w),
		base * CFrame.new(0, shape.lowerBottom + shape.lowerHeight / 2, 0),
		shade(needle, 1 - SHADE_STEP),
		casts
	)
	local uw = w * UPPER_TIER_WIDTH
	foliage(
		trunk,
		"FoliageTop",
		Vector3.new(uw, shape.upperHeight, uw),
		base
			* CFrame.new(0, shape.upperBottom + shape.upperHeight / 2, 0)
			* CFrame.Angles(0, UPPER_YAW, 0),
		shade(needle, 1 + SHADE_STEP),
		casts
	)
	return trunk
end

local function inside(p: WorldLayout.Vec2, center: WorldLayout.Vec2, half: number): boolean
	return math.abs(p.x - center.x) <= half and math.abs(p.z - center.z) <= half
end

-- Builds every tree of `chunk` and calls onTree(index, groundPos, trunk) for each (ChunkService parents the
-- trunk and registers it as a gather node). Deterministic per (seed, chunk).
function TreeBuilder.forEach(
	layout: WorldLayout.Layout,
	chunk: WorldLayout.Chunk,
	onTree: (number, WorldLayout.Vec2, Part) -> (),
	extraClears: { ForestPlacement.Clear }? -- massive structure footprints kept tree free
)
	local half = layout.chunkSize / 2
	local pois = ForestPlacement.poiClears(layout, chunk, extraClears)
	local blocked: { WorldLayout.Vec2 } = {}
	for _, list in { chunk.rocks, chunk.ore, chunk.food, chunk.spawnZones } do
		for _, p in list do
			table.insert(blocked, p)
		end
	end
	local trees = ForestPlacement.generate({
		seed = layout.seed,
		chunkIndex = chunk.index,
		center = chunk.center,
		size = layout.chunkSize,
		ring = chunk.ring,
		camp = layout.camp.position,
		isCampChunk = inside(layout.camp.position, chunk.center, half),
		pois = pois,
		blocked = blocked,
	})
	for i, tree in trees do
		onTree(i, { x = tree.x, z = tree.z }, TreeBuilder.createTree(tree, chunk.biome))
	end
end

return TreeBuilder
