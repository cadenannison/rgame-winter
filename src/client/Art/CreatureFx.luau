--!strict
-- Client-only creature effects (Art Pass 3), started once by MobsClient after launch. One RenderStepped loop
-- for every creature; nothing here is replicated or sent to the server.
--  * Carrion crows: a few cheap follower specks circle each nearby crow and scatter along the Heading attribute
--    when the crow's State turns alarmed (Run/Alert/Attack/Hurt/Telegraph).
--  * Frostbound Brute: a ground ring whose disc fills over the wind-up (Telegraph) so the slam is dodgeable.
--  * Aurora Wisp: ParticleEmitter + Trail (from the Def's TrailA/TrailB attachments) and at most
--    Config.Creatures.MaxWispLights PointLights, only within WispLightRadius, nearest first.
-- Everything is limited to Config.Creatures.AnimRadius of the camera and cleaned up when far or removed.
-- Sound hooks (silent): crow caw on scatter, brute slam thud when the ring completes, wisp hum.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Fx = require(Shared:WaitForChild("logic"):WaitForChild("CreatureFxLogic"))

local CFG = Config.Creatures

local FOLDER_NAME = "CreatureFx"
local SLOW_STEP = 0.25 -- seconds between kind discovery / distance / light selection passes
local ATTACK_FADE = 0.3 -- seconds the ring lingers after the slam lands

-- Crows
local KIND_CROW, KIND_BRUTE, KIND_WISP = "CarrionCrow", "FrostboundBrute", "AuroraWisp"
local FLOCK_FOLLOWERS = 2
local MAX_FLOCKS = 6
local FLOCK_ORBIT = 3.5 -- studs
local FLOCK_HEIGHT = 3 -- studs above the crow
local FLOCK_REACH = 28 -- studs flown when fully scattered
local FLOCK_SCATTER_RATE = 1.4 -- 1/seconds
local FLOCK_SIZE = Vector3.new(0.5, 0.1, 0.35)
local FLOCK_COLOR = Color3.fromRGB(28, 30, 42)
local FLOCK_FLAP_HZ = 13
local FLOCK_FLAP_ANGLE = 0.7
local FLOCK_HIDE_AT = 0.9 -- scatter value above which followers hide (they have "flown away")

-- Brute telegraph
local MAX_RINGS = 3
local RING_RADIUS_PER_SIZE = 1.6 -- slam radius = max(root.Size.X, root.Size.Z) * this
local RING_FALLBACK_TOTAL = 1.2 -- seconds, if TelegraphLeft is missing
local RING_THICKNESS = 0.2
local RING_LIFT = 0.15 -- studs above the ground
local RING_OUTLINE_WIDTH = 0.6
local RING_COLOR = Color3.fromRGB(255, 120, 70)
local FILL_FROM, FILL_TO = 0.8, 0.35
local OUTLINE_TRANSPARENCY = 0.35
local RING_FX_RADIUS = 110 -- only brutes this close to the camera get a ring

-- Wisps
local LIGHT_RANGE = 16
local LIGHT_BRIGHTNESS = 1.4
local LIGHT_HYSTERESIS = 0.15
local LIGHT_COLOR = Color3.fromRGB(120, 255, 210)
local LIGHT_PULSE = 0.25
local WISP_TRAIL_LIFETIME = 0.8
local WISP_TRAIL_WIDTH = 0.7
local WISP_COLORS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(110, 255, 205)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(130, 200, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 150, 255)),
})
local WISP_PARTICLE_RATE = 5
local WISP_PARTICLE_LIFETIME = NumberRange.new(1.2, 2)
local WISP_PARTICLE_SPEED = NumberRange.new(0.3, 0.8)
local WISP_PARTICLE_SIZE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.5),
	NumberSequenceKeypoint.new(1, 0),
})
local WISP_PARTICLE_FADE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.3),
	NumberSequenceKeypoint.new(1, 1),
})

type Tracked = {
	model: Model,
	id: number,
	kind: string?,
	root: BasePart?,
	state: string,
	stateSince: number,
	dist: number,
}
type FlockFx = { parts: { Part }, scatter: number }
type RingFx = { disc: Part, outline: Part, total: number, doneAt: number? }
type WispFx = { emitter: ParticleEmitter?, trail: Trail?, light: PointLight?, orb: BasePart? }

