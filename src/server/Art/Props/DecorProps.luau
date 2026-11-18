--!strict
-- World props: Ground cover and decor (WorldArt budgets these per chunk): drifts, bushes, reeds, crystals, patches.
-- Part of WorldProps (Art/WorldProps.luau re-exports every function here). Geometry only, no gameplay tags.

local PropKit = require(script.Parent:WaitForChild("PropKit"))

local P = PropKit.P
local part = PropKit.part
local model = PropKit.model
local rad = PropKit.rad
local shade = PropKit.shade
local SLATE = PropKit.Material.SLATE
local SNOW = PropKit.Material.SNOW
local ICE = PropKit.Material.ICE
local NEON = PropKit.Material.NEON
local GRASS = PropKit.Material.GRASS
local GLASS = PropKit.Material.GLASS

local TreeProps = require(script.Parent:WaitForChild("TreeProps"))

local WorldProps = {}
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
		return TreeProps.stump(parent, cf)
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

return WorldProps
