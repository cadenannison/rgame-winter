--!strict
-- "Day N survived" banner with its fanfare when the visible Day attribute rises (brief 20 UI effect).
-- Reads only the public Workspace Day attribute; one label, tweened, no per-tick work.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local AtmosphereConfig = require(script.Parent:WaitForChild("AtmosphereConfig"))
local AtmosphereFx = require(script.Parent:WaitForChild("AtmosphereFx"))

local C = AtmosphereConfig

local DayBanner = {}

local started = false
local connection: RBXScriptConnection? = nil
local gui: ScreenGui? = nil

function DayBanner.start()
	if started then
		return
	end
	started = true
	local screen = Instance.new("ScreenGui")
	screen.Name = "DayBanner"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = C.DisplayOrder
	local text = Instance.new("TextLabel")
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Position = UDim2.fromScale(0.5, 0.12)
	text.Size = UDim2.fromOffset(320, 44)
	text.BackgroundTransparency = 1
	text.TextTransparency = 1
	text.TextColor3 = C.TextColor
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.Parent = screen
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = screen

	local last = Workspace:GetAttribute(Config.Time.DayAttribute)
	local previous = if type(last) == "number" then last else 0
	connection = Workspace:GetAttributeChangedSignal(Config.Time.DayAttribute):Connect(function()
		local day = Workspace:GetAttribute(Config.Time.DayAttribute)
		if type(day) ~= "number" or day <= previous then
			if type(day) == "number" then
				previous = day
			end
			return
		end
		previous = day
		text.Text = string.gsub(C.BannerText, "{day}", tostring(day - 1))
		text.TextTransparency = 0
		AtmosphereFx.play("DayBanner")
		task.delay(C.BannerSeconds, function()
			TweenService:Create(text, TweenInfo.new(C.BannerFadeSeconds), { TextTransparency = 1 })
				:Play()
		end)
	end)
end

function DayBanner.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if gui then
		gui:Destroy()
		gui = nil
	end
	started = false
end

return DayBanner
