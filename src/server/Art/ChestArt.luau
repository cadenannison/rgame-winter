--!strict
-- Loot chest art (parts only, no uploads; fixed orientation, never faces the player). LootService calls ChestArt.build via LootService.SetArtBuilder
-- and ChestArt.setOpened when a chest is looted. Five looks (common wood -> legendary gold with a beam) come
-- from shared/logic/ChestStyle. Per-tick glow, light, particles and sound are client-side (client/Loot),
-- driven by the ChestRarity / LootOpened Attributes; this module only builds geometry and the one-shot open.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local ChestStyle = require(ReplicatedStorage.Shared.logic.ChestStyle)

local L = Config.Loot
local B = ChestStyle.Budget

local BODY_SIZE = Vector3.new(4, 2, 2.5)
local LID_SIZE = Vector3.new(4.1, 0.8, 2.6)
local STRAP_WIDTH = 0.3
local STRAP_OVERSHOOT = 0.1
local LOCK_SIZE = Vector3.new(0.6, 0.8, 0.25)
local GEM_SIZE = Vector3.new(0.5, 0.5, 0.3)
local RIDGE_SIZE = Vector3.new(4.2, 0.3, 0.5) -- legendary lid crest
local PRIMARY_NAME = "Base"
local PROMPT_NAME = "OpenPrompt"
local PROMPT_KEY = "ChestPrompt"
local LID_NAME = "Lid"
local GEM_NAME = "Gem"
local RIDGE_NAME = "Ridge"
local OPENED_GEM_TRANSPARENCY = 1
local DIM_NAMES = { "Base", "Lid", "StrapL", "StrapR", "Lock" }

local ChestArt = {}

