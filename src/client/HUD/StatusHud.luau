--!strict
-- Progression status under the stats panel: worn cold resistance, active food buffs with time left, and an
-- underdressed warning (with a one-time toast) when the current biome needs more resistance than worn.
-- Visible Attributes only (ColdResistance, BiomeRing, Buffs, BuffTimes); no hidden metric is read.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Data = Shared:WaitForChild("data")
local Biomes = require(Data:WaitForChild("Biomes"))
local Food = require(Data:WaitForChild("Food"))
local ClothingLogic = require(Shared:WaitForChild("logic"):WaitForChild("ClothingLogic"))
local HudConfig = require(script.Parent:WaitForChild("HudConfig"))
local Toast = require(script.Parent:WaitForChild("Toast"))
local Feedback = require(script.Parent:WaitForChild("Feedback"))

local S = HudConfig.Progression.Status

local StatusHud = {}

local function parseTimes(raw: unknown): { { id: string, expires: number } }
	local out: { { id: string, expires: number } } = {}
	if type(raw) ~= "string" then
		return out
	end
	for part in string.gmatch(raw, "[^,]+") do
		local id, t = string.match(part, "^(%w+):([%d%.]+)$")
		local expires = tonumber(t)
		if id and expires and Food.BuffById[id] then
			table.insert(out, { id = id, expires = expires })
		end
	end
	return out
end

-- Returns a cleanup function.
function StatusHud.start(parent: ScreenGui): () -> ()
	local player = Players.LocalPlayer
	local frame = Instance.new("Frame")
	frame.Name = "Progression"
	frame.Position = S.Position
	frame.Size = UDim2.fromOffset(S.Width, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = frame

	local function row(order: number): TextLabel
		local l = Instance.new("TextLabel")
		l.LayoutOrder = order
		l.Size = UDim2.new(1, 0, 0, S.RowHeight)
		l.BackgroundColor3 = HudConfig.PanelColor
		l.BackgroundTransparency = HudConfig.PanelTransparency
		l.BorderSizePixel = 0
		l.TextColor3 = HudConfig.TextColor
		l.Font = Enum.Font.GothamMedium
		l.TextSize = 14
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextWrapped = true
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 6)
		pad.Parent = l
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 5)
		c.Parent = l
		l.Parent = frame
		return l
	end
	local resist = row(1)
	local warn = row(2)
	warn.TextColor3 = S.WarnColor
	warn.Visible = false
	local buffRows: { TextLabel } = {}
	for i = 1, Config.Buffs.MaxActive do
		local r = row(2 + i)
		r.Visible = false
		table.insert(buffRows, r)
	end
	frame.Parent = parent

	local warnedRing = -1
	local destroyed = false

	local function refresh()
		local value = player:GetAttribute(Config.Biome.ColdResistanceAttribute)
		local resistance = if type(value) == "number" then value else 0
		resist.Text = `Cold resistance {resistance}/{Config.Clothing.MaxColdResistance}`
		local ring = player:GetAttribute(Config.Biome.RingAttribute)
		local biome = if type(ring) == "number" then Biomes.List[ring + 1] else nil
		local message = if biome
			then ClothingLogic.warning(resistance, biome.requiredColdResistance, biome.name)
			else nil
		warn.Visible = message ~= nil
		warn.Text = message or ""
		if message and type(ring) == "number" and ring ~= warnedRing then
			warnedRing = ring
			Toast.show(`{message}. Craft warmer clothing.`)
			Feedback.sound("DenySound", nil)
		elseif message == nil and type(ring) == "number" then
			warnedRing = -1
		end
		local now = Workspace:GetServerTimeNow()
		local active = parseTimes(player:GetAttribute(Food.TimesAttribute))
		for i, r in buffRows do
			local entry = active[i]
			local def = if entry then Food.BuffById[entry.id] else nil
			if entry and def and entry.expires > now then
				local left = math.ceil(entry.expires - now)
				r.Visible = true
				r.Text = `{def.name} {left}s`
				r.TextColor3 = if def.debuff then S.WarnColor else HudConfig.TextColor
			else
				r.Visible = false
			end
		end
	end

	task.spawn(function()
		while not destroyed do
			refresh()
			task.wait(S.UpdateSeconds)
		end
	end)

	return function()
		destroyed = true
		frame:Destroy()
	end
end

return StatusHud
