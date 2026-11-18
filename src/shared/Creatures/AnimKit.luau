--!strict
-- AnimKit: procedural creature animation (Art Pass 3). Drives Motor6D.Transform on joints "J_<part>"
-- (rest = identity) from the replicated State attribute. No asset ids, no per-frame allocation.
-- Pose math (AnimKit.solve and helpers) is pure and unit-tested; AnimKit.bind is the thin Roblox adapter.
--
-- Conventions (Defs must follow): creature faces -Z, up is +Y. Positive rx raises the front (nose up) for
-- body/head/tail and swings a hanging leg forward; positive rz rolls toward +X. Joint pivots (C1) are at the
-- hinge (hip, neck, shoulder). rig.legs order: Quad = FL, BR, FR, BL (diagonal pairs), other gaits alternate
-- odd/even (odd = left, -X). rig.wings: odd = +X side, even = -X side; wings rest FOLDED and positive angle
-- opens them (rz is sign-flipped per side by AnimKit). Slither/Fish: rig.legs are body segments front to back.
-- Sound hook points (silent; no ids): footstep on phase zero-crossings, growl on Alert/Telegraph, attack at
-- Attack start, hurt on hurt(), death at Death start.
local Config = require("../Config")
local Types = require("./Types")

local CFG = Config.Creatures

local TUNING = {
	AttackSeconds = 0.45, -- length of the attack envelope after State becomes Attack
	DeathFallSeconds = 0.7, -- fall/collapse time before the fade starts
	DefaultTelegraph = 0.7, -- wind-up length assumed when TelegraphLeft is missing
	SmoothRate = 26, -- exp smoothing of every channel (1/s)
	GaitBlendRate = 8, -- how fast gait weight follows the state (1/s)
	SpeedSmoothRate = 10, -- speed estimate smoothing (1/s)
	SpeedToPhase = 0.7, -- gait radians advanced per stud of speed
	MinWalkRate = 5, -- rad/s floor while State is Walk
	MinRunRate = 8, -- rad/s floor while State is Run
	MaxPhaseRate = 26, -- rad/s cap
	IdleSwimRate = 3, -- rad/s for always-moving gaits (Slither/Float)
	SwimFloor = 0.3, -- gait weight floor for Slither/Float
	MaxSpeed = 60, -- studs/s clamp on the measured speed
	MaxGap = 0.5, -- seconds: a longer pause between steps resets speed measurement
	MaxDt = 0.1,
	RefreshSteps = 30, -- steps between joint lookups for parts that are missing (streaming)
	FlapRate = 26, -- rad/s wing flap when a Bird flushes
	FlockFlapWalk = 14,
	FlockFlapRun = 22,
	FadeEpsilon = 0.01,
}

export type Ch = { px: number, py: number, pz: number, rx: number, ry: number, rz: number }
export type Pose = { body: Ch, head: Ch, tail: Ch, legs: { Ch }, wings: { Ch } }
export type Spec = {
	gait: string,
	stride: number,
	runScale: number,
	bob: number,
	idleSway: number,
	telegraphPose: string?,
	attackPose: string?,
	unit: number, -- studs: hitbox height, scales translations
	legCount: number,
	wingCount: number,
}
export type Input = {
	state: string,
	t: number,
	phase: number,
	gaitW: number, -- 0..1 gait amplitude weight
	runW: number, -- 0..1 walk->run blend
	stateTime: number,
	telegraphTotal: number,
	hurtAge: number,
	hurtSeconds: number,
}

local AnimKit = {}
AnimKit.Tuning = TUNING

local PI = math.pi

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

local function smoothstep(x: number): number
	local c = clamp01(x)
	return c * c * (3 - 2 * c)
end

local function newCh(): Ch
	return { px = 0, py = 0, pz = 0, rx = 0, ry = 0, rz = 0 }
end

local function zeroCh(c: Ch)
	c.px, c.py, c.pz, c.rx, c.ry, c.rz = 0, 0, 0, 0, 0, 0
