--!strict
-- Server adapter for massive structures A (ResearchStation, MineComplex): turns a pure plan
-- (shared/logic/StructurePlanKitA) into a Model. build() sites the structure with World.heightAt, carves the
-- underground rooms out of the Terrain (FillBlock to air), builds the shell (large parts, lamps, ramps) and
-- returns a Handle. Interior dressing (props, signs, notes, claw marks, eyes) is spawned only while a player is
-- near (Config.Massive.DressingSpawnRadius, hysteresis DressingDespawnRadius) at DressingPartsPerTick parts per
-- Update() call, and removed when everyone leaves. One shared Heartbeat loop flickers every live structure's
-- lights and hides watching eyes when a player gets close. Horror hooks (lurker spots, ambient cue spots, room
-- lookup) are plain server data on the Handle: nothing about them is replicated or labelled for clients.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ArtKit = require(Shared:WaitForChild("ArtKit"))
local Logic = Shared:WaitForChild("logic")
local World = require(Logic:WaitForChild("World"))
local MassiveRules = require(Logic:WaitForChild("MassiveRules"))
local Kit = require(Logic:WaitForChild("StructurePlanKitA"))

local P = ArtKit.palette(Config.Art.World.Palette)

local FLICKER_INTERVAL = 0.12 -- seconds between light updates (one loop for all structures)
local FLICKER_OFF_CHANCE = 0.15
local FLICKER_DIM_CHANCE = 0.4 -- cumulative: below this (and above off) the light dims
local FLICKER_DIM_FACTOR = 0.35
local EYES_VANISH_DISTANCE = 18 -- studs: watching eyes close when a player comes this near
local EYES_TRANSPARENCY = 0.1
local SIGN_DISTANCE = 60
local NOTE_DISTANCE = 14
local SAMPLE_STEP = 8 -- studs between terrain height samples over the footprint
local CARVE_MARGIN = 2 -- studs of extra air around each carved room
local APPROACH_RUN = 40 -- studs: the ramp from an exit door to the terrain
local APPROACH_SLOPE = 3 -- run per rise: keeps approach ramps walkable
local APPROACH_EXTRA_WIDTH = 4
local APPROACH_CLEAR_HEIGHT = 40
local QUARTER_TURN = 90

local function darker(c: Color3, f: number): Color3
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

type Style = { color: Color3, material: Enum.Material, transparency: number? }

local STYLES: { [string]: Style } = {
	Concrete = { color = P.Ruin, material = Enum.Material.Concrete },
	ConcreteDark = { color = P.RuinDark, material = Enum.Material.Concrete },
	Tile = { color = P.SnowShade, material = Enum.Material.SmoothPlastic },
	Metal = { color = P.Metal, material = Enum.Material.Metal },
	MetalDark = { color = P.MetalDark, material = Enum.Material.Metal },
	Grate = { color = darker(P.MetalDark, 0.8), material = Enum.Material.DiamondPlate },
	Rust = { color = P.RockWarm, material = Enum.Material.CorrodedMetal },
	Rock = { color = P.Rock, material = Enum.Material.Slate },
	RockDark = { color = darker(P.RockDark, 0.8), material = Enum.Material.Rock },
	Rubble = { color = P.RockWarm, material = Enum.Material.Rock },
	Wood = { color = P.Wood, material = Enum.Material.WoodPlanks },
	WoodDark = { color = P.WoodDark, material = Enum.Material.Wood },
	Roof = { color = P.Roof, material = Enum.Material.Metal },
	Ice = { color = P.Ice, material = Enum.Material.Ice },
	Glass = { color = P.Spring, material = Enum.Material.Glass, transparency = 0.5 },
	Water = { color = darker(P.IceDeep, 0.5), material = Enum.Material.Glass, transparency = 0.4 },
	Lamp = { color = P.Window, material = Enum.Material.Neon },
	Indicator = { color = P.Spring, material = Enum.Material.Neon },
	Eyes = { color = P.Snow, material = Enum.Material.Neon, transparency = EYES_TRANSPARENCY },
	Ore = { color = P.OreGlint, material = Enum.Material.Metal },
	Rail = { color = P.MetalDark, material = Enum.Material.Metal },
	Paper = { color = P.TentAlt, material = Enum.Material.Fabric },
	Cloth = { color = P.TentAlt, material = Enum.Material.Fabric },
	Scratch = { color = P.Scorch, material = Enum.Material.Slate },
	Sign = { color = darker(P.MetalDark, 0.6), material = Enum.Material.Metal },
	Mast = { color = P.Metal, material = Enum.Material.Metal },
	Emitter = { color = P.Snow, material = Enum.Material.SmoothPlastic, transparency = 1 },
	Approach = { color = P.RuinDark, material = Enum.Material.Concrete },
}

