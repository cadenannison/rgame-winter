--!strict
-- Dread, hunt and Stalker rules (pure, no Roblox APIs). Every value here is server-only: Dread, hunt
-- chance, hunt timers and lurker density must never reach an Attribute, a remote payload or a print.
-- The client sees only cueLevel() through the DreadLevel cue. Every scaling value clamps to a Config cap.

local Config = require("../Config")

local D = Config.Dread
local S = Config.Stalker
local L = Config.Lurkers
local E = Config.Events
local I = Config.Isolation

export type Inputs = {
	isolation: number, -- highest isolation weight in the party (Isolation.weights)
	farFromCamp: boolean, -- someone is beyond Dread.FarFromCampDistance
	dark: boolean, -- night or false night (outside light)
	blizzard: boolean,
	nearFire: boolean, -- every living member is inside a fire radius or warm spot
	day: number,
	ring: number, -- deepest biome ring any member stands in
	eventMultiplier: number, -- EventService dreadGain (1 = none), clamped to Events.MaxDreadGainMultiplier
}

export type HuntContext = {
	day: number,
	now: number,
	cooldownUntil: number,
	hunting: boolean,
	fullGroup: boolean,
	candidates: number, -- living players that could be targeted
}

export type Light = "none" | "torch" | "flare"
export type Phase = "Telegraph" | "Chase" | "Retreat" | "Done"

export type Hunt = {
	phase: Phase,
	phaseLeft: number,
	huntLeft: number,
	torchShortened: boolean,
	struck: boolean,
}

export type HuntInputs = {
	distance: number, -- Stalker to target (studs)
	light: Light, -- what the target holds lit
	targetSafe: boolean, -- target inside fire/warm spot, downed, or gone
}

export type HuntOutcome = {
	strike: boolean, -- deal one strike now (then it retreats)
	retreatStarted: boolean, -- entered Retreat this step (send StalkerRetreat)
	done: boolean, -- hunt over: despawn and start the cooldown
}

export type Repeller = { x: number, z: number, radius: number }

local DreadLogic = {}

local CLAMP_PASSES = 4 -- push-out iterations for overlapping repellers

-- Combined gain multiplier from day, ring and event (each clamped to its cap).
function DreadLogic.gainMultiplier(day: number, ring: number, eventMultiplier: number): number
	local dayMult = math.min(1 + D.GainPerDay * math.max(day - 1, 0), D.MaxDayGainMultiplier)
	local ringMult = math.min(1 + D.GainPerRing * math.max(ring, 0), D.MaxRingGainMultiplier)
	local eventMult = math.clamp(eventMultiplier, 0, E.MaxDreadGainMultiplier)
	return dayMult * ringMult * eventMult
end

-- Hard cap on gainMultiplier (used by tests).
function DreadLogic.maxGainMultiplier(): number
	return D.MaxDayGainMultiplier * D.MaxRingGainMultiplier * E.MaxDreadGainMultiplier
end

-- One Dread step for a party. Returns the new value in [0, Dread.Max].
function DreadLogic.step(dread: number, inputs: Inputs, dt: number): number
	local value = dread
	if inputs.nearFire then
		value -= D.DecayNearFirePerSecond * dt
	else
		local alone = math.clamp(inputs.isolation / I.WeightAlone, 0, 1)
		local gain = D.GainAlonePerSecond * alone
		if inputs.farFromCamp then
			gain += D.GainFarFromCampPerSecond
		end
		if inputs.dark then
			gain += D.GainDarkPerSecond
		end
		if inputs.blizzard then
			gain += D.GainBlizzardPerSecond
		end
		gain *= DreadLogic.gainMultiplier(inputs.day, inputs.ring, inputs.eventMultiplier)
		value += (gain - D.DecayPerSecond) * dt
	end
	return math.clamp(value, 0, D.Max)
end

-- One-off gain (lurker sighting), clamped.
function DreadLogic.add(dread: number, amount: number): number
	return math.clamp(dread + math.max(amount, 0), 0, D.Max)
end

-- Coarse cue level 0..#CueThresholds (the only client-visible view of Dread).
function DreadLogic.cueLevel(dread: number): number
	local level = 0
	for _, t in D.CueThresholds do
		if dread >= t then
			level += 1
		end
	end
	return math.min(level, Config.Cue.MaxLevel)
end

-- Hunt chance per check, capped by Stalker.MaxHuntChance (after the event bonus). 0 before FirstHuntDay.
function DreadLogic.huntChance(dread: number, day: number, bonus: number): number
	if day < S.FirstHuntDay then
		return 0
	end
	local raw = S.BaseHuntChance
		+ S.HuntChancePerDread * math.clamp(dread, 0, D.Max)
		+ S.HuntChancePerDay * math.max(day - S.FirstHuntDay, 0)
		+ math.clamp(bonus, 0, E.MaxHuntChanceBonus)
	return math.clamp(raw, 0, S.MaxHuntChance)
end

function DreadLogic.canHunt(ctx: HuntContext): boolean
	return ctx.day >= S.FirstHuntDay
		and not ctx.hunting
		and not ctx.fullGroup
		and ctx.now >= ctx.cooldownUntil
		and ctx.candidates > 0