local CreatureFx = {}

local started = false
local folder: Folder? = nil
local nextId = 0
local tracked: { [Model]: Tracked } = {}
local flocks: { [Model]: FlockFx } = {}
local rings: { [Model]: RingFx } = {}
local wisps: { [Model]: WispFx } = {}
local ringCount = 0
local lastSlow = 0
local lightsOn: { [number]: boolean } = {}

local function fxFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = Workspace
	folder = created
	return created
end

local function newFxPart(size: Vector3, color: Color3, neon: boolean): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Color = color
	part.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Parent = fxFolder()
	return part
end

local function flatHeading(model: Model): (number, number)
	local h = model:GetAttribute(CFG.HeadingAttribute)
	if typeof(h) == "Vector3" then
		return h.X, h.Z
	end
	return 0, 0
end

-- Crow flock ---------------------------------------------------------------------------------------------

local function dropFlock(model: Model)
	local fx = flocks[model]
	if fx then
		for _, p in fx.parts do
			p:Destroy()
		end
		flocks[model] = nil
	end
end

local function ensureFlock(model: Model): FlockFx
	local existing: FlockFx? = flocks[model]
	if existing then
		return existing
	end
	local parts: { Part } = {}
	for _ = 1, FLOCK_FOLLOWERS do
		table.insert(parts, newFxPart(FLOCK_SIZE, FLOCK_COLOR, false))
	end
	local created: FlockFx = { parts = parts, scatter = 0 }
	flocks[model] = created
	return created
end

local function stepFlock(rec: Tracked, root: BasePart, now: number, dt: number)
	local fx = ensureFlock(rec.model)
	fx.scatter = Fx.scatterStep(fx.scatter, Fx.isScatterState(rec.state), dt, FLOCK_SCATTER_RATE)
	local hx, hz = flatHeading(rec.model)
	local hidden = fx.scatter >= FLOCK_HIDE_AT and (hx ~= 0 or hz ~= 0)
	local pos = root.Position
	for i, part in fx.parts do
		local o = Fx.flockOffset(
			i,
			FLOCK_FOLLOWERS,
			now,
			fx.scatter,
			hx,
			hz,
			FLOCK_ORBIT,
			FLOCK_HEIGHT,
			FLOCK_REACH
		)
		local at = pos + Vector3.new(o.x, o.y, o.z)
		local flap = math.sin(now * FLOCK_FLAP_HZ + i * 2) * FLOCK_FLAP_ANGLE
		local dir = Vector3.new(-o.z, 0, o.x)
		local look = if dir.Magnitude > 0.01 then CFrame.lookAt(at, at + dir) else CFrame.new(at)
		part.CFrame = look * CFrame.Angles(0, 0, flap)
		part.Transparency = if hidden then 1 else 0
	end
end

-- Brute telegraph ring -----------------------------------------------------------------------------------

local function dropRing(model: Model)
	local fx = rings[model]
	if fx then
		fx.disc:Destroy()
		fx.outline:Destroy()
		rings[model] = nil
		ringCount -= 1
	end
end

local function ensureRing(model: Model, radius: number): RingFx?
	local existing: RingFx? = rings[model]
	if existing then
		return existing
	end
	if ringCount >= MAX_RINGS then
		return nil
	end
	local total = model:GetAttribute(CFG.TelegraphAttribute)
	local disc = newFxPart(Vector3.new(RING_THICKNESS, 1, 1), RING_COLOR, true)
	disc.Shape = Enum.PartType.Cylinder
	local outline = newFxPart(Vector3.new(RING_THICKNESS, radius * 2, radius * 2), RING_COLOR, true)
	outline.Shape = Enum.PartType.Cylinder
	outline.Transparency = 1
	local created: RingFx = {
		disc = disc,
		outline = outline,
		total = if type(total) == "number" and total > 0 then total else RING_FALLBACK_TOTAL,
		doneAt = nil,
	}
	rings[model] = created
	ringCount += 1
	return created
end

