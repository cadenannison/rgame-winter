--!strict
-- The Stalker: one unkillable pressure creature per run. Hunts roll from hidden Dread, pick a target by
-- isolation, telegraph through sensory cues only (StalkerTell, Footsteps, FireGutter), strike once with a
-- server-enforced health floor, then retreat. It never enters fire or warm spots and backs off from
-- torches and flares. One Heartbeat loop. Hunt chance and timers never leave the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local DreadLogic = require(Shared.logic.DreadLogic)
local Isolation = require(Shared.logic.Isolation)
local Lurkers = require(Shared.data.Lurkers)
local HorrorWorld = require(script.Parent.HorrorWorld)
local DreadService = require(script.Parent.DreadService)
local CueSender = require(script.Parent.CueSender)
local SurvivalService = require(script.Parent.Parent.Survival.SurvivalService)

local S = Config.Stalker
local CAUSE = S.Tag -- downed-cause label ("Stalker")

local StalkerService = {}

type Active = {
	hunt: DreadLogic.Hunt,
	target: Player,
	model: Model,
	x: number,
	y: number,
	z: number,
	lastPhase: DreadLogic.Phase,
}

local active: Active? = nil
local cooldownUntil = 0
local checkAccumulator = 0
local rng = Random.new()
local strikeCallbacks: { (Player) -> () } = {}
local connections: { RBXScriptConnection } = {}
local started = false

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Fires, warm spots and every party light (torch/flare radius) the Stalker must stay out of.
local function repellers(snap: HorrorWorld.Snapshot): { DreadLogic.Repeller }
	local out = table.clone(snap.warmZones)
	for _, m in snap.members do
		local light = HorrorWorld.lightOf(m.player)
		if light ~= "none" then
			local root = HorrorWorld.rootOf(m.player)
			if root then
				local radius = if light == "flare" then S.FlareRepelRadius else S.TorchRepelRadius
				-- Margin is added by DreadLogic; subtract it so the light radius is exact.
				table.insert(out, {
					x = root.Position.X,
					z = root.Position.Z,
					radius = math.max(radius - S.FireRepelMargin, 0),
				})
			end
		end
	end
	return out
end

local function endHunt()
	local a = active
	if not a then
		return
	end
	active = nil
	a.model:Destroy()
	cooldownUntil = os.clock() + S.HuntCooldownSeconds
end

local function sendTells(target: Player, root: BasePart, snap: HorrorWorld.Snapshot)
	CueSender.send(target, { kind = "StalkerTell", level = Config.Cue.MaxLevel })
	local behind = root.Position - flat(root.CFrame.LookVector).Unit * S.StrikeRange
	CueSender.send(target, { kind = "Footsteps", position = behind })
	-- The fire nearest the target gutters for the whole party (visible warning at camp too).
	local best: DreadLogic.Repeller? = nil
	local bestD2 = math.huge
	for _, f in HorrorWorld.fires() do
		local d2 = (f.x - root.Position.X) ^ 2 + (f.z - root.Position.Z) ^ 2
		if d2 < bestD2 then
			best, bestD2 = f, d2
		end
	end
	if best then
		local pos = Vector3.new(best.x, root.Position.Y, best.z)
		for _, m in snap.members do
			CueSender.send(m.player, { kind = "FireGutter", position = pos })
		end
	end
end

