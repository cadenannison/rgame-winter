--!strict
-- Hub prop generators (art pass 1). Every function builds one prop into `parent` and returns it; the
-- builder (HubBuilder) lays them out and /debug gallery hub shows each one in a row. Pure geometry:
-- no scripts are created. Creator Store models come from ServerStorage[Config.Art.AssetFolderName]
-- (sanitized copies keyed by their Assets name); a missing model falls back to Part-built geometry.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Assets = require(ReplicatedStorage.Shared.Assets)
local ArtKit = require(ReplicatedStorage.Shared.ArtKit)

local H = Config.Art.Hub
local P = ArtKit.palette(H.Palette)
local T = H.Tags

local HubProps = {}

local DEFAULT_PARTICLE = "rbxasset://textures/particles/sparkles_main.dds"
local WOOD = Enum.Material.Wood
local SLATE = Enum.Material.Slate
local SNOW = Enum.Material.Snow
local NEON = Enum.Material.Neon
local PLASTIC = Enum.Material.SmoothPlastic

type Opts = { collide: boolean?, shape: Enum.PartType?, transparency: number?, query: boolean? }

local function part(
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance,
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
	local o: Opts = opts or ({} :: Opts)
	p.CanCollide = o.collide == true
	p.CanQuery = o.query == true or o.collide == true
	p.CanTouch = false
	if o.shape then
		p.Shape = o.shape
	end
	if o.transparency then
		p.Transparency = o.transparency
	end
	p.Parent = parent
	return p
end
HubProps.part = part

local function wedge(
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Anchored = true
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = material
	w.CastShadow = false
	w.CanCollide = false
	w.CanQuery = false
	w.CanTouch = false
	w.Parent = parent
	return w
end

local function model(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function light(parent: Instance, color: Color3, range: number, brightness: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end

local function sound(
	parent: Instance,
	name: string,
	assetKey: string,
	volume: number,
	maxDistance: number
)
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = Assets[assetKey] or ""
	s.Looped = true
	s.Volume = volume
	s.RollOffMaxDistance = maxDistance
	s.RollOffMode = Enum.RollOffMode.Linear
	s.Playing = s.SoundId ~= "" -- hook only: silent until an id is supplied
	s.Parent = parent
end

local function surfaceText(
	target: BasePart,
	face: Enum.NormalId,
	text: string,
	color: Color3,
	ppsud: number
)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Static"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppsud
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	gui.Parent = target
end

local function prompt(parent: BasePart, tag: string, action: string, object: string)
	local pp = Instance.new("ProximityPrompt")
	pp.Name = tag
	pp.ActionText = action
	pp.ObjectText = object
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.HoldDuration = 0
	pp.MaxActivationDistance = H.PromptDistance
	pp.RequiresLineOfSight = false
	pp.ClickablePrompt = true
	CollectionService:AddTag(pp, tag)
	pp.Parent = parent
end

-- Counts instances by kind (used by the builder budget and tools/qa/hub-art).
function HubProps.count(root: Instance): (number, number, number, number)
	local parts, lights, emitters, rate = 0, 0, 0, 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		elseif d:IsA("PointLight") or d:IsA("SpotLight") then
			lights += 1
		elseif d:IsA("ParticleEmitter") then
			emitters += 1
			rate += d.Rate
		elseif d:IsA("Fire") or d:IsA("Smoke") then
			emitters += 1
		end
	end
	return parts, lights, emitters, rate
end

-- Sanitized template cache (pivot moved to the base centre; scripts and cameras removed).
local templates: { [string]: Model? } = {}
local function template(key: string): Model?
	if templates[key] ~= nil then
		return templates[key]
	end
	local folder = ServerStorage:FindFirstChild(Config.Art.AssetFolderName)
	local source = folder and folder:FindFirstChild(key)
	if not (source and source:IsA("Model")) then
		return nil
	end
	local m = source:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Camera") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			-- CollisionFidelity (Box) is a plugin-only property: set when the asset was sanitized in Studio.
		end
	end
	local cf, size = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0))
	templates[key] = m
	return m
end

-- Pine: Creator Store mesh when present, stacked-block fallback otherwise. Trunk collider only when
-- `collide` (inner ring); the foliage never collides.
function HubProps.pine(
	parent: Instance,
	pos: Vector3,
	key: string,
	scale: number,
	yaw: number,
	collide: boolean
): Instance
	local source = template(key)
	local tree: Model
	local height: number
	if source then
		tree = source:Clone()
		tree.Name = key
		tree:ScaleTo(scale)
		tree:PivotTo(CFrame.new(pos) * CFrame.Angles(0, yaw, 0))
		local _, size = tree:GetBoundingBox()
		height = size.Y
	else
		tree = Instance.new("Model")
		tree.Name = key
		height = (if key == "HubPineLarge" then 36 else 15) * scale
		local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
		part(
			"Trunk",
			Vector3.new(height * 0.08, height * 0.25, height * 0.08),
			base * CFrame.new(0, height * 0.125, 0),
			P.WoodDark,
			WOOD,
			tree
		)
		for i = 1, 3 do
			local f = 1 - (i - 1) * 0.28
			local w = height * 0.5 * f
			local y = height * (0.2 + (i - 1) * 0.24)
			part(
				`Tier{i}`,
				Vector3.new(w, height * 0.26, w),
				base * CFrame.new(0, y + height * 0.13, 0) * CFrame.Angles(0, math.rad(45), 0),
				Color3.fromRGB(46, 84, 78),
				Enum.Material.Grass,
				tree
			)
		end
		part(
			"Snow",
			Vector3.new(height * 0.12, height * 0.08, height * 0.12),
			base * CFrame.new(0, height * 0.94, 0),
			P.Snow,
			SNOW,
			tree
		)
	end
	if collide then
		local girth = math.max(1.2, height * 0.07)
		part(
			"Collider",
			Vector3.new(girth, height * 0.5, girth),
			CFrame.new(pos + Vector3.new(0, height * 0.25, 0)),
			P.WoodDark,
			WOOD,
			tree,
			{ collide = true, transparency = 1 }
		)
	end
	tree.Parent = parent
	return tree
end

-- Snow-capped boulder (a dark block with a white cap), half sunk into the ground.
function HubProps.rock(parent: Instance, pos: Vector3, size: Vector3, yaw: number): Instance
	local m = model("Rock", parent)
	local cf = CFrame.new(pos + Vector3.new(0, size.Y * 0.3, 0))
		* CFrame.Angles(math.rad(6), yaw, math.rad(-5))
	part("Stone", size, cf, P.Rock, SLATE, m, { collide = true })
	part(
		"Cap",
		Vector3.new(size.X * 0.82, size.Y * 0.28, size.Z * 0.82),
		cf * CFrame.new(0, size.Y * 0.5, 0),
		P.Snow,
		SNOW,
		m
	)
	return m
end

-- Soft snow mound (squashed ball, no collision).
function HubProps.drift(parent: Instance, pos: Vector3, size: Vector3): Instance
	return part(
		"Drift",
		size,
		CFrame.new(pos + Vector3.new(0, size.Y * 0.15, 0)),
		P.Snow,
		SNOW,
		parent,
		{ shape = Enum.PartType.Ball }
	)
end

-- Lamp post: iron pole, warm lantern (tagged for the flicker loop), snow cap.
function HubProps.lampPost(parent: Instance, pos: Vector3, height: number?): Instance
	local h = height or 10
	local m = model("LampPost", parent)
	part(
		"Base",
		Vector3.new(2, 1, 2),
		CFrame.new(pos + Vector3.new(0, 0.5, 0)),
		P.Iron,
		SLATE,
		m,
		{ collide = true }
	)
	part(
		"Pole",
		Vector3.new(0.6, h, 0.6),
		CFrame.new(pos + Vector3.new(0, h / 2, 0)),
		P.Iron,
		PLASTIC,
		m,
		{ collide = true }
	)
	part(
		"Cradle",
		Vector3.new(2.2, 0.4, 2.2),
		CFrame.new(pos + Vector3.new(0, h, 0)),
		P.Iron,
		PLASTIC,
		m
	)
	local lantern = part(
		"Lantern",
		Vector3.new(1.6, 2, 1.6),
		CFrame.new(pos + Vector3.new(0, h + 1.2, 0)),
		P.Warm,
		NEON,
		m,
		{ transparency = 0.15 }
	)
	light(lantern, P.Warm, 30, 1.8)
	CollectionService:AddTag(lantern, T.Lamp)
	part(
		"Hat",
		Vector3.new(2.4, 0.6, 2.4),
		CFrame.new(pos + Vector3.new(0, h + 2.5, 0)),
		P.Iron,
		PLASTIC,
		m
	)
	part(
		"SnowCap",
		Vector3.new(2, 0.4, 2),
		CFrame.new(pos + Vector3.new(0, h + 2.9, 0)),
		P.Snow,
		SNOW,
		m
	)
	return m
end

-- Decorative fire pit: stone ring, crossed logs, Fire + warm light (tagged), benches around it.
function HubProps.firePit(parent: Instance, pos: Vector3, big: boolean?): Instance
	local scale = if big then 1.6 else 1
	local m = model("FirePit", parent)
	local stones = 10
	for i = 1, stones do
		local a = (i / stones) * math.pi * 2
		local r = 3.4 * scale
		part(
			"Stone",
			Vector3.new(1.6, 1.2, 1.6) * scale,
			CFrame.new(pos + Vector3.new(math.cos(a) * r, 0.5, math.sin(a) * r))
				* CFrame.Angles(0, a, 0),
			P.Rock,
			SLATE,
			m,
			{ collide = true }
		)
	end
	part(
		"Embers",
		Vector3.new(5.2, 0.3, 5.2) * scale,
		CFrame.new(pos + Vector3.new(0, 0.1, 0)),
		Color3.fromRGB(40, 30, 28),
		SLATE,
		m,
		{ shape = Enum.PartType.Cylinder }
	)
	for i = 1, 3 do
		part(
			"Log",
			Vector3.new(0.9, 0.9, 4.6) * scale,
			CFrame.new(pos + Vector3.new(0, 0.7 * scale, 0))
				* CFrame.Angles(math.rad(8), math.rad(i * 60), 0),
			P.WoodDark,
			WOOD,
			m
		)
	end
	local core = part(
		"Core",
		Vector3.new(2, 1, 2) * scale,
		CFrame.new(pos + Vector3.new(0, 1.1 * scale, 0)),
		P.Fire,
		NEON,
		m,
		{ transparency = 0.5 }
	)
	local fire = Instance.new("Fire")
	fire.Size = 7 * scale
	fire.Heat = 4
	fire.Color = P.Fire
	fire.SecondaryColor = Color3.fromRGB(255, 80, 30)
	fire.Parent = core
	local l = light(core, P.Warm, 38 * scale, 2.4)
	l.Name = "Glow"
	CollectionService:AddTag(core, T.Lamp)
	sound(core, "Crackle", "HubFireCrackleSound", 0.5, 70)
	for i = 1, 3 do
		local a = (i / 3) * math.pi * 2 + math.rad(40)
		local r = 7.5 * scale
		part(
			"Bench",
			Vector3.new(6, 1.2, 1.6),
			CFrame.new(pos + Vector3.new(math.cos(a) * r, 0.8, math.sin(a) * r))
				* CFrame.Angles(0, -a + math.pi / 2, 0),
			P.Wood,
			WOOD,
			m,
			{ collide = true }
		)
	end
	return m
end

-- Mountain: two ridges (each two wedges back to back) crossing at right angles, with snow caps. The
-- union reads as a peak with four spurs. Base sits 30 studs below `pos` so it grows out of the ground.
function HubProps.mountain(
	parent: Instance,
	pos: Vector3,
	length: number,
	height: number,
	depth: number,
	yaw: number
): Instance
	local m = model("Mountain", parent)
	local base = CFrame.new(pos + Vector3.new(0, height / 2 - 30, 0)) * CFrame.Angles(0, yaw, 0)
	local function ridge(
		suffix: string,
		size: Vector3,
		lift: number,
		color: Color3,
		material: Enum.Material,
		turn: number
	)
		local half = size.Z / 4
		local c = base * CFrame.Angles(0, turn, 0) * CFrame.new(0, lift, 0)
		local slab = Vector3.new(size.X, size.Y, size.Z / 2)
		wedge("A" .. suffix, slab, c * CFrame.new(0, 0, -half), color, material, m)
		wedge(
			"B" .. suffix,
			slab,
			c * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, 0, -half),
			color,
			material,
			m
		)
	end
	local function spur(
		suffix: string,
		len: number,
		h: number,
		d: number,
		drop: number,
		turn: number
	)
		ridge(suffix, Vector3.new(len, h, d), -drop, P.MountainRock, SLATE, turn)
		ridge(
			suffix .. "Cap",
			Vector3.new(len * 0.94, h * 0.42, d * 0.42),
			h * 0.29 + 0.4 - drop,
			P.Snow,
			SNOW,
			turn
		)
	end
	spur("1", length, height, depth, 0, 0)
	spur("2", depth, height * 0.8, length * 0.8, height * 0.1, math.pi / 2)
	return m
end

-- Boards: two posts, dark face (the tagged part; the client draws the live content), roof, lanterns.
function HubProps.board(parent: Instance, cf: CFrame, tag: string, title: string): Instance
	local m = model(title, parent)
	local w, h = 24, 15
	part(
		"PostL",
		Vector3.new(1, h + 6, 1),
		cf * CFrame.new(-w / 2 + 1, (h + 6) / 2, 0.8),
		P.WoodDark,
		WOOD,
		m,
		{ collide = true }
	)
	part(
		"PostR",
		Vector3.new(1, h + 6, 1),
		cf * CFrame.new(w / 2 - 1, (h + 6) / 2, 0.8),
		P.WoodDark,
		WOOD,
		m,
		{ collide = true }
	)
	part(
		"Frame",
		Vector3.new(w + 1.4, h + 1.4, 0.8),
		cf * CFrame.new(0, h / 2 + 4.5, 0.2),
		P.Wood,
		WOOD,
		m
	)
	local face = part(
		"Face",
		Vector3.new(w, h, 0.6),
		cf * CFrame.new(0, h / 2 + 4.5, -0.3),
		P.Board,
		PLASTIC,
		m
	)
	face:SetAttribute("BoardTitle", title)
	CollectionService:AddTag(face, tag)
	surfaceText(face, Enum.NormalId.Front, title, P.Text, 20)
	part("Roof", Vector3.new(w + 3, 0.8, 3.6), cf * CFrame.new(0, h + 5.8, -0.8), P.Roof, WOOD, m)
	part("RoofSnow", Vector3.new(w + 2, 0.7, 3), cf * CFrame.new(0, h + 6.5, -0.8), P.Snow, SNOW, m)
	for _, sx in { -1, 1 } do
		local lamp = part(
			"Lamp",
			Vector3.new(1.2, 1.2, 1.2),
			cf * CFrame.new(sx * (w / 2 - 3), h + 4.8, -2.2),
			P.Warm,
			NEON,
			m,
			{ transparency = 0.2 }
		)
		light(lamp, P.Warm, 22, 1.4)
		CollectionService:AddTag(lamp, T.Lamp)
	end
	return m
end

-- Shop cabin: log walls, open serving window with a counter (the ProximityPrompt), stepped snowy roof.
-- Local -Z faces the plaza.
function HubProps.shop(parent: Instance, cf: CFrame): Instance
	local m = model("ShopBuilding", parent)
	local W, D, WH = 28, 20, 12
	local function box(
		name: string,
		size: Vector3,
		offset: Vector3,
		color: Color3,
		material: Enum.Material,
		collide: boolean?
	): Part
		return part(name, size, cf * CFrame.new(offset), color, material, m, { collide = collide })
	end
	box("Floor", Vector3.new(W + 2, 1, D + 2), Vector3.new(0, 0.5, 0), P.WoodDark, WOOD, true)
	box("WallBack", Vector3.new(W, WH, 1.2), Vector3.new(0, WH / 2 + 1, D / 2), P.Wood, WOOD, true)
	box("WallL", Vector3.new(1.2, WH, D), Vector3.new(-W / 2, WH / 2 + 1, 0), P.Wood, WOOD, true)
	box("WallR", Vector3.new(1.2, WH, D), Vector3.new(W / 2, WH / 2 + 1, 0), P.Wood, WOOD, true)
	local sideW = (W - 14) / 2
	box(
		"FrontL",
		Vector3.new(sideW, WH, 1.2),
		Vector3.new(-(W - sideW) / 2, WH / 2 + 1, -D / 2),
		P.Wood,
		WOOD,
		true
	)
	box(
		"FrontR",
		Vector3.new(sideW, WH, 1.2),
		Vector3.new((W - sideW) / 2, WH / 2 + 1, -D / 2),
		P.Wood,
		WOOD,
		true
	)
	box(
		"Lintel",
		Vector3.new(14, 3.4, 1.2),
		Vector3.new(0, WH - 0.7 + 1, -D / 2),
		P.WoodDark,
		WOOD,
		true
	)
	for i = 1, 4 do
		box(
			"Log",
			Vector3.new(W + 1.4, 0.7, 0.7),
			Vector3.new(0, 1.6 + i * 2.6, -D / 2 - 0.5),
			P.WoodDark,
			WOOD
		)
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			box(
				"Corner",
				Vector3.new(1.8, WH + 1, 1.8),
				Vector3.new(sx * W / 2, (WH + 1) / 2 + 1, sz * D / 2),
				P.WoodDark,
				WOOD,
				true
			)
		end
	end
	local counter = box(
		"Counter",
		Vector3.new(14, 4, 3),
		Vector3.new(0, 3, -D / 2 - 1.5),
		P.WoodDark,
		WOOD,
		true
	)
	box("CounterTop", Vector3.new(15, 0.6, 3.6), Vector3.new(0, 5.3, -D / 2 - 1.5), P.Wood, WOOD)
	CollectionService:AddTag(counter, T.Shop)
	prompt(counter, T.ShopPrompt, "Open Shop", "Frostline Supply")
	-- Awning (blue/white stripes) over the window.
	for i = 1, 7 do
		local c = if i % 2 == 0 then P.AwningAlt else P.Awning
		box(
			"Awning",
			Vector3.new(2, 0.5, 5),
			Vector3.new(-7 + (i - 1) * 2.34, 9.4, -D / 2 - 2.2),
			c,
			PLASTIC
		)
	end
	-- Roof: three stepped slabs with snow.
	local roofY = WH + 2.2
	box("Roof1", Vector3.new(W + 5, 1.4, D + 5), Vector3.new(0, roofY, 0), P.Roof, WOOD)
	box("Roof2", Vector3.new(W - 3, 1.4, D - 2), Vector3.new(0, roofY + 1.4, 0), P.Roof, WOOD)
	box("Roof3", Vector3.new(W - 11, 1.4, D - 8), Vector3.new(0, roofY + 2.8, 0), P.Roof, WOOD)
	box("Snow1", Vector3.new(W + 3.6, 0.9, D + 3.6), Vector3.new(0, roofY + 1, 0), P.Snow, SNOW)
	box("Snow2", Vector3.new(W - 4.4, 0.9, D - 3.4), Vector3.new(0, roofY + 2.4, 0), P.Snow, SNOW)
	box("Snow3", Vector3.new(W - 12, 1.2, D - 9), Vector3.new(0, roofY + 3.6, 0), P.Snow, SNOW)
	-- Chimney with smoke.
	local chimney = box(
		"Chimney",
		Vector3.new(3, 8, 3),
		Vector3.new(W / 2 - 5, roofY + 5, D / 2 - 4),
		P.Rock,
		SLATE
	)
	local smoke = Instance.new("Smoke")
	smoke.Size = 4
	smoke.Opacity = 0.35
	smoke.RiseVelocity = 5
	smoke.Color = P.SnowShade
	smoke.Parent = chimney
	-- Sign board.
	local sign = box(
		"Sign",
		Vector3.new(16, 3.6, 0.8),
		Vector3.new(0, WH + 6.2, -D / 2 - 3.5),
		P.Board,
		PLASTIC
	)
	surfaceText(sign, Enum.NormalId.Front, "FROSTLINE SUPPLY", P.Text, 30)
	box(
		"SignPostL",
		Vector3.new(0.6, 5, 0.6),
		Vector3.new(-7, WH + 4, -D / 2 - 3.5),
		P.WoodDark,
		WOOD
	)
	box(
		"SignPostR",
		Vector3.new(0.6, 5, 0.6),
		Vector3.new(7, WH + 4, -D / 2 - 3.5),
		P.WoodDark,
		WOOD
	)
	-- Goods on the counter and shelves inside, warm light.
	local goods = {
		Color3.fromRGB(200, 90, 70),
		Color3.fromRGB(90, 160, 210),
		Color3.fromRGB(230, 200, 90),
		Color3.fromRGB(110, 190, 120),
	}
	for i, c in goods do
		box(
			"Goods",
			Vector3.new(1.6, 1.6, 1.6),
			Vector3.new(-5.5 + (i - 1) * 3.6, 6.4, -D / 2 - 1.5),
			c,
			PLASTIC
		)
	end
	box("Shelf", Vector3.new(W - 4, 0.6, 2), Vector3.new(0, 6.5, D / 2 - 1.8), P.WoodDark, WOOD)
	local lamp =
		box("Lantern", Vector3.new(1.4, 1.8, 1.4), Vector3.new(0, 10.2, -D / 2 + 3), P.Warm, NEON)
	lamp.Transparency = 0.2
	light(lamp, P.Warm, 34, 2.2)
	CollectionService:AddTag(lamp, T.Lamp)
	for _, sx in { -1, 1 } do
		local ext = box(
			"Lantern",
			Vector3.new(1.2, 1.6, 1.2),
			Vector3.new(sx * (W / 2 + 0.4), 8, -D / 2 - 1),
			P.Warm,
			NEON
		)
		ext.Transparency = 0.2
		light(ext, P.Warm, 22, 1.4)
		CollectionService:AddTag(ext, T.Lamp)
	end
	return m
end

-- Pad: dark frame, big glowing square (tagged for PartyService and the client pulse), light, number.
function HubProps.pad(parent: Instance, index: number, cf: CFrame): Part
	local width = H.PadBase + (index - 1) * H.PadStep
	part(
		`PadFrame{index}`,
		Vector3.new(width + 2, H.PadThickness * 0.5, width + 2),
		cf * CFrame.new(0, H.PadThickness * 0.25 + 0.02, 0),
		P.Iron,
		SLATE,
		parent
	)
	local pad = part(
		`Pad{index}`,
		Vector3.new(width, H.PadThickness, width),
		cf * CFrame.new(0, H.PadThickness / 2 + 0.05, 0),
		P.PadEmpty,
		NEON,
		parent,
		{ transparency = 0.35 }
	)
	pad.CanTouch = true
	pad:SetAttribute(Config.Lobby.PadIndexAttribute, index)
	CollectionService:AddTag(pad, Config.Lobby.PadTag)
	CollectionService:AddTag(pad, T.Pulse)
	local pl = light(pad, P.PadEmpty, 22, 1.3)
	pl.Name = "PadGlow"
	-- Big number on the ground: SurfaceGui on the top face.
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Static"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	local turned = Instance.new("Frame") -- top-face UI reads sideways; turn it to face the plaza
	turned.Size = UDim2.fromScale(1, 1)
	turned.BackgroundTransparency = 1
	turned.Rotation = 90
	turned.Parent = gui
	local number = Instance.new("TextLabel")
	number.Size = UDim2.fromScale(1, 0.7)
	number.Position = UDim2.fromScale(0, 0.08)
	number.BackgroundTransparency = 1
	number.TextScaled = true
	number.Font = Enum.Font.GothamBlack
	number.TextColor3 = P.Text
	number.TextTransparency = 0.1
	number.Text = tostring(index)
	number.Parent = turned
	local caption = Instance.new("TextLabel")
	caption.Size = UDim2.fromScale(1, 0.14)
	caption.Position = UDim2.fromScale(0, 0.74)
	caption.BackgroundTransparency = 1
	caption.TextScaled = true
	caption.Font = Enum.Font.GothamBold
	caption.TextColor3 = P.Text
	caption.TextTransparency = 0.25
	caption.Text = if index == 1 then "SOLO" else `{index} PLAYERS`
	caption.Parent = turned
	gui.Parent = pad
	return pad
end

-- Stats dais: round platform with a glowing rim and the personal stats board; prompt opens the full panel.
function HubProps.statsArea(parent: Instance, cf: CFrame): Instance
	local m = model("StatsArea", parent)
	part(
		"Dais",
		Vector3.new(1, 22, 22),
		cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
		P.Cobble,
		SLATE,
		m,
		{ collide = true, shape = Enum.PartType.Cylinder }
	)
	part(
		"Rim",
		Vector3.new(0.5, 23, 23),
		cf * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		P.Ice,
		NEON,
		m,
		{ shape = Enum.PartType.Cylinder }
	)
	local board = HubProps.board(m, cf * CFrame.new(0, 1, 7), T.Stats, "YOUR STATS")
	local face = board:FindFirstChild("Face") :: BasePart
	prompt(face, T.StatsPrompt, "View Stats", "Your Stats")
	local glow = part(
		"Glow",
		Vector3.new(1, 1, 1),
		cf * CFrame.new(0, 4, -2),
		P.Ice,
		NEON,
		m,
		{ transparency = 1 }
	)
	light(glow, P.Ice, 26, 1.2)
	return m
end

-- Cosmetic mirror: wooden frame with a pale glass pane; prompt opens the cosmetics shop.
function HubProps.mirror(parent: Instance, cf: CFrame): Instance
	local m = model("Mirror", parent)
	part(
		"Dais",
		Vector3.new(0.8, 14, 14),
		cf * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.pi / 2),
		P.Cobble,
		SLATE,
		m,
		{ collide = true, shape = Enum.PartType.Cylinder }
	)
	local glass = part(
		"Glass",
		Vector3.new(7, 11, 0.4),
		cf * CFrame.new(0, 7, 0),
		P.Ice,
		Enum.Material.Glass,
		m,
		{ transparency = 0.45 }
	)
	glass.Reflectance = 0.35
	CollectionService:AddTag(glass, T.Mirror)
	prompt(glass, T.MirrorPrompt, "Wardrobe", "Cosmetic Mirror")
	part(
		"FrameL",
		Vector3.new(1, 12.4, 1),
		cf * CFrame.new(-4, 7, 0),
		P.WoodDark,
		WOOD,
		m,
		{ collide = true }
	)
	part(
		"FrameR",
		Vector3.new(1, 12.4, 1),
		cf * CFrame.new(4, 7, 0),
		P.WoodDark,
		WOOD,
		m,
		{ collide = true }
	)
	part("FrameTop", Vector3.new(9, 1, 1), cf * CFrame.new(0, 13.2, 0), P.WoodDark, WOOD, m)
	part("FrameBase", Vector3.new(9, 1, 1.6), cf * CFrame.new(0, 1.3, 0), P.WoodDark, WOOD, m)
	part("Crown", Vector3.new(5, 0.7, 1.2), cf * CFrame.new(0, 13.9, 0), P.Ice, NEON, m)
	local glow = part(
		"Glow",
		Vector3.new(1, 1, 1),
		cf * CFrame.new(0, 8, -3),
		P.Ice,
		NEON,
		m,
		{ transparency = 1 }
	)
	light(glow, P.Ice, 22, 1)
	return m