end

function AnimKit.newPose(legCount: number, wingCount: number): Pose
	local pose: Pose = { body = newCh(), head = newCh(), tail = newCh(), legs = {}, wings = {} }
	for i = 1, legCount do
		pose.legs[i] = newCh()
	end
	for i = 1, wingCount do
		pose.wings[i] = newCh()
	end
	return pose
end

function AnimKit.clear(pose: Pose)
	zeroCh(pose.body)
	zeroCh(pose.head)
	zeroCh(pose.tail)
	for _, c in pose.legs do
		zeroCh(c)
	end
	for _, c in pose.wings do
		zeroCh(c)
	end
end

function AnimKit.smoothAlpha(dt: number): number
	return 1 - math.exp(-TUNING.SmoothRate * dt)
end

function AnimKit.smooth(cur: Ch, target: Ch, a: number)
	cur.px += (target.px - cur.px) * a
	cur.py += (target.py - cur.py) * a
	cur.pz += (target.pz - cur.pz) * a
	cur.rx += (target.rx - cur.rx) * a
	cur.ry += (target.ry - cur.ry) * a
	cur.rz += (target.rz - cur.rz) * a
end

-- Gait weight target for a state: returns (gaitW, runW).
function AnimKit.gaitTarget(gait: string, state: string): (number, number)
	if state == "Walk" then
		return 1, 0
	elseif state == "Run" then
		return 1, 1
	elseif state == "Death" then
		return 0, 0
	end
	if gait == "Slither" or gait == "Float" then
		return TUNING.SwimFloor, 0
	end
	return 0, 0
end

-- Gait phase speed in rad/s.
function AnimKit.phaseRate(gait: string, state: string, speed: number): number
	if state == "Walk" then
		return math.clamp(speed * TUNING.SpeedToPhase, TUNING.MinWalkRate, TUNING.MaxPhaseRate)
	elseif state == "Run" then
		return math.clamp(speed * TUNING.SpeedToPhase, TUNING.MinRunRate, TUNING.MaxPhaseRate)
	elseif state ~= "Death" and (gait == "Slither" or gait == "Float") then
		return TUNING.IdleSwimRate
	end
	return 0
end

-- Fraction (0..1) of the telegraph wind-up elapsed.
function AnimKit.telegraphProgress(stateTime: number, total: number): number
	local tot = if total > 0 then total else TUNING.DefaultTelegraph
	return clamp01(stateTime / tot)
end

-- 0..1 fade amount after the fall finished.
function AnimKit.deathFade(stateTime: number): number
	return clamp01((stateTime - TUNING.DeathFallSeconds) / math.max(CFG.DeathFadeSeconds, 0.01))
end

local function isFront(gait: string, i: number, n: number): boolean
	if gait == "Quad" and n >= 4 then
		return i % 2 == 1
	end
	if n <= 2 then
		return true
	end
	return i <= (n + 1) // 2
end

-- -1 = left (-X), +1 = right.
local function legSide(gait: string, i: number, n: number): number
	if gait == "Quad" and n >= 4 then
		return if i == 1 or i == 4 then -1 else 1
	end
	return if i % 2 == 1 then -1 else 1
end

local function wingSign(i: number): number
	return if i % 2 == 1 then 1 else -1
end

local function idleLayer(spec: Spec, inp: Input, pose: Pose)
	local t = inp.t
	local a = spec.idleSway
	local k = 1 - inp.gaitW * 0.8
	local body, head, tail = pose.body, pose.head, pose.tail
	body.py += math.sin(t * 1.7) * spec.unit * 0.012 * k
	body.rx += math.sin(t * 1.1) * a * k
	body.rz += math.sin(t * 0.8 + 1) * a * 0.5 * k
	head.rx += math.sin(t * 0.7 + 2) * a * 0.8 * k
	head.ry += math.sin(t * 0.45) * a * 0.8 * k
	tail.ry += math.sin(t * 1.3) * a * 1.2 * k
	for i = 1, spec.wingCount do
		pose.wings[i].rz += wingSign(i) * math.sin(t * 1.2 + i) * a * 0.5 * k
	end
	if spec.gait == "Float" then
		body.py += math.sin(t * 1.7) * math.max(spec.bob, spec.unit * 0.05)
	end