local function color(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function material(name: string): Enum.Material
	local ok, m = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	if ok and m then
		return m :: Enum.Material
	end
	return Enum.Material.Plastic
end

local function part(
	name: string,
	size: Vector3,
	cf: CFrame,
	c: { number },
	mat: string,
	parent: Model
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color(c)
	p.Material = material(mat)
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function hingeCFrame(baseCf: CFrame, angleDeg: number): CFrame
	local hinge = CFrame.new(0, BODY_SIZE.Y / 2, BODY_SIZE.Z / 2 - B.HingeInset)
	local closed = CFrame.new(0, BODY_SIZE.Y / 2 + LID_SIZE.Y / 2, 0)
	return baseCf * hinge * CFrame.Angles(math.rad(angleDeg), 0, 0) * hinge:Inverse() * closed
end

-- Build a chest of the given rarity. `cframe` is the floor point under the chest centre (facing -Z front).
-- Returns the Model (tagged Config.Loot.ChestTag, attribute ChestRarity set, an "Open" prompt on the base).
function ChestArt.build(rarity: string, cframe: CFrame, parent: Instance): Model
	local style = ChestStyle.get(rarity)
	local model = Instance.new("Model")
	model.Name = "LootChest"

	local baseCf = cframe * CFrame.new(0, BODY_SIZE.Y / 2, 0)
	local base = part(PRIMARY_NAME, BODY_SIZE, baseCf, style.bodyColor, style.bodyMaterial, model)
	local lid =
		part(LID_NAME, LID_SIZE, hingeCFrame(baseCf, 0), style.lidColor, style.bodyMaterial, model)
	local strapSize =
		Vector3.new(STRAP_WIDTH, BODY_SIZE.Y + STRAP_OVERSHOOT, BODY_SIZE.Z + STRAP_OVERSHOOT)
	local sx = BODY_SIZE.X / 2 - STRAP_WIDTH * 2
	part(
		"StrapL",
		strapSize,
		baseCf * CFrame.new(-sx, 0, 0),
		style.trimColor,
		style.trimMaterial,
		model
	)
	part(
		"StrapR",
		strapSize,
		baseCf * CFrame.new(sx, 0, 0),
		style.trimColor,
		style.trimMaterial,
		model
	)
	part(
		"Lock",
		LOCK_SIZE,
		baseCf
			* CFrame.new(0, BODY_SIZE.Y / 2 - LOCK_SIZE.Y / 2, -BODY_SIZE.Z / 2 - LOCK_SIZE.Z / 2),
		style.lockColor,
		style.trimMaterial,
		model
	)
	if style.accent == "crown" then
		local ridge = part(
			RIDGE_NAME,
			RIDGE_SIZE,
			hingeCFrame(baseCf, 0) * CFrame.new(0, LID_SIZE.Y / 2 + RIDGE_SIZE.Y / 2, 0),
			style.trimColor,
			style.trimMaterial,
			model
		)
		ridge.CanCollide = false
	end
	if style.glowColor and style.accent ~= "none" then
		-- one small neon gem on the lock plate; the glow itself is a few client particle emitters
		local gem = part(
			GEM_NAME,
			GEM_SIZE,
			baseCf
				* CFrame.new(
					0,
					BODY_SIZE.Y / 2 - LOCK_SIZE.Y / 2 + 0.3,
					-BODY_SIZE.Z / 2 - LOCK_SIZE.Z - GEM_SIZE.Z / 2
				),
			style.glowColor,
			"Neon",
			model
		)
		gem.Transparency = style.glowTransparency
		gem.CanCollide = false
		gem.CanQuery = false
		gem.CanTouch = false
		gem.CastShadow = false
	end
	lid.CanCollide = false

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = "Open"
	prompt.ObjectText = style.label
	local effort = Config.Gather.Effort.Chest
	prompt.HoldDuration = if effort then effort.HoldSeconds or 0 else 0
	prompt.MaxActivationDistance = Config.Loot.ChestSafety.PromptMaxDistance
	prompt.RequiresLineOfSight = Config.Loot.ChestSafety.RequiresLineOfSight
	prompt.Style = Enum.ProximityPromptStyle.Custom -- client/Loot/ChestPrompt draws the rarity-coloured UI
	prompt:SetAttribute(PROMPT_KEY, true)
	prompt.Parent = base

	model.PrimaryPart = base
	model:SetAttribute(L.ChestRarityAttribute, rarity)
	model:SetAttribute(L.ChestOpenedAttribute, false)
	CollectionService:AddTag(model, L.ChestTag)
	model.Parent = parent
	return model
end

-- Open (true): lid swings open once, gem goes out (client drops emitters and beam), colours dim, prompt disabled, attribute set.
-- Idempotent. (false is not supported: chests are not re-closed; the call is ignored.)
function ChestArt.setOpened(model: Model, opened: boolean)
	if not opened or model:GetAttribute(L.ChestOpenedAttribute) == true then
		return
	end
	local rarity = model:GetAttribute(L.ChestRarityAttribute)
	local style = ChestStyle.get(if type(rarity) == "string" then rarity else "common")
	model:SetAttribute(L.ChestOpenedAttribute, true)

	local base = model.PrimaryPart
	local lid = model:FindFirstChild(LID_NAME)
	if base and lid and lid:IsA("BasePart") then
		TweenService:Create(
			lid,
			TweenInfo.new(style.openSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ CFrame = hingeCFrame(base.CFrame, style.lidAngle) }
		):Play()
	end
	for _, name in DIM_NAMES do
		local p = model:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			local c = p.Color
			p.Color = Color3.new(c.R * B.OpenedDim, c.G * B.OpenedDim, c.B * B.OpenedDim)
		end
	end
	for _, name in { GEM_NAME, RIDGE_NAME } do
		local p = model:FindFirstChild(name) -- the ridge sits on the closed lid: hide it when the lid swings
		if p and p:IsA("BasePart") then
			p.Transparency = OPENED_GEM_TRANSPARENCY
		end
	end
	local prompt = base and base:FindFirstChild(PROMPT_NAME)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = false
	end
end

return ChestArt
