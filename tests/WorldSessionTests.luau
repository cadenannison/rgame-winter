--!strict
-- World and session round: /debug tp resolver, camp fire and spawn pad grounding over many seeds, moonlight config.

local Config = require("../src/shared/Config")
local SiteGround = require("../src/shared/logic/SiteGround")
local TpResolve = require("../src/shared/logic/TpResolve")
local World = require("../src/shared/logic/World")
local WorldLayout = require("../src/shared/logic/WorldLayout")
local DebugCommands = require("../src/shared/logic/DebugCommands")

local FIRE_SIZE = 4 -- ChunkService CAMPFIRE_SIZE footprint
local SEEDS = 50
local DENSE_STEP = 0.5

local function ctxFor(): TpResolve.Ctx
	return {
		ringCount = 4,
		from = { x = 0, z = 0 },
		selfName = "Me",
		sites = {
			{
				key = "ResearchStation#1",
				id = "ResearchStation",
				x = 400,
				z = 0,
				ring = 2,
				radius = 60,
			},
			{
				key = "ResearchStation#2",
				id = "ResearchStation",
				x = -900,
				z = 0,
				ring = 3,
				radius = 60,
			},
			{ key = "MineComplex#1", id = "MineComplex", x = 0, z = 700, ring = 3, radius = 70 },
			{ key = "RuinedTemple#1", id = "RuinedTemple", x = 0, z = -300, ring = 2, radius = 40 },
		},
		players = { { name = "Bobby", x = 10, z = 10 }, { name = "Alice", x = 50, z = 0 } },
		aliases = Config.Debug.TpAliases,
		ringPoint = function(n: number): TpResolve.Vec2?
			return { x = n * 100, z = 0 }
		end,
		gap = 14,
		playerOffset = 5,
	}
end

return function(check: (string, boolean) -> ())
	local ctx = ctxFor()

	-- tp resolver
	local r = TpResolve.resolve("research", ctx)
	check(
		"tp: research -> nearest ResearchStation",
		r.ok and string.find(r.name, "ResearchStation#1", 1, true) ~= nil
	)
	check("tp: approach stops outside the footprint", r.ok and r.x == 400 - (60 + 14) and r.z == 0)
	local b = TpResolve.resolve("Beacon", ctx)
	check(
		"tp: beacon alias, any case",
		b.ok and string.find(b.name, "ResearchStation", 1, true) ~= nil
	)
	local second = TpResolve.resolve("research 2", ctx)
	check(
		"tp: research 2 is the second station",
		second.ok and string.find(second.name, "#2", 1, true) ~= nil
	)
	check("tp: research 3 reports the count", not TpResolve.resolve("research 3", ctx).ok)
	check("tp: fuzzy prefix 'mine'", TpResolve.resolve("mine", ctx).ok)
	check("tp: fuzzy 'research station'", TpResolve.resolve("Research Station", ctx).ok)
	check("tp: structure id form", TpResolve.resolve("structure RuinedTemple", ctx).ok)
	check("tp: structure n form", TpResolve.resolve("structure 2", ctx).ok)
	local ring3 = TpResolve.resolve("ring 3", ctx)
	check("tp: ring 3", ring3.ok and ring3.x == 300 and ring3.name == "ring 3")
	check("tp: ring3 without space", TpResolve.resolve("ring3", ctx).ok)
	check("tp: ring 9 out of range", not TpResolve.resolve("ring 9", ctx).ok)
	check("tp: ring x is an error", not TpResolve.resolve("ring x", ctx).ok)
	local bob = TpResolve.resolve("bob", ctx)
	check("tp: player prefix", bob.ok and bob.name == "Bobby" and bob.x == 15)
	local nobody = TpResolve.resolve("zzzz", ctx)
	check(
		"tp: unknown target gives a clear error",
		not nobody.ok and string.find(nobody.error, "unknown tp target", 1, true) ~= nil
	)
	check("tp: empty query is an error", not TpResolve.resolve("   ", ctx).ok)
	local parsed = DebugCommands.parseTp("research", 4)
	check("tp: parseTp keeps the raw text", parsed ~= nil and parsed.text == "research")
	local badRing = DebugCommands.parseTp("ring 9", 4)
	check("tp: parseTp passes a bad ring to the resolver", badRing ~= nil and badRing.ring == nil)

	-- camp fire and spawn pad over many seeds
	local fireOk, padOk, flatPadOk = true, true, true
	for seed = 1, SEEDS do
		local layout = WorldLayout.generate(seed * 7919, Config.World)
		local cx, cz = layout.camp.position.x, layout.camp.position.z
		local function ground(x: number, z: number): number
			return World.heightAt(layout.seed, x, z, cx, cz)
		end
		local pad = Config.SpawnPadSize
		local sx, sz = cx + Config.World.CampSpawnOffset, cz
		local fireY = SiteGround.footprintTop(ground, cx, cz, FIRE_SIZE, FIRE_SIZE)
		local padY = SiteGround.footprintTop(ground, sx, sz, pad[1], pad[3])
		local half = FIRE_SIZE / 2
		local x = -half
		while x <= half do
			local z = -half
			while z <= half do
				if fireY < ground(cx + x, cz + z) then
					fireOk = false
				end
				z += DENSE_STEP
			end
			x += DENSE_STEP
		end
		x = -pad[1] / 2
		while x <= pad[1] / 2 do
			local z = -pad[3] / 2
			while z <= pad[3] / 2 do
				if padY < ground(sx + x, sz + z) then
					padOk = false
				end
				z += DENSE_STEP
			end
			x += DENSE_STEP
		end
		if padY < Config.Terrain.BaseHeight or fireY < Config.Terrain.BaseHeight then
			flatPadOk = false
		end
	end
	check("camp: fire sits at or above every footprint sample (50 seeds)", fireOk)
	check("camp: spawn pad sits at or above every footprint sample (50 seeds)", padOk)
	check("camp: fire and pad never below the base height (50 seeds)", flatPadOk)
	-- uneven terrain: highest corner wins
	local slope = function(x: number, _z: number): number
		return math.floor(x)
	end
	check(
		"camp: footprintTop takes the highest sample on a slope",
		SiteGround.footprintTop(slope, 0, 0, 6, 6) >= 3
	)

	-- moonlight: readable but clearly darker than day
	local L = Config.Lighting
	local function lum(c: { number }): number
		return (c[1] + c[2] + c[3]) / 3
	end
	check("moon: ambient above black", lum(L.MoonAmbient) > 30 and lum(L.MoonOutdoorAmbient) > 30)
	check(
		"moon: ambient darker than day",
		lum(L.MoonAmbient) < lum(L.DayAmbient)
			and lum(L.MoonOutdoorAmbient) < lum(L.DayOutdoorAmbient)
	)
	check(
		"moon: brightness between zero and day",
		L.MoonBrightness > 0 and L.MoonBrightness < L.DayBrightness
	)
end
