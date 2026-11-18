--!strict
-- Biome look (art pass 2), run servers only: atmosphere, colour grade and falling snow / wind streaks
-- that follow the local player's position and blend smoothly across ring borders (shared/logic/
-- BiomeBlend). Client-side only: it adds its own Atmosphere / ColorCorrection / one emitter plate and
-- never writes Lighting properties (DayNightService owns those). One RenderStepped loop, no remotes.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ArtKit = require(Shared:WaitForChild("ArtKit"))
local BiomeBlend = require(Shared:WaitForChild("logic"):WaitForChild("BiomeBlend"))
local Biomes = require(Shared:WaitForChild("data"):WaitForChild("Biomes"))
local WorldLayout = require(Shared:WaitForChild("logic"):WaitForChild("WorldLayout"))

local W = Config.Art.World
local SMOOTHING = 2 -- 1/seconds: how fast the look follows the target
local RATE_EPSILON = 0.25

local BiomeFx = {}

type Look = {
	atmColor: Color3,
	atmDecay: Color3,
	density: number,
	haze: number,
	glare: number,
	tint: Color3,
	saturation: number,
	contrast: number,
	brightness: number,
	snowRate: number,
	snowSpeed: number,
	snowDrift: number,
	windRate: number,
	windSpeed: number,
}

local function lookOf(def: Config.WorldBiomeArt): Look
	return {
		atmColor = ArtKit.color(def.Atmosphere.Color),
		atmDecay = ArtKit.color(def.Atmosphere.Decay),
		density = def.Atmosphere.Density,
		haze = def.Atmosphere.Haze,
		glare = def.Atmosphere.Glare,
		tint = ArtKit.color(def.Tint.Color),
		saturation = def.Tint.Saturation,
		contrast = def.Tint.Contrast,
		brightness = def.Tint.Brightness,
		snowRate = def.Snow.Rate,
		snowSpeed = def.Snow.Speed,
		snowDrift = def.Snow.Drift,
		windRate = def.Wind.Rate,
		windSpeed = def.Wind.Speed,
	}
end

local function mix(a: Look, b: Look, t: number): Look
	local function n(x: number, y: number): number
		return x + (y - x) * t
	end
	return {
		atmColor = a.atmColor:Lerp(b.atmColor, t),
		atmDecay = a.atmDecay:Lerp(b.atmDecay, t),
		density = n(a.density, b.density),
		haze = n(a.haze, b.haze),
		glare = n(a.glare, b.glare),
		tint = a.tint:Lerp(b.tint, t),
		saturation = n(a.saturation, b.saturation),
		contrast = n(a.contrast, b.contrast),
		brightness = n(a.brightness, b.brightness),
		snowRate = n(a.snowRate, b.snowRate),
		snowSpeed = n(a.snowSpeed, b.snowSpeed),
		snowDrift = n(a.snowDrift, b.snowDrift),
		windRate = n(a.windRate, b.windRate),
		windSpeed = n(a.windSpeed, b.windSpeed),
	}
end

local function makeEmitter(plate: Part, name: string, wind: boolean): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = W.ParticleTexture
	e.Rate = 0
	e.Color = ColorSequence.new(Color3.fromRGB(240, 246, 255))
	e.LightEmission = 0.25
	e.LightInfluence = 0.4
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.25),
		NumberSequenceKeypoint.new(0.85, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	if wind then
		e.Lifetime = NumberRange.new(1.2, 2)
		e.EmissionDirection = Enum.NormalId.Front
		e.SpreadAngle = Vector2.new(4, 4)
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.Size = NumberSequence.new(2.6)
	else
		e.Lifetime = NumberRange.new(5, 7)
		e.EmissionDirection = Enum.NormalId.Bottom
		e.SpreadAngle = Vector2.new(8, 8)
		e.Size = NumberSequence.new(0.35)
	end
	e.Parent = plate
	return e
end

function BiomeFx.start(): () -> ()
	local looks: { Look } = {}
	for ring = 0, WorldLayout.maxRing(Config.World.GridSize) do
		looks[ring + 1] = lookOf(W.Biomes[Biomes.forRing(ring).id] or W.Biomes.SnowyForest)
	end

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "BiomeAtmosphere"
	atmosphere.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "BiomeGrade"
	grade.Parent = Lighting
	local plate = Instance.new("Part")
	plate.Name = "BiomeParticles"
	plate.Anchored = true
	plate.CanCollide = false
	plate.CanQuery = false
	plate.CanTouch = false
	plate.CastShadow = false
	plate.Transparency = 1
	plate.Size = Vector3.new(W.ParticleArea, 1, W.ParticleArea)
	local snow = makeEmitter(plate, "Snow", false)
	local wind = makeEmitter(plate, "Wind", true)
	plate.Parent = Workspace

	local current: Look = looks[1]
	local sinceUpdate = W.UpdateInterval
	local target: Look = looks[1]
	local localPlayer = Players.LocalPlayer

	local function applyLook(look: Look)
		atmosphere.Color = look.atmColor
		atmosphere.Decay = look.atmDecay
		atmosphere.Density = look.density
		atmosphere.Haze = look.haze
		atmosphere.Glare = look.glare
		grade.TintColor = look.tint
		grade.Saturation = look.saturation
		grade.Contrast = look.contrast
		grade.Brightness = look.brightness
		-- particle rates share one cap
		local total = look.snowRate + look.windRate
		local scale = if total > W.MaxParticleRate then W.MaxParticleRate / total else 1
		local snowRate = look.snowRate * scale
		local windRate = look.windRate * scale
		if math.abs(snow.Rate - snowRate) > RATE_EPSILON then
			snow.Rate = snowRate
		end
		if math.abs(wind.Rate - windRate) > RATE_EPSILON then
			wind.Rate = windRate
		end
		snow.Speed = NumberRange.new(look.snowSpeed * 0.8, look.snowSpeed)
		snow.Acceleration = Vector3.new(look.snowDrift, 0, look.snowDrift * 0.35)
		wind.Speed = NumberRange.new(look.windSpeed * 0.8, look.windSpeed)
	end
	applyLook(current)

	local connection = RunService.RenderStepped:Connect(function(dt: number)
		local camera = Workspace.CurrentCamera
		if camera then
			plate.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, W.ParticleHeight, 0))
		end
		sinceUpdate += dt
		if sinceUpdate >= W.UpdateInterval then
			sinceUpdate = 0
			local character = localPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local p = root.Position
				local weights =
					BiomeBlend.weights(p.X, p.Z, Config.World.ChunkSize, #looks - 1, W.BlendStuds)
				local first = weights[1]
				local second = weights[2]
				target = looks[first.ring + 1]
				if second then
					target = mix(looks[first.ring + 1], looks[second.ring + 1], second.weight)
				end
			end
		end
		current = mix(current, target, 1 - math.exp(-SMOOTHING * dt))
		applyLook(current)
	end)

	return function()
		connection:Disconnect()
		atmosphere:Destroy()
		grade:Destroy()
		plate:Destroy()
	end
end

return BiomeFx
