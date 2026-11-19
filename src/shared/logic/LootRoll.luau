--!strict
-- Pure loot rolling (no Roblox APIs). The weights live in server/Loot/LootTables (server-only, never replicated);
-- this module only defines their shape and the rolling math, so tests and the server share one implementation.
-- rng is any () -> number in [0, 1) (e.g. function() return random:NextNumber() end).

local Rarity = require("../data/Rarity")

export type Rng = () -> number
export type Range = { number } -- {min, max} inclusive integers
export type Weights = { [string]: number }
export type DepthRule = {
	PerTier: number, -- per depth tier, a chest rarity of rank r is weighted * (1 + PerTier)^(r-1)
	MaxTier: number, -- depthTier is clamped to 0..MaxTier
}
export type ChestTable = {
	categoryWeights: Weights, -- Rarity.Categories keys
	rarityWeights: Weights, -- item Rarity.List keys (an empty bucket falls back to the next lower rarity)
	items: Range, -- item stacks rolled per chest
}
export type Tables = {
	ringWeights: { Weights }, -- [ring + 1] -> chest rarity weights (ring 0 = start forest)
	structureWeights: { [string]: Weights }, -- structure type -> chest rarity multipliers (missing = 1)
	structureChests: { [string]: Range }, -- structure type -> chest slots per structure
	depth: DepthRule,
	chests: { [string]: ChestTable }, -- chest rarity -> table
	stackCounts: { [string]: Range }, -- loot category -> stack size for stackable items
}
export type PoolItem = { id: string, rarity: string, category: string, maxStack: number }
export type Pool = { items: { PoolItem }, byKey: { [string]: { PoolItem } } } -- key = category .. "/" .. rarity
export type ItemLike = { id: string, maxStack: number, rarity: string?, lootCategory: string? }
export type Stack = { id: string, count: number }

local LootRoll = {}

local function randomInt(range: Range, rng: Rng): number
	local lo, hi = range[1], range[2]
	return lo + math.floor(rng() * (hi - lo + 1))
end
LootRoll.randomInt = randomInt

-- Weighted pick over `order` (deterministic key order). Returns nil when every weight is <= 0.
function LootRoll.weightedPick(weights: Weights, order: { string }, rng: Rng): string?
	local total = 0
	for _, key in order do
		total += math.max(0, weights[key] or 0)
	end
	if total <= 0 then
		return nil
	end
	local roll = rng() * total
	local last: string? = nil
	for _, key in order do
		local w = math.max(0, weights[key] or 0)
		if w > 0 then
			last = key
			if roll < w then
				return key
			end
			roll -= w
		end
	end
	return last
end

