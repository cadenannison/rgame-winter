--!strict
-- Pure shop rules. No Roblox APIs. The server recomputes price, ownership and milestones from data/Shop
-- every time; the client only names an item id. No item is random: a purchase grants exactly what is listed.

local Config = require("../Config")
local Types = require("../data/Types")
local ProfileSchema = require("./ProfileSchema")

local ShopLogic = {}

-- Result of resolving a receipt grant.
export type ReceiptResult = "granted" | "duplicate" | "invalid"

local function countKeys(map: { [string]: boolean }): number
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end

function ShopLogic.validId(id: unknown): boolean
	return type(id) == "string" and #id > 0 and #id <= Config.Meta.MaxItemIdLength
end

function ShopLogic.milestoneMet(profile: ProfileSchema.Profile, item: Types.ShopItemDef): boolean
	local req = item.requires
	return req == nil or ProfileSchema.getStat(profile, req.stat) >= req.atLeast
end

-- Cosmetics, perks (kept in ownedCosmetics under their ids) and gear (unlockedGear).
function ShopLogic.owned(profile: ProfileSchema.Profile, item: Types.ShopItemDef): boolean
	if item.category == "gear" then
		return profile.unlockedGear[item.id] == true
	elseif item.category == "coinPack" then
		return false
	end
	return profile.ownedCosmetics[item.id] == true
end

-- Coin purchase check. Returns (ok, reason) with reason in owned | coins | locked | unavailable.
function ShopLogic.canBuyWithCoins(
	profile: ProfileSchema.Profile,
	item: Types.ShopItemDef?
): (boolean, string?)
	if item == nil or item.currency ~= "coins" or item.category == "coinPack" then
		return false, "unavailable"
	end
	if item.price < Config.Meta.MinCoinPrice or item.price > Config.Meta.MaxCoinPrice then
		return false, "unavailable"
	end
	if ShopLogic.owned(profile, item) then
		return false, "owned"
	end
	if not ShopLogic.milestoneMet(profile, item) then
		return false, "locked"
	end
	if profile.coins < item.price then
		return false, "coins"
	end
	local full = if item.category == "gear"
		then countKeys(profile.unlockedGear) >= Config.Meta.MaxUnlockedGear
		else countKeys(profile.ownedCosmetics) >= Config.Meta.MaxOwnedCosmetics
	if full then
		return false, "unavailable"
	end
	return true, nil
end

-- Marks the item owned (no coin change).
local function own(profile: ProfileSchema.Profile, item: Types.ShopItemDef)
	if item.category == "gear" then
		profile.unlockedGear[item.id] = true
	else
		profile.ownedCosmetics[item.id] = true
	end
end

-- Applies a coin purchase if allowed. Returns (ok, reason).
function ShopLogic.buyWithCoins(
	profile: ProfileSchema.Profile,
	item: Types.ShopItemDef?
): (boolean, string?)
	local ok, reason = ShopLogic.canBuyWithCoins(profile, item)
	if not ok or item == nil then
		return false, reason
	end
	profile.coins = math.clamp(profile.coins - item.price, 0, Config.MaxCoins)
	own(profile, item)
	return true, nil
end

-- Idempotent Robux grant: a PurchaseId already in the log grants nothing ("duplicate", still success for
-- ProcessReceipt). Otherwise grant, then record the receipt in the same mutation. An owned Robux
-- cosmetic is recorded and grants nothing. "invalid" (nothing changed) = bad id/item; caller must not
-- return PurchaseGranted.
function ShopLogic.grantReceipt(
	profile: ProfileSchema.Profile,
	purchaseId: string,
	item: Types.ShopItemDef?,
	now: number
): ReceiptResult
	if item == nil or item.currency ~= "robux" then
		return "invalid"
	end
	if
		type(purchaseId) ~= "string"
		or #purchaseId == 0
		or #purchaseId > Config.Meta.MaxReceiptIdLength
	then
		return "invalid"
	end
	if ProfileSchema.hasReceipt(profile, purchaseId) then
		return "duplicate"
	end
	if item.category == "coinPack" then
		local coins = math.clamp(math.floor(item.coins or 0), 0, Config.Meta.MaxCoinPackCoins)
		profile.coins = math.clamp(profile.coins + coins, 0, Config.MaxCoins)
	elseif item.category == "cosmetic" then
		if
			not profile.ownedCosmetics[item.id]
			and countKeys(profile.ownedCosmetics) < Config.Meta.MaxOwnedCosmetics
		then
			profile.ownedCosmetics[item.id] = true
		end
	else
		return "invalid"
	end
	ProfileSchema.recordReceipt(profile, purchaseId, now)
	return "granted"
end

return ShopLogic
