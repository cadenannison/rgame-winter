--!strict
-- Run-start grants for the run server: unlocked starter gear (milestone-gated, bought with coins) is added
-- to the inventory once per player per run. The equipped perk is read via MetaService.getEquippedPerk
-- (modifier wiring into Survival/Fire/Gather belongs to brief 21; magnitudes are capped by Config).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Shop = require(Shared.data.Shop)
local ShopLogic = require(Shared.logic.ShopLogic)
local DataService = require(script.Parent.Parent.Data.DataService)
local InventoryService = require(script.Parent.Parent.Items.InventoryService)

local PerkService = {}

local GEAR_WAIT_SECONDS = Config.Meta.StarterGearWaitSeconds -- bounded wait for the inventory to exist
local GEAR_POLL = Config.Meta.StarterGearPollSeconds

local granted: { [number]: boolean } = {} -- userId -> already granted this run (rejoin keeps its inventory)
local unsubscribe: (() -> ())? = nil

local function grantGear(player: Player)
	if granted[player.UserId] then
		return
	end
	local waited = 0
	while InventoryService.get(player) == nil do
		if player.Parent ~= Players or waited >= GEAR_WAIT_SECONDS then
			return
		end
		task.wait(GEAR_POLL)
		waited += GEAR_POLL
	end
	local profile = DataService.get(player)
	if not profile or granted[player.UserId] then
		return
	end
	granted[player.UserId] = true
	for _, item in Shop.List do
		local gear = item.gear
		if
			item.category == "gear"
			and gear
			and profile.unlockedGear[item.id]
			and ShopLogic.milestoneMet(profile, item)
		then
			InventoryService.add(
				player,
				gear.itemId,
				math.clamp(gear.count, 1, Config.Meta.MaxStarterGearCount)
			)
		end
	end
end

function PerkService.Start()
	if unsubscribe then
		return
	end
	unsubscribe = DataService.onLoaded(function(player: Player, _profile)
		grantGear(player)
	end)
end

function PerkService.Stop()
	if unsubscribe then
		unsubscribe()
		unsubscribe = nil
	end
	table.clear(granted)
end

return PerkService
