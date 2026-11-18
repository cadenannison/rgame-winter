--!strict
-- Art Pass 3: AnimKit pure pose math (no Roblox instances). Registered in tests/run.luau.

local AnimKit = require("../src/shared/Creatures/AnimKit")

local GAITS = { "Quad", "Biped", "Bird", "Seal", "Slither", "Float", "Flock", "None" }
local STATES = { "Idle", "Walk", "Run", "Alert", "Telegraph", "Attack", "Hurt", "Death" }
local TELEGRAPHS = { "Rear", "Slam", "Crouch", "Spread", "Raise" }
local ATTACKS = { "Lunge", "Bite", "SlamDown", "Peck", "Swipe" }

local function spec(gait: string): AnimKit.Spec
	return {
		gait = gait,
		stride = 0.8,
		runScale = 1.5,
		bob = 0.1,
		idleSway = 0.03,
		telegraphPose = nil,
		attackPose = nil,
		unit = 3,
		legCount = 4,
		wingCount = 2,
	}
end

local function input(state: string, overrides: { [string]: number }?): AnimKit.Input
	local inp: AnimKit.Input = {
		state = state,
		t = 1.3,
		phase = 1.0,
		gaitW = if state == "Walk" or state == "Run" then 1 else 0,
		runW = if state == "Run" then 1 else 0,
		stateTime = 0.2,
		telegraphTotal = 0.7,
		hurtAge = math.huge,
		hurtSeconds = 0.35,
	}
	if overrides then
		local m = inp :: any
		for k, v in overrides do
			m[k] = v
		end
	end
	return inp
end

local function finite(pose: AnimKit.Pose): boolean
	local function ok(c: AnimKit.Ch): boolean
		for _, v in { c.px, c.py, c.pz, c.rx, c.ry, c.rz } do
			if v ~= v or math.abs(v) > 6 then
				return false
			end
		end
		return true
	end
	if not (ok(pose.body) and ok(pose.head) and ok(pose.tail)) then
		return false
	end
	for _, c in pose.legs do
		if not ok(c) then
			return false
		end
	end
	for _, c in pose.wings do
		if not ok(c) then
			return false
		end
	end
	return true
end

