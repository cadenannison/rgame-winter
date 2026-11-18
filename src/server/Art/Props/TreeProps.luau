--!strict
-- World props: Trees (<= Config.Art.World.MaxPartsPerTree parts): pines, dead trees, stump.
-- Part of WorldProps (Art/WorldProps.luau re-exports every function here). Geometry only, no gameplay tags.

local PropKit = require(script.Parent:WaitForChild("PropKit"))

local P = PropKit.P
local part = PropKit.part
local model = PropKit.model
local rad = PropKit.rad
local shade = PropKit.shade
local WOOD = PropKit.Material.WOOD
local SNOW = PropKit.Material.SNOW
local GRASS = PropKit.Material.GRASS

local WorldProps = {}
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

return WorldProps
