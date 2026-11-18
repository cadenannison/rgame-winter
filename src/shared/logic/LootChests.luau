--!strict
-- Pure seeded chest planning (no Roblox APIs). One chest slot + the run seed => the same chest rarity and
-- contents every time, on every server, independent of the order chests are registered or opened.
-- Weights come in as `LootRoll.Tables` (server/Loot/LootTables); this module never requires them.

local Config = require("../Config")
local Rarity = require("../data/Rarity")
local LootRoll = require("./LootRoll")

export type Slot = {
	x: number,
	y: number,
	z: number,
	depth: number, -- depth tier 0..MaxTier
	structureType: string,
	ring: number, -- biome ring 0..3
	index: number?, -- chest index inside its structure (disambiguates stacked slots)
	topMode: string?, -- "force" = top rarity (the Beacon's one), "exclude" = never top, nil = normal roll
}
-- A candidate chest position inside a structure (before the count/spread selection).
export type Candidate = { index: number, room: string?, depth: number }
export type Pick = { index: number, topMode: string? }
export type ChestPlan = { rarity: string, items: { LootRoll.Stack }, seed: number }

local LootChests = {}

-- Exact 32-bit multiply (doubles lose low bits above 2^53).
local function mul32(a: number, b: number): number
	local ah, al = bit32.rshift(a, 16), bit32.band(a, 0xFFFF)
	return bit32.band(al * b + bit32.band(ah * b, 0xFFFF) * 65536, 0xFFFFFFFF)
end

local function mix(h: number, v: number): number
	h = bit32.bxor(h, bit32.band(math.floor(v), 0xFFFFFFFF))
	h = mul32(h, 0x45D9F3B)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h
end

-- Deterministic per-chest seed from run seed, rounded position, structure type and index.
function LootChests.chestSeed(runSeed: number, slot: Slot): number
	local h = mix(0x9E3779B9, runSeed)
	h = mix(h, math.floor(slot.x + 0.5))
	h = mix(h, math.floor(slot.y + 0.5))
	h = mix(h, math.floor(slot.z + 0.5))
	h = mix(h, slot.index or 0)
	for i = 1, #slot.structureType do
		h = mix(h, string.byte(slot.structureType, i))
	end
	return h
end

-- xorshift32 over a mixed seed: () -> [0,1)
function LootChests.makeRng(seed: number): LootRoll.Rng
	local state = mix(bit32.band(seed, 0xFFFFFFFF), 0x1234567)
	if state == 0 then
		state = 0x2545F491
	end
	return function(): number
		state = bit32.bxor(state, bit32.band(bit32.lshift(state, 13), 0xFFFFFFFF))
		state = bit32.bxor(state, bit32.rshift(state, 17))
		state = bit32.bxor(state, bit32.band(bit32.lshift(state, 5), 0xFFFFFFFF))
		return state / 4294967296
	end
end

-- Config.Loot.RingRarityBonus for a ring (clamped to the table): rarity WEIGHTING, never the chest count.
function LootChests.ringBonus(ring: number): number
	local list = Config.Loot.RingRarityBonus
	return list[math.clamp(ring + 1, 1, #list)] or 0
end

-- Count rule key of a structure id (POI kind or massive id): Config.Loot.StructureClass / DefaultClass.
function LootChests.classOf(structureType: string): string
	return Config.Loot.StructureClass[structureType] or Config.Loot.DefaultClass
end

function LootChests.ruleOf(structureType: string): Config.ChestCountRule
	local rules = Config.Loot.Chests
	return rules[LootChests.classOf(structureType)] or rules[Config.Loot.DefaultClass]
end

local function keyHash(runSeed: number, key: string): number
	local h = mix(0x7F4A7C15, runSeed)
	for i = 1, #key do
		h = mix(h, string.byte(key, i))
	end
	return h
end

-- Deterministic chest count for a structure: rule Min..Max from the run seed and the structure key.
-- Never depends on ring (rings change rarity weighting only).
function LootChests.countFor(
	structureType: string,
	runSeed: number,
	key: string,
	available: number
): number
	local rule = LootChests.ruleOf(structureType)
	local rng = LootChests.makeRng(keyHash(runSeed, key))
	local n = rule.Min + math.floor(rng() * (rule.Max - rule.Min + 1))
	return math.min(n, available)
end

-- Picks which candidate chest positions of one structure are real chests: a deterministic count for its
-- class, spread over distinct rooms first and over different depth tiers, so finding them takes exploring.
-- A class with TopRarity (Beacon) marks exactly that many picks (the deepest) "force" top rarity; all
-- others "exclude" it. Order of `candidates` does not matter (sorted by index).
function LootChests.selectSlots(
	structureType: string,
	runSeed: number,
	key: string,
	candidates: { Candidate }
): { Pick }
	local pool = table.clone(candidates)
	table.sort(pool, function(a, b)
		return a.index < b.index
	end)
	local count = LootChests.countFor(structureType, runSeed, key, #pool)
	local rng = LootChests.makeRng(keyHash(runSeed, key .. "#pick"))
	local usedRooms: { [string]: boolean } = {}
	local usedDepths: { [number]: boolean } = {}
	local chosen: { Candidate } = {}
	for _ = 1, count do
		local fresh: { Candidate } = {}
		for _, c in pool do
			if c.room == nil or not usedRooms[c.room] then
				table.insert(fresh, c)
			end
		end
		local source: { Candidate } = if #fresh > 0 then fresh else pool
		local newDepth: { Candidate } = {}
		for _, c in source do
			if not usedDepths[c.depth] then
				table.insert(newDepth, c)
			end
		end
		local options: { Candidate } = if #newDepth > 0 then newDepth else source
		local pick = options[math.floor(rng() * #options) + 1]
		table.insert(chosen, pick)
		if pick.room then
			usedRooms[pick.room] = true
		end
		usedDepths[pick.depth] = true
		table.remove(pool, table.find(pool, pick) :: number)
	end
	local rule = LootChests.ruleOf(structureType)
	local topCount = rule.TopRarity or 0
	-- the deepest picks (ties: lower index) get the forced top rarity
	local byDepth = table.clone(chosen)
	table.sort(byDepth, function(a, b)
		if a.depth ~= b.depth then
			return a.depth > b.depth
		end
		return a.index < b.index
	end)
	local top: { [number]: boolean } = {}
	for i = 1, math.min(topCount, #byDepth) do
		top[byDepth[i].index] = true
	end
	local out: { Pick } = {}
	for _, c in chosen do
		local mode: string? = nil
		if topCount > 0 then
			mode = if top[c.index] then "force" else "exclude"
		end
		table.insert(out, { index = c.index, topMode = mode })
	end
	table.sort(out, function(a, b)
		return a.index < b.index
	end)
	return out
end

function LootChests.plan(
	t: LootRoll.Tables,
	pool: LootRoll.Pool,
	runSeed: number,
	slot: Slot
): ChestPlan
	local seed = LootChests.chestSeed(runSeed, slot)
	local rng = LootChests.makeRng(seed)
	local rarity = if slot.topMode == "force"
		then Rarity.List[#Rarity.List]
		else LootRoll.pickChestRarity(
			t,
			slot.ring,
			slot.structureType,
			slot.depth,
			rng,
			LootChests.ringBonus(slot.ring),
			slot.topMode == "exclude"
		)
	return { rarity = rarity, items = LootRoll.rollChest(t, pool, rarity, rng), seed = seed }
end

return LootChests
