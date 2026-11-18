--!strict
-- Client sensory feedback for blizzards and dark events. Driven only by Remotes.Cue (coarse level) and
-- the visible Workspace attributes; no timers or countdowns exist on the client. Visual only.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local AtmosphereFx =
	require(script.Parent.Parent:WaitForChild("Atmosphere"):WaitForChild("AtmosphereFx"))

local MAX_LEVEL = Config.Cue.MaxLevel
local BLEND_PER_SECOND = 0.8 -- how fast the look follows its target
local WARN_FLICKER_HZ = 7 -- light flicker tell during a false night warning
local WARN_FLICKER_AMOUNT = 0.08
local WARN_CLEAR_SECONDS = Config.Events.MaxWarningSeconds + 5 -- stale-warning guard (not shown)
local ATMOSPHERE_NAME = "EventAtmosphere"
local TINT_NAME = "EventTint"

type Look = {
	density: number,
	brightness: number,
	contrast: number,
	saturation: number,
	tint: Color3,
}

local NEUTRAL: Look = {
	density = 0,
	brightness = 0,
	contrast = 0,
	saturation = 0,
	tint = Color3.new(1, 1, 1),
}

local EventCues = {}

local started = false
local connections: { RBXScriptConnection } = {}
local atmosphere: Atmosphere? = nil
local tint: ColorCorrectionEffect? = nil
local current: Look = table.clone(NEUTRAL)
local target: Look = table.clone(NEUTRAL)
local renderConn: RBXScriptConnection? = nil
local warnKind = ""
local warnLevel = 0
local warnToken = 0

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function look(density: number, bright: number, contrast: number, sat: number, c: Color3): Look
	return {
		density = density,
		brightness = bright,
		contrast = contrast,
		saturation = sat,
		tint = c,
	}
end

local function computeTarget()
	local dark = Workspace:GetAttribute(Config.Events.ActiveAttribute)
	-- No full-screen tint/haze for blizzards: that look is BlizzardFx (snow streaks + whiteout fog).
	if Workspace:GetAttribute(Config.Blizzard.ActiveAttribute) == true then
		dark = ""
	end
	if dark == "FalseNight" then
		target = look(0.2, -0.28, 0.1, -0.35, Color3.fromRGB(150, 165, 215))
	elseif dark == "TheQuiet" then
		target = look(0.05, -0.05, 0, -0.55, Color3.fromRGB(235, 235, 240))
	elseif dark == "DeepFreeze" then
		target = look(0.15, 0, 0.05, -0.2, Color3.fromRGB(205, 232, 255))
	elseif warnKind == "WarnTheQuiet" then
		target = look(0.02 * warnLevel, 0, 0, -0.15 * warnLevel, Color3.fromRGB(240, 240, 245))
	elseif warnKind == "WarnDeepFreeze" then
		target = look(0.04 * warnLevel, 0, 0, -0.06 * warnLevel, Color3.fromRGB(225, 240, 255))
	elseif warnKind == "WarnFalseNight" then
		target = look(
			0.03 * warnLevel,
			-0.04 * warnLevel,
			0,
			-0.08 * warnLevel,
			Color3.fromRGB(225, 228, 245)
		)
	else
		target = table.clone(NEUTRAL)
	end
	-- Reduce-scares: the unsettling events (False Night, The Quiet) look softer. Visual only.
	local scary = dark == "FalseNight"
		or dark == "TheQuiet"
		or warnKind == "WarnFalseNight"
		or warnKind == "WarnTheQuiet"
	if scary and AtmosphereFx.reduceScares() then
		local m = AtmosphereFx.scareMultiplier()
		target = look(
			target.density * m,
			target.brightness * m,
			target.contrast * m,
			target.saturation * m,
			NEUTRAL.tint:Lerp(target.tint, m)
		)
	end
end

local function apply(dt: number)
	local a = math.clamp(BLEND_PER_SECOND * dt, 0, 1)
	current.density = lerp(current.density, target.density, a)
	current.brightness = lerp(current.brightness, target.brightness, a)
	current.contrast = lerp(current.contrast, target.contrast, a)
	current.saturation = lerp(current.saturation, target.saturation, a)
	current.tint = current.tint:Lerp(target.tint, a)
	local flicker = 0
	if warnKind == "WarnFalseNight" and not AtmosphereFx.reduceScares() then -- no flashes when reduced
		flicker = math.sin(os.clock() * WARN_FLICKER_HZ * math.pi * 2)
			* WARN_FLICKER_AMOUNT
			* warnLevel
			/ MAX_LEVEL
	end
	if atmosphere then
		atmosphere.Density = current.density
	end
	if tint then
		tint.Brightness = current.brightness + flicker
		tint.Contrast = current.contrast
		tint.Saturation = current.saturation
		tint.TintColor = current.tint
	end
end

local function settled(): boolean
	return math.abs(current.density - target.density) < 0.002
		and math.abs(current.brightness - target.brightness) < 0.002
		and math.abs(current.saturation - target.saturation) < 0.002
		and warnKind ~= "WarnFalseNight"
end

local function refresh()
	computeTarget()
	if renderConn == nil then
		renderConn = RunService.RenderStepped:Connect(function(dt: number)
			apply(dt)
			if settled() and renderConn then
				renderConn:Disconnect()
				renderConn = nil
			end
		end)
	end
end

local function setWarn(kind: string, level: number)
	warnKind, warnLevel = kind, level
	warnToken += 1
	local token = warnToken
	task.delay(WARN_CLEAR_SECONDS, function()
		if warnToken == token then
			warnKind, warnLevel = "", 0
			refresh()
		end
	end)
end

local function onCue(payload: Remotes.CuePayload)
	if type(payload) ~= "table" or type(payload.kind) ~= "string" then
		return
	end
	local level = if type(payload.level) == "number"
		then math.clamp(payload.level, 0, MAX_LEVEL)
		else 0
	local kind = payload.kind
	if
		kind == "WarnBlizzard"
		or kind == "WarnFalseNight"
		or kind == "WarnTheQuiet"
		or kind == "WarnDeepFreeze"
	then
		setWarn(kind, math.max(level, 1))
	elseif kind == "EventStart" or kind == "EventEnd" then
		warnKind, warnLevel = "", 0
		warnToken += 1
	else
		return -- not an event cue (Dread/Stalker cues belong to brief 15)
	end
	refresh()
end

function EventCues.start()
	if started then
		return
	end
	started = true
	local existing = Lighting:FindFirstChildOfClass("Atmosphere")
	if existing then
		atmosphere = existing
		current.density, target.density = existing.Density, existing.Density
	else
		local atmo = Instance.new("Atmosphere")
		atmo.Name = ATMOSPHERE_NAME
		atmo.Density = 0
		atmo.Parent = Lighting
		atmosphere = atmo
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = TINT_NAME
	cc.Parent = Lighting
	tint = cc
	table.insert(connections, Remotes.event(Remotes.Cue).OnClientEvent:Connect(onCue))
	for _, attr in { Config.Events.ActiveAttribute, Config.Blizzard.ActiveAttribute } do
		table.insert(connections, Workspace:GetAttributeChangedSignal(attr):Connect(refresh))
	end
	refresh()
end

function EventCues.stop()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
	if tint then
		tint:Destroy()
		tint = nil
	end
	started = false
end

return EventCues