local function placeRing(fx: RingFx, root: BasePart, fill: number, outer: number)
	local ground = root.Position - Vector3.new(0, root.Size.Y / 2 - RING_LIFT, 0)
	local flat = CFrame.new(ground) * CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis up
	local d = math.max(fill * 2, 0.1)
	fx.disc.Size = Vector3.new(RING_THICKNESS, d, d)
	fx.disc.CFrame = flat
	local o = outer * 2
	fx.outline.Size =
		Vector3.new(RING_THICKNESS * 0.5, o + RING_OUTLINE_WIDTH, o + RING_OUTLINE_WIDTH)
	fx.outline.CFrame = flat * CFrame.new(RING_THICKNESS * 0.25, 0, 0)
end

local function stepRing(rec: Tracked, root: BasePart, now: number)
	local model = rec.model
	local active = rec.state == "Telegraph"
	local fx: RingFx? = rings[model]
	if active then
		local outer = math.max(root.Size.X, root.Size.Z) * RING_RADIUS_PER_SIZE
		fx = fx or ensureRing(model, outer)
		if not fx then
			return
		end
		fx.doneAt = nil
		local progress = Fx.telegraphProgress(fx.total, now - rec.stateSince)
		placeRing(fx, root, Fx.fillRadius(progress, outer), outer)
		fx.disc.Transparency = Fx.fillTransparency(progress, FILL_FROM, FILL_TO)
		fx.outline.Transparency = OUTLINE_TRANSPARENCY
	elseif fx then
		-- Attack lands: flash full, fade out. Anything else (Death/Hurt/Idle): drop at once.
		if rec.state == "Attack" then
			local landed = fx.doneAt or now
			fx.doneAt = landed
			local t = (now - landed) / ATTACK_FADE
			if t >= 1 then
				dropRing(model)
			else
				local outer = math.max(root.Size.X, root.Size.Z) * RING_RADIUS_PER_SIZE
				placeRing(fx, root, outer, outer)
				fx.disc.Transparency = FILL_TO + (1 - FILL_TO) * t
				fx.outline.Transparency = OUTLINE_TRANSPARENCY + (1 - OUTLINE_TRANSPARENCY) * t
			end
		else
			dropRing(model)
		end
	end
end

-- Wisps --------------------------------------------------------------------------------------------------

local function dropWisp(model: Model)
	local fx = wisps[model]
	if fx then
		if fx.emitter then
			fx.emitter:Destroy()
		end
		if fx.trail then
			fx.trail:Destroy()
		end
		if fx.light then
			fx.light:Destroy()
		end
		wisps[model] = nil
	end
end

local function ensureWisp(model: Model, root: BasePart): WispFx
	local existing: WispFx? = wisps[model]
	if existing then
		return existing
	end
	local orb = model:FindFirstChild("Orb")
	local host = if orb and orb:IsA("BasePart") then orb else root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = WISP_COLORS
	emitter.LightEmission = 1
	emitter.Rate = WISP_PARTICLE_RATE
	emitter.Lifetime = WISP_PARTICLE_LIFETIME
	emitter.Speed = WISP_PARTICLE_SPEED
	emitter.Size = WISP_PARTICLE_SIZE
	emitter.Transparency = WISP_PARTICLE_FADE
	emitter.Parent = host
	local trail: Trail? = nil
	local a0 = host:FindFirstChild("TrailA")
	local a1 = host:FindFirstChild("TrailB")
	if a0 and a1 and a0:IsA("Attachment") and a1:IsA("Attachment") then
		local t = Instance.new("Trail")
		t.Attachment0 = a0
		t.Attachment1 = a1
		t.Color = WISP_COLORS
		t.LightEmission = 1
		t.Lifetime = WISP_TRAIL_LIFETIME
		t.WidthScale = NumberSequence.new(WISP_TRAIL_WIDTH, 0)
		t.Transparency = NumberSequence.new(0.3, 1)
		t.Parent = host
		trail = t
	end
	local created: WispFx = { emitter = emitter, trail = trail, light = nil, orb = host }
	wisps[model] = created
	return created
end