local LIGHT_COLORS: { [string]: Color3 } = {
	Warm = P.Window,
	Cold = P.Ice,
	Sick = P.Crystal,
	Red = P.Tent,
}

type ParticleStyle = {
	color: Color3,
	rate: number,
	lifetime: number,
	size: number,
	speed: number,
	transparency: number,
	accel: Vector3,
}

local PARTICLES: { [string]: ParticleStyle } = {
	Steam = {
		color = P.Snow,
		rate = 5,
		lifetime = 3,
		size = 3.5,
		speed = 3,
		transparency = 0.6,
		accel = Vector3.new(0, 2, 0),
	},
	Dust = {
		color = P.RockWarm,
		rate = 4,
		lifetime = 5,
		size = 1.5,
		speed = 0.6,
		transparency = 0.7,
		accel = Vector3.new(0, 0.2, 0),
	},
	Frost = {
		color = P.Ice,
		rate = 6,
		lifetime = 4,
		size = 1.2,
		speed = 0.8,
		transparency = 0.5,
		accel = Vector3.new(0, -0.3, 0),
	},
}

local StructureKitA = {}

export type ChestSlot = { Position: Vector3, Depth: number, StructureType: string }
export type CueSpot = { Position: Vector3, Kind: string, Room: string }
export type RoomInfo = { Id: string, Name: string, Level: number, Dark: boolean }
export type Handle = {
	Model: Model,
	Footprint: { radius: number, sizeX: number, sizeZ: number, center: Vector3 },
	ChestSlots: { ChestSlot },
	LurkerSpots: { Vector3 }, -- server-only: where "eyes in the dark" may be placed by Horror
	CueSpots: { CueSpot }, -- server-only: ambient sound hooks (Kind: Drip, Hum, Creak, Wind, ...)
	RoomAt: (position: Vector3) -> RoomInfo?,
	Update: (playerPositions: { Vector3 }) -> (),
	Destroy: () -> (),
}

type LightEntry = { light: PointLight, base: number, flicker: boolean }
type GroupState = {
	group: Kit.Group,
	spawned: number,
	parts: { BasePart },
	eyes: { BasePart },
}
type State = {
	plan: Kit.Plan,
	frame: CFrame,
	center: Vector3,
	model: Model,
	dressingFolder: Folder,
	lights: { LightEntry },
	emitters: { ParticleEmitter },
	groups: { GroupState },
	players: { Vector3 },
	active: boolean,
	destroyed: boolean,
	random: Random,
}

local live: { State } = {}
local loopConnection: RBXScriptConnection? = nil
local elapsed = 0

-- Parts -------------------------------------------------------------------------------------------------

local function attachText(part: BasePart, box: Kit.Box)
	local isNote = box.role == "Note"
	local gui = Instance.new("BillboardGui")
	gui.Name = if isNote then "NoteText" else "SignText"
	gui.Size = if isNote then UDim2.fromOffset(260, 110) else UDim2.fromOffset(210, 34)
	gui.StudsOffset = if isNote then Vector3.new(0, 1.6, 0) else Vector3.zero
	gui.MaxDistance = if isNote then NOTE_DISTANCE else SIGN_DISTANCE
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Adornee = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = if isNote then 0.25 else 0.4
	label.BackgroundColor3 = P.Scorch
	label.TextColor3 = P.Snow
	label.Font = if isNote then Enum.Font.SpecialElite else Enum.Font.GothamBold
	label.TextSize = if isNote then 14 else 18
	label.TextWrapped = true
	label.Text = box.text or ""
	label.Parent = gui
	gui.Parent = part
end

