--!strict
-- Pure workbench-tier rules: which recipes a party-wide tier unlocks, upgrade cost/status and the atomic
-- inventory spend. Tier data is Config.Workbench; recipe tiers are ItemCatalog.benchTierOf. No Roblox APIs.

local Config = require("../Config")
local ItemCatalog = require("../ItemCatalog")
local Inventory = require("./Inventory")

local WorkbenchTier = {}

export type Cost = { { id: string, count: number } }

function WorkbenchTier.clamp(tier: unknown): number
	if type(tier) ~= "number" or tier ~= tier then
		return 1
	end
	return math.clamp(math.floor(tier), 1, Config.Workbench.MaxTier)
end

-- Hand recipes and non-workbench stations are always available; workbench recipes need partyTier >= their tier.
function WorkbenchTier.recipeAvailable(recipeId: string, partyTier: number): boolean
	return ItemCatalog.benchTierOf(recipeId) <= partyTier
end

-- Cost to go from `tier` to the next tier (nil at max).
function WorkbenchTier.nextCost(tier: number): Cost?
	local nextDef = Config.Workbench.Tiers[WorkbenchTier.clamp(tier) + 1]
	return if tier < Config.Workbench.MaxTier and nextDef then nextDef.Cost else nil
end

function WorkbenchTier.labelOf(tier: number): string
	local def = Config.Workbench.Tiers[WorkbenchTier.clamp(tier)]
	return if def then def.Label else ""
end

-- "Ok" | "MaxTier" | "NeedStation" | "MissingMaterials" (display and server use the same rule).
function WorkbenchTier.status(
	counts: { [string]: number },
	tier: number,
	nearBench: boolean
): string
	local cost = WorkbenchTier.nextCost(tier)
	if cost == nil then
		return "MaxTier"
	end
	if not nearBench then
		return "NeedStation"
	end
	for _, c in cost do
		if (counts[c.id] or 0) < c.count then
			return "MissingMaterials"
		end
	end
	return "Ok"
end

-- Atomic spend: returns (ok, reasonOrNewTier). On failure the inventory is untouched.
function WorkbenchTier.upgrade(
	inv: Inventory.Inv,
	tier: number,
	nearBench: boolean
): (boolean, string, number)
	local current = WorkbenchTier.clamp(tier)
	local counts: { [string]: number } = {}
	local cost = WorkbenchTier.nextCost(current)
	if cost then
		for _, c in cost do
			counts[c.id] = Inventory.count(inv, c.id)
		end
	end
	local s = WorkbenchTier.status(counts, current, nearBench)
	if s ~= "Ok" or cost == nil then
		return false, s, current
	end
	for _, c in cost do
		Inventory.remove(inv, c.id, c.count)
	end
	return true, "Ok", current + 1
end

-- Cost as "Wood 5/20, Stone 3/10" (have/need) for the craft row.
function WorkbenchTier.costText(cost: Cost, counts: { [string]: number }): string
	local parts: { string } = {}
	for _, c in cost do
		local def = ItemCatalog.Items[c.id]
		table.insert(parts, `{if def then def.name else c.id} {counts[c.id] or 0}/{c.count}`)
	end
	return table.concat(parts, "   ")
end

function WorkbenchTier.scaleOf(tier: number): number
	local def = Config.Workbench.Tiers[WorkbenchTier.clamp(tier)]
	return if def then def.Scale else 1
end

-- Recipe ids for the panel: tier-sorted list filtered to what the party tier unlocks.
function WorkbenchTier.visible(ids: { string }, partyTier: number): { string }
	local out: { string } = {}
	for _, id in ids do
		if WorkbenchTier.recipeAvailable(id, partyTier) then
			table.insert(out, id)
		end
	end
	return out
end

return WorkbenchTier
