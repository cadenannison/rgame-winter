--!strict
-- SiteGround (pure terrain grounding): flat, sloped, steep, cliff-edge and water footprints, relocation,
-- skirt blending, and the ground-snap helpers used by placement. Also runs over real seeded terrain.

local Config = require("../src/shared/Config")
local SiteGround = require("../src/shared/logic/SiteGround")
local World = require("../src/shared/logic/World")

local G = Config.SiteGround
local HALF = 30

local function flat(_x: number, _z: number): number
	return 0
end

local function sloped(slopePerStud: number): SiteGround.HeightFn
	return function(x: number, _z: number): number
		return 200 + math.floor(x * slopePerStud) -- well above water
	end
end

return function(check: (string, boolean) -> ())
	-- flat
	local p = SiteGround.plan(flat, 0, 0, HALF, HALF)
	check("site: flat ok, level at 0", p.ok and p.mode == "level" and p.baseY == 0)
	check("site: flat stats", p.sample.min == 0 and p.sample.max == 0 and p.sample.range == 0)
	check(
		"site: grid samples corners, edges and centre",
		p.sample.nx % 2 == 1
			and p.sample.nz % 2 == 1
			and #p.sample.heights == p.sample.nx * p.sample.nz
	)

	-- gentle slope: within FillRange -> level at the median, in range
	local gentle = SiteGround.plan(sloped(0.05), 0, 0, HALF, HALF)
	check(
		"site: gentle slope levels at median",
		gentle.ok
			and gentle.mode == "level"
			and gentle.baseY >= gentle.sample.min
			and gentle.baseY <= gentle.sample.max
	)

	-- moderate slope: above FillRange, below MaxRange -> foundation at the highest sample
	local moderate = SiteGround.plan(sloped((G.FillRange + 2) / (2 * HALF)), 0, 0, HALF, HALF)
	check(
		"site: moderate slope needs a foundation at the highest sample",
		moderate.ok and moderate.mode == "foundation" and moderate.baseY == moderate.sample.max
	)

	-- steep: range over MaxRange -> reject
	local steep = SiteGround.plan(sloped(1), 0, 0, HALF, HALF)
	check("site: steep slope rejected", not steep.ok and steep.mode == "reject")

	-- cliff edge: one half of the footprint a cliff-step higher than the other
	local function cliff(x: number, _z: number): number
		return if x > 0 then G.CliffStep + 2 else 0
	end
	local cl = SiteGround.plan(cliff, 0, 0, HALF, HALF)
	check("site: cliff edge rejected", not cl.ok and (cl.reason == "Cliff" or cl.reason == "Range"))
	local lowCliff = SiteGround.plan(function(x: number, _z: number): number
		return if x > 0 then G.CliffStep + 1 else 0
	end, 0, 0, HALF, HALF)
	check(
		"site: cliff step over CliffStep rejected",
		not lowCliff.ok and lowCliff.reason == "Cliff"
	)

	-- water / lake
	local function lake(x: number, z: number): number
		return if x * x + z * z < 20 * 20 then G.WaterHeight - 2 else 0
	end
	local w = SiteGround.plan(lake, 0, 0, HALF, HALF)
	check("site: lake footprint rejected", not w.ok and w.reason == "Water")
	local dry = SiteGround.plan(lake, 200, 0, HALF, HALF)
	check("site: dry footprint away from the lake ok", dry.ok)

	-- relocation: bad here, good further east
	local function mixed(x: number, z: number): number
		return if x < 15 then sloped(1)(x, z) else 0
	end
	local relocated = SiteGround.relocate(mixed, 0, 0, 10, 10, nil)
	check("site: relocate finds a usable site", relocated ~= nil and relocated.ok)
	check(
		"site: relocate stays inside RelocateRadius",
		relocated ~= nil
			and math.sqrt(relocated.cx ^ 2 + relocated.cz ^ 2) <= G.RelocateRadius + 0.001
	)
	check(
		"site: relocate returns nil when nothing fits",
		SiteGround.relocate(sloped(1), 0, 0, HALF, HALF, nil) == nil
	)
	local vetoed = SiteGround.relocate(flat, 0, 0, 10, 10, function(x: number, _z: number): boolean
		return x > 5
	end)
	check("site: relocate honours the accept filter", vetoed ~= nil and vetoed.cx > 5)

	-- skirt: base inside, original ground beyond SkirtWidth, monotonic in between (no hard edge)
	local plan = SiteGround.plan(sloped(0.1), 0, 0, HALF, HALF)
	local ground = plan.baseY + 20
	check("site: skirt inside = base", SiteGround.targetHeight(plan, ground, 0, 0) == plan.baseY)
	check(
		"site: skirt outside = ground",
		SiteGround.targetHeight(plan, ground, HALF + G.SkirtWidth + 1, 0) == ground
	)
	local monotonic, maxStep = true, 0
	local prev = plan.baseY
	for d = 0, G.SkirtWidth do
		local t = SiteGround.targetHeight(plan, ground, HALF + d, 0)
		if (ground >= plan.baseY and t < prev) or (ground < plan.baseY and t > prev) then
			monotonic = false
		end
		maxStep = math.max(maxStep, math.abs(t - prev))
		prev = t
	end
	check("site: skirt blends monotonically", monotonic)
	check(
		"site: skirt has no hard step (<= Terrain.MaxStep per stud-block)",
		maxStep <= Config.Terrain.MaxStep
	)

	-- ground snap
	check("site: snapY nil without hits", SiteGround.snapY({}) == nil)
	local snapped = SiteGround.snapY({ 3, 5, 4 })
	check("site: snapY = highest hit + SinkMargin", snapped == 5 + G.SinkMargin)
	local offs = SiteGround.footprintOffsets(4, 2, 0)
	check("site: footprint offsets include centre + corners", #offs == 9)
	check("site: zero footprint dedupes", #SiteGround.footprintOffsets(0, 0, 0.7) == 1)

	-- real seeded terrain: every plan is consistent (ok <=> not reject; base within sample range)
	local consistent, anyOk = true, false
	for _, seed in { 1, 2, 3, 42 } do
		for i = -5, 5 do
			for j = -5, 5 do
				local sp = SiteGround.plan(function(x: number, z: number): number
					return World.heightAt(seed, x, z)
				end, i * 200, j * 200, 20, 20)
				if sp.ok ~= (sp.mode ~= "reject") then
					consistent = false
				end
				if sp.ok then
					anyOk = true
					if sp.baseY < sp.sample.min or sp.baseY > sp.sample.max then
						consistent = false
					end
				end
			end
		end
	end
	check("site: real terrain plans consistent", consistent and anyOk)
end
