--!strict
-- Enterable structure plans (agent C): sizes vs Config.Shelter, open doorways, climbable watchtower, part
-- budgets, deterministic variants, terrain siting. Pure: PoiPlan + World only.

local Config = require("../src/shared/Config")
local PoiPlan = require("../src/shared/logic/PoiPlan")
local World = require("../src/shared/logic/World")

local S = Config.Shelter
local EXTRA_PARTS = 6 -- loot crate + hearth + surround (PoiService)

local function overlapsDoorway(box: PoiPlan.Box, door: PoiPlan.Doorway): boolean
	if not box.collide then
		return false
	end
	local hx, hz = box.sx / 2, box.sz / 2
	if (box.ry or 0) ~= 0 then
		local r = math.sqrt(hx * hx + hz * hz)
		hx, hz = r, r
	end
	-- doorway volume: through the wall, 3 studs inside, 4 studs outside; above the floor
	local x0, x1 = door.x - door.width / 2, door.x + door.width / 2
	local z0, z1 = door.z - door.thickness / 2 - 3, door.z + door.thickness / 2 + 4
	local y0, y1 = 0.01, door.height
	return box.x + hx > x0
		and box.x - hx < x1
		and box.z + hz > z0
		and box.z - hz < z1
		and box.y + box.sy / 2 > y0
		and box.y - box.sy / 2 < y1
end

local function named(plan: PoiPlan.Plan, name: string): PoiPlan.Box?
	for _, b in plan.boxes do
		if b.name == name then
			return b
		end
	end
	return nil
end

