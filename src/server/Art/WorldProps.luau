--!strict
-- World prop generators (art pass 2). Every builder lays low-poly Part geometry into `parent` at `cf`
-- (cf = ground point, +Y up) and returns the Model it made. Pure geometry: no scripts, no gameplay tags;
-- WorldArt places them on chunks/nodes/POIs and /debug gallery world shows each one. Part counts are
-- capped by Config.Art.World (MaxPartsPerTree / MaxPartsPerRock / MaxPartsPerPoi); WorldProps.count
-- measures them. Trees, rocks and decor never collide (the invisible gather node part stays the
-- gameplay object); POI hulls collide where the old block-outs did.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ArtKit = require(ReplicatedStorage.Shared.ArtKit)

local W = Config.Art.World
local P = ArtKit.palette(W.Palette)

local WorldProps = {}

local WOOD = Enum.Material.Wood
local SLATE = Enum.Material.Slate
local ROCK = Enum.Material.Rock
local SNOW = Enum.Material.Snow
local ICE = Enum.Material.Ice
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local GRASS = Enum.Material.Grass
local FABRIC = Enum.Material.Fabric
local GLASS = Enum.Material.Glass
local PLASTIC = Enum.Material.SmoothPlastic

type Opts = { collide: boolean?, shape: Enum.PartType?, transparency: number? }

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	opts: Opts?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = false
	p.CanTouch = false
	local o: Opts = opts or ({} :: Opts)
	p.CanCollide = o.collide == true
	p.CanQuery = o.collide == true
	if o.shape then
		p.Shape = o.shape
	end
	if o.transparency then
		p.Transparency = o.transparency
	end
	p.Parent = parent
	return p
end

