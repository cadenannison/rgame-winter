--!strict
-- Client-only action feedback: swing (animation asset or procedural arm swing), sounds, hit
-- particle bursts and mob hit flashes. Visual/audio only; never changes gameplay state.
-- Every id comes from shared/Assets ("" = skip), every number from Config.Feedback.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Assets = require(Shared:WaitForChild("Assets"))

local FB = Config.Feedback

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end
local HIT_COLOR = rgb(FB.HitParticleColor)
local FLASH_COLOR = rgb(FB.FlashColor)

local Feedback = {}

-- Per-character swing state (the local player and other players' broadcast swings share it).
local busy: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local tracks: { [Animator]: AnimationTrack } = setmetatable({}, { __mode = "k" }) :: any

-- Plays Assets[name] once, at a world position (3D) or as UI sound. Missing id = silent.
function Feedback.sound(name: string, at: Vector3?)
	local id = Assets[name]
	if id == nil or id == "" or FB.MutedSounds[name] == true then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = FB.SoundVolume
	if at then
		local holder = Instance.new("Attachment")
		holder.WorldPosition = at
		sound.Parent = holder
		holder.Parent = Workspace.Terrain
		sound.Ended:Once(function()
			holder:Destroy()
		end)
		Debris:AddItem(holder, 5)
		sound:Play()
	else
		sound.Parent = SoundService
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		Debris:AddItem(sound, 5)
		sound:Play()
	end
end

local function procSwing(character: Model)
	local upper = character:FindFirstChild("RightUpperArm")
	local motor = upper and upper:FindFirstChild("RightShoulder")
	if motor == nil then
		local torso = character:FindFirstChild("Torso") -- R6
		motor = torso and torso:FindFirstChild("Right Shoulder")
	end
	if motor == nil or not motor:IsA("Motor6D") then
		return
	end
	local base = motor.C0
	local half = FB.SwingSeconds / 2
	local up = TweenService:Create(
		motor,
		TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ C0 = base * CFrame.Angles(math.rad(FB.SwingAngle), 0, 0) }
	)
	local down = TweenService:Create(
		motor,
		TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ C0 = base }
	)
	busy[character] = true
	up.Completed:Once(function()
		down:Play()
	end)
	down.Completed:Once(function()
		motor.C0 = base
		busy[character] = nil
	end)
	up:Play()
	task.delay(FB.SwingSeconds * 2, function() -- safety if the character died mid-swing
		busy[character] = nil
	end)
end

-- One arm swing of any character (animation asset, else procedural). Visual only.
local function swingCharacter(character: Model)
	local animId = Assets.SwingAnimation
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animId ~= nil and animId ~= "" and animator then
		local track: AnimationTrack? = tracks[animator]
		if track == nil then
			local anim = Instance.new("Animation")
			anim.AnimationId = animId
			local ok, loaded = pcall(function()
				return animator:LoadAnimation(anim)
			end)
			if ok then
				track = loaded
				tracks[animator] = loaded
			end
		end
		if track then
			track:Play()
			return
		end
	end
	if not busy[character] then
		procSwing(character)
	end
end

-- One swing of the local character's arm plus the swing sound.
function Feedback.swing()
	local character = Players.LocalPlayer.Character
	if character == nil then
		return
	end
	Feedback.sound("SwingSound", nil)
	swingCharacter(character)
end

-- Another player's swing (server relay SwingBroadcast): their arm swings and the whoosh is 3D.
function Feedback.swingOther(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	Feedback.sound("SwingSound", if root and root:IsA("BasePart") then root.Position else nil)
	swingCharacter(character)
end

-- Particle burst at a world position (chips / snow puff).
function Feedback.burst(at: Vector3)
	local holder = Instance.new("Attachment")
	holder.WorldPosition = at
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Color = ColorSequence.new(HIT_COLOR)
	emitter.Speed = NumberRange.new(FB.HitParticleSpeed * 0.5, FB.HitParticleSpeed)
	emitter.Lifetime = NumberRange.new(FB.HitParticleLifetime * 0.5, FB.HitParticleLifetime)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.3, 0)
	emitter.Acceleration = Vector3.new(0, -Workspace.Gravity * 0.2, 0)
	emitter.Parent = holder
	holder.Parent = Workspace.Terrain
	emitter:Emit(FB.HitParticleCount)
	Debris:AddItem(holder, FB.HitParticleLifetime + 0.5)
end

-- Short red highlight on a model or part (mob hit confirm).
function Feedback.flash(target: Instance)
	local h = Instance.new("Highlight")
	h.FillColor = FLASH_COLOR
	h.OutlineColor = FLASH_COLOR
	h.FillTransparency = 0.3
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = target
	h.Parent = target
	Debris:AddItem(h, FB.FlashSeconds)
end

return Feedback
