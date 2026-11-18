--!strict
-- Phase 3 server boot hook for brief 17 (Progression). init.server.luau calls start() once in run mode,
-- after MobService.start() and before Spawn.start(). Must not yield. Starts storage, structures, cooking,
-- repair, buffs, clothing and pings, and binds MobService.damage (brief 16) and MapService.markExplored
-- (brief 13) through the StructureService setters (brief 18 wiring).

local ProgressionBoot = {}

local Server = script.Parent.Parent
local BuffService = require(Server.Items.BuffService)
local ClothingService = require(Server.Items.ClothingService)
local CookingService = require(Server.Items.CookingService)
local RepairService = require(Server.Items.RepairService)
local StorageService = require(Server.Items.StorageService)
local StructureService = require(Server.Items.StructureService)
local PingService = require(Server.Social.PingService)
local MobService = require(Server.Mobs.MobService)
local MapService = require(Server.World.MapService)

local started = false

function ProgressionBoot.start()
	if started then
		return
	end
	started = true
	-- Brief 18 wiring: traps damage mobs through MobService, watchtowers reveal the fog-of-war map.
	StructureService.setMobDamager(function(mob: Model, amount: number, source: Player?)
		MobService.damage(mob, amount, source)
	end)
	StructureService.setExploreProvider(function(position: Vector3, radius: number)
		MapService.markExplored(position, radius)
	end)
	BuffService.start()
	ClothingService.start()
	StorageService.start()
	StructureService.start()
	CookingService.start()
	RepairService.start()
	PingService.start()
end

return ProgressionBoot