local function model(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function rad(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

local function shade(color: Color3, f: number): Color3
	return Color3.new(
		math.clamp(color.R * f, 0, 1),
		math.clamp(color.G * f, 0, 1),
		math.clamp(color.B * f, 0, 1)
	)
end

-- BasePart count under root (budget checks, tools/qa, gallery).
function WorldProps.count(root: Instance): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

----------------------------------------------------------------------------------------------------
-- Trees (<= Config.Art.World.MaxPartsPerTree parts)
----------------------------------------------------------------------------------------------------

type PineSpec = {
	height: number,
	trunk: number,
	tiers: number,
	baseWidth: number,
	needle: Color3,
	snowCaps: boolean,
	frost: boolean,
}

local PINES: { [string]: PineSpec } = {
	PineTall = {
		height = 17,
		trunk = 1.3,
		tiers = 3,
		baseWidth = 8,
		needle = P.Needle,
		snowCaps = false,
		frost = false,
	},
	PineFat = {
		height = 13,
		trunk = 1.6,
		tiers = 3,
		baseWidth = 11,
		needle = P.NeedleDeep,
		snowCaps = true,
		frost = false,
	},
	PineYoung = {
		height = 9,
		trunk = 0.9,
		tiers = 2,
		baseWidth = 6,
		needle = P.Needle,
		snowCaps = false,
		frost = false,
	},
	PineFrost = {
		height = 14,
		trunk = 1.2,
		tiers = 3,
		baseWidth = 7.5,
		needle = P.NeedleFrost,
		snowCaps = true,
		frost = true,
	},
}

-- Stacked tiers, each a pair of blocks twisted 45 degrees (an 8-point star seen from above).
local function pine(parent: Instance, cf: CFrame, spec: PineSpec, name: string): Model
	local m = model(name, parent)
	local h = spec.height
	part(
		m,
		"Trunk",
		Vector3.new(spec.trunk, h * 0.3, spec.trunk),
		cf * CFrame.new(0, h * 0.15, 0),
		P.Bark,
		WOOD
	)
	for i = 1, spec.tiers do
		local f = 1 - (i - 1) / (spec.tiers + 0.4)
		local w = spec.baseWidth * f
		local th = h * 0.42 / (spec.tiers * 0.7 + 0.3)
		local y = h * 0.2 + (i - 1) * (h * 0.7 / spec.tiers) + th / 2
		local color = shade(spec.needle, 0.9 + 0.12 * i)
		local tier = cf * CFrame.new(0, y, 0)
		part(m, `Tier{i}A`, Vector3.new(w, th, w), tier, color, GRASS)
		part(m, `Tier{i}B`, Vector3.new(w, th, w), tier * rad(0, 45, 0), color, GRASS)
		if spec.snowCaps and i <= 2 then
			local capColor = if spec.frost then P.SnowShade else P.Snow
			part(
				m,
				`Snow{i}`,
				Vector3.new(w * 0.62, th * 0.22, w * 0.62),
				tier * CFrame.new(0, th * 0.42, 0) * rad(0, 22, 0),
				capColor,
				SNOW
			)
		end
	end
	return m
end

function WorldProps.pineTall(parent: Instance, cf: CFrame): Model
	return pine(parent, cf, PINES.PineTall, "PineTall")
end
function WorldProps.pineFat(parent: Instance, cf: CFrame): Model
	return pine(parent, cf, PINES.PineFat, "PineFat")
end
function WorldProps.pineYoung(parent: Instance, cf: CFrame): Model
	return pine(parent, cf, PINES.PineYoung, "PineYoung")
end
function WorldProps.pineFrost(parent: Instance, cf: CFrame): Model
	return pine(parent, cf, PINES.PineFrost, "PineFrost")
end

-- Bare dead tree: split trunk and three reaching branches.
function WorldProps.deadTree(parent: Instance, cf: CFrame): Model
	local m = model("DeadTree", parent)
	local c = P.BarkDead
	part(m, "Trunk", Vector3.new(1.4, 8, 1.4), cf * CFrame.new(0, 4, 0) * rad(0, 0, 3), c, WOOD)
	part(m, "Top", Vector3.new(0.9, 4, 0.9), cf * CFrame.new(0.3, 9.5, 0) * rad(0, 0, -6), c, WOOD)
	part(
		m,
		"BranchA",
		Vector3.new(0.5, 4.5, 0.5),
		cf * CFrame.new(-1.8, 7.2, 0) * rad(0, 0, 52),
		c,
		WOOD
	)
	part(
		m,
		"BranchB",
		Vector3.new(0.5, 4, 0.5),
		cf * CFrame.new(1.7, 6, 0.3) * rad(10, 0, -58),
		c,
		WOOD
	)
	part(m, "BranchC", Vector3.new(0.4, 3, 0.4), cf * CFrame.new(0, 10, 1) * rad(48, 0, 8), c, WOOD)
	part(
		m,
		"SnowDust",
		Vector3.new(1.8, 0.4, 1.8),
		cf * CFrame.new(0, 0.25, 0),
		P.Snow,
		SNOW,
		{ shape = Enum.PartType.Ball }
	)
	return m
end

-- Wind-bent tundra tree: leaning, kinked, harsh.
function WorldProps.deadTwisted(parent: Instance, cf: CFrame): Model
	local m = model("DeadTwisted", parent)
	local c = shade(P.BarkDead, 0.85)
	part(m, "Seg1", Vector3.new(1.5, 4.5, 1.5), cf * CFrame.new(0, 2.2, 0) * rad(0, 0, 8), c, WOOD)
	part(m, "Seg2", Vector3.new(1.1, 4.2, 1.1), cf * CFrame.new(1, 6, 0) * rad(0, 0, -18), c, WOOD)
	part(
		m,
		"Seg3",
		Vector3.new(0.8, 3.6, 0.8),
		cf * CFrame.new(0.4, 9.4, 0) * rad(0, 0, 22),
		c,
		WOOD
	)
	part(
		m,
		"Branch",
		Vector3.new(0.4, 4.5, 0.4),
		cf * CFrame.new(3, 6.8, 0) * rad(0, 0, -72),
		c,
		WOOD
	)
	part(
		m,
		"Drift",
		Vector3.new(2.6, 0.6, 1.6),
		cf * CFrame.new(-1.4, 0.2, 0),
		P.Snow,
		SNOW,
		{ shape = Enum.PartType.Ball }
	)
	return m
end

function WorldProps.stump(parent: Instance, cf: CFrame): Model
	local m = model("Stump", parent)
	part(m, "Stump", Vector3.new(1.8, 1.2, 1.8), cf * CFrame.new(0, 0.6, 0), P.BarkDark, WOOD)
	part(m, "Snow", Vector3.new(1.5, 0.3, 1.5), cf * CFrame.new(0, 1.3, 0), P.Snow, SNOW)
	return m
end

local TREES: { [string]: (Instance, CFrame) -> Model } = {
	PineTall = WorldProps.pineTall,
	PineFat = WorldProps.pineFat,
	PineYoung = WorldProps.pineYoung,
	PineFrost = WorldProps.pineFrost,
	DeadTree = WorldProps.deadTree,
	DeadTwisted = WorldProps.deadTwisted,
}

function WorldProps.tree(parent: Instance, cf: CFrame, kind: string): Model
	local make = TREES[kind]
	if make == nil then
		return WorldProps.pineTall(parent, cf)
	end
	return make(parent, cf)
end

----------------------------------------------------------------------------------------------------
-- Rocks and ore (<= Config.Art.World.MaxPartsPerRock parts)
----------------------------------------------------------------------------------------------------

local function boulder(
	parent: Instance,
	cf: CFrame,
	name: string,
	color: Color3,
	material: Enum.Material,
	capped: boolean
): Model
	local m = model(name, parent)
	part(
		m,
		"Main",
		Vector3.new(4.6, 3.4, 4.2),
		cf * CFrame.new(0, 1.2, 0) * rad(5, 20, -6),
		color,
		material
	)
	part(
		m,
		"Side",
		Vector3.new(2.6, 2.2, 2.8),
		cf * CFrame.new(2.4, 0.7, 1) * rad(-8, 50, 10),
		shade(color, 0.88),
		material
	)
	part(
		m,
		"Chip",
		Vector3.new(1.6, 1.4, 1.5),
		cf * CFrame.new(-2.3, 0.5, -1.2) * rad(12, -30, 4),
		shade(color, 1.08),
		material
	)
	if capped then
		part(
			m,
			"Cap",
			Vector3.new(3.6, 0.8, 3.3),
			cf * CFrame.new(0, 2.7, 0) * rad(5, 20, -6),
			P.Snow,
			SNOW
		)
	end
	return m
end

function WorldProps.boulder(parent: Instance, cf: CFrame): Model
	return boulder(parent, cf, "Boulder", P.Rock, SLATE, true)
end

function WorldProps.darkBoulder(parent: Instance, cf: CFrame): Model
	return boulder(parent, cf, "DarkBoulder", P.RockDark, ROCK, true)
end

-- Tall leaning slab on a base block.
local function slab(parent: Instance, cf: CFrame, name: string, color: Color3): Model
	local m = model(name, parent)
	part(
		m,
		"Base",
		Vector3.new(5, 1.6, 3.6),
		cf * CFrame.new(0, 0.6, 0) * rad(0, 12, 0),
		shade(color, 0.9),
		SLATE
	)
	part(
		m,
		"Slab",
		Vector3.new(2, 5.2, 3),
		cf * CFrame.new(0.4, 3.2, 0) * rad(0, 12, 9),
		color,
		SLATE
	)
	part(
		m,
		"Cap",
		Vector3.new(1.8, 0.5, 2.6),
		cf * CFrame.new(0.9, 5.7, 0) * rad(0, 12, 9),
		P.Snow,
		SNOW
	)
	return m
end

function WorldProps.slab(parent: Instance, cf: CFrame): Model
	return slab(parent, cf, "Slab", P.Rock)
end

function WorldProps.darkSlab(parent: Instance, cf: CFrame): Model
	return slab(parent, cf, "DarkSlab", P.RockWarm)
end

-- Frozen rock: translucent ice blocks.
function WorldProps.iceRock(parent: Instance, cf: CFrame): Model
	local m = model("IceRock", parent)
	part(
		m,
		"IceA",
		Vector3.new(3.6, 4, 3.2),
		cf * CFrame.new(0, 1.6, 0) * rad(4, 24, -8),
		P.Ice,
		ICE,
		{ transparency = 0.12 }
	)
	part(
		m,
		"IceB",
		Vector3.new(2.2, 2.8, 2.2),
		cf * CFrame.new(2.2, 1, 0.8) * rad(-6, 60, 14),
		P.IceDeep,
		ICE,
		{ transparency = 0.18 }
	)
	part(
		m,
		"Core",
		Vector3.new(3, 2, 2.6),
		cf * CFrame.new(-0.3, 0.7, 0) * rad(0, 24, 0),
		P.Rock,
		SLATE
	)
	return m
end

-- Iron ore node: dark rock with glowing orange veins.
function WorldProps.ore(parent: Instance, cf: CFrame): Model
	local m = model("IronOre", parent)
	part(
		m,
		"Main",
		Vector3.new(4.4, 3.6, 4),
		cf * CFrame.new(0, 1.3, 0) * rad(4, 15, -5),
		P.RockDark,
		ROCK
	)
	part(
		m,
		"Side",
		Vector3.new(2.4, 2, 2.6),
		cf * CFrame.new(-2.2, 0.8, 0.6) * rad(0, -35, 8),
		shade(P.RockDark, 1.15),
		ROCK
	)
	part(
		m,
		"VeinA",
		Vector3.new(0.5, 2.2, 0.5),
		cf * CFrame.new(0.9, 1.9, 2.0) * rad(0, 15, 24),
		P.Ore,
		NEON
	)
	part(
		m,
		"VeinB",
		Vector3.new(0.4, 1.6, 0.4),
		cf * CFrame.new(-0.8, 2.2, 2.1) * rad(0, 15, -30),
		P.OreGlint,
		NEON
	)
	part(
		m,
		"Cap",
		Vector3.new(3, 0.6, 2.8),
		cf * CFrame.new(-0.2, 3.1, -0.4) * rad(4, 15, -5),
		P.Snow,
		SNOW
	)
	return m
end

-- Depleted rock / ore: a few chips left behind.
function WorldProps.rubbleSmall(parent: Instance, cf: CFrame, color: Color3?): Model
	local m = model("Rubble", parent)
	local c = color or P.Rock
	part(
		m,
		"ChipA",
		Vector3.new(1.6, 0.9, 1.4),
		cf * CFrame.new(0, 0.4, 0) * rad(0, 20, 0),
		c,
		SLATE
	)
	part(
		m,
		"ChipB",
		Vector3.new(1, 0.6, 1.1),
		cf * CFrame.new(1.4, 0.3, 0.8) * rad(0, 55, 0),
		shade(c, 0.85),
		SLATE
	)
	return m
end

local ROCKS: { [string]: (Instance, CFrame) -> Model } = {
	Boulder = WorldProps.boulder,
	Slab = WorldProps.slab,
	IceRock = WorldProps.iceRock,
	DarkBoulder = WorldProps.darkBoulder,
	DarkSlab = WorldProps.darkSlab,
}

function WorldProps.rock(parent: Instance, cf: CFrame, kind: string): Model
	local make = ROCKS[kind]
	if make == nil then
		return WorldProps.boulder(parent, cf)
	end
	return make(parent, cf)
end

----------------------------------------------------------------------------------------------------
-- Ground cover and decor (WorldArt budgets these per chunk)
----------------------------------------------------------------------------------------------------

function WorldProps.drift(parent: Instance, cf: CFrame, size: Vector3): Part
	return part(
		parent,
		"Drift",
		size,
		cf * CFrame.new(0, size.Y * 0.18, 0),
		P.Snow,
		SNOW,
		{ shape = Enum.PartType.Ball }
	)
end

function WorldProps.bush(parent: Instance, cf: CFrame): Model
	local m = model("Bush", parent)
	part(
		m,
		"Leaves",
		Vector3.new(3, 2, 3),
		cf * CFrame.new(0, 0.9, 0),
		P.NeedleDeep,
		GRASS,
		{ shape = Enum.PartType.Ball }
	)
	part(
		m,
		"Frost",
		Vector3.new(2.4, 0.7, 2.4),
		cf * CFrame.new(0, 1.6, 0),
		P.Snow,
		SNOW,
		{ shape = Enum.PartType.Ball }
	)
	return m
end

function WorldProps.tuft(parent: Instance, cf: CFrame): Model
	local m = model("Tuft", parent)
	part(
		m,
		"BladesA",
		Vector3.new(0.3, 2, 1.4),
		cf * CFrame.new(0, 1, 0) * rad(0, 0, 8),
		P.Reed,
		GRASS
	)
	part(
		m,
		"BladesB",
		Vector3.new(1.4, 1.6, 0.3),
		cf * CFrame.new(0.2, 0.8, 0) * rad(8, 0, 0),
		shade(P.Reed, 0.85),
		GRASS
	)
	return m
end

function WorldProps.reeds(parent: Instance, cf: CFrame): Model
	local m = model("Reeds", parent)
	for i = 1, 3 do
		local a = i * 2.1
		part(
			m,
			`Reed{i}`,
			Vector3.new(0.25, 3.6 - i * 0.4, 0.25),
			cf
				* CFrame.new(math.cos(a) * 0.8, 1.7, math.sin(a) * 0.8)
				* rad(i * 5 - 8, a * 20, i * 6 - 9),
			P.Reed,
			GRASS
		)
	end
	return m
end

function WorldProps.shard(parent: Instance, cf: CFrame): Model
	local m = model("IceShards", parent)
	part(
		m,
		"ShardA",
		Vector3.new(0.9, 3.4, 0.9),
		cf * CFrame.new(0, 1.5, 0) * rad(8, 30, 12),
		P.Ice,
		ICE,
		{ transparency = 0.15 }
	)
	part(
		m,
		"ShardB",
		Vector3.new(0.7, 2.2, 0.7),
		cf * CFrame.new(1, 0.9, 0.5) * rad(-12, 70, -20),
		P.IceDeep,
		ICE,
		{ transparency = 0.2 }
	)
	return m
end

-- Cracks across lake ice: two thin dark bars, slightly skewed.
function WorldProps.crack(parent: Instance, cf: CFrame, length: number): Model
	local m = model("IceCrack", parent)
	part(
		m,
		"CrackA",
		Vector3.new(length, 0.06, 0.35),
		cf * CFrame.new(0, 0.1, 0),
		P.IceDeep,
		GLASS,
		{ transparency = 0.15 }
	)
	part(
		m,
		"CrackB",
		Vector3.new(length * 0.55, 0.06, 0.25),
		cf * CFrame.new(length * 0.2, 0.1, 0.5) * rad(0, 38, 0),
		P.IceDeep,
		GLASS,
		{ transparency = 0.15 }
	)
	return m
end

function WorldProps.crystal(parent: Instance, cf: CFrame, deep: boolean?): Model
	local m = model("Crystals", parent)
	local c = if deep then P.CrystalDeep else P.Crystal
	part(
		m,
		"CrystalA",
		Vector3.new(0.9, 4.2, 0.9),
		cf * CFrame.new(0, 1.9, 0) * rad(6, 20, 10),
		c,
		NEON,
		{ transparency = 0.2 }
	)
	part(
		m,
		"CrystalB",
		Vector3.new(0.7, 2.8, 0.7),
		cf * CFrame.new(1, 1.2, 0.6) * rad(-14, 60, -22),
		shade(c, 0.85),
		NEON,
		{ transparency = 0.25 }
	)
	part(
		m,
		"CrystalC",
		Vector3.new(0.6, 2, 0.6),
		cf * CFrame.new(-0.9, 0.9, -0.4) * rad(16, 100, 24),
		shade(c, 0.75),
		NEON,
		{ transparency = 0.25 }
	)
	return m
end

function WorldProps.scree(parent: Instance, cf: CFrame): Model
	local m = model("Scree", parent)
	part(
		m,
		"StoneA",
		Vector3.new(1.4, 0.8, 1.2),
		cf * CFrame.new(0, 0.3, 0) * rad(0, 25, 0),
		P.RockDark,
		SLATE
	)
	part(
		m,
		"StoneB",
		Vector3.new(0.9, 0.6, 1),
		cf * CFrame.new(1.2, 0.2, 0.6) * rad(0, 70, 0),
		shade(P.RockDark, 1.2),
		SLATE
	)
	return m
end

function WorldProps.rubble(parent: Instance, cf: CFrame): Model
	local m = model("RuinRubble", parent)
	part(
		m,
		"BlockA",
		Vector3.new(2.2, 1.4, 1.8),
		cf * CFrame.new(0, 0.6, 0) * rad(0, 30, 6),
		P.Ruin,
		SLATE
	)
	part(
		m,
		"BlockB",
		Vector3.new(1.4, 1, 1.4),
		cf * CFrame.new(1.7, 0.4, 0.8) * rad(0, 70, -8),
		P.RuinDark,
		SLATE
	)
	return m
end

-- Flat coloured ground patch (wind-scoured earth, snow sheets, glacier ice). Thin, never collides.
function WorldProps.patch(
	parent: Instance,
	pos: Vector3,
	size: number,
	yaw: number,
	color: Color3,
	material: Enum.Material
): Part
	local p = part(
		parent,
		"Patch",
		Vector3.new(0.12, size, size * 0.7),
		CFrame.new(pos.X, 0.06, pos.Z) * CFrame.Angles(0, yaw, math.pi / 2),
		color,
		material,
		{ shape = Enum.PartType.Cylinder }
	)
	return p
end

-- Part cost of each decor kind (WorldArt budgets with it).
WorldProps.DecorCost = {
	Drift = 1,
	Bush = 2,
	Stump = 2,
	Tuft = 2,
	Reeds = 3,
	Shard = 2,
	Crack = 2,
	Crystal = 3,
	Scree = 2,
	Rubble = 2,
} :: { [string]: number }

function WorldProps.decor(parent: Instance, cf: CFrame, kind: string, rng: Random): Instance?
	if kind == "Drift" then
		return WorldProps.drift(
			parent,
			cf,
			Vector3.new(rng:NextNumber(9, 18), rng:NextNumber(3, 5), rng:NextNumber(7, 12))
		)
	elseif kind == "Bush" then
		return WorldProps.bush(parent, cf)
	elseif kind == "Stump" then
		return WorldProps.stump(parent, cf)
	elseif kind == "Tuft" then
		return WorldProps.tuft(parent, cf)
	elseif kind == "Reeds" then
		return WorldProps.reeds(parent, cf)
	elseif kind == "Shard" then
		return WorldProps.shard(parent, cf)
	elseif kind == "Crack" then
		return WorldProps.crack(parent, cf, rng:NextNumber(12, 30))
	elseif kind == "Crystal" then
		return WorldProps.crystal(parent, cf, rng:NextNumber() < 0.3)
	elseif kind == "Scree" then
		return WorldProps.scree(parent, cf)
	elseif kind == "Rubble" then
		return WorldProps.rubble(parent, cf)
	end
	return nil
end

----------------------------------------------------------------------------------------------------
-- Points of interest (<= Config.Art.World.MaxPartsPerPoi parts each). cf = POI base, +Z = front.
-- Hulls collide where the old block-outs did; crate/hearth/spring/ice stay in PoiService.
----------------------------------------------------------------------------------------------------

-- Log cabin 12 x 7 x 10. Front (+Z) has the door, lit windows, firewood; hearth/crate sit outside it.
function WorldProps.cabin(parent: Instance, base: CFrame): Model
	local m = model("Cabin", parent)
	part(
		m,
		"Hull",
		Vector3.new(12, 7, 10),
		base * CFrame.new(0, 3.5, 0),
		P.Wood,
		WOOD,
		{ collide = true, transparency = 1 }
	)
	-- log walls (visual): four wall blocks slightly proud of the hull
	part(
		m,
		"WallBack",
		Vector3.new(12.4, 6.6, 0.8),
		base * CFrame.new(0, 3.3, -5),
		P.WoodDark,
		WOOD
	)
	part(m, "WallFront", Vector3.new(12.4, 6.6, 0.8), base * CFrame.new(0, 3.3, 5), P.Wood, WOOD)
	part(m, "WallLeft", Vector3.new(0.8, 6.6, 10), base * CFrame.new(-6, 3.3, 0), P.Wood, WOOD)
	part(m, "WallRight", Vector3.new(0.8, 6.6, 10), base * CFrame.new(6, 3.3, 0), P.Wood, WOOD)
	-- gable roof: two tilted slabs with snow on top
	part(
		m,
		"RoofL",
		Vector3.new(7.4, 0.8, 11.6),
		base * CFrame.new(-3, 8, 0) * rad(0, 0, 28),
		P.Roof,
		WOOD
	)
	part(
		m,
		"RoofR",
		Vector3.new(7.4, 0.8, 11.6),
		base * CFrame.new(3, 8, 0) * rad(0, 0, -28),
		P.Roof,
		WOOD
	)
	part(
		m,
		"SnowL",
		Vector3.new(7, 0.7, 11.2),
		base * CFrame.new(-3, 8.55, 0) * rad(0, 0, 28),
		P.Snow,
		SNOW
	)
	part(
		m,
		"SnowR",
		Vector3.new(7, 0.7, 11.2),
		base * CFrame.new(3, 8.55, 0) * rad(0, 0, -28),
		P.Snow,
		SNOW
	)
	-- chimney
	part(m, "Chimney", Vector3.new(2, 5, 2), base * CFrame.new(3.6, 9.5, -2.4), P.RuinDark, SLATE)
	part(
		m,
		"ChimneyCap",
		Vector3.new(2.4, 0.5, 2.4),
		base * CFrame.new(3.6, 12.2, -2.4),
		P.Snow,
		SNOW
	)
	-- door and windows (front), warm glass panes
	part(m, "Door", Vector3.new(2.6, 4.6, 0.4), base * CFrame.new(0, 2.3, 5.5), P.WoodDark, WOOD)
	part(
		m,
		"DoorFrame",
		Vector3.new(3.2, 5.2, 0.3),
		base * CFrame.new(0, 2.6, 5.35),
		shade(P.Wood, 0.8),
		WOOD
	)
	part(
		m,
		"WindowL",
		Vector3.new(1.8, 1.8, 0.3),
		base * CFrame.new(-3.6, 3.8, 5.45),
		P.Window,
		NEON,
		{ transparency = 0.1 }
	)
	part(
		m,
		"WindowR",
		Vector3.new(1.8, 1.8, 0.3),
		base * CFrame.new(3.6, 3.8, 5.45),
		P.Window,
		NEON,
		{ transparency = 0.1 }
	)
	part(
		m,
		"SillL",
		Vector3.new(2.4, 0.3, 0.6),
		base * CFrame.new(-3.6, 2.8, 5.5),
		P.WoodDark,
		WOOD
	)
	part(m, "SillR", Vector3.new(2.4, 0.3, 0.6), base * CFrame.new(3.6, 2.8, 5.5), P.WoodDark, WOOD)
	-- porch step + firewood stack + snow bank
	part(m, "Step", Vector3.new(4, 0.5, 1.8), base * CFrame.new(0, 0.25, 6.2), P.WoodDark, WOOD)
	part(
		m,
		"Firewood",
		Vector3.new(3.2, 1.6, 1.4),
		base * CFrame.new(-4.6, 0.8, 6.2),
		shade(P.Wood, 1.15),
		WOOD
	)
	part(
		m,
		"SnowBank",
		Vector3.new(9, 2, 4),
		base * CFrame.new(1, 0.4, -6.2),
		P.Snow,
		SNOW,
		{ shape = Enum.PartType.Ball }
	)
	return m
end

-- Crashed plane: half-buried fuselage, snapped wing, tail fin, scorch and debris.
function WorldProps.plane(parent: Instance, base: CFrame): Model
	local m = model("CrashedPlane", parent)
	local tilt = base * CFrame.new(0, 2.6, -1) * rad(5, 0, 0)
	-- cylinder axis is X; turn it to run along Z
	part(
		m,
		"Fuselage",
		Vector3.new(16, 5, 5),
		tilt * rad(0, 90, 0),
		P.Metal,
		METAL,
		{ collide = true, shape = Enum.PartType.Cylinder }
	)
	part(
		m,
		"Nose",
		Vector3.new(5, 5, 5),
		tilt * CFrame.new(0, 0, 8.2),
		P.MetalDark,
		METAL,
		{ shape = Enum.PartType.Ball }
	)
	part(
		m,
		"Cockpit",
		Vector3.new(3.4, 1.4, 3),
		tilt * CFrame.new(0, 2.1, 5.2),
		shade(P.Rune, 0.5),
		GLASS,
		{ transparency = 0.35 }
	)
	part(m, "Stripe", Vector3.new(5.1, 0.5, 14), tilt * CFrame.new(0, 0.2, -0.5), P.Tent, PLASTIC)
	part(
		m,
		"WingL",
		Vector3.new(11, 0.6, 4.4),
		tilt * CFrame.new(-7.8, -0.4, 0.4) * rad(0, 0, 6),
		P.Metal,
		METAL
	)
	part(
		m,
		"WingR",
		Vector3.new(6, 0.6, 4.4),
		tilt * CFrame.new(5, -0.9, 0.4) * rad(0, 0, -22),
		P.Metal,
		METAL
	)
	part(
		m,
		"WingStub",
		Vector3.new(2, 0.7, 4),
		tilt * CFrame.new(2.6, -0.4, 0.4),
		P.MetalDark,
		METAL
	)
	part(
		m,
		"TailFin",
		Vector3.new(0.6, 5, 3.6),
		tilt * CFrame.new(0, 4.4, -8.2) * rad(0, 0, 6),
		P.Tent,
		METAL
	)
	part(m, "TailPlane", Vector3.new(7, 0.5, 2.6), tilt * CFrame.new(0, 1.6, -8.4), P.Metal, METAL)
	part(
		m,
		"Engine",
		Vector3.new(2.4, 2.4, 3),
		base * CFrame.new(-12, 1.2, 4) * rad(0, 20, 0),
		P.MetalDark,
		METAL,
		{ shape = Enum.PartType.Cylinder }
	)
	part(
		m,
		"Scorch",
		Vector3.new(0.1, 18, 12),
		base * CFrame.new(0, 0.07, 7) * CFrame.Angles(0, 0, math.pi / 2),
		P.Scorch,
		SLATE,
		{ shape = Enum.PartType.Cylinder }
	)
	part(
		m,
		"Debris1",
		Vector3.new(2.4, 0.3, 1.6),
		base * CFrame.new(6, 0.3, 8) * rad(0, 40, 10),
		P.Metal,
		METAL
	)
	part(
		m,
		"Debris2",
		Vector3.new(1.6, 0.3, 2.2),
		base * CFrame.new(-6, 0.3, 9) * rad(0, -25, -12),
		P.Tent,
		METAL
	)
	part(
		m,
		"Drift",
		Vector3.new(14, 3.6, 5),
		base * CFrame.new(-1, 0.4, -9),
		P.Snow,
		SNOW,
		{ shape = Enum.PartType.Ball }
	)
	return m
end

-- Cave: rock shell you can walk into (interior 10 x 9, mouth faces +Z), glowing crystals, dark floor.
function WorldProps.cave(parent: Instance, base: CFrame): Model
	local m = model("Cave", parent)
	local rock, dark = P.RockDark, shade(P.RockDark, 0.7)
	part(
		m,
		"Back",
		Vector3.new(18, 11, 3),
		base * CFrame.new(0, 5.5, -6.5),
		rock,
		ROCK,
		{ collide = true }
	)
	part(
		m,
		"WallL",
		Vector3.new(4, 11, 14),
		base * CFrame.new(-7, 5.5, 0),
		rock,
		ROCK,
		{ collide = true }
	)
	part(
		m,
		"WallR",
		Vector3.new(4, 11, 14),
		base * CFrame.new(7, 5.5, 0),
		rock,
		ROCK,
		{ collide = true }
	)
	part(
		m,
		"Roof",
		Vector3.new(18, 4, 14),
		base * CFrame.new(0, 9.5, 0),
		rock,
		ROCK,
		{ collide = true }
	)
	part(
		m,
		"FrontL",
		Vector3.new(4, 11, 3),
		base * CFrame.new(-5.5, 5.5, 6.5),
		shade(rock, 1.1),
		ROCK,
		{ collide = true }
	)
	part(
		m,
		"FrontR",
		Vector3.new(4, 11, 3),
		base * CFrame.new(5.5, 5.5, 6.5),
		shade(rock, 1.1),
		ROCK,
		{ collide = true }
	)
	part(
		m,
		"Lintel",
		Vector3.new(8, 4, 3),
		base * CFrame.new(0, 9, 6.5),
		rock,
		ROCK,
		{ collide = true }
	)
	part(m, "Floor", Vector3.new(10, 0.2, 12), base * CFrame.new(0, 0.12, 0), P.Cave, SLATE)
	part(m, "Darkness", Vector3.new(9, 8, 0.3), base * CFrame.new(0, 4, -4.7), P.Cave, PLASTIC)
	-- crags on the roof, snow on top
	part(
		m,
		"CragA",
		Vector3.new(7, 4, 6),
		base * CFrame.new(-3, 12.5, -1) * rad(0, 25, 6),
		dark,
		ROCK
	)
	part(
		m,
		"CragB",
		Vector3.new(5, 3.4, 5),
		base * CFrame.new(4, 12, 1) * rad(0, -30, -8),
		rock,
		ROCK
	)
	part(
		m,
		"SnowCrown",
		Vector3.new(11, 1.4, 8),
		base * CFrame.new(0, 14, -1),
		P.Snow,
		SNOW,
		{ shape = Enum.PartType.Ball }
	)
	-- glowing crystals inside and at the mouth
	WorldProps.crystal(m, base * CFrame.new(-3, 0, -3), false)
	WorldProps.crystal(m, base * CFrame.new(3.2, 0, -2) * rad(0, 90, 0), true)
	WorldProps.crystal(m, base * CFrame.new(-7.8, 0, 8.6) * rad(0, 40, 0), false)
	part(
		m,
		"Scatter",
		Vector3.new(2, 1.2, 1.8),
		base * CFrame.new(5.5, 0.5, 9) * rad(0, 30, 0),
		dark,
		ROCK
	)
	return m
end

-- Tundra ruin: broken pillars (colliders as before), slab lintel, fallen column, rune tile, rubble.
function WorldProps.ruin(parent: Instance, base: CFrame): Model
	local m = model("Ruin", parent)
	part(
		m,
		"PillarA",
		Vector3.new(3, 9, 3),
		base * CFrame.new(-6, 4.5, 0),
		P.Ruin,
		SLATE,
		{ collide = true }
	)
	part(
		m,
		"PillarB",
		Vector3.new(3, 9, 3),
		base * CFrame.new(6, 4.5, 0),
		P.Ruin,
		SLATE,
		{ collide = true }
	)
	part(
		m,
		"Slab",
		Vector3.new(14, 1, 3),
		base * CFrame.new(0, 9.5, 0),
		P.RuinDark,
		SLATE,
		{ collide = true }
	)
	part(m, "CapA", Vector3.new(3.8, 0.8, 3.8), base * CFrame.new(-6, 9, 0), P.RuinDark, SLATE)
	part(m, "CapB", Vector3.new(3.8, 0.8, 3.8), base * CFrame.new(6, 9, 0), P.RuinDark, SLATE)
	part(m, "BaseA", Vector3.new(4.4, 1, 4.4), base * CFrame.new(-6, 0.5, 0), P.RuinDark, SLATE)
	part(m, "BaseB", Vector3.new(4.4, 1, 4.4), base * CFrame.new(6, 0.5, 0), P.RuinDark, SLATE)
	part(
		m,
		"Fallen",
		Vector3.new(9, 2.4, 2.4),
		base * CFrame.new(-9, 1.2, 7) * rad(0, 25, 0),
		P.Ruin,
		SLATE,
		{ shape = Enum.PartType.Cylinder }
	)
	part(
		m,
		"WallStub",
		Vector3.new(7, 3, 1.4),
		base * CFrame.new(9, 1.5, -6) * rad(0, -15, 0),
		P.RuinDark,
		SLATE
	)
	part(
		m,
		"WallStub2",
		Vector3.new(4, 1.8, 1.4),
		base * CFrame.new(3, 0.9, -8) * rad(0, 10, 0),
		P.Ruin,
		SLATE
	)
	part(m, "RuneTile", Vector3.new(6, 0.12, 4), base * CFrame.new(0, 0.1, 3.5), P.RuinDark, SLATE)
	part(
		m,
		"RuneGlow",
		Vector3.new(4.4, 0.14, 0.4),
		base * CFrame.new(0, 0.18, 3.5),
		P.Rune,
		NEON,
		{ transparency = 0.3 }
	)
	part(
		m,
		"RuneGlow2",
		Vector3.new(0.4, 0.14, 2.6),
		base * CFrame.new(0, 0.18, 3.5),
		P.Rune,
		NEON,
		{ transparency = 0.3 }
	)
	part(
		m,
		"RubbleA",
		Vector3.new(2.4, 1.4, 2),
		base * CFrame.new(5, 0.7, 6) * rad(0, 40, 6),
		P.Ruin,
		SLATE
	)
	part(
		m,
		"RubbleB",
		Vector3.new(1.6, 1, 1.4),
		base * CFrame.new(-3, 0.5, 8) * rad(0, 70, -6),
		P.RuinDark,
		SLATE
	)
	part(
		m,
		"Scour",
		Vector3.new(13, 0.8, 4),
		base * CFrame.new(3, 0.3, -3),
		P.Snow,
		SNOW,
		{ shape = Enum.PartType.Ball }
	)
	return m
end

-- Campsite: A-frame tent, log seats, cold fire ring, pack.
function WorldProps.campsite(parent: Instance, base: CFrame): Model
	local m = model("Campsite", parent)
	part(
		m,
		"Hull",
		Vector3.new(5, 3, 5),
		base * CFrame.new(0, 1.5, 0),
		P.Tent,
		FABRIC,
		{ collide = true, transparency = 1 }
	)
	part(
		m,
		"PanelL",
		Vector3.new(0.3, 4.6, 6.4),
		base * CFrame.new(-1.5, 2, 0) * rad(0, 0, 36),
		P.Tent,
		FABRIC
	)
	part(
		m,
		"PanelR",
		Vector3.new(0.3, 4.6, 6.4),
		base * CFrame.new(1.5, 2, 0) * rad(0, 0, -36),
		P.TentAlt,
		FABRIC
	)
	part(
		m,
		"Flap",
		Vector3.new(2.2, 3.2, 0.2),
		base * CFrame.new(0, 1.7, 3.2),
		shade(P.Tent, 0.55),
		FABRIC
	)
	part(m, "Ridge", Vector3.new(0.4, 0.4, 6.8), base * CFrame.new(0, 4, 0), P.WoodDark, WOOD)
	part(m, "SnowRoof", Vector3.new(1.6, 0.4, 6), base * CFrame.new(0, 4.1, 0), P.Snow, SNOW)
	part(
		m,
		"LogA",
		Vector3.new(4, 1, 1),
		base * CFrame.new(-6, 0.5, 5) * rad(0, 20, 0),
		P.Wood,
		WOOD
	)
	part(
		m,
		"LogB",
		Vector3.new(4, 1, 1),
		base * CFrame.new(-1, 0.5, 8) * rad(0, -70, 0),
		P.Wood,
		WOOD
	)
	part(
		m,
		"Ash",
		Vector3.new(0.1, 3.4, 3.4),
		base * CFrame.new(-3, 0.07, 3) * CFrame.Angles(0, 0, math.pi / 2),
		P.Scorch,
		SLATE,
		{ shape = Enum.PartType.Cylinder }
	)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		part(
			m,
			"RingStone",
			Vector3.new(0.9, 0.7, 0.9),
			base
				* CFrame.new(-3 + math.cos(a) * 1.9, 0.35, 3 + math.sin(a) * 1.9)
				* rad(0, a * 57, 0),
			P.Rock,
			SLATE
		)
	end
	part(
		m,
		"Pack",
		Vector3.new(1.4, 1.8, 1),
		base * CFrame.new(3.4, 0.9, 3.8) * rad(0, 30, 0),
		P.TentAlt,
		FABRIC
	)
	return m
end

-- Hot spring dressing (the functional warm-spot part is built by PoiService): rim stones, snow, steam.
function WorldProps.springRim(parent: Instance, base: CFrame): Model
	local m = model("SpringRim", parent)
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		local r = 8.6 + (i % 2) * 0.5
		local size = 1.8 + (i % 3) * 0.5
		part(
			m,
			"RimStone",
			Vector3.new(size * 1.3, size, size * 1.2),
			base * CFrame.new(math.cos(a) * r, size * 0.35, math.sin(a) * r) * rad(0, a * 57, 6),
			if i % 2 == 0 then P.Rock else P.RockDark,
			SLATE
		)
	end
	part(
		m,
		"SnowA",
		Vector3.new(6, 1.4, 4),
		base * CFrame.new(10.4, 0.3, 4) * rad(0, 30, 0),
		P.Snow,
		SNOW,
		{ shape = Enum.PartType.Ball }
	)
	part(
		m,
		"SnowB",
		Vector3.new(5, 1.2, 4),
		base * CFrame.new(-9.4, 0.3, -5) * rad(0, -20, 0),
		P.Snow,
		SNOW,
		{ shape = Enum.PartType.Ball }
	)
	return m
end

-- Steam over the spring surface (one emitter, Config-capped rate).
function WorldProps.steam(target: BasePart)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Steam"
	e.Texture = W.ParticleTexture
	e.Rate = W.SpringSteamRate
	e.Lifetime = NumberRange.new(2.5, 4)
	e.Speed = NumberRange.new(2, 3)
	e.SpreadAngle = Vector2.new(20, 20)
	e.EmissionDirection = Enum.NormalId.Right -- spring cylinder axis is X, so Right is world up
	e.Color = ColorSequence.new(Color3.fromRGB(235, 245, 250))
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85),
		NumberSequenceKeypoint.new(0.4, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) })
	e.LightEmission = 0.1
	e.Parent = target
