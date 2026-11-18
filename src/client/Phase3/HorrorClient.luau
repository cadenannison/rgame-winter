--!strict
-- Phase 3 client boot hook for brief 15 (Horror). init.client.luau calls start() once in run mode after
-- HudController.start(). Must not yield: the cue controller is started in its own thread.

local HorrorCues = require(script.Parent.Parent.Horror.HorrorCues)

local HorrorClient = {}

function HorrorClient.start()
	task.spawn(HorrorCues.start)
end

return HorrorClient