end

-- Lurker spawn chance per interval for one player, capped by Lurkers.MaxDensity.
function DreadLogic.lurkerDensity(day: number, ring: number, isolation: number): number
	local base = L.BaseDensity
		+ L.DensityPerDay * math.max(day - 1, 0)
		+ L.DensityPerRing * math.max(ring, 0)
	local capped = math.clamp(base, 0, L.MaxDensity)
	return capped * math.clamp(isolation / I.WeightAlone, 0, 1)
end

-- Strike damage after the server floor: never below 0, never more than MaxHealth - 1, and from full
-- health never enough to reach 0.
function DreadLogic.strikeDamage(health: number, maxHealth: number): number
	local dmg = math.clamp(S.Damage, 0, math.max(maxHealth - 1, 0))
	if health >= maxHealth then
		dmg = math.min(dmg, math.max(health - 1, 0))
	end
	return dmg
end

-- True when (x, z) is inside any repeller radius plus margin.
function DreadLogic.isInside(x: number, z: number, repellers: { Repeller }, margin: number): boolean
	for _, r in repellers do
		local reach = r.radius + margin
		local dx, dz = x - r.x, z - r.z
		if dx * dx + dz * dz < reach * reach then
			return true
		end
	end
	return false
end

-- Pushes (x, z) out to the edge of every repeller it is inside. Returns the new point and whether it is
-- now clear; callers keep the previous valid point when it is not.
function DreadLogic.clampOutside(
	x: number,
	z: number,
	repellers: { Repeller },
	margin: number
): (number, number, boolean)
	local px, pz = x, z
	for _ = 1, CLAMP_PASSES do
		local moved = false
		for _, r in repellers do
			local reach = r.radius + margin
			local dx, dz = px - r.x, pz - r.z
			local d2 = dx * dx + dz * dz
			if d2 < reach * reach then
				local d = math.sqrt(d2)
				if d <= 0 then
					dx, dz, d = 1, 0, 1
				end
				-- Nudge just past the edge so floating point never lands exactly on it.
				local scale = (reach + 1e-3) / d
				px, pz = r.x + dx * scale, r.z + dz * scale
				moved = true
			end
		end
		if not moved then
			break
		end
	end
	return px, pz, not DreadLogic.isInside(px, pz, repellers, margin)
end

-- One movement step toward (tx, tz) at speed, never ending inside a repeller. Returns the new point and
-- false when it could not stay clear (the caller ends the hunt and despawns).
function DreadLogic.moveToward(
	x: number,
	z: number,
	tx: number,
	tz: number,
	speed: number,
	dt: number,
	repellers: { Repeller },
	margin: number
): (number, number, boolean)
	local dx, dz = tx - x, tz - z
	local dist = math.sqrt(dx * dx + dz * dz)
	local step = math.min(speed * dt, dist)
	local nx, nz = x, z
	if dist > 0 then
		nx, nz = x + dx / dist * step, z + dz / dist * step
	end
	local cx, cz, clear = DreadLogic.clampOutside(nx, nz, repellers, margin)
	if clear then
		return cx, cz, true
	end
	if not DreadLogic.isInside(x, z, repellers, margin) then
		return x, z, true
	end
	return cx, cz, false
end

function DreadLogic.newHunt(): Hunt
	return {
		phase = "Telegraph",
		phaseLeft = S.TelegraphSeconds,
		huntLeft = S.MaxHuntSeconds,
		torchShortened = false,
		struck = false,
	}
end

local function enterRetreat(h: Hunt, out: HuntOutcome)
	h.phase = "Retreat"
	h.phaseLeft = S.RetreatSeconds
	out.retreatStarted = true
end

-- Advances a hunt by dt. Telegraph -> Chase -> (strike) -> Retreat -> Done. A flare ends it at once, a
-- torch shortens the remaining time once, and the time limit always ends it.
function DreadLogic.stepHunt(h: Hunt, inputs: HuntInputs, dt: number): HuntOutcome
	local out: HuntOutcome = { strike = false, retreatStarted = false, done = false }
	if h.phase == "Done" then
		out.done = true
		return out
	end
	if h.phase == "Retreat" then
		h.phaseLeft -= dt
		if h.phaseLeft <= 0 then
			h.phase = "Done"
			out.done = true
		end
		return out
	end
	h.huntLeft -= dt
	if inputs.light == "flare" then
		enterRetreat(h, out)
		return out
	end
	if inputs.light == "torch" and not h.torchShortened then
		h.torchShortened = true
		h.huntLeft *= 1 - math.clamp(S.TorchHuntShorten, 0, 1)
	end
	if h.huntLeft <= 0 then
		enterRetreat(h, out)
		return out
	end
	if h.phase == "Telegraph" then
		h.phaseLeft -= dt
		if h.phaseLeft <= 0 then
			h.phase = "Chase"
		end
		return out
	end
	-- Chase: strike once in range, unless the target is safe or holds a light it backs off from.
	if inputs.distance <= S.StrikeRange and not inputs.targetSafe and inputs.light == "none" then
		out.strike = true
		h.struck = true
		enterRetreat(h, out)
	end
	return out
end

return DreadLogic
