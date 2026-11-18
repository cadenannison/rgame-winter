--!strict
-- World art (pass 2): turns the block-out chunks into biome-distinct scenery. ChunkService calls
--   WorldArt.styleGround  - per-biome ground colour/material
--   WorldArt.decorChunk   - ground patches + ground cover, capped by Config.Art.World.ChunkDecorBudget
--   WorldArt.skinNode     - tree/rock/ore art for a gather slot; the slot Part stays the invisible
--                           gameplay node, art hides and a stump/rubble shows while it is depleted
--   WorldArt.poi          - POI dressing (cabins, planes, caves, ruins, camps, springs)
-- Everything is deterministic from (Config.Art.World.Seed, chunk index) so a reloaded chunk looks the
-- same. Data (palettes, per-biome sets and counts) lives in Config.Art.World.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ArtKit = require(ReplicatedStorage.Shared.ArtKit)
local ItemCatalog = require(ReplicatedStorage.Shared.ItemCatalog)
local WorldProps = require(script.Parent.WorldProps)

local W = Config.Art.World
local P = ArtKit.palette(W.Palette)

local WorldArt = {}

local MATERIALS: { [string]: Enum.Material } = {
	Snow = Enum.Material.Snow,
	Ice = Enum.Material.Ice,
	Glacier = Enum.Material.Glacier,
	Slate = Enum.Material.Slate,
	Rock = Enum.Material.Rock,
	Ground = Enum.Material.Ground,
}

local function material(name: string): Enum.Material
	return MATERIALS[name] or Enum.Material.Snow
end

local function biomeArt(biome: string): Config.WorldBiomeArt
	return W.Biomes[biome] or W.Biomes.SnowyForest
end

-- Deterministic generator for one chunk.
function WorldArt.chunkRandom(chunkIndex: number): Random
	return Random.new(W.Seed + chunkIndex * 7919)
end

function WorldArt.styleGround(ground: Part, biome: string, variantShade: number)
	local art = biomeArt(biome)
	local c = ArtKit.color(art.Ground)
	ground.Color = Color3.new(
		math.clamp(c.R * variantShade, 0, 1),
		math.clamp(c.G * variantShade, 0, 1),
		math.clamp(c.B * variantShade, 0, 1)
	)
	ground.Material = material(art.Material)
end

-- Random point inside the chunk (axis-aligned square around its centre), clear of the edge.
local function pointIn(centerX: number, centerZ: number, rng: Random): Vector3
	local half = Config.World.ChunkSize / 2 - W.DecorEdgeMargin
	return Vector3.new(
		centerX + rng:NextNumber(-half, half),
		0,
		centerZ + rng:NextNumber(-half, half)
	)
end

-- Patches first (they sit under everything), then ground cover round-robin over the biome's decor list
-- until the part budget is spent. Returns the parts added.
function WorldArt.decorChunk(
	model: Model,
	biome: string,
	centerX: number,
	centerZ: number,
	rng: Random
): number
	local art = biomeArt(biome)
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	local budget = W.ChunkDecorBudget
	local used = 0
	local alt = ArtKit.color(art.GroundAlt)
	local patchMaterial = material(art.PatchMaterial)
	for _ = 1, W.ChunkPatchCount do
		if used >= budget then
			break
		end
		local size = rng:NextNumber(W.PatchSize[1], W.PatchSize[2])
		local pos = pointIn(centerX, centerZ, rng)
		local k = rng:NextNumber(0.9, 1.08)
		WorldProps.patch(
			folder,
			pos,
			size,
			rng:NextNumber(0, math.pi),
			Color3.new(
				math.clamp(alt.R * k, 0, 1),
				math.clamp(alt.G * k, 0, 1),
				math.clamp(alt.B * k, 0, 1)
			),
			patchMaterial
		)
		used += 1
	end
	local remaining: { { kind: string, left: number } } = {}
	for _, entry in art.Decor do
		table.insert(remaining, { kind = entry.kind, left = entry.count })
	end
	local progressed = true
	while used < budget and progressed do
		progressed = false
		for _, entry in remaining do
			local cost = WorldProps.DecorCost[entry.kind] or 2
			if entry.left > 0 and used + cost <= budget then
				entry.left -= 1
				progressed = true
				local pos = pointIn(centerX, centerZ, rng)
				local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
				if WorldProps.decor(folder, cf, entry.kind, rng) then
					used += cost
				end
			end
		end
	end
	folder.Parent = model
	return used
end

----------------------------------------------------------------------------------------------------
-- Gather nodes
----------------------------------------------------------------------------------------------------

type Shown = { part: BasePart, transparency: number }

local function collect(root: Instance): { Shown }
	local out: { Shown } = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, { part = d, transparency = d.Transparency })
		end
	end
	return out
end

local function setShown(list: { Shown }, shown: boolean)
	for _, s in list do
		s.part.Transparency = if shown then s.transparency else 1
	end
end

local function pick(list: { string }, rng: Random): string
	return list[rng:NextInteger(1, #list)]
end

-- Builds the art for one gather slot. `node` is the Part GatherService registers (kept as is: it still
-- carries the hit/depletion attributes); it is made invisible and its art model sits in `parent`.
function WorldArt.skinNode(node: Part, kind: string, biome: string, parent: Instance, rng: Random)
	local art = biomeArt(biome)
	local ground = Vector3.new(node.Position.X, 0, node.Position.Z)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local cf = CFrame.new(ground) * CFrame.Angles(0, yaw, 0)
	local holder = Instance.new("Model")
	holder.Name = `{node.Name}Art`
	local full: Model
	local gone: Model
	if kind == "Tree" then
		full = WorldProps.tree(holder, cf, pick(art.TreeSet, rng))
		gone = WorldProps.stump(holder, cf)
	elseif kind == "IronOre" then
		full = WorldProps.ore(holder, cf)
		gone = WorldProps.rubbleSmall(holder, cf, P.RockDark)
	else
		full = WorldProps.rock(holder, cf, pick(art.RockSet, rng))
		gone = WorldProps.rubbleSmall(holder, cf, nil)
	end
	local fullParts = collect(full)
	local goneParts = collect(gone)
	setShown(goneParts, false)
	node.Transparency = 1 -- invisible hit proxy; GatherService records this as its "visible" state
	local function sync()
		local depleted = node:GetAttribute(ItemCatalog.NodeDepletedAttribute) == true
		setShown(fullParts, not depleted)
		setShown(goneParts, depleted)
	end
	-- Connection dies with the node part (chunk unload destroys the model).
	node:GetAttributeChangedSignal(ItemCatalog.NodeDepletedAttribute):Connect(sync)
	holder.Parent = parent
	sync()
end

----------------------------------------------------------------------------------------------------
-- Points of interest
----------------------------------------------------------------------------------------------------

function WorldArt.poi(parent: Instance, kind: string, base: CFrame)
	WorldProps.poi(parent, kind, base)
end

-- Dressing that attaches to PoiService's functional parts.
function WorldArt.dressHearth(parent: Instance, base: CFrame, offset: Vector3, hearth: BasePart)
	WorldProps.hearthSurround(parent, base, offset)
	WorldProps.hearthFx(hearth)
end

function WorldArt.dressSpring(spring: BasePart)
	WorldProps.steam(spring)
end

return WorldArt
