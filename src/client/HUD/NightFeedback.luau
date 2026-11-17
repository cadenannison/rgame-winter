--!strict
-- Client-only night feedback driven by replicated Attributes (no remotes): bite screen flash + sound,
-- wolf growl + tint during the attack windup, dusk/dawn cues, and a warm PointLight on lit campfires.
-- Visual/audio only; never changes gameplay state. Ids come from shared/Assets ("" = silent).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Assets = require(Shared:WaitForChild("Assets"))
local LightingMath = require(Shared:WaitForChild("logic"):WaitForChild("LightingMath"))
local Feedback = require(script.Parent.Feedback)

local N = Config.Night
local CUE_DEBRIS_SECONDS = 8
local FLASH_DISPLAY_ORDER = 50

local NightFeedback = {}

local started = false
local flash: Frame? = nil

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function playCue(name: string)
	local id = Assets[name]
	if id == nil or id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = N.CueVolume
	sound.Parent = SoundService
	Debris:AddItem(sound, CUE_DEBRIS_SECONDS)
	sound:Play()
end

local function buildFlash(player: Player)
	local gui = Instance.new("ScreenGui")
	gui.Name = "BiteFlash"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = FLASH_DISPLAY_ORDER
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = rgb(N.FlashColor)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Active = false -- never swallows touch/mouse input
	frame.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	flash = frame
end

local function onBite()
	Feedback.sound("BiteSound")
	local frame = flash
	if not frame then
		return
	end
	frame.BackgroundTransparency = N.FlashTransparency
	TweenService:Create(
		frame,
		TweenInfo.new(N.FlashSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	):Play()
end

local function watchMob(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local original = root.Color
	local conn = model:GetAttributeChangedSignal(N.WindupAttribute):Connect(function()
		if model:GetAttribute(N.WindupAttribute) == true then
			root.Color = rgb(N.TelegraphColor)
			Feedback.sound("WolfGrowlSound", root.Position)
		else
			root.Color = original
		end
	end)
	model.Destroying:Once(function()
		conn:Disconnect()
	end)
end

local function lightHost(fire: Instance): BasePart?
	if fire:IsA("BasePart") then
		return fire
	elseif fire:IsA("Model") then
		return fire.PrimaryPart or fire:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function watchFire(fire: Instance)
	local host = lightHost(fire)
	if not host then
		return
	end
	local light = host:FindFirstChild(N.FireLightName)
	if not light or not light:IsA("PointLight") then
		local made = Instance.new("PointLight")
		made.Name = N.FireLightName
		made.Color = rgb(N.FireLightColor)
		made.Brightness = N.FireLightBrightness
		made.Shadows = false
		made.Parent = host
		light = made
	end
	local pointLight = light :: PointLight
	local function refresh()
		local fuel = fire:GetAttribute(Config.Fire.FuelAttribute)
		local lit = fire:GetAttribute(Config.Fire.LitAttribute)
		pointLight.Enabled = lit == true or (type(fuel) == "number" and fuel > 0)
		local radius = fire:GetAttribute(N.WarmRadiusAttribute)
		local warm = if type(radius) == "number" then radius else Config.Fire.WarmRadius
		pointLight.Range = LightingMath.fireLightRange(warm, N.FireLightRange, N.FireLightMaxRange)
	end
	refresh()
	local conns = {
		fire:GetAttributeChangedSignal(Config.Fire.LitAttribute):Connect(refresh),
		fire:GetAttributeChangedSignal(Config.Fire.FuelAttribute):Connect(refresh),
		fire:GetAttributeChangedSignal(N.WarmRadiusAttribute):Connect(refresh),
	}
	fire.Destroying:Once(function()
		for _, c in conns do
			c:Disconnect()
		end
	end)
end

function NightFeedback.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer

	buildFlash(player)
	player:GetAttributeChangedSignal(N.BiteAttribute):Connect(onBite)

	local lastNight = Workspace:GetAttribute(Config.Time.IsNightAttribute) == true
	Workspace:GetAttributeChangedSignal(Config.Time.IsNightAttribute):Connect(function()
		local night = Workspace:GetAttribute(Config.Time.IsNightAttribute) == true
		if night ~= lastNight then
			lastNight = night
			playCue(if night then "DuskSound" else "DawnSound")
		end
	end)

	CollectionService:GetInstanceAddedSignal(Config.Mobs.Tag):Connect(watchMob)
	for _, mob in CollectionService:GetTagged(Config.Mobs.Tag) do
		watchMob(mob)
	end
	CollectionService:GetInstanceAddedSignal(Config.Fire.Tag):Connect(watchFire)
	for _, fire in CollectionService:GetTagged(Config.Fire.Tag) do
		watchFire(fire)
	end
end

return NightFeedback