end

local function gaitLayer(spec: Spec, inp: Input, pose: Pose)
	local w = inp.gaitW
	if w <= 0.001 then
		return
	end
	local gait = spec.gait
	local runW = inp.runW
	local s = spec.stride * (1 + (spec.runScale - 1) * runW) * w
	local ph = inp.phase
	local t = inp.t
	local bobAmt = spec.bob * (1 + 0.5 * runW) * w
	local body, head, tail = pose.body, pose.head, pose.tail
	local n = spec.legCount
	if gait == "Quad" or gait == "Biped" then
		for i = 1, n do
			local off = if gait == "Quad"
				then (if i <= 2 then 0 else PI)
				else (if i % 2 == 1 then 0 else PI)
			pose.legs[i].rx += math.sin(ph + off) * s
		end
		body.py += bobAmt * math.abs(math.sin(ph))
		body.rx += math.sin(2 * ph + 1.57) * 0.05 * w * (1 + runW)
		head.rx -= math.sin(2 * ph + 1.57) * 0.03 * w
		tail.ry += math.sin(ph) * 0.25 * w
		if gait == "Biped" then
			body.rz += math.sin(ph) * 0.06 * w
			body.ry += math.sin(ph) * 0.06 * w
			head.ry -= math.sin(ph) * 0.06 * w
		end
	elseif gait == "Bird" then
		for i = 1, n do
			pose.legs[i].rx += math.sin(ph + (if i % 2 == 1 then 0 else PI)) * s
		end
		body.py += bobAmt * math.abs(math.sin(ph))
		head.rx += math.sin(2 * ph) * 0.22 * w * (1 - runW)
		body.rx -= 0.12 * runW * w
		local flap = math.sin(t * TUNING.FlapRate)
		for i = 1, spec.wingCount do
			pose.wings[i].rz += wingSign(i) * (0.5 + 0.8 * flap) * runW * w
		end
		body.py += runW * w * bobAmt * (0.5 + 0.5 * flap)
	elseif gait == "Flock" then
		local hz = TUNING.FlockFlapWalk + (TUNING.FlockFlapRun - TUNING.FlockFlapWalk) * runW
		local flap = math.sin(t * hz)
		for i = 1, spec.wingCount do
			pose.wings[i].rz += wingSign(i) * (1.0 + 0.6 * flap) * w
		end
		for i = 1, n do
			pose.legs[i].rx += 0.9 * w
		end
		body.py += bobAmt * flap * 0.5
		body.rx += 0.08 * flap * w
		body.rz += math.sin(t * 0.9) * 0.15 * w
	elseif gait == "Seal" then
		local hump = math.sin(ph)
		body.py += bobAmt * (0.5 + 0.5 * hump)
		body.rx += 0.12 * hump * w
		head.rx -= 0.15 * hump * w
		for i = 1, n do
			pose.legs[i].ry += math.sin(ph + (if i % 2 == 1 then 0 else PI)) * s * 0.7
		end
		tail.ry += math.sin(ph) * 0.35 * w
	elseif gait == "Slither" then
		for i = 1, n do
			pose.legs[i].ry += math.sin(ph - 0.9 * i) * s
		end
		tail.ry += math.sin(ph - 0.9 * (n + 1)) * s * 1.3
		body.ry += math.sin(ph) * s * 0.5
		head.ry -= math.sin(ph) * s * 0.3
	elseif gait == "Float" then
		body.rx -= 0.25 * w
		for i = 1, n do
			pose.legs[i].rx += math.sin(t * 2.5 + i) * 0.4 * w
		end
		for i = 1, spec.wingCount do
			pose.wings[i].rz += wingSign(i) * math.sin(t * 3 + i) * 0.35 * (0.4 + w)
		end
		tail.ry += math.sin(t * 2.2) * 0.35
	end