local function makePart(box: Kit.Box, frame: CFrame): Part
	local style = STYLES[box.style] or STYLES.Concrete
	local part = Instance.new("Part")
	part.Name = box.name
	part.Anchored = true
	part.CanCollide = box.collide
	part.CanTouch = false
	part.CastShadow = false
	part.Material = style.material
	part.Color = style.color
	part.Transparency = style.transparency or 0
	if box.role == "Emitter" then
		part.CanQuery = false
	end
	local cf = frame
		* CFrame.new(box.x, box.y, box.z)
		* CFrame.Angles(math.rad(box.rx or 0), math.rad(box.ry or 0), math.rad(box.rz or 0))
	if box.shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(box.sy, box.sx, box.sz)
		cf = cf * CFrame.Angles(0, 0, math.pi / 2)
	else
		part.Size = Vector3.new(box.sx, box.sy, box.sz)
	end
	part.CFrame = cf
	if box.text ~= nil then
		attachText(part, box)
	end
	return part
end

local function addLight(state: State, part: Part, box: Kit.Box)
	local def = box.light
	if def == nil then
		return
	end
	local light = Instance.new("PointLight")
	light.Range = def.range
	light.Brightness = def.brightness
	light.Color = LIGHT_COLORS[def.color] or P.Window
	light.Shadows = false
	light.Parent = part
	table.insert(state.lights, { light = light, base = def.brightness, flicker = def.flicker })
end

local function addParticles(state: State, part: Part, box: Kit.Box)
	local style = box.particle and PARTICLES[box.particle]
	if style == nil then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(style.color)
	emitter.Rate = style.rate
	emitter.Lifetime = NumberRange.new(style.lifetime * 0.7, style.lifetime)
	emitter.Speed = NumberRange.new(style.speed * 0.5, style.speed)
	emitter.Size = NumberSequence.new(style.size)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, style.transparency),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Acceleration = style.accel
	emitter.LightEmission = 0
	emitter.Enabled = false
	emitter.Parent = part
	table.insert(state.emitters, emitter)
end

-- Terrain and siting ------------------------------------------------------------------------------------

local function carveBox(
	frame: CFrame,
	x0: number,
	y0: number,
	z0: number,
	x1: number,
	y1: number,
	z1: number
)
	local cf = frame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	local size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)
	local ok = pcall(function()
		Workspace.Terrain:FillBlock(cf, size, Enum.Material.Air)
	end)
	return ok
end

-- Lowest terrain top under the footprint and the highest.
local function sampleGround(seed: number, plan: Kit.Plan, base: CFrame): (number, number)
	local lo, hi = math.huge, -math.huge
	local x = plan.minX
	while x <= plan.maxX + SAMPLE_STEP do
		local z = plan.minZ
		while z <= plan.maxZ + SAMPLE_STEP do
			local p = base:PointToWorldSpace(
				Vector3.new(math.min(x, plan.maxX), 0, math.min(z, plan.maxZ))
			)
			local h = World.heightAt(seed, p.X, p.Z)
			lo, hi = math.min(lo, h), math.max(hi, h)
			z += SAMPLE_STEP
		end
		x += SAMPLE_STEP
	end
	return lo, hi
end

-- A walkable ramp from an exit door out to the terrain, with the hill above it cut away.
local function buildApproach(state: State, exit: Kit.Exit, seed: number, ground: number)
	local frame = state.frame
	local function terrainAt(d: number): number
		local p =
			frame:PointToWorldSpace(Vector3.new(exit.x + exit.dx * d, 0, exit.z + exit.dz * d))
		return World.heightAt(seed, p.X, p.Z)
	end
	local run = APPROACH_RUN
	local delta = terrainAt(run) - ground
	run = math.max(APPROACH_RUN, math.abs(delta) * APPROACH_SLOPE)
	delta = terrainAt(run) - ground
	local width = exit.width + APPROACH_EXTRA_WIDTH
	local length = math.sqrt(run * run + delta * delta)
	local angle = math.atan2(delta, run)
	local thick = Kit.RAMP_THICK
	local cf = CFrame.new(
		exit.x + exit.dx * run / 2,
		delta / 2 - thick / 2 / math.cos(angle),
		exit.z + exit.dz * run / 2
	) * CFrame.Angles(0, math.atan2(exit.dx, exit.dz), 0) * CFrame.Angles(-angle, 0, 0)
	local style = STYLES.Approach
	local part = Instance.new("Part")
	part.Name = `{exit.room}_approach`
	part.Anchored = true
	part.CanTouch = false
	part.CastShadow = false
	part.Material = style.material
	part.Color = style.color
	part.Size = Vector3.new(width, thick, length)
	part.CFrame = state.frame * cf
	part.Parent = state.model
	if delta > 0 then
		local clear = state.frame * cf * CFrame.new(0, APPROACH_CLEAR_HEIGHT / 2 + thick, 0)
		pcall(function()
			Workspace.Terrain:FillBlock(
				clear,
				Vector3.new(width + 2, APPROACH_CLEAR_HEIGHT, length),
				Enum.Material.Air
			)
		end)
	end
