--!strict
-- Client side of the horror: turns Remotes.Cue (brief 15 kinds) into sensory feedback only. It never
-- sees Dread, hunt chance or timers: just a coarse level and positions. Effects are local (Lighting and
-- GUI changes on the client do not replicate). Lurker models hide locally when looked at head-on.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Assets = require(Shared:WaitForChild("Assets"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local AtmosphereFx =
	require(script.Parent.Parent:WaitForChild("Atmosphere"):WaitForChild("AtmosphereFx"))

-- Presentation tuning (visual only): Config.Cue.Horror.
local H = Config.Cue.Horror
local FROST_PER_LEVEL = H.FrostPerLevel
local FROST_TELL = H.FrostTell
local DESAT_PER_LEVEL = H.DesatPerLevel
local DESAT_TELL = H.DesatTell
local RUMBLE_VOLUME_PER_LEVEL = H.RumbleVolumePerLevel
local FADE_SECONDS = H.FadeSeconds
local TELL_HOLD_SECONDS = Config.Stalker.TelegraphSeconds
local GUTTER_SECONDS = H.GutterSeconds
local GUTTER_BRIGHTNESS = H.GutterBrightness
local GUTTER_RADIUS = Config.Fire.RepelRadius -- fires within this of the cue position gutter
local PULSE_SECONDS = H.PulseSeconds
local FROST_EDGE_COLOR =
	Color3.fromRGB(H.FrostEdgeColor[1], H.FrostEdgeColor[2], H.FrostEdgeColor[3])
local EDGE_SIZE = H.EdgeSize
local SOUND_MAX_DISTANCE = H.SoundMaxDistance
local SOUND_CLEANUP_SECONDS = H.SoundCleanupSeconds
local LURKER_SOFT_TRANSPARENCY = 0.55 -- LocalTransparencyModifier for lurkers under reduce-scares
local GUI_NAME = "HorrorCues"
local EFFECT_NAME = "HorrorColor"

local HorrorCues = {}

local OWN_KINDS: { [string]: boolean } = {
	DreadLevel = true,
	StalkerTell = true,
	Footsteps = true,
	FireGutter = true,
	StalkerRetreat = true,
	LurkerSighted = true,
	IceCrack = true,
}

local player = Players.LocalPlayer
local level = 0
local tellUntil = 0
local frostRoot: CanvasGroup? = nil
local guttering: { [PointLight]: number } = {}
local color: ColorCorrectionEffect? = nil
local rumble: Sound? = nil
local connections: { RBXScriptConnection } = {}
local started = false

local function playAt(soundId: string, position: Vector3?)
	if soundId == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.RollOffMaxDistance = SOUND_MAX_DISTANCE
	local holder: Instance = SoundService
	if position then
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = position
		attachment.Parent = Workspace.Terrain
		holder = attachment
	end
	sound.Parent = holder
	local function cleanup()
		if holder ~= SoundService then
			holder:Destroy()
		else
			sound:Destroy()
		end
	end
	sound.Ended:Once(cleanup)
	task.delay(SOUND_CLEANUP_SECONDS, cleanup)
	sound:Play()
end

local function buildFrost(): CanvasGroup
	local gui = Instance.new("ScreenGui")
	gui.Name = GUI_NAME
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -1 -- under the HUD
	local root = Instance.new("CanvasGroup")
	root.Name = "Frost"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	if Assets.FrostEdgeTexture ~= "" then
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromScale(1, 1)
		image.Image = Assets.FrostEdgeTexture
		image.Parent = root
	else
		-- Fallback: four gradient edges that fade toward the centre.
		type Edge = { size: UDim2, position: UDim2, rotation: number }
		local edges: { Edge } = {
			{
				size = UDim2.fromScale(1, EDGE_SIZE),
				position = UDim2.fromScale(0, 0),
				rotation = 90,
			},
			{
				size = UDim2.fromScale(1, EDGE_SIZE),
				position = UDim2.fromScale(0, 1 - EDGE_SIZE),
				rotation = -90,
			},
			{
				size = UDim2.fromScale(EDGE_SIZE, 1),
				position = UDim2.fromScale(0, 0),
				rotation = 0,
			},
			{
				size = UDim2.fromScale(EDGE_SIZE, 1),
				position = UDim2.fromScale(1 - EDGE_SIZE, 0),
				rotation = 180,
			},
		}
		for _, e in edges do
			local frame = Instance.new("Frame")
			frame.BorderSizePixel = 0
			frame.BackgroundColor3 = FROST_EDGE_COLOR
			frame.Size = e.size
			frame.Position = e.position
			local gradient = Instance.new("UIGradient")
			gradient.Rotation = e.rotation
			gradient.Transparency = NumberSequence.new(0, 1)
			gradient.Parent = frame
			frame.Parent = root
		end
	end
	root.GroupTransparency = 1
	gui.Parent = player:WaitForChild("PlayerGui")
	return root
end

-- Reduce-scares scales frost/vignette, desaturation and rumble down (never changes server danger).
local function mult(): number
	return AtmosphereFx.scareMultiplier()
end

local function setFrost(amount: number, seconds: number)
	amount *= mult()
	local root = frostRoot
	if root then
		TweenService
			:Create(
				root,
				TweenInfo.new(seconds),
				{ GroupTransparency = 1 - math.clamp(amount, 0, 1) }
			)
			:Play()
	end
end

local function setSaturation(value: number, seconds: number)
	value *= mult()
	local effect = color
	if effect then
		TweenService:Create(effect, TweenInfo.new(seconds), { Saturation = value }):Play()
	end
end

-- Baseline from the DreadLevel cue; a live Stalker tell overrides it until it ends.
local function applyBaseline()
	if os.clock() < tellUntil then
		return
	end
	setFrost(level * FROST_PER_LEVEL, FADE_SECONDS)
	setSaturation(level * DESAT_PER_LEVEL, FADE_SECONDS)
	local sound = rumble
	if sound then
		sound.Volume = level * RUMBLE_VOLUME_PER_LEVEL * mult()
		if level > 0 and not sound.IsPlaying then
			sound:Play()
		elseif level == 0 then
			sound:Stop()
		end
	end
end

local function gutterFiresNear(position: Vector3)
	for _, fire in CollectionService:GetTagged(Config.Fire.Tag) do
		local p = if fire:IsA("Model")
			then fire:GetPivot().Position
			elseif fire:IsA("BasePart") then fire.Position
			else nil
		if p and (p - position).Magnitude <= GUTTER_RADIUS then
			for _, d in fire:GetDescendants() do
				if d:IsA("PointLight") and guttering[d] == nil then
					local normal = d.Brightness
					guttering[d] = normal
					d.Brightness = normal * (1 - (1 - GUTTER_BRIGHTNESS) * mult()) -- softer dip, no blackout
					task.delay(GUTTER_SECONDS, function()
						guttering[d] = nil
						if d.Parent then
							d.Brightness = normal
						end
					end)
				end
			end
		end
	end
end

local function onCue(payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	local p = payload :: { [string]: unknown }
	local kind = p.kind
	if type(kind) ~= "string" or not OWN_KINDS[kind] then
		return
	end
	local position = if typeof(p.position) == "Vector3" then p.position :: Vector3 else nil
	if kind == "DreadLevel" then
		local l = p.level
		if type(l) == "number" then
			level = math.clamp(math.floor(l), 0, Config.Cue.MaxLevel)
			applyBaseline()
		end
	elseif kind == "StalkerTell" then
		-- Wildlife silent + frost creep: the world goes cold and quiet around the target.
		tellUntil = os.clock() + TELL_HOLD_SECONDS
		setFrost(FROST_TELL, FADE_SECONDS)
		setSaturation(DESAT_TELL, FADE_SECONDS)
		task.delay(TELL_HOLD_SECONDS, applyBaseline)
	elseif kind == "Footsteps" then
		playAt(Assets.StalkerCrunchSound, position)
	elseif kind == "FireGutter" then
		if position then
			gutterFiresNear(position)
		end
		playAt(Assets.FireGutterSound, position)
	elseif kind == "StalkerRetreat" then
		if position then
			playAt(Assets.StalkerStrikeSound, position)
		end
		tellUntil = 0
		applyBaseline()
	elseif kind == "LurkerSighted" then
		playAt(Assets.LurkerWhisperSound, position)
		setFrost(math.max(level * FROST_PER_LEVEL, FROST_PER_LEVEL * 2), PULSE_SECONDS)
		task.delay(PULSE_SECONDS, applyBaseline)
	elseif kind == "IceCrack" then
		playAt(Assets.IceCrackSound, position)
	end
end

-- Lurkers are never seen clearly: hide locally while the camera looks straight at one.
local function hideLookedAtLurkers()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local origin = camera.CFrame.Position
	local look = camera.CFrame.LookVector
	-- Reduce-scares: lurkers are always half see-through (a softer silhouette).
	local softness = if AtmosphereFx.reduceScares() then LURKER_SOFT_TRANSPARENCY else 0
	for _, model in CollectionService:GetTagged(Config.Lurkers.Tag) do
		if model:IsA("Model") then
			local offset = model:GetPivot().Position - origin
			local seen = offset.Magnitude > 0
				and look:Dot(offset.Unit) > Config.Lurkers.LookDotThreshold
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = if seen then 1 else softness
				end
			end
		end
	end
end

function HorrorCues.start()
	if started then
		return
	end
	started = true
	frostRoot = buildFrost()
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = EFFECT_NAME
	effect.Parent = Lighting
	color = effect
	if Assets.DreadRumbleSound ~= "" then
		local sound = Instance.new("Sound")
		sound.SoundId = Assets.DreadRumbleSound
		sound.Looped = true
		sound.Volume = 0
		sound.Parent = SoundService
		rumble = sound
	end
	table.insert(connections, Remotes.event(Remotes.Cue).OnClientEvent:Connect(onCue))
	table.insert(connections, RunService.RenderStepped:Connect(hideLookedAtLurkers))
end

function HorrorCues.stop()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	local root = frostRoot
	if root and root.Parent then
		(root.Parent :: Instance):Destroy()
	end
	frostRoot = nil
	if color then
		color:Destroy()
		color = nil
	end
	if rumble then
		rumble:Destroy()
		rumble = nil
	end
	started = false
end

return HorrorCues
