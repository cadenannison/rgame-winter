--!strict
-- World props: Points of interest (<= Config.Art.World.MaxPartsPerPoi parts each): cabin, plane, cave, ruin, campsite, spring, hearth.
-- Part of WorldProps (Art/WorldProps.luau re-exports every function here). Geometry only, no gameplay tags.

local PropKit = require(script.Parent:WaitForChild("PropKit"))

local W = PropKit.W
local P = PropKit.P
local part = PropKit.part
local model = PropKit.model
local rad = PropKit.rad
local shade = PropKit.shade
local WOOD = PropKit.Material.WOOD
local SLATE = PropKit.Material.SLATE
local ROCK = PropKit.Material.ROCK
local SNOW = PropKit.Material.SNOW
local NEON = PropKit.Material.NEON
local METAL = PropKit.Material.METAL
local FABRIC = PropKit.Material.FABRIC
local GLASS = PropKit.Material.GLASS
local PLASTIC = PropKit.Material.PLASTIC

local DecorProps = require(script.Parent:WaitForChild("DecorProps"))

local WorldProps = {}
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
	DecorProps.crystal(m, base * CFrame.new(-3, 0, -3), false)
	DecorProps.crystal(m, base * CFrame.new(3.2, 0, -2) * rad(0, 90, 0), true)
	DecorProps.crystal(m, base * CFrame.new(-7.8, 0, 8.6) * rad(0, 40, 0), false)
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
