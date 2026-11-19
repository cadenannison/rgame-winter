--!strict
-- Adapter for the pure fire-safe aggro rules (logic/MobAggro): runs before a mob's AI step and, when the mob
-- may not target the nearest player (inside a fire, out of sight, beyond the leash), clears that target so the
-- mob wanders. A wind-up in progress is never interrupted here (Frost Brute poise).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local MobAggro = require(Shared.logic.MobAggro)
local MobSpecies = require(Shared.logic.MobSpecies)
local Mobs = script.Parent.Parent
local MobWorld = require(Mobs.MobWorld)
local Types = require(Mobs.MobTypes)

type MobRow = Types.MobRow
type Env = Types.Env

local AggroGate = {}

local function fireSafe(row: MobRow): boolean
	local cached = row.sp.fireSafe
	if type(cached) == "boolean" then
		return cached
	end
	local def = row.kind.species
	local role = if def then def.role else row.kind.category
	local value = MobAggro.isFireSafe(
		row.kind.name,
		role,
		if def then def.fireSafe else nil,
		row.kind.breaksFire
	)
	row.sp.fireSafe = value
	return value
end

local function windingUp(row: MobRow): boolean
	local tele = row.sp.tele
	return row.windup.startedAt ~= nil or (type(tele) == "table" and tele.left ~= nil)
end

local function aggroRange(row: MobRow): number
	local def = row.kind.species
	if def then
		return def.aggroRange * MobSpecies.aggroScale(def, row.ring)
	end
	return row.kind.stats.AggroRange
end

-- Filters env.nearestInfo / env.nearest for this mob (in place).
function AggroGate.apply(row: MobRow, env: Env)
	if not fireSafe(row) or windingUp(row) then
		return
	end
	-- Night hunters at dawn run off (Leave) and need the nearest player to flee from.
	if row.kind.stats.NightOnly and not env.danger then
		return
	end
	local info, dist = env.nearestInfo, env.nearest
	local state = row.sp.aggro :: MobAggro.State? or MobAggro.new()
	local range = aggroRange(row)
	local pos = info and info.root.Position
	local hitAt = row.sp.lastHitAt :: number?
	local hitBy = row.sp.lastHitBy :: Player?
	local newState, engaged = MobAggro.step(state, {
		fireSafe = true,
		dist = dist,
		aggroRange = range,
		targetInFire = pos ~= nil and MobAggro.targetInFire(pos.X, pos.Z, env.fires),
		hitRecently = info ~= nil and hitBy == info.player and MobAggro.hitRecently(env.now, hitAt),
		canSee = info ~= nil and MobWorld.hasSight(row.root.Position, info.root),
	}, env.dt)
	row.sp.aggro = newState
	if not engaged then
		env.nearestInfo, env.nearest = nil, nil
	elseif dist ~= nil then
		-- Leash > aggro range: keep chasing out to the leash by reporting the target as in range.
		env.nearest = math.min(dist, range)
	end
end

-- Debug/QA: whether a row is flagged fire-safe.
function AggroGate.isFireSafe(row: MobRow): boolean
	return fireSafe(row)
end

return AggroGate