local function setWispLight(fx: WispFx, on: boolean)
	if on and not fx.light and fx.orb then
		local light = Instance.new("PointLight")
		light.Color = LIGHT_COLOR
		light.Range = LIGHT_RANGE
		light.Brightness = LIGHT_BRIGHTNESS
		light.Shadows = false
		light.Parent = fx.orb
		fx.light = light
	elseif not on and fx.light then
		fx.light:Destroy()
		fx.light = nil
	end
end

-- Tracking -----------------------------------------------------------------------------------------------

local function untrack(model: Model)
	tracked[model] = nil
	dropFlock(model)
	dropRing(model)
	dropWisp(model)
end

local function track(inst: Instance)
	if not inst:IsA("Model") or tracked[inst] then
		return
	end
	nextId += 1
	tracked[inst] = {
		model = inst,
		id = nextId,
		kind = nil,
		root = nil,
		state = "Idle",
		stateSince = os.clock(),
		dist = math.huge,
	}
end

local function rootOf(model: Model): BasePart?
	local r = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function frame(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local now = os.clock()
	local camPos = camera.CFrame.Position
	local slow = now - lastSlow >= SLOW_STEP
	if slow then
		lastSlow = now
	end

	-- Distance / kind / state bookkeeping (cheap) and removal of dead entries.
	local cands: { Fx.Candidate } = {}
	local byId: { [number]: Model } = {}
	local crowPool: { Tracked } = {}
	for model, rec in tracked do
		if not model.Parent then
			untrack(model)
		else
			if rec.kind == nil then
				local k = model:GetAttribute(CFG.KindAttribute)
				if type(k) == "string" then
					rec.kind = k
				end
			end
			local root = rec.root
			if not root or not root.Parent then
				root = rootOf(model)
				rec.root = root
			end
			local state = model:GetAttribute(CFG.StateAttribute)
			if type(state) == "string" and state ~= rec.state then
				rec.state = state
				rec.stateSince = now
			end
			if root then
				rec.dist = (root.Position - camPos).Magnitude
			else
				rec.dist = math.huge
			end
			local kind = rec.kind
			if kind == KIND_CROW then
				if rec.dist <= CFG.AnimRadius and root then
					table.insert(crowPool, rec)
				else
					dropFlock(model)
				end
			elseif kind == KIND_BRUTE then
				if rec.dist <= math.min(RING_FX_RADIUS, CFG.AnimRadius) and root then
					stepRing(rec, root, now)
				else
					dropRing(model)
				end
			elseif kind == KIND_WISP then
				if rec.dist <= CFG.AnimRadius and root then
					local fx = ensureWisp(model, root)
					if fx.light then
						fx.light.Brightness = LIGHT_BRIGHTNESS
							* (1 + math.sin(now * 2.3 + rec.id) * LIGHT_PULSE)
					end
					table.insert(cands, { id = rec.id, dist = rec.dist })
					byId[rec.id] = model
				else
					dropWisp(model)
				end
			end
		end
	end

	-- Crows: only the nearest MAX_FLOCKS keep followers.
	table.sort(crowPool, function(a, b)
		return a.dist < b.dist
	end)
	for i, rec in crowPool do
		local root = rec.root
		if i <= MAX_FLOCKS and root then
			stepFlock(rec, root, now, dt)
		else
			dropFlock(rec.model)
		end
	end

	-- Wisps: light the nearest few, within radius (throttled).
	if slow then
		lightsOn = Fx.selectLights(
			cands,
			lightsOn,
			CFG.MaxWispLights,
			CFG.WispLightRadius,
			LIGHT_HYSTERESIS
		)
		for _, c in cands do
			local model = byId[c.id]
			local fx = model and wisps[model]
			if fx then
				setWispLight(fx, lightsOn[c.id] == true)
			end
		end
	end
end

-- Idempotent, non-yielding. Safe to call from MobsClient after launch.
function CreatureFx.start()
	if started then
		return
	end
	started = true
	for _, inst in CollectionService:GetTagged(CFG.Tag) do
		track(inst)
	end
	CollectionService:GetInstanceAddedSignal(CFG.Tag):Connect(track)
	CollectionService:GetInstanceRemovedSignal(CFG.Tag):Connect(function(inst: Instance)
		if inst:IsA("Model") then
			untrack(inst)
		end
	end)
	RunService.RenderStepped:Connect(frame)
end

return CreatureFx
