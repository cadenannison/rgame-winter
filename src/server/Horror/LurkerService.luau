--!strict
-- Lurkers: ambient watchers that never attack. Spawn odds are weighted by isolation and capped
-- (Lurkers.MaxDensity/MaxPerPlayer/MaxTotal). Tree watchers and ice scratchers vanish when approached or
-- faced; eyes back away from torchlight and close in on a player with no light. Ice scratchers mark thin
-- ice that cracks and costs warmth. Sightings raise Dread and send a LurkerSighted cue. The roll and the
-- density never leave the server. One Heartbeat loop for all lurkers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local DreadLogic = require(Shared.logic.DreadLogic)
local Lurkers = require(Shared.data.Lurkers)
local Biomes = require(Shared.data.Biomes)
local Types = require(Shared.data.Types)
local HorrorWorld = require(script.Parent.HorrorWorld)
local DreadService = require(script.Parent.DreadService)
local CueSender = require(script.Parent.CueSender)
local SurvivalService = require(script.Parent.Parent.Survival.SurvivalService)

local L = Config.Lurkers
local T = Lurkers.Tuning
local V = Lurkers.Visuals

type Lurker = {
	owner: Player,
	def: Types.LurkerDef,
	model: Model,
	x: number,
	y: number,
	z: number,
	expiresAt: number,
}

type Patch = {
	part: BasePart,
	x: number,
	z: number,
	warmthLoss: number,
	expiresAt: number,
	warned: { [Player]: boolean },
}

local LurkerService = {}

local lurkers: { [Model]: Lurker } = {}
local patches: { Patch } = {}
local connections: { RBXScriptConnection } = {}
local rng = Random.new()
local spawnAccumulator = 0
local started = false

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function countFor(player: Player): (number, number)
	local mine, total = 0, 0
	for _, l in lurkers do
		total += 1
		if l.owner == player then
			mine += 1
		end
	end
	return mine, total
end

local function remove(l: Lurker)
	lurkers[l.model] = nil
	l.model:Destroy()
end

local function makePatch(x: number, y: number, z: number, warmthLoss: number)
	local look = V.ThinIce
	local part = Instance.new("Part")
	part.Name = "ThinIce"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(look.thickness, T.ThinIcePatchRadius * 2, T.ThinIcePatchRadius * 2)
	part.CFrame = CFrame.new(x, y + look.thickness / 2, z) * CFrame.Angles(0, 0, math.pi / 2)
	part.Color = Color3.fromRGB(look.color[1], look.color[2], look.color[3])
	part.Transparency = look.transparency
	part.Material = Enum.Material.Glass
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = HorrorWorld.folder()
	local patch: Patch = {
		part = part,
		x = x,
		z = z,
		warmthLoss = warmthLoss,
		expiresAt = os.clock() + L.LifetimeSeconds,
		warned = {},
	}
	table.insert(patches, patch)
end

local function trySpawn(member: HorrorWorld.Member, weight: number, snap: HorrorWorld.Snapshot)
	local kind = Biomes.forRing(member.ring).lurkerKind
	local def = if kind then Lurkers.ByKind[kind] else nil
	local visual = if kind then V[kind] else nil
	if not def or not visual then
		return
	end
	local mine, total = countFor(member.player)
	if mine >= L.MaxPerPlayer or total >= L.MaxTotal then
		return
	end
	local density = DreadLogic.lurkerDensity(snap.day, member.ring, weight)
	if snap.fullGroup then
		density *= Config.Scares.GroupChanceMultiplier
	end
	if rng:NextNumber() >= density then
		return
	end
	-- Out of sight: somewhere behind the player, between the spawn distances.
	local root = member.root
	local back = flat(root.CFrame.LookVector)
	back = if back.Magnitude > 0 then -back.Unit else Vector3.xAxis
	local dir = CFrame.Angles(0, rng:NextNumber(-math.pi / 2, math.pi / 2), 0)
		:VectorToWorldSpace(back)
	local spot = root.Position + dir * rng:NextNumber(L.SpawnMinDistance, L.SpawnMaxDistance)
	if DreadLogic.isInside(spot.X, spot.Z, snap.warmZones, Config.FireRules.SpawnMargin) then
		return
	end
	local ground = HorrorWorld.groundAt(spot.X, spot.Z, root.Position.Y)
	if not ground then
		return
	end
	local model = HorrorWorld.makeModel(def.kind, visual, L.Tag, ground)
	model:SetAttribute(T.KindAttribute, def.kind)
	lurkers[model] = {
		owner = member.player,
		def = def,
		model = model,
		x = ground.X,
		y = ground.Y,
		z = ground.Z,
		expiresAt = os.clock() + L.LifetimeSeconds,
	}
	if def.behavior == "scratch" and def.thinIceWarmthLoss then
		local toward = flat(root.Position - ground)
		toward = if toward.Magnitude > 0 then toward.Unit else Vector3.xAxis
		local p = ground + toward * T.ThinIceOffset
		makePatch(p.X, ground.Y, p.Z, def.thinIceWarmthLoss)
	end