-- Effective chest rarity weights for a ring, a structure type and a depth tier (0 = entrance, deeper = better).
function LootRoll.chestWeights(
	t: Tables,
	ring: number,
	structureType: string,
	depthTier: number,
	ringBonus: number? -- Config.Loot.RingRarityBonus: rank r weight * (1 + bonus * (r - 1))
): Weights
	local base = t.ringWeights[math.clamp(ring + 1, 1, #t.ringWeights)]
	local mult = t.structureWeights[structureType]
	local tier = math.clamp(depthTier, 0, t.depth.MaxTier)
	local out: Weights = {}
	for i, name in Rarity.List do
		local w = base[name] or 0
		if mult then
			w *= mult[name] or 1
		end
		out[name] = w * (1 + t.depth.PerTier * tier) ^ (i - 1) * (1 + (ringBonus or 0) * (i - 1))
	end
	return out
end

function LootRoll.pickChestRarity(
	t: Tables,
	ring: number,
	structureType: string,
	depthTier: number,
	rng: Rng,
	ringBonus: number?,
	excludeTop: boolean? -- never roll the top rarity (a Beacon has exactly one, placed on purpose)
): string
	local weights = LootRoll.chestWeights(t, ring, structureType, depthTier, ringBonus)
	if excludeTop then
		weights[Rarity.List[#Rarity.List]] = 0
	end
	local picked = LootRoll.weightedPick(weights, Rarity.List, rng)
	return picked or Rarity.List[1]
end

-- Number of loot chests a structure of this type holds (0 for unknown types).
function LootRoll.chestCount(t: Tables, structureType: string, rng: Rng): number
	local range = t.structureChests[structureType]
	return if range then randomInt(range, rng) else 0
end

function LootRoll.buildPool(items: { [string]: ItemLike }): Pool
	local pool: Pool = { items = {}, byKey = {} }
	local ids: { string } = {}
	for id in items do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local def = items[id]
		if def.rarity ~= nil and def.lootCategory ~= nil then
			local entry: PoolItem = {
				id = id,
				rarity = def.rarity,
				category = def.lootCategory,
				maxStack = def.maxStack,
			}
			table.insert(pool.items, entry)
			local key = `{entry.category}/{entry.rarity}`
			local bucket = pool.byKey[key] or {}
			table.insert(bucket, entry)
			pool.byKey[key] = bucket
		end
	end
	return pool
end

-- Pool entries for a category at a rarity, falling back to lower rarities when that bucket is empty.
-- `weightOf` (optional) drops items whose weight is <= 0 (e.g. iron before its ring) before the emptiness test.
export type ItemWeight = (id: string) -> number
function LootRoll.bucket(
	pool: Pool,
	category: string,
	rarity: string,
	weightOf: ItemWeight?
): { PoolItem }
	for r = Rarity.rank(rarity), 1, -1 do
		local bucket = pool.byKey[`{category}/{Rarity.List[r]}`]
		if bucket and weightOf then
			local kept: { PoolItem } = {}
			for _, item in bucket do
				if weightOf(item.id) > 0 then
					table.insert(kept, item)
				end
			end
			bucket = kept
		end
		if bucket and #bucket > 0 then
			return bucket
		end
	end
	return {}
end

-- Uniform pick among positive-weight items; an item with weight w < 1 is kept with probability w, otherwise
-- replaced by a full-weight (w >= 1) item of the same category at this rarity or lower.
local function pickItem(
	pool: Pool,
	category: string,
	rarity: string,
	bucket: { PoolItem },
	weightOf: ItemWeight?,
	rng: Rng
): PoolItem
	local item = bucket[math.floor(rng() * #bucket) + 1]
	if weightOf == nil then
		return item
	end
	local w = weightOf(item.id)
	if w >= 1 or rng() < w then
		return item
	end
	local full = LootRoll.bucket(pool, category, rarity, function(id: string): number
		local x = weightOf(id)
		return if x >= 1 then x else 0
	end)
	if #full == 0 then
		return item
	end
	return full[math.floor(rng() * #full) + 1]
end

-- Rolls the contents of one chest. Never returns more stacks than ChestTable.items[2].
function LootRoll.rollChest(
	t: Tables,
	pool: Pool,
	chestRarity: string,
	rng: Rng,
	weightOf: ItemWeight? -- per-item relative weight (1 = normal, 0 = never); nil = uniform
): { Stack }
	local chest = t.chests[chestRarity]
	local out: { Stack } = {}
	if chest == nil then
		return out
	end
	for _ = 1, randomInt(chest.items, rng) do
		local category = LootRoll.weightedPick(chest.categoryWeights, Rarity.Categories, rng)
		local rarity = LootRoll.weightedPick(chest.rarityWeights, Rarity.List, rng)
		if category and rarity then
			local bucket = LootRoll.bucket(pool, category, rarity, weightOf)
			if #bucket > 0 then
				local item = pickItem(pool, category, rarity, bucket, weightOf, rng)
				local range = t.stackCounts[category]
				local count = if item.maxStack > 1 and range then randomInt(range, rng) else 1
				table.insert(out, { id = item.id, count = math.clamp(count, 1, item.maxStack) })
			end
		end
	end
	return out
end

return LootRoll