end

local function alertLayer(_spec: Spec, inp: Input, pose: Pose)
	local w = smoothstep(inp.stateTime / 0.25)
	pose.head.rx += 0.45 * w
	pose.head.ry += math.sin(inp.t * 1.2) * 0.3 * w
	pose.body.rx += 0.1 * w
	pose.tail.rx += 0.3 * w
end

local function telegraphLayer(spec: Spec, inp: Input, pose: Pose)
	local p = AnimKit.telegraphProgress(inp.stateTime, inp.telegraphTotal)
	local e = smoothstep(p)
	local unit, gait, n = spec.unit, spec.gait, spec.legCount
	local body, head, tail = pose.body, pose.head, pose.tail
	local name = spec.telegraphPose or "Crouch"
	local tremble = math.sin(inp.t * 45) * 0.03 * e
	if name == "Rear" then
		body.rx += 0.85 * e
		body.py += unit * 0.12 * e
		head.rx += 0.2 * e
		tail.rx -= 0.2 * e
		for i = 1, n do
			local front = isFront(gait, i, n)
			pose.legs[i].rx += (if front then 1.1 else -0.3) * e
			if gait == "Seal" then
				pose.legs[i].rz += legSide(gait, i, n) * 0.9 * e
			end
		end
		body.rz += tremble
	elseif name == "Slam" then
		body.rx += 0.35 * e
		body.py += unit * 0.08 * e
		head.rx += 0.3 * e
		for i = 1, n do
			if isFront(gait, i, n) then
				pose.legs[i].rx += 1.6 * e
			end
		end
		for i = 1, spec.wingCount do
			pose.wings[i].rz += wingSign(i) * 0.9 * e
		end
	elseif name == "Spread" then
		for i = 1, spec.wingCount do
			pose.wings[i].rz += wingSign(i) * (1.3 * e + math.sin(inp.t * 30) * 0.1 * e)
		end
		body.rx += 0.2 * e
		head.rx += 0.25 * e
		body.py += unit * 0.05 * e
	elseif name == "Raise" then
		head.rx += 0.5 * e
		body.rx += 0.2 * e
		for i = 1, n do
			if isFront(gait, i, n) then
				pose.legs[i].rx += 1.3 * e
			end
		end
		for i = 1, spec.wingCount do
			pose.wings[i].rz += wingSign(i) * 0.6 * e
		end
	else -- Crouch
		body.py -= unit * 0.18 * e
		body.rx -= 0.2 * e
		head.rx -= 0.25 * e
		tail.rx += 0.4 * e
		for i = 1, n do
			pose.legs[i].rx += (if isFront(gait, i, n) then 0.35 else -0.35) * e
		end
		body.rz += tremble
	end
end

