--!strict
-- Eating: registers the InventoryService use handler (UseItemRequest). InventoryService already did
-- type, slot range and rate limit; this is the state check (alive, not downed, not full) and the act.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ItemCatalog = require(Shared.ItemCatalog)
local Consume = require(Shared.logic.Consume)
local Cooking = require(Shared.logic.Cooking)
local BuffService = require(script.Parent.BuffService)
local CookingService = require(script.Parent.CookingService)
local InventoryService = require(script.Parent.InventoryService)
local SurvivalService = require(script.Parent.Parent.Survival.SurvivalService)

local FoodService = {}

local function notify(player: Player, text: string)
	Remotes.event(Remotes.Notify):FireClient(player, "eat", text)
end

-- Returns true to consume one item. Server recomputes the gain from catalog data.
local function onUse(player: Player, def: ItemCatalog.ItemDef, _slot: number): boolean
	if def.kind ~= "food" then
		return false
	end
	local meters = SurvivalService.getMeters(player)
	if meters == nil then
		return false
	end
	local ok, result = Consume.eat(def, meters, Config.Meters.MaxHunger)
	if not ok then
		notify(player, tostring(result))
		return false
	end
	SurvivalService.feed(player, result :: number)
	-- Buff from the food (capped); food cooked at a station lasts longer. Raw fish carries a debuff.
	local buff = Cooking.buffFor(def.id)
	if
		buff
		and BuffService.grant(
			player,
			buff.id,
			Cooking.buffDuration(buff, CookingService.consumeStationBonus(player, def.id))
		)
	then
		notify(player, `Ate {def.name}: {buff.name}`)
		return true
	end
	notify(player, `Ate {def.name}`)
	return true
end

-- Call before InventoryService.start so no use request arrives unwired.
function FoodService.install()
	InventoryService.setUseHandler(onUse)
end

return FoodService
