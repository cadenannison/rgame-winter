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
local forcedNight = false -- dark event with night rules (False Night): counts as night for every system

local function publish()
	info = DayClock.at(elapsed, T)
	Workspace:SetAttribute(T.DayAttribute, info.day)
	Workspace:SetAttribute(T.IsNightAttribute, info.isNight or forcedNight)
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
	-- Shadows: night keeps an ambient and brightness floor (Config.Shadows) so the forest stays readable
	-- on a phone while the shadowed floor under the canopy is still dim.
	local SH = Config.Shadows
	local ambient = LightingMath.lerpColor(L.DayAmbient, L.NightAmbient, n)
	local outdoor = LightingMath.lerpColor(L.DayOutdoorAmbient, L.NightOutdoorAmbient, n)
	-- Moonlight floors (Config.Lighting.Moon*) are the readable night minimum; Shadows floors still apply.
	local moonAmbient = LightingMath.lerpColor({ 0, 0, 0 }, L.MoonAmbient, n)
	local moonOutdoor = LightingMath.lerpColor({ 0, 0, 0 }, L.MoonOutdoorAmbient, n)
	local shadeAmbient = LightingMath.lerpColor(SH.NightMinAmbient, { 0, 0, 0 }, 1 - n)
	local shadeOutdoor = LightingMath.lerpColor(SH.NightMinOutdoorAmbient, { 0, 0, 0 }, 1 - n)
	local floorAmbient = {
		math.max(moonAmbient[1], shadeAmbient[1]),
		math.max(moonAmbient[2], shadeAmbient[2]),
		math.max(moonAmbient[3], shadeAmbient[3]),
	}
	local floorOutdoor = {
		math.max(moonOutdoor[1], shadeOutdoor[1]),
		math.max(moonOutdoor[2], shadeOutdoor[2]),
		math.max(moonOutdoor[3], shadeOutdoor[3]),
	}
	Lighting.Ambient = color({
		math.max(ambient[1], floorAmbient[1]),
		math.max(ambient[2], floorAmbient[2]),
		math.max(ambient[3], floorAmbient[3]),
	})
	Lighting.OutdoorAmbient = color({
		math.max(outdoor[1], floorOutdoor[1]),
		math.max(outdoor[2], floorOutdoor[2]),
		math.max(outdoor[3], floorOutdoor[3]),
	})
	Lighting.Brightness = math.max(
		mix(L.DayBrightness, L.NightBrightness, n),
		SH.NightMinBrightness * n,
		L.MoonBrightness * n
	)
	Lighting.ExposureCompensation = L.MoonExposure * n
	Lighting.FogColor = color(LightingMath.lerpColor(L.DayFogColor, L.NightFogColor, n))
	Lighting.FogStart = mix(L.DayFogStart, L.NightFogStart, n)
	Lighting.FogEnd = mix(L.DayFogEnd, L.NightFogEnd, n)
end

function DayNightService.getDay(): number
	return info.day
end

function DayNightService.isNight(): boolean
	return info.isNight or forcedNight
end

-- Wiring (init.server, EventService nightRules): a False Night makes night rules apply in daylight.
function DayNightService.setForcedNight(on: boolean)
	forcedNight = on == true
	publish()
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
	Lighting.GlobalShadows = Config.Shadows.GlobalShadows
	Lighting.ShadowSoftness = Config.Shadows.ShadowSoftness
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
	forcedNight = false
	started = false
end

return DayNightService
