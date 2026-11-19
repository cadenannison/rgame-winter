--!strict
-- Pure natural-spawn picker (no Roblox APIs): the one weighted table MobSpawner draws from (legacy biome rows
-- + species ring weights, caps, day density, dread) and a headless simulation of it for the creature-count
-- audit (tests/MobWildlifeTests.luau). Every number comes from Config.Mobs / Config.Wildlife.

local Config = require("../Config")
local Biomes = require("../data/Biomes")
local MobData = require("../data/Mobs")
local MobDread = require("./MobDread")
local MobRules = require("./MobRules")
local MobScaling = require("./MobScaling")
local MobSpecies = require("./MobSpecies")
local MobWildlife = require("./MobWildlife")

export type Ctx = {
	entries: { MobScaling.Entry },
	ring: number,
	day: number,
	danger: boolean,
	dread: number, -- MobDread.factor for the anchor player (1 = neutral)
	live: { [string]: number }, -- live count per kind
	limits: boolean, -- true = legacy caps and day density apply (false reproduces the pre-audit picker)
}

export type SimOpts = {
	ring: number,
	day: number,
	danger: boolean,
	ticks: number, -- spawn ticks (one every Config.Mobs.SpawnInterval seconds)
	failChance: number, -- chance an attempt finds no valid site (ground, footprint, parts)
	rand: () -> number, -- [0, 1)
	limits: boolean,
}

local LEGACY_COST = 1 -- ArcticHare, Caribou, Wolf (MobKinds)

local MobSpawnPick = {}

-- Legacy spawn rows (animals and hostiles with biome lists; bosses never use the normal budget).
function MobSpawnPick.legacyEntries(): { MobScaling.Entry }
	local out: { MobScaling.Entry } = {}
	local function add(name: string, category: string, stats: Config.MobStats)
		table.insert(out, {
			kind = name,
			category = category,
			biomes = MobData.LegacyBiomes[name] or {},
			minDay = 1,
			nightOnly = stats.NightOnly,
			weight = stats.Weight,
		})
	end
	add("ArcticHare", "animal", Config.Mobs.Hare)
	add("Caribou", "animal", Config.Mobs.Caribou)
	add("Wolf", "hostile", Config.Mobs.Wolf)
	for _, def in MobData.List do
		if def.category == "animal" or def.category == "hostile" then
			table.insert(out, {
				kind = def.kind,
				category = def.category :: string,
				biomes = def.biomes,
				minDay = def.minDay,
				nightOnly = def.nightOnly,
				weight = def.weight,
			})
		end
	end
	table.sort(out, function(a, b)
		return a.kind < b.kind
	end)
	return out
end

-- Budget slots one mob of this kind holds.
function MobSpawnPick.cost(name: string): number
	local species = Config.Mobs.Species[name]
	if species then
		return species.cost
	end
	for _, def in MobData.List do
		if def.kind == name then
			return def.budgetCost
		end
	end
	return LEGACY_COST
end

-- Live cap of a kind (limits = false: species caps only, legacy kinds uncapped as before the audit).
function MobSpawnPick.cap(name: string, danger: boolean, limits: boolean): number
	local species = Config.Mobs.Species[name]
	if species then
		return if limits then MobWildlife.scaledCap(species.spawnCap, danger) else species.spawnCap
	end
	if not limits then
		return math.huge
	end
	local base = Config.Wildlife.LegacyCaps[name] or Config.Wildlife.LegacyDefaultCap
	return MobWildlife.scaledCap(base, danger)
end

-- Herd / pack size to spawn together, never past the kind's cap.
function MobSpawnPick.groupSize(
	name: string,
	live: number,
	danger: boolean,
	limits: boolean
): number
	local species = Config.Mobs.Species[name]
	local packSize = if species and species.packSize then species.packSize else 1
	return math.max(0, math.min(packSize, MobSpawnPick.cap(name, danger, limits) - live))
end

-- The weighted table at a spawn site: names and weights in a stable order.
function MobSpawnPick.weights(ctx: Ctx): ({ string }, { number })
	local names: { string } = {}
	local weights: { number } = {}
	local biomeId = Biomes.forRing(ctx.ring).id
	for _, row in MobScaling.spawnTable(ctx.entries, biomeId, ctx.day, ctx.danger) do
		if (ctx.live[row.kind] or 0) < MobSpawnPick.cap(row.kind, ctx.danger, ctx.limits) then
			table.insert(names, row.kind)
			table.insert(weights, row.weight * MobScaling.weightFactor(row.kind, ctx.day))
		end
	end
	for _, id in Config.Mobs.SpeciesIds do
		local def = Config.Mobs.Species[id]
		if (ctx.live[id] or 0) < MobSpawnPick.cap(id, ctx.danger, ctx.limits) then
			local w = MobSpecies.spawnWeight(def, ctx.ring, ctx.day, ctx.danger)
			if w > 0 then
				table.insert(names, id)
				table.insert(weights, MobDread.weight(def.role, w, ctx.dread))
			end
		end
	end
	return names, weights
end

function MobSpawnPick.pick(ctx: Ctx, roll01: number): string?
	local names, weights = MobSpawnPick.weights(ctx)
	local index = MobRules.pickWeighted(weights, roll01)
	return if index then names[index] else nil
end

-- Simulated live creatures after `ticks` spawn ticks for one solo player (nothing dies or despawns, so this is
-- the picker's fill level). Returns counts per kind and the total.
function MobSpawnPick.simulate(o: SimOpts): ({ [string]: number }, number)
	local entries = MobSpawnPick.legacyEntries()
	local live: { [string]: number } = {}
	local total, used = 0, 0
	local liveBudget = MobScaling.liveBudget(
		Config.Mobs.Budget,
		MobScaling.multipliers(o.day, o.ring, 1),
		1,
		o.danger,
		Config.Mobs.NightBudgetMultiplier
	)
	local budget = if o.limits then MobWildlife.budget(liveBudget, o.ring, 1) else liveBudget
	for _ = 1, o.ticks do
		local attempts = if o.limits then MobWildlife.attempts(total, o.ring) else 1
		for _ = 1, attempts do
			if total >= Config.Scaling.MaxLiveMobs then
				break
			end
			if o.rand() >= o.failChance then
				local name = MobSpawnPick.pick({
					entries = entries,
					ring = o.ring,
					day = o.day,
					danger = o.danger,
					dread = 1,
					live = live,
					limits = o.limits,
				}, o.rand())
				if name then
					local cost = MobSpawnPick.cost(name)
					local count = MobSpawnPick.groupSize(name, live[name] or 0, o.danger, o.limits)
					while count > 1 and cost > 0 and used + cost * count > budget do
						count -= 1
					end
					if count >= 1 and not (cost > 0 and used + cost * count > budget) then
						live[name] = (live[name] or 0) + count
						total += count
						used += cost * count
					end
				end
			end
		end
	end
	return live, total
end

return MobSpawnPick
