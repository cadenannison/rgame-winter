--!strict
-- Massive structures A (research station, mine complex): pure plans against Config.Massive via
-- MassiveRules.validatePlan plus the kit rules (reachability, doors, ramps, chests, PG text, determinism).

local Config = require("../src/shared/Config")
local MassiveRules = require("../src/shared/logic/MassiveRules")
local Kit = require("../src/shared/logic/StructurePlanKitA")
local ResearchStationPlan = require("../src/shared/logic/ResearchStationPlan")
local MineComplexPlan = require("../src/shared/logic/MineComplexPlan")

local SEEDS = { 1, 7, 1234, 98765, 424242 }

type Builder = (number) -> Kit.Plan

local function sorted(plan: Kit.Plan): string
	local parts: { string } = {}
	for _, c in plan.chests do
		table.insert(parts, `{c.room}:{c.x}:{c.z}:{c.depth}`)
	end
	for _, g in plan.dressing do
		for _, b in g.boxes do
			if b.text ~= nil then
				table.insert(parts, b.text)
			end
		end
	end
	for _, b in plan.shell do
		if b.light ~= nil then
			table.insert(parts, tostring(b.light.flicker))
		end
	end
	return table.concat(parts, "|")
end

local function suite(check: (string, boolean) -> (), label: string, id: string, build: Builder)
	local def = Config.Massive.Structures[id]
	local allOk = true
	local firstErr = ""
	for _, seed in SEEDS do
		local plan = build(seed)
		local errs = Kit.validate(plan)
		if #errs > 0 then
			allOk = false
			firstErr = errs[1]
		end
	end
	check(`{label}: plan passes MassiveRules and kit rules for every seed {firstErr}`, allOk)

	local plan = build(1)
	local s = plan.summary
	check(
		`{label}: footprint {s.footprintX}x{s.footprintZ} >= {def.MinFootprintX}x{def.MinFootprintZ}`,
		s.footprintX >= def.MinFootprintX and s.footprintZ >= def.MinFootprintZ
	)
	check(
		`{label}: many rooms ({s.rooms}) and levels ({s.levels})`,
		s.rooms >= def.MinRooms * 2 and s.levels >= def.MinLevels
	)
	check(
		`{label}: underground depth {s.undergroundDepth} >= {def.UndergroundDepth}`,
		s.undergroundDepth >= def.UndergroundDepth
	)
	check(
		`{label}: parts {s.parts}/{def.Budget.Parts} dressing {s.dressingParts}/{def.Budget.DressingParts} lights {s.lights}/{def.Budget.Lights} particles {s.particles}/{def.Budget.Particles}`,
		s.parts <= def.Budget.Parts
			and s.dressingParts <= def.Budget.DressingParts
			and s.lights <= def.Budget.Lights
			and s.particles <= def.Budget.Particles
	)
	check(
		`{label}: corridors {s.minCorridorWidth} wide, ceilings {s.minCeilingHeight} high`,
		s.minCorridorWidth >= Config.Massive.CorridorWidthMin
			and s.minCeilingHeight >= Config.Massive.CeilingHeightMin
	)
	check(
		`{label}: every room reaches the surface`,
		#Kit.unreachable(plan) == 0 and #plan.exits >= 2
	)
	check(
		`{label}: footprint radius covers the plan`,
		(function(): boolean
			local r = MassiveRules.footprintRadius(id)
			for _, room in plan.rooms do
				for _, x in { room.x0, room.x1 } do
					for _, z in { room.z0, room.z1 } do
						if math.sqrt(x * x + z * z) > r then
							return false
						end
					end
				end
			end
			return true
		end)()
	)

	-- determinism and seed variation
	check(`{label}: same seed, same plan`, sorted(build(99)) == sorted(build(99)))
	check(`{label}: another seed varies notes or chests`, sorted(build(1)) ~= sorted(build(2)))

	-- loot: deepest chests live in the deepest rooms
	local byLevel: { [number]: { number } } = {}
	for _, c in plan.chests do
		local room = plan.byId[c.room]
		local list = byLevel[room.level] or {}
		byLevel[room.level] = list
		table.insert(list, c.depth)
	end
	local deepest, shallowest = 0, 0
	local maxDeepDepth, maxShallowDepth = 0, 0
	for level, list in byLevel do
		deepest, shallowest = math.min(deepest, level), math.max(shallowest, level)
		for _, d in list do
			if level == deepest then
				maxDeepDepth = math.max(maxDeepDepth, d)
			end
		end
	end
	local shallowList: { number } = byLevel[shallowest] or {}
	for _, d in shallowList do
		maxShallowDepth = math.max(maxShallowDepth, d)
	end
	maxDeepDepth = 0
	local deepList: { number } = byLevel[deepest] or {}
	for _, d in deepList do
		maxDeepDepth = math.max(maxDeepDepth, d)
	end
	check(
		`{label}: chests deepest at depth {maxDeepDepth} (surface {maxShallowDepth})`,
		maxDeepDepth == Config.Loot.MaxDepthTier and maxShallowDepth <= 1 and #plan.chests >= 12
	)
	local monotone = true
	for _, c in plan.chests do
		local room = plan.byId[c.room]
		if room.level == 0 and c.depth > 1 then
			monotone = false
		end
		if room.level <= -2 and c.depth < 2 then
			monotone = false
		end
	end
	check(`{label}: chest depth grows with level`, monotone)

	-- horror hooks and atmosphere
	check(`{label}: lurker spots and ambient cues exist`, #plan.lurkers >= 5 and #plan.cues >= 6)
	local eyes, notes, signs, claws = 0, 0, 0, 0
	for _, g in plan.dressing do
		for _, b in g.boxes do
			if b.role == "Eyes" then
				eyes += 1
			elseif b.role == "Note" then
				notes += 1
			elseif b.role == "Sign" then
				signs += 1
			elseif b.style == "Scratch" then
				claws += 1
			end
		end
	end
	check(
		`{label}: eyes {eyes}, notes {notes}, claw marks {claws}, one sign per room`,
		eyes >= 10 and notes >= 8 and claws >= 8 and signs >= s.rooms
	)
	local flicker = 0
	for _, b in plan.shell do
		if b.light ~= nil and b.light.flicker then
			flicker += 1
		end
	end
	check(`{label}: flickering lights ({flicker})`, flicker >= 3)

	-- loot slots never share a spot
	local seen: { [string]: boolean } = {}
	local unique = true
	for _, c in plan.chests do
		local key = `{c.room}:{c.x}:{c.z}`
		if seen[key] then
			unique = false
		end
		seen[key] = true
	end
	check(`{label}: chest slots are unique`, unique)
end

return function(check: (string, boolean) -> ())
	suite(check, "research station", "ResearchStation", ResearchStationPlan.plan)
	suite(check, "mine complex", "MineComplex", MineComplexPlan.plan)

	local station = ResearchStationPlan.plan(1)
	local mine = MineComplexPlan.plan(1)
	check(
		"structures A: station has three levels and halls ramp between them",
		station.summary.levels == 3
			and station.byId.hallW.hall ~= nil
			and station.byId.hallE.hall ~= nil
	)
	check(
		"structures A: mine has four levels and a cavern taller than the tunnels",
		mine.summary.levels == 4 and mine.byId.cav.h > Config.Massive.CeilingHeightMin * 2
	)
	check(
		"structures A: ramps are gentle (<= 30 degrees)",
		(function(): boolean
			for _, plan in { station, mine } do
				for _, room in plan.rooms do
					local hall = room.hall
					if hall ~= nil then
						local run = math.abs(hall.rampTo - hall.rampFrom)
						if
							math.deg(math.atan2(hall.yHigh - hall.yLow, run)) > Kit.MAX_RAMP_DEGREES
						then
							return false
						end
					end
				end
			end
			return true
		end)()
	)
	check(
		"structures A: Massive ids are configured",
		Config.Massive.Structures.ResearchStation ~= nil
			and Config.Massive.Structures.MineComplex ~= nil
	)
end
