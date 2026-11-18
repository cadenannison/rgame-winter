--!strict
-- Phase 4 cross-system wiring (brief 21). init.server.luau calls Wiring.apply(mode) once per mode, after
-- MetaBoot (MetaService started) and before Spawn.start(). Run mode only does work: meta progress sources
-- (events, placement, cooking, revives, crafting, biome ring) and the run perk capture. Server only;
-- nothing hidden crosses to a client (progress counters are saved stats, shown via MetaState).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Events = require(Shared.data.Events)

local Server = script.Parent.Parent
local DataService = require(Server.Data.DataService)
local MetaService = require(Server.Meta.MetaService)
local EventService = require(Server.Events.EventService)
local BiomeService = require(Server.World.BiomeService)
local SurvivalService = require(Server.Survival.SurvivalService)
local CraftingService = require(Server.Items.CraftingService)
local PlacementService = require(Server.Items.PlacementService)
local CookingService = require(Server.Items.CookingService)
local GatherService = require(Server.Items.GatherService)
local PerkModifiers = require(script.Parent.PerkModifiers)

local Wiring = {}

local applied = false

function Wiring.apply(mode: string)
	if applied or mode ~= Config.Teleport.ModeRun then
		return
	end
	applied = true

	-- Run perk: captured once per player on their first profile load here, then frozen for the run.
	DataService.onLoaded(function(player: Player, _profile)
		PerkModifiers.capture(player.UserId, MetaService.getEquippedPerk(player))
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		PerkModifiers.leave(player.UserId)
	end)
	GatherService.setYieldBonusProvider(PerkModifiers.gatherBonus)

	-- Achievement progress sources (MetaService clamps and caps every counter).
	EventService.onEventEnd(function(id: string, survivors: { Player })
		local field = if id == Config.Blizzard.EventId
			then "blizzardsSurvived"
			elseif Events.ById[id] ~= nil then "darkEventsSurvived"
			else nil
		if field then
			for _, player in survivors do
				MetaService.addProgress(player, field, 1)
			end
		end
	end)
	PlacementService.setPlacedHandler(function(player: Player, _structureId: string)
		MetaService.addProgress(player, "structuresPlaced", 1)
	end)
	CookingService.setCookedHandler(function(player: Player, _itemId: string)
		MetaService.addProgress(player, "mealsCooked", 1)
	end)
	SurvivalService.setReviveHandler(function(reviver: Player, _target: Player)
		MetaService.addProgress(reviver, "revivesGiven", 1)
	end)
	CraftingService.setCraftedHandler(function(player: Player, _recipeId: string)
		MetaService.addStat(player, "crafted", 1)
	end)
	BiomeService.onRingChanged(function(player: Player, ring: number)
		MetaService.raiseProgress(player, "deepestRing", ring)
	end)
end

return Wiring