local function attackLayer(spec: Spec, inp: Input, pose: Pose)
	local q = clamp01(inp.stateTime / TUNING.AttackSeconds)
	local peak = math.sin(PI * q ^ 0.7)
	local unit, gait, n = spec.unit, spec.gait, spec.legCount
	local body, head, tail = pose.body, pose.head, pose.tail
	local name = spec.attackPose or "Lunge"
	if name == "Bite" then
		head.pz -= unit * 0.3 * peak
		head.rx -= 0.55 * peak
		body.pz -= unit * 0.18 * peak
		body.rx -= 0.1 * peak
		for i = 1, n do
			if isFront(gait, i, n) then
				pose.legs[i].rx += 0.4 * peak
			end
		end
	elseif name == "SlamDown" then
		local raised = 1 - smoothstep(q * 3)
		body.rx += 0.35 * raised - 0.45 * peak
		body.py -= unit * 0.1 * peak
		head.rx -= 0.3 * peak
		for i = 1, n do
			if isFront(gait, i, n) then
				pose.legs[i].rx += 1.6 * raised - 0.4 * peak
			end
		end
		for i = 1, spec.wingCount do
			pose.wings[i].rz += wingSign(i) * 0.9 * raised
		end
	elseif name == "Peck" then
		head.rx -= 1.1 * peak
		head.pz -= unit * 0.25 * peak
		body.rx -= 0.35 * peak
		tail.rx += 0.4 * peak
	elseif name == "Swipe" then
		body.ry += (0.5 - q) * 0.8 * peak
		for i = 1, n do
			if isFront(gait, i, n) then
				pose.legs[i].rx += 1.2 * peak
				pose.legs[i].ry -= legSide(gait, i, n) * (0.8 - 1.6 * q) * peak
			end
		end
	else -- Lunge
		body.pz -= unit * 0.45 * peak
		body.rx += 0.2 * peak
		head.pz -= unit * 0.1 * peak
		head.rx -= 0.3 * peak
		tail.rx += 0.3 * peak
		for i = 1, n do
			pose.legs[i].rx += (if isFront(gait, i, n) then 0.8 else -0.8) * peak
		end
	end
end

local function hurtLayer(spec: Spec, inp: Input, pose: Pose)
	local h = clamp01(1 - inp.hurtAge / math.max(inp.hurtSeconds, 0.01))
	if h <= 0 then
		return
	end
	local t = inp.t
	pose.body.rx += 0.3 * h
	pose.body.pz += spec.unit * 0.08 * h
	pose.body.rz += math.sin(t * 55) * 0.07 * h
	pose.head.rx += 0.35 * h
	pose.tail.rx += 0.4 * h
	for i = 1, spec.legCount do
		pose.legs[i].rx += math.sin(t * 40 + i) * 0.2 * h
	end
end

local function deathLayer(spec: Spec, inp: Input, pose: Pose)
	local d = smoothstep(inp.stateTime / TUNING.DeathFallSeconds)
	local gait, n = spec.gait, spec.legCount
	pose.body.rz += 1.45 * d
	pose.body.py -= spec.unit * 0.28 * d
	pose.body.rx += 0.1 * d
	pose.head.rx -= 0.4 * d
	pose.tail.rx -= 0.5 * d
	for i = 1, n do
		local c = pose.legs[i]
		c.rx += (if i % 2 == 1 then 0.5 else -0.3) * d
		c.rz += legSide(gait, i, n) * 0.4 * d
	end
	for i = 1, spec.wingCount do
		pose.wings[i].rz -= wingSign(i) * 0.4 * d
	end
end

-- Full generic pose for one frame (pure). `pose` is cleared and filled; rig.custom runs after, in the adapter.
function AnimKit.solve(spec: Spec, inp: Input, pose: Pose)
	AnimKit.clear(pose)
	local state = inp.state
	if state == "Death" then
		deathLayer(spec, inp, pose)
		return
	end
	idleLayer(spec, inp, pose)
	gaitLayer(spec, inp, pose)
	if state == "Alert" then
		alertLayer(spec, inp, pose)
	elseif state == "Telegraph" then
		telegraphLayer(spec, inp, pose)
	elseif state == "Attack" then
		attackLayer(spec, inp, pose)
	end
	hurtLayer(spec, inp, pose)
end

type Slot = {
	name: string,
	jointName: string,
	target: Ch,
	cur: Ch,
	joint: Motor6D?,
}

local VALID_STATE: { [string]: boolean } = {}
for _, s in CFG.States do
	VALID_STATE[s] = true
end

