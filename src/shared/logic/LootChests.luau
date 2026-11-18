--!strict
-- Pure seeded chest planning (no Roblox APIs). One chest slot + the run seed => the same chest rarity and
-- contents every time, on every server, independent of the order chests are registered or opened.
-- Weights come in as `LootRoll.Tables` (server/Loot/LootTables); this module never requires them.

local LootRoll = require("./LootRoll")

export type Slot = {
	x: number,
	y: number,
	z: number,
	depth: number, -- depth tier 0..MaxTier
	structureType: string,
	ring: number, -- biome ring 0..3
	index: number?, -- chest index inside its structure (disambiguates stacked slots)
}
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

function LootChests.plan(
	t: LootRoll.Tables,
	pool: LootRoll.Pool,
	runSeed: number,
	slot: Slot
): ChestPlan
	local seed = LootChests.chestSeed(runSeed, slot)
	local rng = LootChests.makeRng(seed)
	local rarity = LootRoll.pickChestRarity(t, slot.ring, slot.structureType, slot.depth, rng)
	return { rarity = rarity, items = LootRoll.rollChest(t, pool, rarity, rng), seed = seed }
end

return LootChests
