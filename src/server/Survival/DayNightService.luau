--!strict
-- Server day/night clock. One Heartbeat connection; publishes Workspace attributes.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local DayClock = require(Shared.logic.DayClock)
local LightingMath = require(Shared.logic.LightingMath)
local DebugService = require(script.Parent.Parent.Debug.DebugService)

local T = Config.Time
local L = Config.Lighting
local HOUR_PRECISION = 10 -- hour attribute rounded to 1/10 hour to avoid per-frame writes

local DayNightService = {}

local elapsed = 0
local speed = 1
local started = false
local info: DayClock.Info = DayClock.at(0, T)
local connection: RBXScriptConnection? = nil
local lightAccum = 0
local unregisters: { () -> () } = {}

local function publish()
	info = DayClock.at(elapsed, T)
	Workspace:SetAttribute(T.DayAttribute, info.day)
	Workspace:SetAttribute(T.IsNightAttribute, info.isNight)
	Workspace:SetAttribute(
		T.ClockAttribute,
		math.floor(info.hour * HOUR_PRECISION + 0.5) / HOUR_PRECISION
	)
end

local function color(c: { number }): Color3
	return Color3.fromRGB(math.floor(c[1] + 0.5), math.floor(c[2] + 0.5), math.floor(c[3] + 0.5))
end

-- Writes Lighting for the current phase: dusk/dawn blend smoothly between the day and night looks.
local function applyLighting()
	local n = LightingMath.nightAmount(info.phase, T.DayFraction, L.TwilightPhase)
	local mix = LightingMath.lerp
	Lighting.ClockTime = mix(L.DayClockTime, L.NightClockTime, n)
	Lighting.Ambient = color(LightingMath.lerpColor(L.DayAmbient, L.NightAmbient, n))
	Lighting.OutdoorAmbient =
		color(LightingMath.lerpColor(L.DayOutdoorAmbient, L.NightOutdoorAmbient, n))
	Lighting.Brightness = mix(L.DayBrightness, L.NightBrightness, n)
	Lighting.FogColor = color(LightingMath.lerpColor(L.DayFogColor, L.NightFogColor, n))
	Lighting.FogStart = mix(L.DayFogStart, L.NightFogStart, n)
	Lighting.FogEnd = mix(L.DayFogEnd, L.NightFogEnd, n)
end

function DayNightService.getDay(): number
	return info.day
end

function DayNightService.isNight(): boolean
	return info.isNight
end

function DayNightService.getElapsed(): number
	return elapsed
end

function DayNightService.setDay(day: number)
	elapsed = DayClock.elapsedForDay(math.floor(day), T)
	publish()
	applyLighting()
end

function DayNightService.setClockSpeed(multiplier: number)
	speed = math.max(multiplier, 0)
end

function DayNightService.start()
	if started then
		return
	end
	started = true
	elapsed = 0
	speed = 1
	publish()
	applyLighting()
	connection = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt * speed
		publish()
		lightAccum += dt
		if lightAccum >= L.UpdateInterval then
			lightAccum = 0
			applyLighting()
		end
	end)
	table.insert(
		unregisters,
		DebugService.register("setDay", function(_player, arg)
			if type(arg) == "number" then
				DayNightService.setDay(arg)
			end
		end)
	)
	table.insert(
		unregisters,
		DebugService.register("clockSpeed", function(_player, arg)
			if type(arg) == "number" then
				DayNightService.setClockSpeed(arg)
			end
		end)
	)
end

function DayNightService.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	for _, unregister in unregisters do
		unregister()
	end
	table.clear(unregisters)
	started = false
end

return DayNightService