function AnimKit.bind(model: Model, rig: Types.RigSpec): Types.Binding
	local root: BasePart? = model.PrimaryPart
	if not root then
		local c = model:FindFirstChild("HumanoidRootPart")
		if c and c:IsA("BasePart") then
			root = c
		end
	end
	local spec: Spec = {
		gait = rig.gait,
		stride = rig.stride,
		runScale = rig.runScale,
		bob = rig.bob,
		idleSway = rig.idleSway,
		telegraphPose = rig.telegraphPose,
		attackPose = rig.attackPose,
		unit = if root then root.Size.Y else 3,
		legCount = #rig.legs,
		wingCount = #rig.wings,
	}
	local pose = AnimKit.newPose(spec.legCount, spec.wingCount)
	local curPose = AnimKit.newPose(spec.legCount, spec.wingCount)
	local inp: Input = {
		state = "Idle",
		t = 0,
		phase = 0,
		gaitW = 0,
		runW = 0,
		stateTime = 0,
		telegraphTotal = 0,
		hurtAge = math.huge,
		hurtSeconds = CFG.HurtSeconds,
	}

	local joints: { [string]: Motor6D } = {}
	local missAt: { [string]: number } = {}
	local frame = 0
	local slots: { Slot } = {}
	local function addSlot(name: string, target: Ch, cur: Ch)
		table.insert(
			slots,
			{ name = name, jointName = "J_" .. name, target = target, cur = cur, joint = nil }
		)
	end
	addSlot(rig.body, pose.body, curPose.body)
	if rig.head then
		addSlot(rig.head, pose.head, curPose.head)
	end
	if rig.tail then
		addSlot(rig.tail, pose.tail, curPose.tail)
	end
	for i, name in rig.legs do
		addSlot(name, pose.legs[i], curPose.legs[i])
	end
	for i, name in rig.wings do
		addSlot(name, pose.wings[i], curPose.wings[i])
	end

	local function lookup(name: string): Motor6D?
		local part = model:FindFirstChild(name)
		if part then
			local j = part:FindFirstChild("J_" .. name)
			if j and j:IsA("Motor6D") then
				return j
			end
		end
		return nil
	end

	local parts: { BasePart } = {}
	local origTrans: { number } = {}
	local dirty = true
	local conns: { RBXScriptConnection } = {}
	local function markDirty()
		dirty = true
	end
	table.insert(conns, model.ChildAdded:Connect(markDirty))
	table.insert(conns, model.ChildRemoved:Connect(markDirty))

	local function refresh()
		for _, slot in slots do
			local j = slot.joint
			if not j or not j.Parent then
				local found = lookup(slot.name)
				slot.joint = found
				if found then
					joints[slot.name] = found
				else
					joints[slot.name] = nil
				end
			end
		end
		if dirty then
			dirty = false
			table.clear(parts)
			table.clear(origTrans)
			for _, c in model:GetChildren() do
				if c:IsA("BasePart") and c ~= root then
					table.insert(parts, c)
					table.insert(origTrans, c.Transparency)
				end
			end
		end
	end

	local extraJoints: { [Motor6D]: boolean } = {}
	local ctx: Types.AnimCtx = {
		model = model,
		joints = joints,
		state = "Idle",
		t = 0,
		dt = 0,
		phase = 0,
		speed = 0,
		stateTime = 0,
		telegraphLeft = 0,
		pose = function(partName: string, offset: CFrame)
			local j = joints[partName]
			if not j then
				local missed = missAt[partName]
				if missed and frame - missed < TUNING.RefreshSteps then
					return
				end
				local found = lookup(partName)
				if not found then
					missAt[partName] = frame
					return
				end
				missAt[partName] = nil
				joints[partName] = found
				j = found
			end
			if j then
				j.Transform = offset
				extraJoints[j] = true
			end
		end,
	}

	local alive = true
	local customFn = rig.custom
	local prevState = ""
	local stateTime = 0
	local telegraphTotal = 0
	local hurtAge = math.huge
	local t = 0
	local phase = 0
	local gaitW = 0
	local runW = 0
	local speed = 0
	local lastPos: Vector3? = nil
	local lastClock = 0
	local lastFade = 0

	local function step(dt: number)
		if not alive or dt <= 0 then
			return
		end
		if dt > TUNING.MaxDt then
			dt = TUNING.MaxDt
		end
		t += dt
		frame += 1
		if dirty or frame % TUNING.RefreshSteps == 0 then
			refresh()
		end

		local raw = model:GetAttribute(CFG.StateAttribute)
		local state = if type(raw) == "string" and VALID_STATE[raw] then raw else "Idle"
		if state ~= prevState then
			prevState = state
			stateTime = 0
			if state == "Telegraph" then
				local a = model:GetAttribute(CFG.TelegraphAttribute)
				telegraphTotal = if type(a) == "number" and a > 0
					then a
					else TUNING.DefaultTelegraph
			elseif state == "Hurt" then
				hurtAge = 0
			end
		else
			stateTime += dt
		end
		hurtAge += dt
		if state == "Telegraph" then
			local a = model:GetAttribute(CFG.TelegraphAttribute)
			if type(a) == "number" and a > telegraphTotal then
				telegraphTotal = a
			end
		end

		if root then
			local now = os.clock()
			local p = root.Position
			local prev = lastPos
			if prev and now - lastClock < TUNING.MaxGap then
				local d = ((p - prev) * Vector3.new(1, 0, 1)).Magnitude
				local inst = math.min(d / math.max(now - lastClock, 1e-3), TUNING.MaxSpeed)
				speed += (inst - speed) * (1 - math.exp(-TUNING.SpeedSmoothRate * dt))
			else
				speed = 0
			end
			lastPos = p
			lastClock = now
		end

		local gTarget, rTarget = AnimKit.gaitTarget(spec.gait, state)
		local blend = 1 - math.exp(-TUNING.GaitBlendRate * dt)
		gaitW += (gTarget - gaitW) * blend
		runW += (rTarget - runW) * blend
		phase = (phase + AnimKit.phaseRate(spec.gait, state, speed) * dt) % (2 * PI)

		inp.state = state
		inp.t = t
		inp.phase = phase
		inp.gaitW = gaitW
		inp.runW = runW
		inp.stateTime = stateTime
		inp.telegraphTotal = telegraphTotal
		inp.hurtAge = hurtAge
		AnimKit.solve(spec, inp, pose)

		local a = AnimKit.smoothAlpha(dt)
		for _, slot in slots do
			local j = slot.joint
			if j then
				local c = slot.cur
				AnimKit.smooth(c, slot.target, a)
				j.Transform = CFrame.new(c.px, c.py, c.pz) * CFrame.Angles(c.rx, c.ry, c.rz)
			end
		end

		if customFn then
			ctx.state = state :: Types.State
			ctx.t = t
			ctx.dt = dt
			ctx.phase = phase
			ctx.speed = speed
			ctx.stateTime = stateTime
			ctx.telegraphLeft = if state == "Telegraph"
				then math.max(0, telegraphTotal - stateTime)
				else 0
			local ok = pcall(customFn, ctx)
			if not ok then
				customFn = nil
			end
		end

		local fade = if state == "Death" then AnimKit.deathFade(stateTime) else 0
		if math.abs(fade - lastFade) > TUNING.FadeEpsilon or (fade == 0 and lastFade ~= 0) then
			lastFade = fade
			for i, part in parts do
				local o = origTrans[i]
				part.Transparency = o + (1 - o) * fade
			end
		end
	end

	local function unbind()
		if not alive then
			return
		end
		alive = false
		for _, c in conns do
			c:Disconnect()
		end
		table.clear(conns)
		for _, j in joints do
			j.Transform = CFrame.identity
		end
		for j in extraJoints do
			j.Transform = CFrame.identity
		end
		for i, part in parts do
			part.Transparency = origTrans[i]
		end
		table.clear(joints)
		table.clear(extraJoints)
		table.clear(parts)
		table.clear(slots)
	end

	local function hurt()
		hurtAge = 0
	end

	return { step = step, unbind = unbind, hurt = hurt }
end

return AnimKit
