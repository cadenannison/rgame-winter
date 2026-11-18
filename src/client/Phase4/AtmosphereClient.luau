--!strict
-- Phase 4 client boot hook for brief 20 (atmosphere, polish, performance). init.client.luau calls
-- start(mode) once in BOTH modes. Must not yield: all waiting work runs in its own thread.
-- Lobby: settings toggle + MetaState. Run: also cue audio/particles (Remotes.Cue -> AudioCues rows),
-- ambient loops, day banner, first-run hints and other players' swings (SwingBroadcast).
-- See docs/systems/atmosphere.md.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Atmosphere = script.Parent.Parent:WaitForChild("Atmosphere")

local AtmosphereClient = {}

local started = false

function AtmosphereClient.start(mode: string)
	if started then
		return
	end
	started = true
	task.spawn(function()
		local Shared = ReplicatedStorage:WaitForChild("Shared")
		local Config = require(Shared:WaitForChild("Config"))
		local Remotes = require(Shared:WaitForChild("Remotes"))
		local CueResolve = require(Shared:WaitForChild("logic"):WaitForChild("CueResolve"))
		local AtmosphereFx = require(Atmosphere:WaitForChild("AtmosphereFx"))
		local AtmosphereAmbient = require(Atmosphere:WaitForChild("AtmosphereAmbient"))
		local AtmosphereHints = require(Atmosphere:WaitForChild("AtmosphereHints"))
		local DayBanner = require(Atmosphere:WaitForChild("DayBanner"))
		local SettingsUi = require(Atmosphere:WaitForChild("SettingsUi"))
		local Feedback = require(script.Parent.Parent:WaitForChild("HUD"):WaitForChild("Feedback"))
		local isRun = mode == Config.Teleport.ModeRun
		local player = Players.LocalPlayer

		-- Server snapshot: reduce-scares setting and which hints are already seen.
		Remotes.event(Remotes.MetaState).OnClientEvent:Connect(function(payload: unknown)
			if type(payload) ~= "table" then
				return
			end
			local settings = (payload :: { [string]: unknown }).settings
			if type(settings) == "table" then
				local value = (settings :: { [string]: unknown }).reduceScares
				if type(value) == "boolean" then
					AtmosphereFx.setMetaReduce(value)
				end
			end
			AtmosphereHints.onMetaState(payload)
		end)
		Remotes.event(Remotes.MetaStateRequest):FireServer()

		SettingsUi.start()
		AtmosphereHints.start(isRun)
		if not isRun then
			return
		end
		-- Studio-only QA through the HUD client bridge (tools/qa/settings-player-path.luau).
		local HudController =
			require(script.Parent.Parent:WaitForChild("HUD"):WaitForChild("HudController"))
		HudController.addQA("settingsToggle", function()
			SettingsUi.toggle()
		end)
		HudController.addQA("settingsState", function()
			return SettingsUi.state()
		end)
		HudController.addQA("hintSeen", AtmosphereHints.isSeen)
		HudController.addQA("hintReset", AtmosphereHints.qaReset)

		-- Cue -> audio + particles. The horror client already plays its own sounds: particles only there.
		Remotes.event(Remotes.Cue).OnClientEvent:Connect(function(payload: unknown)
			if type(payload) ~= "table" then
				return
			end
			local p = payload :: { [string]: unknown }
			local kind = p.kind
			if type(kind) ~= "string" then
				return
			end
			local position = if typeof(p.position) == "Vector3" then p.position :: Vector3 else nil
			AtmosphereHints.onCue(kind)
			if CueResolve.HorrorOwnsSound[kind] then
				AtmosphereFx.playParticle(kind, position)
			else
				AtmosphereFx.play(kind, position)
			end
		end)

		-- Other players' swings (server relays one event per accepted swing to nearby players).
		local windowStart = os.clock()
		local handled = 0
		Remotes.event(Remotes.SwingBroadcast).OnClientEvent:Connect(function(payload: unknown)
			if type(payload) ~= "table" then
				return
			end
			local userId = (payload :: { [string]: unknown }).userId
			if type(userId) ~= "number" or userId == player.UserId then
				return
			end
			local now = os.clock()
			if now - windowStart >= 1 then
				windowStart, handled = now, 0
			end
			if handled >= Config.Perf.SwingMaxPerSecond then
				return
			end
			handled += 1
			local other = Players:GetPlayerByUserId(userId)
			local character = other and other.Character
			if character then
				Feedback.swingOther(character)
			end
		end)

		AtmosphereAmbient.start()
		require(Atmosphere:WaitForChild("BlizzardFx")).start()
		DayBanner.start()
	end)
end

return AtmosphereClient