end

-- Dressing ----------------------------------------------------------------------------------------------

local function nearestDistance(state: State, group: Kit.Group): number
	local p = state.frame:PointToWorldSpace(Vector3.new(group.x, 0, group.z))
	local best = math.huge
	for _, pos in state.players do
		local dx, dz = pos.X - p.X, pos.Z - p.Z
		best = math.min(best, dx * dx + dz * dz)
	end
	return best
end

local function spawnOne(state: State, gs: GroupState)
	local box = gs.group.boxes[gs.spawned + 1]
	local part = makePart(box, state.frame)
	if box.light ~= nil then
		addLight(state, part, box)
	end
	part.Parent = state.dressingFolder
	gs.spawned += 1
	table.insert(gs.parts, part)
	if box.role == "Eyes" then
		table.insert(gs.eyes, part)
	end
end

local function removeOne(gs: GroupState)
	local part = table.remove(gs.parts)
	if part == nil then
		gs.spawned = 0
		return
	end
	local i = table.find(gs.eyes, part)
	if i then
		table.remove(gs.eyes, i)
	end
	part:Destroy()
	gs.spawned -= 1
end

local function setEmitters(state: State, enabled: boolean)
	for _, emitter in state.emitters do
		emitter.Enabled = enabled
	end
end

local function updateState(state: State, positions: { Vector3 })
	if state.destroyed then
		return
	end
	state.players = positions
	local M = Config.Massive
	local nearest = math.huge
	for _, pos in positions do
		local dx, dz = pos.X - state.center.X, pos.Z - state.center.Z
		nearest = math.min(nearest, math.sqrt(dx * dx + dz * dz))
	end
	local wasActive = state.active
	if state.active then
		if nearest > M.DressingDespawnRadius then
			state.active = false
		end
	elseif nearest <= M.DressingSpawnRadius then
		state.active = true
	end
	if state.active ~= wasActive then
		setEmitters(state, state.active)
	end
	local budget = M.DressingPartsPerTick
	if state.active then
		local order: { GroupState } = table.clone(state.groups)
		local dist: { [GroupState]: number } = {}
		for _, gs in order do
			dist[gs] = nearestDistance(state, gs.group)
		end
		table.sort(order, function(a: GroupState, b: GroupState): boolean
			return dist[a] < dist[b]
		end)
		for _, gs in order do
			while budget > 0 and gs.spawned < #gs.group.boxes do
				spawnOne(state, gs)
				budget -= 1
			end
			if budget <= 0 then
				break
			end
		end
	else
		for _, gs in state.groups do
			while budget > 0 and gs.spawned > 0 do
				removeOne(gs)
				budget -= 1
			end
			if budget <= 0 then
				break
			end
		end
	end
end

-- One loop for every live structure: light flicker and shy eyes.
local function step(dt: number)
	elapsed += dt
	if elapsed < FLICKER_INTERVAL then
		return
	end
	elapsed = 0
	for _, state in live do
		if state.active then
			for _, entry in state.lights do
				if entry.flicker and entry.light.Parent ~= nil then
					local r = state.random:NextNumber()
					if r < FLICKER_OFF_CHANCE then
						entry.light.Brightness = 0
					elseif r < FLICKER_DIM_CHANCE then
						entry.light.Brightness = entry.base * FLICKER_DIM_FACTOR
					else
						entry.light.Brightness = entry.base
					end
				end
			end
			for _, gs in state.groups do
				for _, eye in gs.eyes do
					local near = false
					for _, pos in state.players do
						if (pos - eye.Position).Magnitude < EYES_VANISH_DISTANCE then
							near = true
							break
						end
					end
					eye.Transparency = if near then 1 else EYES_TRANSPARENCY
				end
			end
		end
	end
end

local function register(state: State)
	table.insert(live, state)
	if loopConnection == nil then
		loopConnection = RunService.Heartbeat:Connect(step)
	end
end

local function unregister(state: State)
	local i = table.find(live, state)
	if i then
		table.remove(live, i)
	end
	if #live == 0 and loopConnection ~= nil then
		loopConnection:Disconnect()
		loopConnection = nil
	end
end

-- Build -------------------------------------------------------------------------------------------------

