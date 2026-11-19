--!strict
-- Legacy AI driver (ArcticHare, Caribou, Fish and every Phase 3 hostile / mini boss / boss, Wolf included).
-- Moved verbatim from MobService.stepMob; behavior is unchanged (MobAI.decide + windupStep). Pure decisions
-- live in src/shared/logic/MobAI.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local CreatureRegistry = require(Shared.Creatures.Registry)
local FireRepel = require(Shared.logic.FireRepel)
local MobAI = require(Shared.logic.MobAI)
local MobDamage = require(Shared.logic.MobDamage)
local MobRules = require(Shared.logic.MobRules)
local MobData = require(Shared.data.Mobs)
local Mobs = script.Parent.Parent
local MobActions = require(Mobs.MobActions)
local MobRegistry = require(Mobs.MobRegistry)
local MobState = require(Mobs.MobState)
local MobWorld = require(Mobs.MobWorld)
local Types = require(Mobs.MobTypes)

type MobRow = Types.MobRow
type Env = Types.Env

local MOBS = Config.Mobs
local NIGHT = Config.Night
local toPoint = MobWorld.toPoint
local horizontalDir = MobWorld.horizontalDir
local rng = Random.new()

local Legacy = {}

function Legacy.step(row: MobRow, env: Env)
	local now = env.now
	local fires = env.fires
	local pos = row.root.Position
	local stats = row.kind.stats
	local nearestInfo = env.nearestInfo
	local nearest = env.nearest
	local hunter = row.kind.behavior == "Hunt"
	local repelled = MobRules.repelledByFire(row.kind.category, row.kind.breaksFire)
	local fireIndex = if hunter and repelled
		then FireRepel.insideAny(pos.X, pos.Z, fires, NIGHT.RepelMargin, Config.Fire.RepelRadius)
		else nil
	local fire = if fireIndex then fires[fireIndex] else nil
	local action = MobAI.decide({
		behavior = row.kind.behavior,
		nearestPlayerDist = nearest,
		isNight = env.danger,
		nightOnly = stats.NightOnly,
		fleeRange = stats.FleeRange,
		aggroRange = stats.AggroRange,
		attackRange = stats.AttackRange,
		inFireRepel = fire ~= nil,
		canAttack = now >= row.nextAttackAt,
	})
	-- A windup in progress holds its place until the bite lands or the target leaves strike reach.
	if hunter and row.windup.startedAt ~= nil and (action == "Chase" or action == "Attack") then
		action = "Attack"
	end
	if hunter and action ~= "Attack" and row.windup.startedAt ~= nil then
		row.windup.startedAt = nil
		MobActions.setWindup(row, false)
	end
	-- Ambusher: lies buried (half hidden) until a player is inside aggro range.
	if row.kind.ambush then
		local buried = action == "Wander"
		if (row.model:GetAttribute(MobData.BuriedAttribute) == true) ~= buried then
			row.model:SetAttribute(MobData.BuriedAttribute, buried)
			if CreatureRegistry.get(row.kind.name) == nil then
				row.root.Transparency = if buried then 0.7 else 0 -- stub body only (a creature rig keeps the hitbox invisible)
			end
		end
	end
	-- Heavy mobs and bosses chew through a wall or door that blocks the way.
	if action == "Chase" and row.kind.breaksStructures and now >= row.nextAttackAt then
		if MobActions.breakStructure(row, pos) then
			row.nextAttackAt = now + stats.AttackCooldown
			row.lastAction = "Attack"
			MobState.attacked(row, now)
			return
		end
	end
	row.lastAction = action
	MobState.setTarget(row, if nearestInfo then nearestInfo.player else nil)
	if action ~= "Leave" then
		row.leaveDeadline = nil
	end

	local humanoid = row.humanoid
	if action == "Flee" and nearestInfo then
		-- Sprint / pause rhythm so a walking player can close in during the pauses.
		if MobAI.fleeBurst(row.burst, now, stats.FleeBurstSeconds, stats.FleeRestSeconds) then
			humanoid.WalkSpeed = stats.FleeSpeed
			humanoid:MoveTo(pos + horizontalDir(nearestInfo.root.Position, pos) * MOBS.FleeStep)
		else
			row.lastAction = "Rest"
			humanoid:MoveTo(pos)
		end
	elseif action == "Retreat" and fire then
		humanoid.WalkSpeed = stats.FleeSpeed
		humanoid:MoveTo(
			pos + horizontalDir(Vector3.new(fire.x, pos.Y, fire.z), pos) * MOBS.RetreatStep
		)
	elseif action == "Leave" then
		-- Dawn: run away from the nearest player, then despawn.
		local deadline = row.leaveDeadline or (now + NIGHT.DawnLeaveSeconds)
		row.leaveDeadline = deadline
		if now >= deadline then
			MobRegistry.remove(row.model)
			return
		end
		humanoid.WalkSpeed = stats.FleeSpeed
		if nearestInfo then
			humanoid:MoveTo(pos + horizontalDir(nearestInfo.root.Position, pos) * MOBS.RetreatStep)
		end
	elseif action == "Chase" and nearestInfo then
		humanoid.WalkSpeed = stats.FleeSpeed
		local target = nearestInfo.root.Position
		local tx, tz = target.X, target.Z
		-- Never path into a fire's repel circle to reach a sheltered player.
		if repelled then
			for _, f in fires do
				tx, tz = FireRepel.clampTarget(tx, tz, f, MobWorld.repelOf(f))
			end
		end
		humanoid:MoveTo(Vector3.new(tx, target.Y, tz))
	elseif action == "Attack" and nearestInfo then
		-- Server recomputes distance at every phase of the bite.
		local d = MobRules.distance(toPoint(pos), toPoint(nearestInfo.root.Position))
		local reach = d <= stats.AttackRange + NIGHT.StrikeLeeway
		local result =
			MobAI.windupStep(row.windup, now, d <= stats.AttackRange, reach, NIGHT.WindupSeconds)
		if result == "Start" then
			row.lastAction = "Windup"
			row.telegraphSeconds = NIGHT.WindupSeconds
			humanoid:MoveTo(pos)
			MobActions.setWindup(row, true)
		elseif result == "Wait" then
			row.lastAction = "Windup"
			humanoid:MoveTo(pos)
		elseif result == "Cancel" then
			row.lastAction = "Chase" -- target stepped out of reach: the bite never happened
			MobActions.setWindup(row, false)
		elseif result == "Strike" then
			MobActions.setWindup(row, false)
			row.nextAttackAt = now + MobDamage.cooldown(row.kind.name, stats.AttackCooldown)
			MobState.attacked(row, now)
			local biteOk = MobRules.biteAllowed(
				repelled,
				toPoint(pos),
				toPoint(nearestInfo.root.Position),
				fires
			)
			if biteOk then
				MobActions.dealDamage(row, nearestInfo)
			end
		end
	elseif row.kind.ambush and action == "Wander" then
		humanoid:MoveTo(pos) -- buried: hold still
	else
		humanoid.WalkSpeed = stats.WalkSpeed
		if now >= row.wanderUntil then
			row.wanderUntil = now + MOBS.WanderInterval * (0.5 + rng:NextNumber())
			local angle = rng:NextNumber(0, math.pi * 2)
			humanoid:MoveTo(
				pos + Vector3.new(math.cos(angle), 0, math.sin(angle)) * MOBS.WanderRadius
			)
		end
	end
end

return Legacy
