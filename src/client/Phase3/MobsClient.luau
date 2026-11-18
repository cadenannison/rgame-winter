--!strict
-- Phase 3 client boot hook for brief 16 (Mobs). Owned exclusively by brief 16.
-- init.client.luau calls start() once in run mode after HudController.start(). Must not yield.
-- Starts the bow controller and shows a toast for the BossWarning cue.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local ShootController = require(script.Parent.Parent.Combat.ShootController)
local Toast = require(script.Parent.Parent.HUD.Toast)
local CreatureAnim = require(script.Parent.Parent.Art.CreatureAnim)
local CreatureFx = require(script.Parent.Parent.Art.CreatureFx)

local BOSS_WARNING_TEXT = "Something huge is coming toward camp"

local MobsClient = {}

local started = false

function MobsClient.start()
	if started then
		return
	end
	started = true
	ShootController.start()
	CreatureAnim.start()
	CreatureFx.start()
	Remotes.event(Remotes.Cue).OnClientEvent:Connect(function(payload: Remotes.CuePayload)
		if type(payload) == "table" and payload.kind == "BossWarning" then
			Toast.show(BOSS_WARNING_TEXT)
		end
	end)
end

return MobsClient