local function yawFor(seed: number, origin: Vector3): number
	local rng = Kit.rng(seed + math.floor(origin.X) * 7 + math.floor(origin.Z) * 13)
	return math.floor(rng() * 4) * math.rad(QUARTER_TURN)
end

function StructureKitA.build(
	plan: Kit.Plan,
	origin: Vector3,
	seed: number,
	parent: Instance
): Handle
	local yaw = yawFor(seed, origin)
	local base = CFrame.new(origin.X, 0, origin.Z) * CFrame.Angles(0, yaw, 0)
	local lo, hi = sampleGround(seed, plan, base)
	local ground = math.floor(lo)
	local frame = CFrame.new(origin.X, ground, origin.Z) * CFrame.Angles(0, yaw, 0)
	local rise = hi - ground

	local model = Instance.new("Model")
	model.Name = plan.id
	model:SetAttribute("MassiveId", plan.id)
	local dressingFolder = Instance.new("Folder")
	dressingFolder.Name = "Dressing"
	dressingFolder.Parent = model

	local state: State = {
		plan = plan,
		frame = frame,
		center = frame:PointToWorldSpace(
			Vector3.new((plan.minX + plan.maxX) / 2, 0, (plan.minZ + plan.maxZ) / 2)
		),
		model = model,
		dressingFolder = dressingFolder,
		lights = {},
		emitters = {},
		groups = {},
		players = {},
		active = false,
		destroyed = false,
		random = Random.new(seed),
	}

	-- carve the voids out of the terrain first, then build the shell inside them
	for _, c in plan.carves do
		local up = if c.open then rise + CARVE_MARGIN * 4 else 0
		carveBox(
			frame,
			c.x0 - CARVE_MARGIN,
			c.y0 - 1,
			c.z0 - CARVE_MARGIN,
			c.x1 + CARVE_MARGIN,
			c.y1 + up,
			c.z1 + CARVE_MARGIN
		)
	end
	for _, box in plan.shell do
		local part = makePart(box, frame)
		if box.light ~= nil then
			addLight(state, part, box)
		end
		if box.particle ~= nil then
			addParticles(state, part, box)
		end
		part.Parent = model
	end
	for _, exit in plan.exits do
		buildApproach(state, exit, seed, ground)
	end
	for _, group in plan.dressing do
		table.insert(state.groups, { group = group, spawned = 0, parts = {}, eyes = {} })
	end
	model.Parent = parent

	-- data for the integration
	local chests: { ChestSlot } = {}
	for _, c in plan.chests do
		table.insert(chests, {
			Position = frame:PointToWorldSpace(Vector3.new(c.x, c.y, c.z)),
			Depth = c.depth,
			StructureType = plan.id,
		})
	end
	local lurkers: { Vector3 } = {}
	for _, s in plan.lurkers do
		table.insert(lurkers, frame:PointToWorldSpace(Vector3.new(s.x, s.y, s.z)))
	end
	local cues: { CueSpot } = {}
	for _, s in plan.cues do
		table.insert(cues, {
			Position = frame:PointToWorldSpace(Vector3.new(s.x, s.y, s.z)),
			Kind = s.kind,
			Room = s.room,
		})
	end

	register(state)

	local handle: Handle = {
		Model = model,
		Footprint = {
			radius = MassiveRules.footprintRadius(plan.id),
			sizeX = plan.maxX - plan.minX,
			sizeZ = plan.maxZ - plan.minZ,
			center = state.center,
		},
		ChestSlots = chests,
		LurkerSpots = lurkers,
		CueSpots = cues,
		RoomAt = function(position: Vector3): RoomInfo?
			local p = frame:PointToObjectSpace(position)
			for _, room in plan.rooms do
				if
					p.X >= room.x0
					and p.X <= room.x1
					and p.Z >= room.z0
					and p.Z <= room.z1
					and p.Y >= room.y - Kit.SLAB
					and p.Y <= room.y + room.h + Kit.SLAB
				then
					return { Id = room.id, Name = room.name, Level = room.level, Dark = room.dark }
				end
			end
			return nil
		end,
		Update = function(playerPositions: { Vector3 })
			updateState(state, playerPositions)
		end,
		Destroy = function()
			if state.destroyed then
				return
			end
			state.destroyed = true
			unregister(state)
			table.clear(state.lights)
			table.clear(state.emitters)
			table.clear(state.groups)
			table.clear(state.players)
			model:Destroy()
		end,
	}
	return handle
end

return StructureKitA
