--!strict
-- Pure, seeded placement of forage, resource nodes and relics (no Roblox APIs). Same seed + cell gives the
-- same entries, independent of load order. The server adapter (server/Forage/ForageService) decides which
-- entries become instances (near players, grounded, outside footprints, part budget).

local Config = require("../Config")
local World = require("./World")

export type Entry = {
	key: string, -- stable per seed ("f:cx:cz:i", "n:cx:cz", "r:siteKey:i")
	class: string, -- "forage" | "node" | "relic"
	kind: string, -- item id (also the ItemCatalog.Nodes kind)
	x: number,
	z: number,
	count: number, -- items this pick gives
}
export type Site = { key: string, x: number, z: number, radius: number, ring: number }

local ForagePlan = {}

local MOD = 4294967296
local MIX = 40503 -- small odd multiplier: products stay exact in doubles
local NODE_SLOT = 1000
local RELIC_SALT = 77

-- Uniform [0, 1) from integers. Deterministic.
function ForagePlan.rand(seed: number, a: number, b: number, c: number): number
	local h = (seed * 1013904223 + a * 374761393 + b * 668265263 + c * 2246822519) % MOD
	h = bit32.bxor(h, bit32.rshift(h, 15))
	h = (h * MIX) % MOD
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = (h * MIX) % MOD
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h / MOD
end

function ForagePlan.cellOf(x: number, z: number): (number, number)
	local size = Config.Forage.CellSize
	return math.floor(x / size), math.floor(z / size)
end

type RingKind = { minRing: number, maxRing: number, weight: number }

-- Weighted pick among kinds valid at `ring`; roll in [0, 1). Returns the list index or nil.
function ForagePlan.pickKind(kinds: { any }, ring: number, roll: number): number?
	local total = 0
	for _, entry in kinds do
		local k: RingKind = entry
		if ring >= k.minRing and ring <= k.maxRing then
			total += k.weight
		end
	end
	if total <= 0 then
		return nil
	end
	local target = roll * total
	for i, entry in kinds do
		local k: RingKind = entry
		if ring >= k.minRing and ring <= k.maxRing then
			target -= k.weight
			if target < 0 then
				return i
			end
		end
	end
	return nil
end

local function countIn(minCount: number, maxCount: number, roll: number): number
	return minCount + math.min(math.floor(roll * (maxCount - minCount + 1)), maxCount - minCount)
end

local function insideWorld(x: number, z: number): boolean
	local limit = World.halfExtent() - Config.Forage.EdgeMargin
	return math.abs(x) <= limit and math.abs(z) <= limit
end

-- Forage and node entries for one grid cell (cell = floor(pos / CellSize)).
function ForagePlan.cell(seed: number, cx: number, cz: number): { Entry }
	local F = Config.Forage
	local size = F.CellSize
	local out: { Entry } = {}
	for i = 1, F.ForagePerCellMax do
		if ForagePlan.rand(seed, cx, cz, i * 5) < F.ForageChance then
			local x = (cx + ForagePlan.rand(seed, cx, cz, i * 5 + 1)) * size
			local z = (cz + ForagePlan.rand(seed, cx, cz, i * 5 + 2)) * size
			if insideWorld(x, z) then
				local idx = ForagePlan.pickKind(
					F.Forage,
					World.ringAt(x, z),
					ForagePlan.rand(seed, cx, cz, i * 5 + 3)
				)
				if idx then
					local k = F.Forage[idx]
					table.insert(out, {
						key = `f:{cx}:{cz}:{i}`,
						class = "forage",
						kind = k.itemId,
						x = x,
						z = z,
						count = countIn(
							k.minCount,
							k.maxCount,
							ForagePlan.rand(seed, cx, cz, i * 5 + 4)
						),
					})
				end
			end
		end
	end
	if ForagePlan.rand(seed, cx, cz, NODE_SLOT) < F.NodeChance then
		local x = (cx + ForagePlan.rand(seed, cx, cz, NODE_SLOT + 1)) * size
		local z = (cz + ForagePlan.rand(seed, cx, cz, NODE_SLOT + 2)) * size
		if insideWorld(x, z) then
			local idx = ForagePlan.pickKind(
				F.Nodes,
				World.ringAt(x, z),
				ForagePlan.rand(seed, cx, cz, NODE_SLOT + 3)
			)
			if idx then
				local k = F.Nodes[idx]
				table.insert(out, {
					key = `n:{cx}:{cz}`,
					class = "node",
					kind = k.itemId,
					x = x,
					z = z,
					count = countIn(
						k.minCount,
						k.maxCount,
						ForagePlan.rand(seed, cx, cz, NODE_SLOT + 4)
					),
				})
			end
		end
	end
	return out
end

-- Relic fragments around one structure site: outside the footprint (RadiusMin x radius or more).
function ForagePlan.relics(seed: number, site: Site): { Entry }
	local R = Config.Forage.Relic
	local out: { Entry } = {}
	if site.ring < R.minRing then
		return out
	end
	local sx, sz = math.floor(site.x), math.floor(site.z)
	local n = countIn(R.minPerSite, R.maxPerSite, ForagePlan.rand(seed, sx, sz, RELIC_SALT))
	for i = 1, n do
		local angle = ForagePlan.rand(seed, sx, sz, RELIC_SALT + i * 3) * math.pi * 2
		local dist = site.radius
			* (
				R.RadiusMin
				+ (R.RadiusMax - R.RadiusMin)
					* ForagePlan.rand(seed, sx, sz, RELIC_SALT + i * 3 + 1)
			)
		local x, z = site.x + math.cos(angle) * dist, site.z + math.sin(angle) * dist
		if insideWorld(x, z) then
			table.insert(out, {
				key = `r:{site.key}:{i}`,
				class = "relic",
				kind = R.itemId,
				x = x,
				z = z,
				count = countIn(
					R.minCount,
					R.maxCount,
					ForagePlan.rand(seed, sx, sz, RELIC_SALT + i * 3 + 2)
				),
			})
		end
	end
	return out
end

-- True when (x, z) is inside any site's footprint disc plus margin.
function ForagePlan.insideSite(x: number, z: number, sites: { Site }, margin: number): boolean
	for _, s in sites do
		local dx, dz = x - s.x, z - s.z
		local r = s.radius + margin
		if dx * dx + dz * dz < r * r then
			return true
		end
	end
	return false
end

return ForagePlan
