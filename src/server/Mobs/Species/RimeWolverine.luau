--!strict
-- Rime Wolverine (hostile ambusher): lurks, then crouches (Telegraph) and charges at the spot the player
-- stood on when the wind-up ended. The charge is a straight line: sidestep it and it misses. Fire-safe.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local FireRepel = require(Shared.logic.FireRepel)
local MobBehaviors = require(Shared.logic.MobBehaviors)
local MobRules = require(Shared.logic.MobRules)
local Mobs = script.Parent.Parent
local MobActions = require(Mobs.MobActions)
local MobState = require(Mobs.MobState)
local MobWorld = require(Mobs.MobWorld)
local SpeciesKit = require(Mobs.Drivers.SpeciesKit)
local Types = require(Mobs.MobTypes)

type MobRow = Types.MobRow
type Env = Types.Env

local Telegraph = MobBehaviors.Telegraph

local function recover(row: MobRow, now: number)
	row.sp.phase = "Lurk"
	row.sp.tele = Telegraph.new()
	row.nextAttackAt = now + SpeciesKit.def(row).attackCooldown
end

local RimeWolverine: Types.Species = {
	init = function(row: MobRow)
		row.sp.phase = "Lurk"
		row.sp.tele = Telegraph.new()
	end,
	step = function(row: MobRow, env: Env)
		local def = SpeciesKit.def(row)
		local tune = def.tune
		local sp = row.sp
		local now = env.now
		local pos = row.root.Position
		local info, d = env.nearestInfo, env.nearest
		if SpeciesKit.retreatFromFire(row, env) then
			recover(row, now)
			return
		end
		if sp.phase == "Charge" then
			-- Straight line at the locked point; hits only a player it actually reaches.
			sp.chargeLeft -= env.dt
			local dir = sp.dir :: Vector3
			row.lastAction = "Charge"
			row.humanoid.WalkSpeed = def.runSpeed
			row.humanoid:MoveTo(pos + dir * (def.runSpeed * 0.5))
			MobState.setTarget(row, if info then info.player else nil)
			if info and d ~= nil and d <= def.attackRange then
				if
					MobRules.biteAllowed(
						true,
						MobWorld.toPoint(pos),
						MobWorld.toPoint(info.root.Position),
						env.fires
					)
				then
					MobActions.strike(row, info, now)
				else
					MobState.attacked(row, now)
				end
				row.lastAction = "Attack"
				recover(row, now)
			elseif sp.chargeLeft <= 0 then
				recover(row, now)
			end
			return
		end
		if not info or d == nil or d > SpeciesKit.aggro(row) then
			row.lastAction = "Idle" -- lies in wait
			MobState.setTarget(row, nil)
			SpeciesKit.resetTelegraph(row)
			MobActions.stop(row)
			return
		end
		local tele = sp.tele
		local ready = d <= tune.chargeRange and now >= row.nextAttackAt
		if tele.left == nil and not ready then
			-- Creeps closer at walking pace until it is inside charge range.
			SpeciesKit.chase(row, env, def.walkSpeed)
			return
		end
		local newTele, out = Telegraph.step(
			tele,
			{ ready = ready, inReach = d <= tune.chargeRange * 1.5, seconds = def.telegraphSeconds },
			env.dt
		)
		sp.tele = newTele
		if out.event == "Start" or out.event == "Wait" then
			row.lastAction = "Windup"
			if out.event == "Start" then
				row.telegraphSeconds = def.telegraphSeconds
			end
			MobState.setTarget(row, info.player)
			MobActions.stop(row)
			SpeciesKit.face(row, info.root.Position.X, info.root.Position.Z)
		elseif out.event == "Strike" then
			-- Wind-up over: lock the line to where the player stands now, never the player later.
			local locked = info.root.Position
			local tx, tz = locked.X, locked.Z
			for _, f in env.fires do
				tx, tz = FireRepel.clampTarget(tx, tz, f, MobWorld.repelOf(f))
			end
			sp.dir = MobWorld.horizontalDir(pos, Vector3.new(tx, pos.Y, tz))
			sp.phase = "Charge"
			sp.chargeLeft = tune.chargeSeconds
			row.lastAction = "Charge"
			MobState.setTarget(row, info.player)
		else
			SpeciesKit.chase(row, env, def.walkSpeed) -- Cancel
		end
	end,
}

return RimeWolverine
