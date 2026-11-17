--!strict
-- World-space burn-time bar above every campfire (BillboardGui, built in code). Driven by the fire's
-- FuelFraction / Lit attributes (server throttles writes); no remote. One loop for all fires, tagged via
-- CollectionService. Shown within Config.Fire.Meter.ShowRange of the local player, hidden when far.
-- Warm colour fades to red as fuel runs low; the bar pulses at or under Meter.LowFraction.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local F = Config.Fire
local M = F.Meter
local TWO_PI = math.pi * 2

type Meter = {
	gui: BillboardGui,
	fill: Frame,
	adornee: BasePart,
	conns: { RBXScriptConnection },
}

local FireMeter = {}

local function color(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function anchorPart(fire: Instance): BasePart?
	if fire:IsA("BasePart") then
		return fire
	elseif fire:IsA("Model") then
		return fire.PrimaryPart or fire:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

-- Returns a cleanup function.
function FireMeter.start(): () -> ()
	local player = Players.LocalPlayer
	local meters: { [Instance]: Meter } = {}
	local conns: { RBXScriptConnection } = {}
	local fullColor, lowColor, backColor = color(M.FullColor), color(M.LowColor), color(M.BackColor)

	local function destroyMeter(fire: Instance)
		local m = meters[fire]
		if not m then
			return
		end
		meters[fire] = nil
		for _, c in m.conns do
			c:Disconnect()
		end
		m.gui:Destroy()
	end

	local function track(fire: Instance)
		if meters[fire] then
			return
		end
		local part = anchorPart(fire)
		if not part then
			return
		end
		local gui = Instance.new("BillboardGui")
		gui.Name = M.GuiName
		gui.Size = UDim2.fromOffset(M.WidthPx, M.HeightPx)
		gui.StudsOffsetWorldSpace = Vector3.new(0, M.OffsetY, 0)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.ResetOnSpawn = false
		gui.Enabled = false
		gui.Adornee = part
		local back = Instance.new("Frame")
		back.Name = "Back"
		back.Size = UDim2.fromScale(1, 1)
		back.BackgroundColor3 = backColor
		back.BackgroundTransparency = M.BackTransparency
		back.BorderSizePixel = 0
		local backCorner = Instance.new("UICorner")
		backCorner.CornerRadius = UDim.new(0.5, 0)
		backCorner.Parent = back
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = fullColor
		fill.BorderSizePixel = 0
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0.5, 0)
		fillCorner.Parent = fill
		fill.Parent = back
		back.Parent = gui
		gui.Parent = player:WaitForChild("PlayerGui")
		local m: Meter = { gui = gui, fill = fill, adornee = part, conns = {} }
		meters[fire] = m
		table.insert(
			m.conns,
			fire.Destroying:Connect(function()
				destroyMeter(fire)
			end)
		)
	end

	table.insert(conns, CollectionService:GetInstanceAddedSignal(F.Tag):Connect(track))
	table.insert(conns, CollectionService:GetInstanceRemovedSignal(F.Tag):Connect(destroyMeter))
	for _, fire in CollectionService:GetTagged(F.Tag) do
		track(fire)
	end

	-- One visual loop for every fire.
	table.insert(
		conns,
		RunService.RenderStepped:Connect(function()
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local rootPos = if root and root:IsA("BasePart") then root.Position else nil
			local pulse = (math.sin(os.clock() / M.PulseSeconds * TWO_PI) + 1) / 2
			for fire, m in meters do
				local near = rootPos ~= nil
					and (m.adornee.Position - rootPos).Magnitude <= M.ShowRange
				m.gui.Enabled = near
				if near then
					local raw = fire:GetAttribute(F.FuelFractionAttribute)
					local fraction = if type(raw) == "number" then math.clamp(raw, 0, 1) else 0
					m.fill.Size = UDim2.fromScale(fraction, 1)
					-- Warm at full, red at empty: lerp over the span from LowFraction to full, red below it.
					local t = math.clamp(fraction / math.max(M.LowFraction * 2, 0.01), 0, 1)
					m.fill.BackgroundColor3 = lowColor:Lerp(fullColor, t)
					local low = fraction <= M.LowFraction
					m.fill.BackgroundTransparency = if low
						then 1 - (M.PulseMinAlpha + (1 - M.PulseMinAlpha) * pulse)
						else 0
				end
			end
		end)
	)

	return function()
		for _, c in conns do
			c:Disconnect()
		end
		table.clear(conns)
		for fire in table.clone(meters) do
			destroyMeter(fire)
		end
	end
end

return FireMeter