local function tryStart(force: boolean)
	if active then
		return
	end
	local snap = DreadService.snapshot()
	local candidates: { HorrorWorld.Member } = {}
	local weights: { number } = {}
	for i, m in snap.members do
		if not m.warm and not m.downed then
			table.insert(candidates, m)
			table.insert(weights, snap.weights[i] or 0)
		end
	end
	if not force then
		local ok = DreadLogic.canHunt({
			day = snap.day,
			now = os.clock(),
			cooldownUntil = cooldownUntil,
			hunting = false,
			fullGroup = snap.fullGroup,
			candidates = #candidates,
		})
		if not ok then
			return
		end
		local chance =
			DreadLogic.huntChance(DreadService.value(), snap.day, snap.modifiers.huntBonus)
		if rng:NextNumber() >= chance then
			return
		end
	elseif #candidates == 0 then
		return
	end
	local index = if force
		then Isolation.mostIsolated(weights)
		else Isolation.pick(weights, rng:NextNumber())
	local member = if index then candidates[index] else nil
	if not member then
		return
	end
	local root = HorrorWorld.rootOf(member.player)
	if not root then
		return
	end
	-- Start out of sight behind the target, clamped outside every warm zone and light.
	local back = flat(root.CFrame.LookVector)
	back = if back.Magnitude > 0 then -back.Unit else Vector3.xAxis
	local spawn = root.Position + back * S.ApproachDistance
	local x, z, clear =
		DreadLogic.clampOutside(spawn.X, spawn.Z, repellers(snap), S.FireRepelMargin)
	if not clear then
		return
	end
	local ground = HorrorWorld.groundAt(x, z, root.Position.Y)
	local y = if ground then ground.Y else root.Position.Y
	local model = HorrorWorld.makeModel(S.Tag, Lurkers.Visuals.Stalker, S.Tag, Vector3.new(x, y, z))
	active = {
		hunt = DreadLogic.newHunt(),
		target = member.player,
		model = model,
		x = x,
		y = y,
		z = z,
		lastPhase = "Telegraph",
	}
	sendTells(member.player, root, snap)
end

local function knockback(target: Player, root: BasePart, from: Vector3)
	local dir = flat(root.Position - from)
	dir = if dir.Magnitude > 0 then dir.Unit else Vector3.xAxis
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { HorrorWorld.folder() }
	if target.Character then
		table.insert(exclude, target.Character)
	end
	params.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(root.Position, dir * S.KnockbackStuds, params)
	local distance = if hit then math.max(hit.Distance - root.Size.X, 0) else S.KnockbackStuds
	local character = target.Character
	if character and distance > 0 then
		character:PivotTo(character:GetPivot() + dir * distance)
	end
end

local function strike(a: Active, root: BasePart)
	local meters = SurvivalService.getMeters(a.target)
	if not meters or meters.downed or meters.dead then
		return
	end
	-- Server floor: from full health a strike can never reach 0.
	local damage = DreadLogic.strikeDamage(meters.health, Config.Meters.MaxHealth)
	SurvivalService.markHit(a.target, CAUSE)
	SurvivalService.damage(a.target, damage, CAUSE)
	SurvivalService.warm(a.target, -S.WarmthLoss)
	knockback(a.target, root, Vector3.new(a.x, a.y, a.z))
	for _, cb in strikeCallbacks do
		task.spawn(function()
			local ok = pcall(cb, a.target)
			if not ok then
				warn("[StalkerService] strike callback failed")
			end
		end)
	end
end

local function goalFor(a: Active, target: Vector3): (number, number, number)
	local dx, dz = a.x - target.X, a.z - target.Z
	local d = math.sqrt(dx * dx + dz * dz)
	if d <= 0 then
		dx, dz, d = 1, 0, 1
	end
	if a.hunt.phase == "Chase" then
		return target.X, target.Z, S.ChaseSpeed
	elseif a.hunt.phase == "Retreat" then
		-- Walk directly away, well past the approach distance.
		local far = S.ApproachDistance * 2
		return a.x + dx / d * far, a.z + dz / d * far, S.ChaseSpeed
	end
	-- Telegraph: lurk at the approach distance.
	return target.X + dx / d * S.ApproachDistance,
		target.Z + dz / d * S.ApproachDistance,
		S.WalkSpeed
end

