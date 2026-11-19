--!strict
-- Client blizzard presentation: wind-whipped snow streaks that follow the camera, and a whiteout
-- (Atmosphere + fog toward white, ~PeakVisibility studs at peak) that eases in/out over EaseSeconds.
-- Driven only by Workspace attributes (Blizzard, BlizzardWarning, BlizzardIntensity); wind is a pure
-- function of server time (logic/BlizzardWind). No full-screen overlay (optional faint vignette only).
-- Particles are capped (lower on touch devices); no parts are added, so no part-budget impact.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local BlizzardWind = require(Shared:WaitForChild("logic"):WaitForChild("BlizzardWind"))

local B = Config.Blizzard
local BIND_NAME = "BlizzardFxWhiteout"
local GLOW_NAME = "BlizzardGlow"
local GLOW_SCAN_SECONDS = 1

local BlizzardFx = {}

type Tracked = { base: number, written: number }

local started = false
local presence = 0 -- eased 0..1
local intensity = 0 -- eased 0..1
local debugIntensity: number? = nil -- client-only override (nil = follow server)
local holder: Part? = nil
local streaks: ParticleEmitter? = nil
local flakes: ParticleEmitter? = nil
local windAccum = 0
local glowAccum = 0
local tracks: { [Instance]: { [string]: Tracked } } = {}
local colorTracks: { [Instance]: { [string]: { base: Color3, written: Color3 } } } = {}
local glowing: { [Instance]: Highlight } = {}
local vignette: ScreenGui? = nil
local conns: { RBXScriptConnection } = {}

