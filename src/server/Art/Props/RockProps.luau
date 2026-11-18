--!strict
-- World props: Rocks and ore (<= Config.Art.World.MaxPartsPerRock parts): boulders, slabs, ice rock, iron ore, rubble.
-- Part of WorldProps (Art/WorldProps.luau re-exports every function here). Geometry only, no gameplay tags.

local PropKit = require(script.Parent:WaitForChild("PropKit"))

local P = PropKit.P
local part = PropKit.part
local model = PropKit.model
local rad = PropKit.rad
local shade = PropKit.shade
local SLATE = PropKit.Material.SLATE
local ROCK = PropKit.Material.ROCK
local SNOW = PropKit.Material.SNOW
local ICE = PropKit.Material.ICE
local NEON = PropKit.Material.NEON

local WorldProps = {}
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

return WorldProps
