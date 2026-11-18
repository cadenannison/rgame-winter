--!strict
-- One loop for every ambient effect (brief 20): wind/snow, blizzard and dark-event loops (driven by the
-- visible Workspace attributes, no timers), and a single fire crackle that follows the nearest fire.
-- Sounds and particles come from AudioCues rows via Assets (a "" id is silent). Reduce-scares scales the
-- scary rows. Emitters count against Perf.MaxParticleEmitters; one Heartbeat connection drives everything.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CueResolve = require(Shared:WaitForChild("logic"):WaitForChild("CueResolve"))
local PerfBudget = require(Shared:WaitForChild("logic"):WaitForChild("PerfBudget"))
local AtmosphereConfig = require(script.Parent:WaitForChild("AtmosphereConfig"))
local AtmosphereFx = require(script.Parent:WaitForChild("AtmosphereFx"))

local C = AtmosphereConfig
local PERF = Config.Perf

local AtmosphereAmbient = {}

type Loop = {
	sound: Sound?,
	emitter: ParticleEmitter?,
	reserved: boolean,
	volume: number, -- current faded volume
}

local loops: { [string]: Loop } = {}
local connection: RBXScriptConnection? = nil
local accumulator = 0
local holder: Part? = nil -- follows the camera; carries the snow/blizzard emitters
local fireHolder: Attachment? = nil
local started = false

local function newEmitter(textureId: string, parent: Instance, shapeBox: boolean): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = textureId
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(4, 6)
	emitter.Speed = NumberRange.new(2, 5)
	emitter.Acceleration = Vector3.new(0, -4, 0)
	emitter.Size = NumberSequence.new(C.ParticleSize)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	if shapeBox then
		emitter.Shape = Enum.ParticleEmitterShape.Box
	end
	emitter.Parent = parent
	return emitter
end

-- Get or create the loop for a row key. Allocated lazily, released when the row is no longer wanted.
local function ensureLoop(key: string, parent: Instance, box: boolean): Loop?
	local existing = loops[key]
	if existing then
		return existing
	end
	local pres = CueResolve.resolve(key, AtmosphereFx.reduceScares())
	if pres == nil then
		return nil
	end
	local loop: Loop = { sound = nil, emitter = nil, reserved = false, volume = 0 }
	if pres.soundId ~= "" then
		local sound = Instance.new("Sound")
		sound.SoundId = pres.soundId
		sound.Looped = true
		sound.Volume = 0
		sound.Parent = SoundService
		sound:Play()
		loop.sound = sound
	end
	if pres.particleId ~= "" and AtmosphereFx.reserveEmitter() then
		loop.reserved = true
		loop.emitter = newEmitter(pres.particleId, parent, box)
	end
	loops[key] = loop
	return loop
end

local function releaseLoop(key: string)
	local loop = loops[key]
	if loop == nil then
		return
	end
	loops[key] = nil
	if loop.sound then
		loop.sound:Destroy()
	end
	if loop.emitter then
		loop.emitter:Destroy()
	end
	if loop.reserved then
		AtmosphereFx.releaseEmitter()
	end
end

-- Drive one loop toward wanted (0..1 share of the row volume) and particle rate scale.
local function drive(
	key: string,
	want: number,
	rateScale: number,
	parent: Instance,
	box: boolean,
	dt: number
)
	if want <= 0 then
		local loop = loops[key]
		if loop == nil then
			return
		end
		loop.volume = math.max(0, loop.volume - C.LoopFadePerSecond * dt)
		if loop.sound then
			loop.sound.Volume = loop.volume
		end
		if loop.emitter then
			loop.emitter.Rate = 0
		end
		if loop.volume <= 0 then
			releaseLoop(key)
		end
		return
	end
	local loop = ensureLoop(key, parent, box)
	local pres = CueResolve.resolve(key, AtmosphereFx.reduceScares())
	if loop == nil or pres == nil then
		return
	end
	local target = pres.volume * want
	if loop.volume < target then
		loop.volume = math.min(target, loop.volume + C.LoopFadePerSecond * dt)
	else
		loop.volume = math.max(target, loop.volume - C.LoopFadePerSecond * dt)
	end
	if loop.sound then
		loop.sound.Volume = loop.volume
	end
	if loop.emitter then
		loop.emitter.Rate =
			PerfBudget.clampRate(C.SnowRate * rateScale, PERF.MaxParticleRate, pres.particleScale)
	end
end

local function nearestFire(from: Vector3): (Instance?, number)
	local best: Instance? = nil
	local bestDist = C.FireCrackleRange
	for _, fire in CollectionService:GetTagged(Config.Fire.Tag) do
		local pos = if fire:IsA("BasePart")
			then fire.Position
			elseif fire:IsA("Model") then fire:GetPivot().Position
			else nil
		if pos then
			local d = (pos - from).Magnitude
			if d < bestDist then
				best, bestDist = fire, d
			end
		end
	end
	return best, bestDist
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	local part = holder
	if camera == nil or part == nil then
		return
	end
	local center = camera.CFrame.Position
	part.CFrame = CFrame.new(center + Vector3.new(0, C.SnowHeight, 0))
	local blizzard = Workspace:GetAttribute(Config.Blizzard.ActiveAttribute) == true
	local dark = Workspace:GetAttribute(Config.Events.ActiveAttribute)
	local quiet = dark == "TheQuiet"

	-- Ambient wind and snow (ducked to silence during The Quiet: silence is its cue).
	drive("WindAmbient", if quiet then 0 else 1, 1, part, true, dt)
	drive("Blizzard", if blizzard then 1 else 0, C.BlizzardRateScale, part, true, dt)
	for _, id in Config.Debug.DarkEvents do
		drive(id, if dark == id then 1 else 0, 1, part, true, dt)
	end

	-- One crackle for the nearest fire.
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local fire, dist = nil :: Instance?, math.huge
	if root and root:IsA("BasePart") then
		fire, dist = nearestFire(root.Position)
	end
	local fh = fireHolder
	if fire and fh then
		local pos = if fire:IsA("BasePart")
			then fire.Position
			else (fire :: Model):GetPivot().Position
		fh.WorldPosition = pos
		drive("FireCrackle", 1 - dist / C.FireCrackleRange, 1, fh, false, dt)
		local loop = loops["FireCrackle"]
		if loop and loop.emitter then
			loop.emitter.Rate = math.min(C.FireEmberRate, PERF.MaxParticleRate)
		end
	else
		drive("FireCrackle", 0, 1, fh or part, false, dt)
	end
end

function AtmosphereAmbient.start()
	if started then
		return
	end
	started = true
	local part = Instance.new("Part")
	part.Name = "AtmosphereSnow"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(C.SnowAreaSize, 1, C.SnowAreaSize)
	part.Parent = Workspace.CurrentCamera or Workspace
	holder = part
	local attachment = Instance.new("Attachment")
	attachment.Name = "AtmosphereFire"
	attachment.Parent = Workspace.Terrain
	fireHolder = attachment
	connection = RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < C.LoopInterval then
			return
		end
		local elapsed = accumulator
		accumulator = 0
		step(elapsed)
	end)
end

function AtmosphereAmbient.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	for key in table.clone(loops) do
		releaseLoop(key)
	end
	if holder then
		holder:Destroy()
		holder = nil
	end
	if fireHolder then
		fireHolder:Destroy()
		fireHolder = nil
	end
	started = false
end

return AtmosphereAmbient
