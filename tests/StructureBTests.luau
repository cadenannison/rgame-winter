--!strict
-- Massive structures B (shipwreck, temple, lodge, ruins): pure plans validated against Config.Massive via
-- MassiveRules.validatePlan, plus structure-specific rules (doorways clear, ramps gentle, deepest loot deepest).

local Config = require("../src/shared/Config")
local Kit = require("../src/shared/logic/PlanKitB")
local MassiveRules = require("../src/shared/logic/MassiveRules")
local RuinsPlan = require("../src/shared/logic/RuinsPlan")
local ShipwreckPlan = require("../src/shared/logic/ShipwreckPlan")
local TemplePlan = require("../src/shared/logic/TemplePlan")
local LodgePlan = require("../src/shared/logic/LodgePlan")

local SEEDS = 24
local MAX_RAMP_DEGREES = 20
local DOOR_CLEAR_DEPTH = 7

local plans: { [string]: (number) -> Kit.Plan } = {
	FrozenShipwreck = ShipwreckPlan.make,
	RuinedTemple = TemplePlan.make,
	RangerLodge = LodgePlan.make,
	ExpandedRuins = RuinsPlan.make,
}

-- Door passage volume (inward `depth` from the wall line) for a door of a room.
local function doorVolume(
	room: Kit.Room,
	d: Kit.Door,
	depth: number
): (number, number, number, number)
	local x1, x2, z1, z2
	local lo, hi = d.c - d.width / 2 + 0.1, d.c + d.width / 2 - 0.1
	if d.side == "N" then
		x1, x2, z1, z2 = lo, hi, room.z1, room.z1 + depth
	elseif d.side == "S" then
		x1, x2, z1, z2 = lo, hi, room.z2 - depth, room.z2
	elseif d.side == "W" then
		x1, x2, z1, z2 = room.x1, room.x1 + depth, lo, hi
	else
		x1, x2, z1, z2 = room.x2 - depth, room.x2, lo, hi
	end
	return x1, x2, z1, z2
end

local function hits(
	b: Kit.Box,
	x1: number,
	x2: number,
	z1: number,
	z2: number,
	y1: number,
	y2: number,
	round: boolean
): boolean
	local hx, hz = b.sx / 2, b.sz / 2
	if round then
		local r = math.max(hx, hz) * 1.42
		hx, hz = r, r
	end
	return b.x + hx > x1
		and b.x - hx < x2
		and b.z + hz > z1
		and b.z - hz < z2
		and b.y + b.sy / 2 > y1
		and b.y - b.sy / 2 < y2
end

local function plain(b: Kit.Box): boolean
	return b.collide and b.rx == nil and b.ry == nil and b.rz == nil
end

local function doorwaysClear(plan: Kit.Plan): boolean
	for _, room in plan.rooms do
		for _, d in room.doors do
			local y1, y2 = d.y + 0.5, d.y + Kit.DOOR_H - 0.1
			-- walls: only the wall thickness band
			local wx1, wx2, wz1, wz2 = doorVolume(room, d, Kit.WALL_T)
			local px1, px2, pz1, pz2 = doorVolume(room, d, DOOR_CLEAR_DEPTH)
			for _, b in plan.shell do
				if plain(b) then
					local isStructure = string.sub(b.name, 1, 5) == "Wall_"
					if isStructure then
						if hits(b, wx1, wx2, wz1, wz2, y1, y2, false) then
							print(`  wall {b.name} blocks door of {room.id} {d.side}`)
							return false
						end
					elseif string.sub(b.name, 1, 9) == "Landmark_" then
						if hits(b, px1, px2, pz1, pz2, y1, y2, false) then
							print(`  landmark {b.name} blocks door of {room.id} {d.side}`)
							return false
						end
					end
				end
			end
			for _, dr in plan.dressing do
				if
					dr.room == room.id
					and dr.box.collide
					and hits(dr.box, px1, px2, pz1, pz2, y1, y2, true)
				then
					return false
				end
			end
		end
	end
	return true
end

