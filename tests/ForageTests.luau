--!strict
-- Headless tests: forage placement determinism, ring gating, footprints, item/recipe coverage.

local Config = require("../src/shared/Config")
local ForagePlan = require("../src/shared/logic/ForagePlan")
local ItemCatalog = require("../src/shared/ItemCatalog")

local SEED = 12345

return function(check: (string, boolean) -> ())
	local F = Config.Forage
	local a = ForagePlan.cell(SEED, 3, -2)
	local b = ForagePlan.cell(SEED, 3, -2)
	local same = #a == #b
	for i, e in a do
		same = same
			and b[i].key == e.key
			and b[i].x == e.x
			and b[i].z == e.z
			and b[i].count == e.count
	end
	check("forage: cell plan is deterministic", same)

	local total, nodes, bad, outside, badCount = 0, 0, 0, 0, 0
	local World = require("../src/shared/logic/World")
	for cx = -8, 7 do
		for cz = -8, 7 do
			for _, e in ForagePlan.cell(SEED, cx, cz) do
				total += 1
				local ring = World.ringAt(e.x, e.z)
				local kinds: { any } = if e.class == "node" then F.Nodes else F.Forage
				if e.class == "node" then
					nodes += 1
				end
				local ok = false
				for _, k in kinds do
					if k.itemId == e.kind and ring >= k.minRing and ring <= k.maxRing then
						ok = k.maxCount >= e.count and k.minCount <= e.count
					end
				end
				if not ok then
					bad += 1
				end
				if math.abs(e.x) > World.halfExtent() or math.abs(e.z) > World.halfExtent() then
					outside += 1
				end
				if e.count < 1 then
					badCount += 1
				end
			end
		end
	end
	check("forage: world has pickups", total > 50)
	check("forage: world has nodes", nodes > 0)
	check("forage: kinds respect ring and count ranges", bad == 0 and badCount == 0)
	check("forage: nothing outside the world", outside == 0)
	check(
		"forage: crystal only in the deepest ring and scrap not in rings 0-1",
		(function(): boolean
			for cx = -8, 7 do
				for cz = -8, 7 do
					for _, e in ForagePlan.cell(SEED, cx, cz) do
						local ring = World.ringAt(e.x, e.z)
						if e.kind == "Crystal" and ring ~= 3 then
							return false
						end
						if e.kind == "ScrapMetal" and ring < 2 then
							return false
						end
					end
				end
			end
			return true
		end)()
	)

	local site: ForagePlan.Site = { key = "Ruins#1", x = 400, z = -300, radius = 40, ring = 2 }
	local relics = ForagePlan.relics(SEED, site)
	local outsideFootprint = #relics >= F.Relic.minPerSite
	for _, e in relics do
		local d = math.sqrt((e.x - site.x) ^ 2 + (e.z - site.z) ^ 2)
		outsideFootprint = outsideFootprint and d >= site.radius
	end
	check("forage: relics sit outside the structure footprint", outsideFootprint)
	check(
		"forage: no relics at low-ring sites",
		#ForagePlan.relics(SEED, { key = "x", x = 0, z = 0, radius = 30, ring = 0 }) == 0
	)
	check(
		"forage: insideSite detects footprint",
		ForagePlan.insideSite(405, -300, { site }, 5)
			and not ForagePlan.insideSite(600, -300, { site }, 5)
	)

	local itemsOk, recipesOk = true, true
	for _, k in F.Forage do
		itemsOk = itemsOk
			and ItemCatalog.Items[k.itemId] ~= nil
			and ItemCatalog.Nodes[k.itemId] ~= nil
	end
	for _, k in F.Nodes do
		itemsOk = itemsOk
			and ItemCatalog.Items[k.itemId] ~= nil
			and ItemCatalog.Nodes[k.itemId] ~= nil
	end
	itemsOk = itemsOk and ItemCatalog.Items[F.Relic.itemId] ~= nil
	for _, id in { "Wood", "FrostShard", "Rope" } do
		recipesOk = recipesOk and ItemCatalog.Recipes[id] ~= nil
	end
	check("forage: every kind has an item and node def", itemsOk)
	check("forage: recipes registered", recipesOk)
	check(
		"forage: stacks (materials 20, rare 10)",
		ItemCatalog.stackOf("Stick") == 20
			and ItemCatalog.stackOf("Crystal") == 10
			and ItemCatalog.stackOf("Winterberry") == 20
	)
	local ItemsGather = require("../src/shared/logic/ItemsGather")
	check("forage: hand pick needs no tool", (ItemsGather.canHarvest("Stick", nil)))
	check("forage: coal seam needs a pickaxe", not (ItemsGather.canHarvest("Coal", nil)))
	check(
		"forage: crystal needs metal tier",
		not (ItemsGather.canHarvest("Crystal", { id = "StonePickaxe", count = 1 }))
	)
end