return function(check: (string, boolean) -> ())
	local worstParts = 0
	local allOk = true
	local sizesOk, doorsOk, collideOk, budgetOk, namesOk = true, true, true, true, true
	local lightOk, apronOk = true, true
	local maxDrop = S.MaxApronSteps * S.StairRise
	for _, kind in PoiPlan.EnterableKinds do
		local variants = PoiPlan.allVariants(kind)
		allOk = allOk and #variants >= 2
		for _, variant in variants do
			for _, drop in { 0, 4, maxDrop } do
				local plan = PoiPlan.build(kind, variant, drop, 8)
				if plan == nil then
					allOk = false
					continue
				end
				local count = #plan.boxes
				if drop == 0 then
					worstParts = math.max(worstParts, count)
				end
				local extra = if plan.hearth then EXTRA_PARTS else 1
				if count + extra > Config.Art.World.MaxPartsPerPoi then
					budgetOk = false
				end
				local seen: { [string]: boolean } = {}
				for _, b in plan.boxes do
					if seen[b.name] and not string.find(b.name, "^[%a]+$") then
						namesOk = false
					end
					seen[b.name] = true
					if b.sx <= 0 or b.sy <= 0 or b.sz <= 0 then
						namesOk = false
					end
				end
				if plan.apronSteps > 0 then
					local rise = drop / plan.apronSteps
					apronOk = apronOk
						and rise <= S.StairRise + 1e-6
						and plan.apronSteps <= S.MaxApronSteps
				else
					apronOk = apronOk and drop <= 0.5
				end
				if drop == 0 then
					local door = plan.doorway
					if door then
						local fuselage = kind == "plane"
						local minW = if fuselage then S.NarrowInteriorWidth else S.InteriorWidth
						local minD = if fuselage then S.NarrowInteriorWidth else S.InteriorDepth
						local minH = if fuselage then S.NarrowCeilingHeight else S.CeilingHeight
						local minDoorW = if fuselage then S.NarrowInteriorWidth else S.DoorWidth
						local minDoorH = if fuselage
							then S.NarrowCeilingHeight - 1
							else S.DoorHeight
						sizesOk = sizesOk
							and plan.interiorWidth >= minW
							and plan.interiorDepth >= minD
							and plan.ceiling >= minH
						doorsOk = doorsOk
							and door.width >= minDoorW
							and door.height >= minDoorH
							and door.height < plan.ceiling
						for _, b in plan.boxes do
							if overlapsDoorway(b, door) then
								doorsOk = false
							end
						end
						local floorBox, roofBox = named(plan, "Floor"), named(plan, "Roof")
						collideOk = collideOk
							and floorBox ~= nil
							and floorBox.collide
							and math.abs(floorBox.y + floorBox.sy / 2) < 1e-6
							and roofBox ~= nil
							and roofBox.collide
							and math.abs(roofBox.y - roofBox.sy / 2 - plan.ceiling) < 1e-6
						for _, n in { "WallBack", "WallLeft", "WallRight", "Foundation" } do
							local w = named(plan, n)
							collideOk = collideOk and w ~= nil and w.collide
						end
						local lit = false
						for _, b in plan.boxes do
							if b.light then
								lit = true
							end
						end
						if kind == "cabin" then
							lightOk = lightOk
								and lit
								and plan.hearth ~= nil
								and named(plan, "BedFrame") ~= nil
						end
						if kind == "ruin" then
							lightOk = lightOk and not lit -- ruins stay dark
						end
					end
				end
				-- crate stands on something inside the footprint
				local crate = plan.crate
				sizesOk = sizesOk
					and math.abs(crate.x) < plan.radius
					and math.abs(crate.z) < plan.radius
			end
		end
	end
	check("poi every enterable kind has >= 2 variants", allOk)
	check("poi interior/ceiling/door sizes meet Config.Shelter", sizesOk)
	check("poi doorway volumes are open (no collider inside)", doorsOk)
	check("poi floor walkable, walls/roof/foundation collide", collideOk)
	check("poi cabins lit with hearth and bed, ruins dark", lightOk)
	check("poi part budget within MaxPartsPerPoi (+crate/hearth)", budgetOk)
	check("poi MaxPartsPerStructure respected at drop 0", worstParts <= S.MaxPartsPerStructure)
	check("poi box names and sizes valid", namesOk)
	check("poi entry steps within StairRise and MaxApronSteps", apronOk)

	-- Watchtower: climbable without jumping
	local tower = PoiPlan.build("campsite", "Watchtower", 0, 4)
	local towerOk = tower ~= nil
	if tower then
		local steps: { PoiPlan.Box } = {}
		for _, b in tower.boxes do
			if string.find(b.name, "^Step") or string.find(b.name, "^Landing%d") then
				table.insert(steps, b)
			end
		end
		table.sort(steps, function(a, b)
			return a.y + a.sy / 2 < b.y + b.sy / 2
		end)
		local prev = 0
		local maxRise = 0
		for _, b in steps do
			local top = b.y + b.sy / 2
			if top - prev > 1e-6 then
				maxRise = math.max(maxRise, top - prev)
				prev = top
			end
		end
		local deck = named(tower, "Deck")
		local deckTop = if deck then deck.y + deck.sy / 2 else 0
		towerOk = towerOk and maxRise <= S.StairRise + 1e-6
		towerOk = towerOk and deck ~= nil and deckTop >= S.WatchtowerHeight - 1e-6
		towerOk = towerOk and math.abs(prev - deckTop) < 1e-6 -- last step is level with the deck
		towerOk = towerOk and deck ~= nil and deck.sx >= S.WatchtowerPlatformSize
		local step = named(tower, "Step1_1")
		towerOk = towerOk and step ~= nil and math.max(step.sx, step.sz) >= S.StairWidth
		local rail = named(tower, "RailN")
		towerOk = towerOk and rail ~= nil and rail.sy >= S.WatchtowerRailHeight
		-- the top step lies beside the deck and the east rail leaves it open
		local flightLen = 0
		for _, b in tower.boxes do
			if string.find(b.name, "^Step4_") then
				flightLen += 1
			end
		end
		local topStep = named(tower, `Step4_{flightLen}`)
		local railE = named(tower, "RailE")
		if deck and topStep and railE then
			local half = deck.sx / 2
			towerOk = towerOk and math.abs(topStep.z) <= half
			towerOk = towerOk and topStep.z - topStep.sz / 2 > railE.z + railE.sz / 2 - 1e-6
			towerOk = towerOk and topStep.x - topStep.sx / 2 >= half - 1e-6
		else
			towerOk = false
		end
		towerOk = towerOk and tower.enterable and tower.crate.y >= S.WatchtowerHeight
	end
	check("poi watchtower stairs climbable (rise, width, level top, open rail)", towerOk)

	-- Variant selection: deterministic, varied, valid per biome
	local detOk, variedOk, validOk = true, true, true
	for _, kind in PoiPlan.EnterableKinds do
		local seen: { [string]: boolean } = {}
		local distinct = 0
		for i = 1, 60 do
			local id = `{i * 7}:{kind}:{i % 3}`
			local a = PoiPlan.pickVariant(42, id, kind, "SnowyForest")
			local b = PoiPlan.pickVariant(42, id, kind, "SnowyForest")
			detOk = detOk and a == b
			validOk = validOk and table.find(PoiPlan.variantIds(kind, "SnowyForest"), a) ~= nil
			if not seen[a] then
				seen[a] = true
				distinct += 1
			end
		end
		variedOk = variedOk and distinct >= 2
	end
	check("poi variant pick deterministic", detOk)
	check("poi variants vary and are valid for the biome", variedOk and validOk)
	check(
		"poi variant differs across seeds",
		(function(): boolean
			for seed = 1, 30 do
				if
					PoiPlan.pickVariant(seed, "a:cabin:1", "cabin", "SnowyForest")
					~= PoiPlan.pickVariant(1, "a:cabin:1", "cabin", "SnowyForest")
				then
					return true
				end
			end
			return false
		end)()
	)

	-- Footprints (documented in INTEGRATION "C footprints")
	local footOk = true
	for _, kind in PoiPlan.EnterableKinds do
		local r = PoiPlan.kindFootprint(kind)
		footOk = footOk and r >= S.FootprintMargin + 7
		for _, variant in PoiPlan.allVariants(kind) do
			local plan = PoiPlan.build(kind, variant, 0, 0)
			footOk = footOk and plan ~= nil and plan.radius <= r
			if plan then
				local half = math.max(plan.interiorWidth, plan.interiorDepth) / 2
				footOk = footOk and plan.radius >= half + S.FootprintMargin
			end
		end
	end
	check("poi footprint radii cover structure plus margin", footOk)

	-- Siting on real terrain
	local siteOk = true
	for seed = 1, 4 do
		for _, p in { { 300, 420 }, { -700, 90 }, { 55, -980 }, { 640, 640 } } do
			local fn = function(x: number, z: number): number
				return World.heightAt(seed, x, z)
			end
			local hi, lo = PoiPlan.siteFloor(fn, p[1], p[2], 14)
			siteOk = siteOk and hi >= lo and hi >= fn(p[1], p[2]) and lo <= fn(p[1], p[2])
			local y1 = PoiPlan.chooseYaw(fn, p[1], p[2], 12, 2)
			local y2 = PoiPlan.chooseYaw(fn, p[1], p[2], 12, 2)
			siteOk = siteOk and y1 == y2 and y1 >= 0 and y1 <= 3
			local dx, dz = PoiPlan.doorDirection(y1)
			local chosen = fn(p[1] + dx * 12, p[2] + dz * 12)
			for k = 0, 3 do
				local ex, ez = PoiPlan.doorDirection(k)
				siteOk = siteOk and chosen <= fn(p[1] + ex * 12, p[2] + ez * 12)
			end
		end
	end
	check("poi siting: floor at max terrain, door faces lowest ground", siteOk)
end