end

-- Spawn: the SpawnLocation (Config.Lobby.SpawnName) on a lit ring with a welcome arch behind it.
function HubProps.spawn(parent: Instance, pos: Vector3): Instance
	local m = model("SpawnArea", parent)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = Config.Lobby.SpawnName
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(pos)
	spawn.Transparency = 1
	spawn.CanQuery = false
	spawn.Parent = parent
	part(
		"Ring",
		Vector3.new(0.3, 16, 16),
		CFrame.new(pos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		P.Ice,
		NEON,
		m,
		{ shape = Enum.PartType.Cylinder, transparency = 0.4 }
	)
	part(
		"Disc",
		Vector3.new(0.4, 13, 13),
		CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		P.Cobble,
		SLATE,
		m,
		{ shape = Enum.PartType.Cylinder }
	)
	local z = pos.Z + 10
	part(
		"ArchL",
		Vector3.new(1.6, 14, 1.6),
		CFrame.new(pos.X - 9, pos.Y + 7, z),
		P.WoodDark,
		WOOD,
		m,
		{ collide = true }
	)
	part(
		"ArchR",
		Vector3.new(1.6, 14, 1.6),
		CFrame.new(pos.X + 9, pos.Y + 7, z),
		P.WoodDark,
		WOOD,
		m,
		{ collide = true }
	)
	part(
		"ArchTop",
		Vector3.new(21, 1.6, 1.8),
		CFrame.new(pos.X, pos.Y + 14.4, z),
		P.WoodDark,
		WOOD,
		m
	)
	part(
		"ArchSnow",
		Vector3.new(21.4, 0.8, 2.4),
		CFrame.new(pos.X, pos.Y + 15.5, z),
		P.Snow,
		SNOW,
		m
	)
	local sign = part(
		"ArchSign",
		Vector3.new(14, 3, 0.4),
		CFrame.new(pos.X, pos.Y + 12.4, z - 1.1),
		P.Board,
		PLASTIC,
		m
	)
	surfaceText(sign, Enum.NormalId.Front, "ARCTIC OUTPOST", P.Text, 30)
	for _, sx in { -1, 1 } do
		local lamp = part(
			"ArchLamp",
			Vector3.new(1.4, 1.4, 1.4),
			CFrame.new(pos.X + sx * 9, pos.Y + 15, z),
			P.Warm,
			NEON,
			m,
			{ transparency = 0.2 }
		)
		light(lamp, P.Warm, 26, 1.6)
		CollectionService:AddTag(lamp, T.Lamp)
	end
	return m
end

-- One large invisible emitter plate above the plaza (single ParticleEmitter for the whole hub).
function HubProps.snow(parent: Instance, origin: Vector3): Instance
	local plate = part(
		"SnowEmitter",
		Vector3.new(H.SnowAreaRadius * 2, 1, H.SnowAreaRadius * 2),
		CFrame.new(origin + Vector3.new(0, H.SnowHeight, 0)),
		P.Snow,
		PLASTIC,
		parent,
		{ transparency = 1 }
	)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Snowfall"
	e.Texture = if (Assets.SnowParticle or "") ~= "" then Assets.SnowParticle else DEFAULT_PARTICLE
	e.Rate = H.SnowRate
	e.Lifetime = NumberRange.new(10, 13)
	e.Speed = NumberRange.new(4, 7)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = Vector3.new(2.5, 0, 1)
	e.Size = NumberSequence.new(0.35)
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.08, 0.15),
		NumberSequenceKeypoint.new(0.9, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.LightEmission = 0.25
	e.Color = ColorSequence.new(P.Snow)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Parent = plate
	return plate
end

-- Looping ambient hooks: silent until Assets.HubWindSound / HubMusicSound are supplied.
function HubProps.ambience(parent: Instance): Instance
	local holder = part(
		"Ambience",
		Vector3.new(1, 1, 1),
		CFrame.new(ArtKit.vec(H.Origin) + Vector3.new(0, 20, 0)),
		P.Snow,
		PLASTIC,
		parent,
		{ transparency = 1 }
	)
	sound(holder, "Wind", "HubWindSound", 0.4, 400)
	sound(holder, "Music", "HubMusicSound", 0.25, 400)
	return holder
end

return HubProps
