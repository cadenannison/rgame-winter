--!strict
-- Chest look table (pure): every rarity has a distinct style inside the light/particle/part budgets,
-- effects scale up with rarity, rare+ is visible from far, and the loot-only gear tiers exist.

local Config = require("../src/shared/Config")
local ItemCatalog = require("../src/shared/ItemCatalog")
local Rarity = require("../src/shared/data/Rarity")
local ChestStyle = require("../src/shared/logic/ChestStyle")

return function(check: (string, boolean) -> ())
	local B = ChestStyle.Budget
	local allOk, monotonic, distinct, farOk = true, true, true, true
	local prev: ChestStyle.Style? = nil
	local seenBody: { [string]: boolean } = {}
	for _, name in Rarity.List do
		local s = ChestStyle.Styles[name]
		if s == nil or #ChestStyle.validate(name, s) > 0 then
			allOk = false
			continue
		end
		local key = `{s.bodyColor[1]},{s.bodyColor[2]},{s.bodyColor[3]}`
		if seenBody[key] then
			distinct = false
		end
		seenBody[key] = true
		if prev then
			if
				s.lightRange < prev.lightRange
				or s.particleRate < prev.particleRate
				or s.beamHeight < prev.beamHeight
				or s.burstCount < prev.burstCount
				or s.openSeconds < prev.openSeconds
			then
				monotonic = false
			end
		end
		if
			Rarity.rank(name) >= Rarity.rank("rare") and (s.glowColor == nil or s.beamHeight < 20)
		then
			farOk = false
		end
		prev = s
	end
	check("chest: five styles inside budget", allOk and #Rarity.List == 5)
	check("chest: styles distinct", distinct)
	check("chest: glow, light, particles, burst and open time grow with rarity", monotonic)
	check("chest: rare+ has a beam visible from far", farOk)
	check(
		"chest: common has no light or particles",
		not ChestStyle.hasEffects(ChestStyle.get("common"))
	)
	check("chest: rare+ has light and particles", ChestStyle.hasEffects(ChestStyle.get("rare")))
	check(
		"chest: legendary beam is the tallest",
		ChestStyle.get("legendary").beamHeight > ChestStyle.get("epic").beamHeight
	)
	check(
		"chest: unknown rarity falls back to common",
		ChestStyle.get("nope") == ChestStyle.Styles.common
	)
	check(
		"chest: effect chests inside the emitter budget",
		B.MaxEffectChests >= 1 and B.MaxEffectChests <= Config.Perf.MaxParticleEmitters
	)
	check("chest: particle rate within Perf", B.MaxParticleRate <= Config.Perf.MaxParticleRate)
	check(
		"chest: prompt distance matches Loot.OpenRange",
		B.PromptDistance == Config.Loot.OpenRange
	)

	local dimmed = ChestStyle.dim({ 200, 100, 50 }, B.OpenedDim)
	check("chest: opened colour is darker", dimmed[1] < 200 and dimmed[2] < 100 and dimmed[3] < 50)
	local rare = ChestStyle.get("rare")
	local pulseOk = true
	for i = 0, 40 do
		local p = ChestStyle.pulse(rare, i * 0.37)
		if p < rare.glowTransparency - 1e-6 or p > 1 then
			pulseOk = false
		end
	end
	check("chest: glow pulse stays in range", pulseOk)
	check("chest: common pulse is static", ChestStyle.pulse(ChestStyle.get("common"), 3) == 1)

	-- Gear additions: every tier from rare up has at least a weapon, a tool and a light/gear piece.
	local counts: { [string]: { [string]: number } } = {}
	for id, def in ItemCatalog.Items do
		if def.lootCategory ~= nil and def.rarity ~= nil then
			local r: { [string]: number } = counts[def.rarity] or {}
			r[def.lootCategory] = (r[def.lootCategory] or 0) + 1
			counts[def.rarity] = r
			if def.kind == "weapon" and (def.damage or 0) <= 0 then
				check(`chest: weapon {id} has damage`, false)
			end
		end
	end
	local gearOk = true
	for _, rar in { "epic", "legendary" } do
		local r: { [string]: number } = counts[rar] or {}
		if
			(r.weapon or 0) < 1
			or (r.tool or 0) < 1
			or (r.gear or 0) < 1
			or (r.clothing or r.material or 0) < 1
		then
			gearOk = false
		end
	end
	check("chest: epic and legendary have weapon, tool, gear and another category", gearOk)
	local spear = ItemCatalog.Items.IronSpear
	local blade = ItemCatalog.Items.AuroraBlade
	local sun = ItemCatalog.Items.SunpiercerSpear
	check(
		"chest: weapon damage grows with rarity",
		spear ~= nil
			and blade ~= nil
			and sun ~= nil
			and (spear.damage or 0) < (blade.damage or 0)
			and (blade.damage or 0) < (sun.damage or 0)
	)
end
