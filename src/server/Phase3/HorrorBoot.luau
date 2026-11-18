--!strict
-- Phase 3 server boot hook for brief 15 (Horror). init.server.luau calls start() once in run mode, after
-- MobService.start() and before Spawn.start(). Must not yield.
-- Wiring for brief 18 (all optional, nil-safe): HorrorWorld.setPartyProvider / setFireProvider /
-- setWarmSpotProvider / setEventProvider / setLightProvider / setCampProvider;
-- EventService.setFullGroupPredicate(DreadService.isFullGroup); StalkerService.onStrike(cb).

local Horror = script.Parent.Parent.Horror
local CueSender = require(Horror.CueSender)
local DreadService = require(Horror.DreadService)
local StalkerService = require(Horror.StalkerService)
local LurkerService = require(Horror.LurkerService)

local HorrorBoot = {}

function HorrorBoot.start()
	CueSender.start()
	DreadService.start()
	StalkerService.start()
	LurkerService.start()
end

return HorrorBoot
