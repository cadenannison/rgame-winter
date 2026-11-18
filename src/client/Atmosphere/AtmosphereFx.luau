--!strict
-- Client audio/particle player for AudioCues rows (brief 20). play(key, position?) looks the key up,
-- applies reduce-scares scaling and the Perf caps (MaxActiveSounds, MaxParticleEmitters, MaxParticleRate)
-- and silently does nothing for a missing row or an empty asset id. Presentation only.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CueResolve = require(Shared:WaitForChild("logic"):WaitForChild("CueResolve"))
local PerfBudget = require(Shared:WaitForChild("logic"):WaitForChild("PerfBudget"))
local AtmosphereConfig = require(script.Parent:WaitForChild("AtmosphereConfig"))

local AtmosphereFx = {}

local C = AtmosphereConfig
local PERF = Config.Perf
local player = Players.LocalPlayer

local activeSounds = 0
local activeEmitters = 0
local metaReduce: boolean? = nil -- MetaState settings.reduceScares (fallback before the attribute exists)
local override: boolean? = nil -- optimistic toggle until the server value arrives
local overrideToken = 0

-- True when the player's reduce-scares setting is on (server attribute, else meta snapshot).
function AtmosphereFx.reduceScares(): boolean
	if override ~= nil then
		return override
	end
	local attr = player:GetAttribute(Config.Settings.ReduceScaresAttribute)
	if type(attr) == "boolean" then
		return attr
	end
	if metaReduce ~= nil then
		return metaReduce
	end
	return Config.Settings.DefaultReduceScares
end

-- Intensity multiplier for scary visuals/sounds: 1 normally, Settings.ReducedScareVisualMultiplier when on.
function AtmosphereFx.scareMultiplier(): number
	return CueResolve.scale(true, AtmosphereFx.reduceScares())
end

function AtmosphereFx.setMetaReduce(value: boolean)
	metaReduce = value
end

-- Optimistic local value after the player toggles (the server confirms through the attribute).
function AtmosphereFx.setOverride(value: boolean)
	override = value
	overrideToken += 1
	local token = overrideToken
	task.delay(C.OverrideSeconds, function()
		if overrideToken == token then
			override = nil
		end
	end)
end

function AtmosphereFx.clearOverride()
	override = nil
	overrideToken += 1
end

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

function AtmosphereFx.activeEmitters(): number
	return activeEmitters
end

-- Reserve one emitter slot under the cap; false when full. Pair with releaseEmitter.
function AtmosphereFx.reserveEmitter(): boolean
	if not PerfBudget.canAdd(activeEmitters, PERF.MaxParticleEmitters) then
		return false
	end
	activeEmitters += 1
	return true
end

function AtmosphereFx.releaseEmitter()
	activeEmitters = math.max(0, activeEmitters - 1)
end

-- One-shot sound (3D when a position is given). Returns false when skipped.
local function playSound(soundId: string, volume: number, position: Vector3?): boolean
	if
		soundId == ""
		or volume <= 0
		or not PerfBudget.canAdd(activeSounds, PERF.MaxActiveSounds)
	then
		return false
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	local holder: Instance = SoundService
	if position then
		sound.RollOffMaxDistance = C.SoundMaxDistance
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = position
		attachment.Parent = Workspace.Terrain
		holder = attachment
	end
	activeSounds += 1
	local released = false
	local function cleanup()
		if released then
			return
		end
		released = true
		activeSounds = math.max(0, activeSounds - 1)
		if holder ~= SoundService then
			holder:Destroy()
		else
			sound:Destroy()
		end
	end
	sound.Ended:Once(cleanup)
	sound.Parent = holder
	Debris:AddItem(sound, C.SoundCleanupSeconds)
	task.delay(C.SoundCleanupSeconds, cleanup)
	sound:Play()
	return true
end

-- One-shot particle burst at a position (the local character when nil). Returns false when skipped.
local function emitBurst(textureId: string, scale: number, position: Vector3?): boolean
	if textureId == "" or scale <= 0 then
		return false
	end
	local at = position or rootPosition()
	if at == nil or not AtmosphereFx.reserveEmitter() then
		return false
	end
	local count =
		math.max(1, math.floor(PerfBudget.clampRate(C.EmitCount, PERF.MaxParticleRate, scale)))
	local holder = Instance.new("Attachment")
	holder.WorldPosition = at
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = textureId
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(C.ParticleLifetime * 0.5, C.ParticleLifetime)
	emitter.Speed = NumberRange.new(C.ParticleSpeed * 0.5, C.ParticleSpeed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(C.ParticleSize * scale, 0)
	emitter.Parent = holder
	holder.Parent = Workspace.Terrain
	emitter:Emit(count)
	Debris:AddItem(holder, C.BurstCleanupSeconds)
	task.delay(C.BurstCleanupSeconds, AtmosphereFx.releaseEmitter)
	return true
end

-- Plays the cue row for `key` (sound + particle). No-ops silently for an unknown key or empty ids.
function AtmosphereFx.play(key: string, position: Vector3?)
	local pres = CueResolve.resolve(key, AtmosphereFx.reduceScares())
	if pres == nil then
		return
	end
	playSound(pres.soundId, pres.volume, position)
	emitBurst(pres.particleId, pres.particleScale, position)
end

-- Particles only (the horror client already plays that cue's sound).
function AtmosphereFx.playParticle(key: string, position: Vector3?)
	local pres = CueResolve.resolve(key, AtmosphereFx.reduceScares())
	if pres then
		emitBurst(pres.particleId, pres.particleScale, position)
	end
end

return AtmosphereFx