end

local function spawnTick()
	local snap = DreadService.snapshot()
	if snap.blizzard then
		return -- scare budget: nothing while players shelter from a blizzard
	end
	for i, m in snap.members do
		if not m.warm and not m.downed then
			trySpawn(m, snap.weights[i] or 0, snap)
		end
	end
end

local function sight(l: Lurker)
	DreadService.addSighting(l.owner, l.def.dreadOnSight)
	CueSender.send(l.owner, { kind = "LurkerSighted", position = Vector3.new(l.x, l.y, l.z) })
	remove(l)
end

local function moveLurker(l: Lurker, toward: Vector3, speed: number, dt: number, away: boolean)
	local d = flat(Vector3.new(l.x, 0, l.z) - flat(toward))
	if d.Magnitude <= 0 then
		return
	end
	local step = d.Unit * speed * dt * (if away then 1 else -1)
	l.x += step.X
	l.z += step.Z
end

local function updateLurker(l: Lurker, now: number, dt: number)
	local root = HorrorWorld.rootOf(l.owner)
	if not root or l.owner.Parent ~= Players or now >= l.expiresAt or not l.model.Parent then
		remove(l)
		return
	end
	-- Lurkers never enter a warm zone: one that drifts (or a fire placed) inside it melts away.
	if DreadLogic.isInside(l.x, l.z, DreadService.snapshot().warmZones, 0) then
		remove(l)
		return
	end
	local rp = root.Position
	local offset = flat(Vector3.new(l.x, rp.Y, l.z) - rp)
	local dist = offset.Magnitude
	if l.def.behavior == "eyes" then
		if HorrorWorld.lightOf(l.owner) ~= "none" then
			local keep = (l.def.torchRetreatRadius or 0) * T.EyesTorchRetreatMultiplier
			if dist < keep then
				moveLurker(l, rp, T.EyesRetreatSpeed, dt, true)
			end
		else
			moveLurker(l, rp, T.EyesCloseInSpeed, dt, false)
			if dist <= l.def.vanishDistance then
				sight(l) -- no light: they close in and Dread rises fast
				return
			end
		end
	else
		local look = flat(root.CFrame.LookVector)
		local facing = if look.Magnitude > 0 and dist > 0 then look.Unit:Dot(offset.Unit) else 0
		if dist <= l.def.vanishDistance or facing > L.LookDotThreshold then
			sight(l)
			return
		end
	end
	local half = l.model:GetExtentsSize().Y / 2
	local at = Vector3.new(l.x, l.y + half, l.z)
	local face = Vector3.new(rp.X, l.y + half, rp.Z)
	l.model:PivotTo(if (face - at).Magnitude > 0 then CFrame.lookAt(at, face) else CFrame.new(at))
end

local function updatePatches(now: number)
	if #patches == 0 then
		return
	end
	local party = HorrorWorld.party()
	for i = #patches, 1, -1 do
		local patch = patches[i]
		local cracked = false
		if now < patch.expiresAt and patch.part.Parent then
			for _, player in party do
				local root = HorrorWorld.rootOf(player)
				if root then
					local d =
						math.sqrt((root.Position.X - patch.x) ^ 2 + (root.Position.Z - patch.z) ^ 2)
					local pos = Vector3.new(patch.x, root.Position.Y, patch.z)
					if d <= T.ThinIcePatchRadius then
						SurvivalService.warm(player, -patch.warmthLoss)
						CueSender.send(player, { kind = "IceCrack", position = pos })
						cracked = true
						break
					elseif d <= T.ThinIceWarnRadius and not patch.warned[player] then
						patch.warned[player] = true
						CueSender.send(player, { kind = "IceCrack", position = pos })
					end
				end
			end
		else
			cracked = true
		end
		if cracked then
			patch.part:Destroy()
			table.remove(patches, i)
		end
	end
end

function LurkerService.start()
	if started then
		return
	end
	started = true
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt: number)
			spawnAccumulator += dt
			if spawnAccumulator >= L.SpawnIntervalSeconds then
				spawnAccumulator = 0
				spawnTick()
			end
			local now = os.clock()
			for _, l in lurkers do
				updateLurker(l, now, dt)
			end
			updatePatches(now)
		end)
	)
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player: Player)
			for _, l in lurkers do
				if l.owner == player then
					remove(l)
				end
			end
			for _, patch in patches do
				patch.warned[player] = nil
			end
		end)
	)
end

function LurkerService.stop()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	for _, l in lurkers do
		l.model:Destroy()
	end
	table.clear(lurkers)
	for _, patch in patches do
		patch.part:Destroy()
	end
	table.clear(patches)
	started = false
	spawnAccumulator = 0
end

return LurkerService