local function stepActive(dt: number)
	local a = active
	if not a then
		return
	end
	local root = HorrorWorld.rootOf(a.target)
	if not root or a.target.Parent ~= Players or not a.model.Parent then
		endHunt()
		return
	end
	local snap = DreadService.snapshot()
	local reps = repellers(snap)
	local tp = root.Position
	local light: DreadLogic.Light = HorrorWorld.lightOf(a.target)
	local safe = SurvivalService.isDowned(a.target)
		or DreadLogic.isInside(tp.X, tp.Z, snap.warmZones, 0)
	local distance = math.sqrt((a.x - tp.X) ^ 2 + (a.z - tp.Z) ^ 2)
	local inputs: DreadLogic.HuntInputs = { distance = distance, light = light, targetSafe = safe }
	local out = DreadLogic.stepHunt(a.hunt, inputs, dt)
	-- Server gate: it never strikes from, or at a target standing in, a warm zone.
	local inWarm = DreadLogic.isInside(a.x, a.z, snap.warmZones, 0)
		or DreadLogic.isInside(tp.X, tp.Z, snap.warmZones, 0)
	if out.strike and not inWarm then
		strike(a, root)
	end
	if out.retreatStarted then
		-- Position present = it struck (client plays the strike sound there); absent = it gave up.
		CueSender.send(a.target, {
			kind = "StalkerRetreat",
			position = if out.strike and not inWarm then Vector3.new(a.x, a.y, a.z) else nil,
		})
	elseif a.lastPhase == "Telegraph" and a.hunt.phase == "Chase" then
		CueSender.send(a.target, {
			kind = "Footsteps",
			position = tp - flat(root.CFrame.LookVector).Unit * S.StrikeRange,
		})
	end
	a.lastPhase = a.hunt.phase
	if out.done then
		endHunt()
		return
	end
	local gx, gz, speed = goalFor(a, tp)
	local nx, nz, clear =
		DreadLogic.moveToward(a.x, a.z, gx, gz, speed, dt, reps, S.FireRepelMargin)
	if not clear then
		-- A fire or light appeared on top of it: it melts away rather than stand in warmth.
		CueSender.send(a.target, { kind = "StalkerRetreat" })
		endHunt()
		return
	end
	local ground = HorrorWorld.groundAt(nx, nz, a.y)
	a.x, a.z = nx, nz
	if ground then
		a.y = ground.Y
	end
	local half = Lurkers.Visuals.Stalker.size[2] / 2
	local at = Vector3.new(a.x, a.y + half, a.z)
	local look = Vector3.new(tp.X, a.y + half, tp.Z)
	a.model:PivotTo(if (look - at).Magnitude > 0 then CFrame.lookAt(at, look) else CFrame.new(at))
end

-- Server only. Never replicate.
function StalkerService.isHunting(): boolean
	return active ~= nil
end

-- Server only, read-only. World position of the active hunter (nil when no hunt); crows scatter toward it.
function StalkerService.getHuntPosition(): Vector3?
	local a = active
	return if a then Vector3.new(a.x, a.y, a.z) else nil
end

-- Called once per strike with the struck player. Returns a disconnect function.
function StalkerService.onStrike(cb: (Player) -> ()): () -> ()
	table.insert(strikeCallbacks, cb)
	return function()
		local i = table.find(strikeCallbacks, cb)
		if i then
			table.remove(strikeCallbacks, i)
		end
	end
end

-- Debug/QA: start a hunt now on the most isolated player outside warmth (ignores day, cooldown, roll).
function StalkerService.forceHunt()
	tryStart(true)
end

function StalkerService.start()
	if started then
		return
	end
	started = true
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt: number)
			if active then
				stepActive(dt)
			else
				checkAccumulator += dt
				if checkAccumulator >= S.HuntCheckIntervalSeconds then
					checkAccumulator = 0
					tryStart(false)
				end
			end
		end)
	)
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player: Player)
			local a = active
			if a and a.target == player then
				endHunt()
			end
		end)
	)
	local debugAttr = Config.Debug.WorldStalkerAttribute
	table.insert(
		connections,
		Workspace:GetAttributeChangedSignal(debugAttr):Connect(function()
			if Workspace:GetAttribute(debugAttr) then
				StalkerService.forceHunt()
			end
		end)
	)
end

function StalkerService.stop()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	endHunt()
	started = false
	checkAccumulator = 0
	cooldownUntil = 0
end

return StalkerService
