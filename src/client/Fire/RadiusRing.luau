--!strict
-- Soft dotted ground rings at each lit campfire's warm radius (and, while a build-limited placeable is
-- selected, the build radius). Visual only, local to this client. Radii come from the fire's Attributes
-- (WarmRadius / BuildRadius), so an upgrade redraws it with no remote. Dots are small flat parts that
-- follow the terrain (raycast, cached), fade with distance from the player, and are capped for mobile.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local FireTiers = require(Shared:WaitForChild("logic"):WaitForChild("FireTiers"))

local F = Config.Fire
local R = F.Ring
local TWO_PI = math.pi * 2

type Layer = {
	dots: { Part },
	ys: { [number]: number },
	radius: number, -- radius the dots were laid out for
	count: number,
}
type Ring = {
	fire: Instance,
	warm: Layer,
	build: Layer,
	conns: { RBXScriptConnection },
}

export type Options = {
	isPlacing: () -> boolean, -- a build-limited placeable is selected
	onUpgraded: (fire: Instance, tier: number) -> (), -- a fire's Tier attribute rose
}

local RadiusRing = {}

local function color(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function pivot(i: Instance): Vector3?
	if i:IsA("BasePart") then
		return i.Position
	elseif i:IsA("Model") then
		return i:GetPivot().Position
	end
	return nil
end

local function newLayer(): Layer
	return { dots = {}, ys = {}, radius = 0, count = 0 }
end

-- Returns a cleanup function.
function RadiusRing.start(opts: Options): () -> ()
	local rings: { [Instance]: Ring } = {}
	local conns: { RBXScriptConnection } = {}
	local folder = Instance.new("Folder")
	folder.Name = R.FolderName
	local warmDay, warmNight = color(R.WarmColorDay), color(R.WarmColorNight)
	local buildDay, buildNight = color(R.BuildColorDay), color(R.BuildColorNight)
	local lastNight: boolean? = nil
	local allocAccum, stepAccum = R.AllocateInterval, 0.0
	local destroyed = false

	local function setCount(layer: Layer, count: number)
		while #layer.dots > count do
			local dot = table.remove(layer.dots) :: Part
			dot:Destroy()
		end
		while #layer.dots < count do
			local dot = Instance.new("Part")
			dot.Name = "Dot"
			dot.Shape = Enum.PartType.Cylinder
			dot.Size = Vector3.new(R.DotThickness, R.DotDiameter, R.DotDiameter)
			dot.Anchored = true
			dot.CanCollide = false
			dot.CanQuery = false
			dot.CanTouch = false
			dot.CastShadow = false
			dot.Transparency = 1
			dot.Parent = folder
			table.insert(layer.dots, dot)
		end
		if layer.count ~= count then
			table.clear(layer.ys)
		end
		layer.count = count
	end

	local function destroyRing(fire: Instance)
		local ring = rings[fire]
		if not ring then
			return
		end
		rings[fire] = nil
		for _, c in ring.conns do
			c:Disconnect()
		end
		setCount(ring.warm, 0)
		setCount(ring.build, 0)
	end

	local function track(fire: Instance)
		if rings[fire] or destroyed then
			return
		end
		local ring: Ring = { fire = fire, warm = newLayer(), build = newLayer(), conns = {} }
		rings[fire] = ring
		table.insert(
			ring.conns,
			fire.Destroying:Connect(function()
				destroyRing(fire)
			end)
		)
		local lastTier = fire:GetAttribute(F.TierAttribute)
		table.insert(
			ring.conns,
			fire:GetAttributeChangedSignal(F.TierAttribute):Connect(function()
				local tier = fire:GetAttribute(F.TierAttribute)
				if type(tier) == "number" and type(lastTier) == "number" and tier > lastTier then
					opts.onUpgraded(fire, tier)
				end
				lastTier = tier
			end)
		)
	end

	table.insert(conns, CollectionService:GetInstanceAddedSignal(F.Tag):Connect(track))
	table.insert(conns, CollectionService:GetInstanceRemovedSignal(F.Tag):Connect(destroyRing))
	for _, fire in CollectionService:GetTagged(F.Tag) do
		track(fire)
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	local raysLeft = 0

	local function groundY(x: number, z: number, nearY: number): number?
		if raysLeft <= 0 then
			return nil
		end
		raysLeft -= 1
		local hit = Workspace:Raycast(
			Vector3.new(x, nearY + R.RayHeight, z),
			Vector3.new(0, -R.RayLength, 0),
			rayParams
		)
		if hit and not CollectionService:HasTag(hit.Instance, Config.Gather.NodeTag) then
			return hit.Position.Y
		end
		return nil
	end

	-- Decide how many dots each layer gets: nearest fires first, within the global cap.
	local function allocate(rootPos: Vector3, placing: boolean)
		local chunks = Workspace:FindFirstChild(Config.World.ChunkFolderName)
		rayParams.FilterDescendantsInstances = if chunks then { chunks, Workspace.Terrain } else {}
		local order: { Ring } = {}
		for _, ring in rings do
			table.insert(order, ring)
		end
		local function dist(ring: Ring): number
			local p = pivot(ring.fire)
			return if p then (p - rootPos).Magnitude else math.huge
		end
		table.sort(order, function(a: Ring, b: Ring): boolean
			return dist(a) < dist(b)
		end)
		local budget = R.MaxDotsTotal
		for _, ring in order do
			local fire = ring.fire
			local lit = fire:GetAttribute(F.LitAttribute) == true
			local function size(layer: Layer, attr: string, wanted: boolean)
				local radius = fire:GetAttribute(attr)
				local n = 0
				if wanted and lit and type(radius) == "number" and radius > 0 then
					n = FireTiers.ringDotCount(radius, R.Spacing, R.MinDots, R.MaxDotsPerLayer)
					n = math.min(n, budget)
					if n < R.MinDots then
						n = 0
					end
					if layer.radius ~= radius then
						table.clear(layer.ys)
						layer.radius = radius
					end
				end
				budget -= n
				setCount(layer, n)
			end
			size(ring.warm, F.WarmRadiusAttribute, true)
			size(ring.build, F.BuildRadiusAttribute, placing)
		end
	end

	local function paint(
		ring: Ring,
		layer: Layer,
		rootPos: Vector3,
		base: number,
		night: boolean,
		tint: Color3
	)
		local center = pivot(ring.fire)
		if not center or layer.count == 0 then
			return
		end
		local radius = layer.radius
		for i, dot in layer.dots do
			local angle = (i - 1) / layer.count * TWO_PI
			local x, z = center.X + math.cos(angle) * radius, center.Z + math.sin(angle) * radius
			local y: number? = layer.ys[i]
			if y == nil then
				y = groundY(x, z, center.Y)
				if y then
					layer.ys[i] = y
				end
			end
			if y then
				dot.CFrame = CFrame.new(x, y + R.GroundLift, z) * CFrame.Angles(0, 0, math.pi / 2)
				local dx, dz = x - rootPos.X, z - rootPos.Z
				local d = math.sqrt(dx * dx + dz * dz)
				local fade = math.clamp((d - R.FadeStart) / (R.FadeEnd - R.FadeStart), 0, 1)
				dot.Transparency = base + (1 - base) * fade
				dot.Color = tint
				dot.Material = if night then Enum.Material.Neon else Enum.Material.SmoothPlastic
			else
				dot.Transparency = 1 -- ground not loaded yet; retried next step
			end
		end
	end

	local function step(dt: number)
		stepAccum += dt
		if stepAccum < R.UpdateInterval then
			return
		end
		stepAccum = 0
		allocAccum += R.UpdateInterval
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		local rootPos = root.Position
		local placing = opts.isPlacing()
		local night = Workspace:GetAttribute(Config.Time.IsNightAttribute) == true
		if allocAccum >= R.AllocateInterval or night ~= lastNight then
			allocAccum = 0
			lastNight = night
			allocate(rootPos, placing)
		end
		raysLeft = R.RaysPerStep
		local warmBase = if night then R.WarmTransparencyNight else R.WarmTransparencyDay
		local buildBase = if night then R.BuildTransparencyNight else R.BuildTransparencyDay
		for _, ring in rings do
			paint(ring, ring.warm, rootPos, warmBase, night, if night then warmNight else warmDay)
			-- The build layer only has dots while placing (allocate runs on selection change below).
			paint(
				ring,
				ring.build,
				rootPos,
				buildBase,
				night,
				if night then buildNight else buildDay
			)
		end
	end

	local lastPlacing = false
	table.insert(
		conns,
		RunService.RenderStepped:Connect(function(dt: number)
			local placing = opts.isPlacing()
			if placing ~= lastPlacing then
				lastPlacing = placing
				allocAccum = R.AllocateInterval -- reallocate next step
			end
			step(dt)
		end)
	)

	folder.Parent = Workspace

	return function()
		destroyed = true
		for _, c in conns do
			c:Disconnect()
		end
		table.clear(conns)
		for fire in table.clone(rings) do
			destroyRing(fire)
		end
		folder:Destroy()
	end
end

return RadiusRing
