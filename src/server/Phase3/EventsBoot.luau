--!strict
-- Phase 3 server boot hook for brief 14 (Events). Owned exclusively by brief 14: require and wire your
-- services here and start them in start(). init.server.luau calls start() once in run mode, after
-- MobService.start() and before Spawn.start(). Must not yield.
-- Brief 18 wires the cross-deps on EventService: setSeed, setFullGroupPredicate, setSpawnMultiplierSink.

local EventsBoot = {}

function EventsBoot.start()
	require(script.Parent.Parent.Events.EventService).start()
end

return EventsBoot
