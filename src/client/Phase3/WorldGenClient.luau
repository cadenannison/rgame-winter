--!strict
-- Phase 3 client boot hook for brief 13 (WorldGen): map panel and thin-ice crack feedback.
-- Visual only; all state comes from Attributes/tags set by the server.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Map = script.Parent.Parent:WaitForChild("Map")
local MapView = require(Map:WaitForChild("MapView"))

local ICE_TAG = "ThinIce"
local CRACK_COLOR = Color3.fromRGB(120, 150, 175)
local CRACK_TWEEN = TweenInfo.new(1.5)

local WorldGenClient = {}

local started = false

local function watchIce(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local normal = part.Color
	part:GetAttributeChangedSignal("Cracking"):Connect(function()
		local cracking = part:GetAttribute("Cracking") == true
		TweenService:Create(part, CRACK_TWEEN, { Color = if cracking then CRACK_COLOR else normal })
			:Play()
	end)
end

function WorldGenClient.start()
	if started then
		return
	end
	started = true
	MapView.start()
	CollectionService:GetInstanceAddedSignal(ICE_TAG):Connect(watchIce)
	for _, part in CollectionService:GetTagged(ICE_TAG) do
		watchIce(part)
	end
end

return WorldGenClient