local function isMobile(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function col(c: { number }, scale: number): Color3
	return Color3.fromRGB(
		math.floor(c[1] * scale + 0.5),
		math.floor(c[2] * scale + 0.5),
		math.floor(c[3] * scale + 0.5)
	)
end

-- Blend `inst[prop]` toward `target` by w without compounding: if another system rewrote the value,
-- that becomes the new base; if the value is still the one we wrote, keep the stored base.
local function blendNumber(inst: Instance, prop: string, target: number, w: number)
	local forInst = tracks[inst]
	if forInst == nil then
		forInst = {}
		tracks[inst] = forInst
	end
	local cur = (inst :: any)[prop] :: number
	local t = forInst[prop]
	if t == nil or math.abs(cur - t.written) > 1e-4 then
		t = { base = cur, written = cur }
		forInst[prop] = t
	end
	local v = BlizzardWind.lerp(t.base, target, w)
	t.written = v;
	(inst :: any)[prop] = v
end

local function blendColor(inst: Instance, prop: string, target: Color3, w: number)
	local forInst = colorTracks[inst]
	if forInst == nil then
		forInst = {}
		colorTracks[inst] = forInst
	end
	local cur = (inst :: any)[prop] :: Color3
	local t = forInst[prop]
	if t == nil or cur ~= t.written then
		t = { base = cur, written = cur }
		forInst[prop] = t
	end
	local v = t.base:Lerp(target, w)
	t.written = v;
	(inst :: any)[prop] = v
end

local function releaseTracks()
	-- Clear stale entries (instances may be gone); live ones re-seed from their own value next frame.
	table.clear(tracks)
	table.clear(colorTracks)
end

local function targetIntensity(): number
	local dbg = debugIntensity
	if dbg ~= nil then
		return dbg
	end
	local v = Workspace:GetAttribute(B.IntensityAttribute)
	if type(v) == "number" then
		return math.clamp(v, 0, 1)
	end
	return 0
end

local function targetPresence(): number
	if debugIntensity ~= nil or Workspace:GetAttribute(B.ActiveAttribute) == true then
		return 1
	end
	if Workspace:GetAttribute(B.WarningAttribute) == true then
		return B.WarningPresence
	end
	return 0
end

local function applyWind()
	local part, s, f = holder, streaks, flakes
	local camera = Workspace.CurrentCamera
	if part == nil or s == nil or f == nil or camera == nil then
		return
	end
	local wind = BlizzardWind.sample(Workspace:GetServerTimeNow(), intensity, B)
	local dir = Vector3.new(wind.dirX, 0, wind.dirZ)
	local center = camera.CFrame.Position
	local pos = center - dir * B.SpawnUpwind + Vector3.new(0, B.SpawnHeight * 0.25, 0)
	part.CFrame = CFrame.lookAt(pos, pos + dir)
	local visible = presence * math.max(intensity, B.WarningPresence * 0.5)
	local avgLife = (B.StreakLifetime[1] + B.StreakLifetime[2]) * 0.5
	local cap = BlizzardWind.particleCap(isMobile(), B.MaxParticles, B.MaxParticlesMobile)
	local rate = BlizzardWind.emissionRate(visible, B.RatePerIntensity, cap, avgLife)
	s.Rate = rate * 0.65
	f.Rate = rate * 0.35
	s.Speed = NumberRange.new(wind.strength * 0.9, wind.strength * 1.15)
	f.Speed = NumberRange.new(wind.strength * 0.5, wind.strength * 0.8)
	-- Slight downward drift; the wind is the main motion.
	s.Acceleration = Vector3.new(0, -6, 0)
	f.Acceleration = Vector3.new(0, -10, 0)
	s.Enabled = rate > 0
	f.Enabled = rate > 0
end

local function makeEmitter(
	name: string,
	width: number,
	squash: number,
	life: { number }
): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = B.Texture
	e.Rate = 0
	e.Enabled = false
	e.Lifetime = NumberRange.new(life[1], life[2])
	e.Size = NumberSequence.new(width)
	e.Squash = NumberSequence.new(squash)
	e.Transparency = NumberSequence.new(B.StreakTransparency)
	e.LightEmission = B.LightEmission
	e.LightInfluence = 0
	e.Color = ColorSequence.new(Color3.new(1, 1, 1))
	e.EmissionDirection = Enum.NormalId.Front
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Drag = 0
	e.RotSpeed = NumberRange.new(0)
	return e
end

local function whiteoutStep()
	local w = BlizzardWind.whiteout(presence, intensity, B.FullWhiteoutIntensity)
	local outdoor = Lighting.OutdoorAmbient
	local dayOutdoor = Config.Lighting.DayOutdoorAmbient
	local current = (outdoor.R + outdoor.G + outdoor.B) / 3 * 255
	local day = (dayOutdoor[1] + dayOutdoor[2] + dayOutdoor[3]) / 3
	local white = col(B.WhiteColor, BlizzardWind.lightScale(current, day, B.MinLightScale))
	if w <= 0.001 then
		if next(tracks) ~= nil or next(colorTracks) ~= nil then
			-- Restore: blending at w = 0 writes the base back, then forget.
			for _, child in Lighting:GetChildren() do
				if child:IsA("Atmosphere") then
					blendNumber(child, "Density", 0, 0)
					blendNumber(child, "Offset", 0, 0)
					blendNumber(child, "Haze", 0, 0)
					blendColor(child, "Color", white, 0)
					blendColor(child, "Decay", white, 0)
				end
			end
			blendColor(Lighting, "FogColor", white, 0)
			blendNumber(Lighting, "FogStart", 0, 0)
			blendNumber(Lighting, "FogEnd", 0, 0)
			releaseTracks()
		end
		return
	end
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") then
			blendNumber(child, "Density", B.AtmoDensity, w)
			blendNumber(child, "Offset", B.AtmoOffset, w)
			blendNumber(child, "Haze", B.AtmoHaze, w)
			blendColor(child, "Color", white, w)
			blendColor(child, "Decay", white, w)
		end
	end
	blendColor(Lighting, "FogColor", white, w)
	blendNumber(Lighting, "FogStart", B.FogStartPeak, w)
	blendNumber(Lighting, "FogEnd", B.PeakVisibility, w)
end

-- Fires and warm spots stay faintly visible through the whiteout: a faint always-on-top highlight on the
-- nearest few (capped), removed when the whiteout fades.
local function glowStep(w: number)
	local camera = Workspace.CurrentCamera
	if camera == nil or w <= 0.05 then
		for inst, h in glowing do
			h:Destroy()
			glowing[inst] = nil
		end
		return
	end
	local origin = camera.CFrame.Position
	local found: { { inst: Instance, d: number } } = {}
	local tags = table.clone(B.GlowTags)
	table.insert(tags, Config.Fire.Tag)
	for _, tag in tags do
		for _, inst in CollectionService:GetTagged(tag) do
			local pos = if inst:IsA("BasePart")
				then inst.Position
				elseif inst:IsA("Model") then inst:GetPivot().Position
				else nil
			if pos then
				local d = (pos - origin).Magnitude
				if d <= B.GlowRange then
					table.insert(found, { inst = inst, d = d })
				end
			end
		end
	end
	table.sort(found, function(a, b)
		return a.d < b.d
	end)
	local keep: { [Instance]: boolean } = {}
	for i = 1, math.min(#found, B.GlowMax) do
		local inst = found[i].inst
		keep[inst] = true
		local existing: Highlight? = glowing[inst]
		if existing == nil then
			local h = Instance.new("Highlight")
			h.Name = GLOW_NAME
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.FillColor = col(B.GlowColor, 1)
			h.OutlineColor = col(B.GlowColor, 1)
			h.Adornee = inst
			h.Parent = inst
			glowing[inst] = h
		end
	end
	for inst, h in glowing do
		if not keep[inst] or inst.Parent == nil then
			h:Destroy()
			glowing[inst] = nil
		else
			h.FillTransparency = BlizzardWind.lerp(1, B.GlowTransparency, w)
			h.OutlineTransparency = BlizzardWind.lerp(1, B.GlowOutlineTransparency, w)
		end
	end
end

local function buildVignette()
	local alpha = BlizzardWind.vignetteAlpha(B.VignetteAlpha, B.VignetteMaxAlpha)
	if alpha <= 0 then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "BlizzardVignette"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1
	local edges: { { size: UDim2, pos: UDim2, rot: number } } = {
		{ size = UDim2.fromScale(1, 0.18), pos = UDim2.fromScale(0, 0), rot = 90 },
		{ size = UDim2.fromScale(1, 0.18), pos = UDim2.fromScale(0, 0.82), rot = 270 },
		{ size = UDim2.fromScale(0.12, 1), pos = UDim2.fromScale(0, 0), rot = 0 },
		{ size = UDim2.fromScale(0.12, 1), pos = UDim2.fromScale(0.88, 0), rot = 180 },
	}
	for _, e in edges do
		local f = Instance.new("Frame")
		f.Size = e.size
		f.Position = e.pos
		f.BackgroundColor3 = col(B.WhiteColor, 1)
		f.BorderSizePixel = 0
		f.Active = false
		local g = Instance.new("UIGradient")
		g.Rotation = e.rot
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1 - alpha),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = f
		f.Parent = gui
	end
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	vignette = gui
end

local function frame(dt: number)
	presence = BlizzardWind.approach(presence, targetPresence(), dt, B.EaseSeconds)
	intensity = BlizzardWind.approach(intensity, targetIntensity(), dt, B.EaseSeconds * 0.25)
	whiteoutStep()
	windAccum += dt
	if windAccum >= B.WindUpdateInterval then
		windAccum = 0
		applyWind()
	end
	glowAccum += dt
	if glowAccum >= GLOW_SCAN_SECONDS then
		glowAccum = 0
		glowStep(BlizzardWind.whiteout(presence, intensity, B.FullWhiteoutIntensity))
	end
	local v = vignette
	if v then
		v.Enabled = presence > 0.01
	end
end

-- Client-only test hook: pins the visible intensity locally (nil follows the server attributes).
function BlizzardFx.DebugSetIntensity(value: number?)
	debugIntensity = if value == nil then nil else math.clamp(value, 0, 1)
end

function BlizzardFx.start()
	if started then
		return
	end
	started = true
	local part = Instance.new("Part")
	part.Name = "BlizzardSnow"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(B.SpawnWidth, B.SpawnHeight, 1)
	local s = makeEmitter("Streaks", B.StreakWidth, B.StreakSquash, B.StreakLifetime)
	local f = makeEmitter("Flakes", B.StreakWidth * 0.6, B.StreakSquash * 0.5, B.StreakLifetime)
	s.Parent = part
	f.Parent = part
	part.Parent = Workspace.CurrentCamera or Workspace
	holder, streaks, flakes = part, s, f
	buildVignette()
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Last.Value, frame)
	table.insert(
		conns,
		Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			if holder and Workspace.CurrentCamera then
				holder.Parent = Workspace.CurrentCamera
			end
		end)
	)
end

function BlizzardFx.stop()
	if not started then
		return
	end
	started = false
	RunService:UnbindFromRenderStep(BIND_NAME)
	for _, c in conns do
		c:Disconnect()
	end
	table.clear(conns)
	for inst, h in glowing do
		h:Destroy()
		glowing[inst] = nil
	end
	releaseTracks()
	if holder then
		holder:Destroy()
		holder, streaks, flakes = nil, nil, nil
	end
	if vignette then
		vignette:Destroy()
		vignette = nil
	end
end

return BlizzardFx
