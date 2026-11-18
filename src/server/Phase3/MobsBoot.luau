--!strict
-- Phase 3 server boot hook for brief 16 (Mobs). Owned exclusively by brief 16.
-- init.server.luau calls start() once in run mode, after MobService.start() and before Spawn.start().
-- Must not yield. Brief 18 wires the nil-safe setters:
--   MobService.setRingProvider(BiomeService.getRing-style fn(Vector3) -> number)
--   BossService.setCampProvider(ChunkService camp position fn)
--   BossService.wireEvents(EventService.onBlizzardStart)
-- Boss kills reach RunLifecycleService.RecordKill(player, true) through MobService.setKillHandler.

local Server = script.Parent.Parent
local BossService = require(Server.Mobs.BossService)
local ProjectileService = require(Server.Combat.ProjectileService)

local MobsBoot = {}

function MobsBoot.start()
	BossService.start()
	ProjectileService.start()
end

return MobsBoot
