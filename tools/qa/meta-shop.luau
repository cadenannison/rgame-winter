--!nocheck
-- QA scenario meta-shop (brief 21): SERVER datamodel, LOBBY mode (Workspace ServerMode = "lobby" set in
-- edit mode before start_play), local player, one MCP call. Prints <= 10 lines
-- `PASS meta-shop/check` or `FAIL meta-shop/check: reason` (FAILs first).
-- Reaches the live services through the Studio-only QA bridge (Shop.handleBuy / handleRobux, Meta.handleEquipPerk,
-- Meta.evaluate, Receipt.processItem / process). The test profile is protected: MetaQA.backup() copies every
-- meta field server-side first and MetaQA.restore() writes them back at the end (also after an error).
local MAX_LINES = 10
local NAME = "meta-shop"
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local Shop = require(RS.Shared.data.Shop)
local Achievements = require(RS.Shared.data.Achievements)

local Bridge = game:GetService("ServerStorage"):WaitForChild(Config.Debug.BridgeName, 10)
local function svc(name)
	return setmetatable({}, {
		__index = function(_, fn)
			return function(...)
				return Bridge:Invoke(name, fn, ...)
			end
		end,
	})
end
local ShopS, MetaS, ReceiptS, QA = svc("Shop"), svc("Meta"), svc("Receipt"), svc("MetaQA")

local P
local function scenario(chk)
	for _ = 1, 40 do
		P = Players:GetPlayers()[1]
		if P and QA.read(P) then
			break
		end
		task.wait(0.5)
	end
	if not (P and QA.backup(P)) then
		chk("setup", false, "no player / profile not loaded / bridge missing")
		return
	end
	local function coins()
		return QA.read(P).coins
	end
	local wait = function(interval)
		task.wait(interval + 0.15)
	end
	local A, B = Shop.ById.WarmBlood, Shop.ById.Kindler
	QA.clearOwned(P, A.id)
	QA.clearOwned(P, B.id)

	-- 1. price is recomputed on the server: a client "price" field is ignored
	QA.setCoins(P, A.price - 1)
	local cheap = ShopS.handleBuy(P, { itemId = A.id, price = 1 })
	wait(Config.Net.ShopRateInterval)
	QA.setCoins(P, A.price + 5)
	local bought = ShopS.handleBuy(P, { itemId = A.id, price = 1 })
	chk(
		"coin_buy_server_price",
		cheap == "coins" and bought == "ok" and coins() == 5 and QA.read(P).ownedCosmetics[A.id],
		`short {cheap} buy {bought} coins {coins()}`
	)

	-- 2. duplicate buy refused, coins unchanged
	wait(Config.Net.ShopRateInterval)
	QA.setCoins(P, A.price + 5)
	local dup = ShopS.handleBuy(P, { itemId = A.id })
	chk("duplicate_buy_refused", dup == "owned" and coins() == A.price + 5, `{dup} coins {coins()}`)

	-- 3. exactly one perk equipped: equipping B replaces A; an unowned perk is refused
	wait(Config.Net.ShopRateInterval)
	QA.setCoins(P, B.price)
	ShopS.handleBuy(P, { itemId = B.id })
	MetaS.handleEquipPerk(P, { id = A.id })
	wait(Config.Net.EquipRateInterval)
	MetaS.handleEquipPerk(P, { id = B.id })
	local afterB = QA.read(P).equippedPerk
	wait(Config.Net.EquipRateInterval)
	QA.clearOwned(P, "LightStep")
	MetaS.handleEquipPerk(P, { id = "LightStep" })
	local afterC = QA.read(P).equippedPerk
	chk("one_perk_equipped", afterB == B.id and afterC == B.id, `after B {afterB} after unowned {afterC}`)

	-- 4. an achievement unlocks once and pays once
	local def = Achievements.ById.CampCook
	QA.clearAchievement(P, def.id)
	QA.setStat(P, def.condition.stat, def.condition.atLeast)
	local c0 = coins()
	local first = MetaS.evaluate(P)
	local c1 = coins()
	local second = MetaS.evaluate(P)
	local function has(list, id)
		return table.find(list, id) ~= nil
	end
	chk(
		"achievement_once",
		has(first, def.id) and not has(second, def.id) and c1 - c0 == def.coins and coins() == c1,
		`first {has(first, def.id)} second {has(second, def.id)} coins +{c1 - c0}/{def.coins}`
	)

	-- 5. a fake receipt processed twice grants once (ProductIds are 0, so QA names the shop item)
	local pack = Shop.ById[Shop.ByProductKey.CoinPackSmall.id]
	local purchaseId = `QA-{os.time()}-{math.random(1, 1e6)}`
	local r0 = coins()
	local g1 = ReceiptS.processItem(P, purchaseId, pack, os.time())
	local r1 = coins()
	local g2 = ReceiptS.processItem(P, purchaseId, pack, os.time())
	chk(
		"receipt_twice_grants_once",
		g1 == true and g2 == true and r1 - r0 == pack.coins and coins() == r1,
		`grant {g1}/{g2} coins +{r1 - r0} then +{coins() - r1}`
	)

	-- 6. NotProcessedYet when no profile is loaded (player gone); no prompt while ProductIds are 0
	local notLoaded = ReceiptS.process(nil, purchaseId .. "x", 1, os.time())
	local prompt = ShopS.handleRobux(P, { itemId = pack.id })
	chk(
		"receipt_not_loaded_and_no_prompt",
		notLoaded == false and prompt == "unavailable" and Config.Meta.ProductIds.CoinPackSmall == 0,
		`notLoaded {notLoaded} prompt {prompt}`
	)
end

local lines, fails, passes = {}, {}, {}
local function chk(check, ok, why)
	if ok then
		table.insert(passes, "PASS " .. NAME .. "/" .. check)
	else
		table.insert(fails, "FAIL " .. NAME .. "/" .. check .. ": " .. tostring(why))
	end
end
local success, err = pcall(scenario, chk)
if not success then
	table.insert(fails, "FAIL " .. NAME .. "/error: " .. tostring(err))
end
-- Always put the test profile back.
local before = P and QA.read(P)
local restored = P ~= nil and QA.restore(P)
chk("profile_restored", restored, "restore failed")
if restored and before then
	MetaS.pushState(P)
end
for _, l in fails do
	if #lines < MAX_LINES then
		table.insert(lines, l)
	end
end
for _, l in passes do
	if #lines < MAX_LINES then
		table.insert(lines, l)
	end
end
return table.concat(lines, "\n")