return function(check: (string, boolean) -> ())
	-- Every gait x state x pose name stays finite and bounded over a time sweep.
	local allFinite = true
	for _, gait in GAITS do
		for _, state in STATES do
			local names: { string } = if state == "Telegraph" then TELEGRAPHS else ATTACKS
			for _, name in names do
				local s = spec(gait)
				s.telegraphPose = name
				s.attackPose = name
				local pose = AnimKit.newPose(4, 2)
				for step = 0, 20 do
					local st = step * 0.05
					AnimKit.solve(
						s,
						input(
							state,
							{ stateTime = st, t = st * 3, phase = st * 6, hurtAge = st * 0.3 }
						),
						pose
					)
					allFinite = allFinite and finite(pose)
				end
			end
		end
	end
	check("animkit: all gait/state/pose combos finite and bounded", allFinite)

	-- Idle with no gait weight leaves legs still; gait weight moves them.
	local pose = AnimKit.newPose(4, 2)
	AnimKit.solve(spec("Quad"), input("Idle"), pose)
	check("animkit: idle legs at rest", pose.legs[1].rx == 0 and pose.legs[3].rx == 0)
	AnimKit.solve(spec("Quad"), input("Walk"), pose)
	check(
		"animkit: quad diagonal legs in phase",
		math.abs(pose.legs[1].rx - pose.legs[2].rx) < 1e-9
	)
	check(
		"animkit: quad opposite diagonals out of phase",
		math.abs(pose.legs[1].rx + pose.legs[3].rx) < 1e-9
	)
	check("animkit: walk legs swing", math.abs(pose.legs[1].rx) > 0.1)
	local walkSwing = 0
	local runSwing = 0
	for i = 1, 40 do
		local ph = i * 0.2
		AnimKit.solve(spec("Quad"), input("Walk", { phase = ph }), pose)
		walkSwing = math.max(walkSwing, math.abs(pose.legs[1].rx))
		AnimKit.solve(spec("Quad"), input("Run", { phase = ph }), pose)
		runSwing = math.max(runSwing, math.abs(pose.legs[1].rx))
	end
	check("animkit: run swings wider than walk", runSwing > walkSwing * 1.3)

	-- Bird flushes (wings open) on Run only.
	AnimKit.solve(spec("Bird"), input("Walk"), pose)
	local walkWing = math.abs(pose.wings[1].rz)
	AnimKit.solve(spec("Bird"), input("Run", { t = 0.06 }), pose)
	check("animkit: bird wings open on run", math.abs(pose.wings[1].rz) > walkWing + 0.1)
	check("animkit: wing sides mirror", math.abs(pose.wings[1].rz + pose.wings[2].rz) < 0.2)

	-- Telegraph progress is monotone and drives the pose.
	check("animkit: telegraph progress 0", AnimKit.telegraphProgress(0, 1) == 0)
	check("animkit: telegraph progress clamps", AnimKit.telegraphProgress(5, 1) == 1)
	check("animkit: telegraph default total", AnimKit.telegraphProgress(0.35, 0) > 0.4)
	local s = spec("Quad")
	s.telegraphPose = "Rear"
	local prev = -1.0
	local mono = true
	for i = 0, 10 do
		AnimKit.solve(s, input("Telegraph", { stateTime = i * 0.07, telegraphTotal = 0.7 }), pose)
		mono = mono and pose.body.rx >= prev - 1e-6
		prev = pose.body.rx
	end
	check("animkit: rear raises body monotonically", mono and pose.body.rx > 0.5)
	s.telegraphPose = "Crouch"
	AnimKit.solve(s, input("Telegraph", { stateTime = 0.7 }), pose)
	check("animkit: crouch lowers body", pose.body.py < -0.3)

	-- Attack peaks mid-envelope and returns to neutral.
	s.attackPose = "Lunge"
	AnimKit.solve(s, input("Attack", { stateTime = AnimKit.Tuning.AttackSeconds * 0.5 }), pose)
	local mid = math.abs(pose.body.pz)
	AnimKit.solve(s, input("Attack", { stateTime = 2 }), pose)
	check("animkit: lunge peaks then settles", mid > 0.3 and math.abs(pose.body.pz) < 0.01)

	-- Hurt flinch decays.
	AnimKit.solve(spec("Quad"), input("Idle", { hurtAge = 0 }), pose)
	local flinch = pose.head.rx
	AnimKit.solve(spec("Quad"), input("Idle", { hurtAge = 1 }), pose)
	check("animkit: hurt flinch decays", flinch > pose.head.rx + 0.2)

	-- Death falls over and fades after the fall.
	AnimKit.solve(spec("Quad"), input("Death", { stateTime = 2 }), pose)
	check("animkit: death rolls body", pose.body.rz > 1.3 and pose.body.py < 0)
	check("animkit: no fade during fall", AnimKit.deathFade(0.1) == 0)
	check("animkit: fade complete", AnimKit.deathFade(60) == 1)
	check("animkit: fade monotone", AnimKit.deathFade(1.0) <= AnimKit.deathFade(1.5))

	-- Gait targets and phase rate.
	local gw, rw = AnimKit.gaitTarget("Quad", "Run")
	check("animkit: run gait target", gw == 1 and rw == 1)
	gw = AnimKit.gaitTarget("Quad", "Idle")
	check("animkit: idle gait target zero", gw == 0)
	gw = AnimKit.gaitTarget("Slither", "Idle")
	check("animkit: swimmers keep moving", gw > 0)
	check("animkit: phase rate zero idle", AnimKit.phaseRate("Quad", "Idle", 5) == 0)
	check(
		"animkit: phase rate floors",
		AnimKit.phaseRate("Quad", "Walk", 0) >= AnimKit.Tuning.MinWalkRate
	)
	check(
		"animkit: phase rate capped",
		AnimKit.phaseRate("Quad", "Run", 1000) <= AnimKit.Tuning.MaxPhaseRate
	)

	-- Smoothing converges without overshoot.
	local cur: AnimKit.Ch = { px = 0, py = 0, pz = 0, rx = 0, ry = 0, rz = 0 }
	local target: AnimKit.Ch = { px = 0, py = 0, pz = 0, rx = 1, ry = 0, rz = 0 }
	local a = AnimKit.smoothAlpha(1 / 60)
	local over = false
	for _ = 1, 120 do
		AnimKit.smooth(cur, target, a)
		over = over or cur.rx > 1
	end
	check("animkit: smoothing converges", not over and cur.rx > 0.99)

	-- Clear resets everything.
	AnimKit.solve(spec("Quad"), input("Run"), pose)
	AnimKit.clear(pose)
	check(
		"animkit: clear zeroes pose",
		pose.body.py == 0 and pose.legs[1].rx == 0 and pose.wings[2].rz == 0
	)
end