end

-- Stone fireplace surround and iron grate for the cabin hearth (the Hearth part itself is PoiService's).
function WorldProps.hearthSurround(parent: Instance, base: CFrame, offset: Vector3): Model
	local m = model("HearthSurround", parent)
	local at = base * CFrame.new(offset)
	part(m, "Back", Vector3.new(4.2, 3.2, 0.8), at * CFrame.new(0, 1.6, -1.9), P.RuinDark, SLATE)
	part(m, "SideL", Vector3.new(0.8, 2.2, 3.4), at * CFrame.new(-1.9, 1.1, 0), P.Ruin, SLATE)
	part(m, "SideR", Vector3.new(0.8, 2.2, 3.4), at * CFrame.new(1.9, 1.1, 0), P.Ruin, SLATE)
	part(
		m,
		"Logs",
		Vector3.new(2.4, 0.5, 0.5),
		at * CFrame.new(0, 1.0, 0.2) * rad(0, 20, 0),
		P.WoodDark,
		WOOD
	)
	return m
end

-- Fire + warm light for a lit hearth (WorldArt toggles Enabled; light count is bounded by cabins loaded).
function WorldProps.hearthFx(target: BasePart)
	local fire = Instance.new("Fire")
	fire.Name = "HearthFire"
	fire.Size = 4
	fire.Heat = 6
	fire.Color = Color3.fromRGB(255, 150, 60)
	fire.SecondaryColor = Color3.fromRGB(255, 80, 30)
	fire.Enabled = false
	fire.Parent = target
	local light = Instance.new("PointLight")
	light.Name = "HearthLight"
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Range = W.HearthLight.Range
	light.Brightness = W.HearthLight.Brightness
	light.Shadows = false
	light.Enabled = false
	light.Parent = target
end

local POIS: { [string]: (Instance, CFrame) -> Model } = {
	cabin = WorldProps.cabin,
	plane = WorldProps.plane,
	cave = WorldProps.cave,
	ruin = WorldProps.ruin,
	campsite = WorldProps.campsite,
	hotspring = WorldProps.springRim,
}

function WorldProps.poi(parent: Instance, kind: string, base: CFrame): Model?
	local make = POIS[kind]
	if make then
		return make(parent, base)
	end
	return nil
end

return WorldProps