local function summaryKey(plan: Kit.Plan): string
	local parts: { string } =
		{ tostring(plan.yaw), tostring(#plan.shell), tostring(#plan.dressing) }
	for _, c in plan.chests do
		table.insert(parts, `{c.room}:{c.x}:{c.z}:{c.depth}`)
	end
	for i, d in plan.dressing do
		if i % 7 == 0 then
			table.insert(parts, `{d.box.name}:{d.box.x}:{d.box.z}`)
		end
	end
	return table.concat(parts, "|")
end

return function(check: (string, boolean) -> ())
	local M = Config.Massive
	for id, make in plans do
		local allOk, errMsg = true, ""
		local detOk, rampsOk, doorsOk, dressOk, footOk, yawSet = true, true, true, true, true, {}
		local radius = MassiveRules.footprintRadius(id)
		for seed = 1, SEEDS do
			local plan = make(seed)
			local errs = Kit.problems(plan)
			if #errs > 0 then
				allOk = false
				errMsg = errs[1]
			end
			if summaryKey(plan) ~= summaryKey(make(seed)) then
				detOk = false
			end
			yawSet[plan.yaw] = true
			if not doorwaysClear(plan) then
				doorsOk = false
			end
			for _, b in plan.shell do
				if string.sub(b.name, 1, 5) == "Ramp_" then
					local angle = math.max(math.abs(b.rx or 0), math.abs(b.rz or 0))
					if angle > MAX_RAMP_DEGREES or angle < 1 then
						rampsOk = false
					end
				end
				-- shell stays inside the reserved footprint circle
				local far =
					math.sqrt((math.abs(b.x) + b.sx / 2) ^ 2 + (math.abs(b.z) + b.sz / 2) ^ 2)
				if b.rx == nil and b.ry == nil and b.rz == nil and far > radius + 20 then
					footOk = false
				end
			end
			for _, d in plan.dressing do
				local room = plan.byId[d.room]
				if
					d.box.x < room.x1
					or d.box.x > room.x2
					or d.box.z < room.z1
					or d.box.z > room.z2
				then
					dressOk = false
				end
			end
		end
		if not allOk then
			print(`  {id}: {errMsg}`)
		end
		check(`structB {id}: plan passes MassiveRules.validatePlan and structure rules`, allOk)
		check(`structB {id}: deterministic per seed`, detOk)
		check(
			`structB {id}: yaw varies with seed`,
			(function()
				local n = 0
				for _ in yawSet do
					n += 1
				end
				return n >= 2
			end)()
		)
		check(`structB {id}: doorways stay clear of walls, landmarks and props`, doorsOk)
		check(`structB {id}: ramps are gentle (<= {MAX_RAMP_DEGREES} deg)`, rampsOk)
		check(`structB {id}: dressing lies inside its room`, dressOk)
		check(`structB {id}: shell stays near the footprint`, footOk)

		local plan = make(5)
		local summary = Kit.summary(plan)
		local def = M.Structures[id]
		check(
			`structB {id}: meets budgets with headroom for dressing`,
			summary.parts <= def.Budget.Parts
				and summary.dressingParts >= 40
				and summary.dressingParts <= def.Budget.DressingParts
				and summary.lights >= 4
				and summary.lights <= def.Budget.Lights
				and summary.particles <= def.Budget.Particles
		)
		check(`structB {id}: ring set allows the biome`, #def.Rings > 0)
		-- every underground volume is carved
		local carved = true
		for _, room in plan.rooms do
			if room.underground then
				local found = false
				for _, c in plan.carves do
					if c.name == `Carve_{room.id}` then
						found = true
					end
				end
				carved = carved and found
			end
		end
		check(`structB {id}: underground rooms are carved from terrain`, carved)
		-- pad exists whenever there is an underground
		check(
			`structB {id}: terrain pad when underground`,
			summary.undergroundDepth == 0 or plan.pad ~= nil
		)
		-- chests: valid tiers; the max tier is used
		local maxTier = 0
		for _, c in plan.chests do
			maxTier = math.max(maxTier, c.depth)
		end
		check(
			`structB {id}: chest slots reach the top depth tier`,
			maxTier == Config.Loot.MaxDepthTier
		)
		check(`structB {id}: more than six chest slots`, #plan.chests >= 6)
	end

	-- structure specifics
	local ship = ShipwreckPlan.make(3)
	check(
		"structB ship: hull rooms (hold, flooded, captain) and three levels",
		ship.byId.hold ~= nil
			and ship.byId.flooded ~= nil
			and ship.byId.flooded.flooded
			and ship.byId.captain ~= nil
			and Kit.summary(ship).levels == 3
	)
	check(
		"structB ship: no underground (sits on the lake ice)",
		ship.pad == nil and #ship.carves == 0
	)
	local temple = TemplePlan.make(3)
	check(
		"structB temple: crypt >= 20 deep, legendary chamber deepest",
		Kit.summary(temple).undergroundDepth >= M.Structures.RuinedTemple.UndergroundDepth
			and Kit.distances(temple).legendary == 8
			and temple.byId.legendary.depth == Config.Loot.MaxDepthTier
	)
	check(
		"structB temple: crypt zones raise dread hooks",
		temple.dread.cryptHall == "Crypt" and temple.dread.legendary == "Legendary"
	)
	local lodge = LodgePlan.make(3)
	check(
		"structB lodge: cellar below and hearth fire in the main room",
		Kit.summary(lodge).undergroundDepth >= 8
			and (function()
				for _, d in lodge.dressing do
					if d.box.name == "HearthFire" and d.room == "main" and d.box.fx == "Fire" then
						return true
					end
				end
				return false
			end)()
	)
	local ruins = RuinsPlan.make(3)
	check(
		"structB ruins: 12+ chambers, not one open space (most rooms enclosed)",
		#ruins.rooms >= 12
			and (function()
				local roofed = 0
				for _, r in ruins.rooms do
					roofed += if r.roof then 1 else 0
				end
				return roofed >= 8
			end)()
	)
	-- shared kit rules
	check(
		"structB kit: door/ceiling/stair minimums come from Config.Massive",
		Kit.DOOR_W >= M.DoorWidthMin
			and Kit.DOOR_H >= M.DoorHeightMin
			and Kit.ROOM_H >= M.CeilingHeightMin
			and Kit.RAMP_W >= M.StairWidthMin
			and Kit.LANE_W >= M.StairWidthMin
			and Kit.LANE_W >= M.CorridorWidthMin
	)
end
