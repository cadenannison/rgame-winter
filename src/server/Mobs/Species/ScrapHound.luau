--!strict
-- Scrap Hound (hostile pack of 3): the pack spreads round the player (PackFlank Surround), then rushes in
-- together; each hound winds up (Telegraph) before its bite. Night hunters; they back off from fires.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local MobBehaviors = require(Shared.logic.MobBehaviors)
local Combat = require(Shared.logic.MobBehaviorsCombat)
local Mobs = script.Parent.Parent
local MobActions = require(Mobs.MobActions)
local MobRegistry = require(Mobs.MobRegistry)
local MobState = require(Mobs.MobState)
local MobWorld = require(Mobs.MobWorld)
local SpeciesKit = require(Mobs.Drivers.SpeciesKit)
local Types = require(Mobs.MobTypes)

type MobRow = Types.MobRow
type Env = Types.Env

local PackFlank = MobBehaviors.PackFlank

type Pack = {
	state: Combat.FlankState,
	at: number, -- env.now of the last compute (one compute per AI pass)
	phase: string,
	slots: { [MobRow]: Combat.Point },
}

local PACK_STALE_SECONDS = 30
local packs: { [number]: Pack } = {}

-- One PackFlank step per pack per AI pass (the first member to step computes it for the rest).
local function packFor(row: MobRow, env: Env): Pack?
	local id = row.groupId
	if id == nil then
		return nil
	end
	local pack = packs[id]
	if pack and pack.at == env.now then
		return pack
	end
	for otherId, other in packs do
		if env.now - other.at > PACK_STALE_SECONDS then
			packs[otherId] = nil -- pack gone (all dead / despawned)
		end
	end
	local members = MobRegistry.group(id)
	local points: { Combat.Point } = {}
	local cx, cz = 0, 0
	for i, member in members do
		local p = member.root.Position
		points[i] = { x = p.X, z = p.Z }
		cx += p.X
		cz += p.Z
	end
	local n = math.max(#members, 1)
	local centroid = Vector3.new(cx / n, row.root.Position.Y, cz / n)
	local info, d = MobWorld.nearestPlayer(centroid, env.infos)
	local def = SpeciesKit.def(row)
	local target: Combat.Point? = nil
	if info and d ~= nil and d <= SpeciesKit.aggro(row) * 1.5 then
		target = { x = info.root.Position.X, z = info.root.Position.Z }
	end
	local state = if pack then pack.state else PackFlank.new()
	local dt = if pack then math.clamp(env.now - pack.at, 0, 1) else 0
	local newState, out = PackFlank.step(state, {
		members = points,
		target = target,
		radius = def.tune.flankRadius,
		engageSeconds = def.tune.engageSeconds,
		slotTolerance = def.tune.slotTolerance,
	}, dt)
	local slots: { [MobRow]: Combat.Point } = {}
	for i, member in members do
		slots[member] = out.slots[i]
	end
	local fresh: Pack = { state = newState, at = env.now, phase = out.phase, slots = slots }
	packs[id] = fresh
	return fresh
end

local ScrapHound: Types.Species = {
	step = function(row: MobRow, env: Env)
		local def = SpeciesKit.def(row)
		if SpeciesKit.leaveAtDawn(row, env) or SpeciesKit.retreatFromFire(row, env) then
			SpeciesKit.resetTelegraph(row)
			return
		end
		local info, d = env.nearestInfo, env.nearest
		local pack = packFor(row, env)
		if not info or d == nil or pack == nil or d > SpeciesKit.aggro(row) * 1.5 then
			SpeciesKit.resetTelegraph(row)
			row.lastAction = "Wander"
			MobState.setTarget(row, nil)
			MobActions.wander(row, env.now, SpeciesKit.rng)
			return
		end
		local slot = pack.slots[row]
		local windingUp = row.sp.tele ~= nil and (row.sp.tele :: Combat.TelegraphState).left ~= nil
		if pack.phase == "Rush" or windingUp or d <= def.attackRange then
			SpeciesKit.engage(row, env, {
				chaseSpeed = def.runSpeed,
				leeway = Config.Night.StrikeLeeway,
				aoe = false,
			})
		elseif slot then
			-- Surround: take the flank slot (never into a fire circle's middle: the chase clamp is not needed
			-- because slots sit on a ring round the player, and retreatFromFire pushes it back out).
			row.lastAction = "Chase"
			MobState.setTarget(row, info.player)
			MobActions.moveToward(row, slot.x, slot.z, def.runSpeed)
		end
	end,
}

return ScrapHound
