--!strict
-- Client HUD built in code. Read-only: displays MetersUpdate / InventoryUpdate / Workspace + Player
-- Attributes; sends intent only (SelectSlotRequest, GatherRequest, AttackRequest, UseItemRequest,
-- PlaceRequest, AddFuelRequest, CraftRequest). Server validates everything.
-- Input: hotbar keys 1-9 / click / tap / mouse wheel; click, E or the mobile Act button = context action;
-- C or the Craft button = crafting panel. Feedback: swing, sounds, hit bursts, prompts, onboarding chain.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ItemCatalog = require(Shared:WaitForChild("ItemCatalog"))
local Logic = Shared:WaitForChild("logic")
local HudMath = require(Logic:WaitForChild("HudMath"))
local ActionPick = require(Logic:WaitForChild("ActionPick"))
local FireTiers = require(Logic:WaitForChild("FireTiers"))
local Crafting = require(Logic:WaitForChild("Crafting"))
local Repair = require(Logic:WaitForChild("Repair"))
local MetaSnapshot = require(Logic:WaitForChild("MetaSnapshot"))
local RadiusRing = require(script.Parent.Parent:WaitForChild("Fire"):WaitForChild("RadiusRing"))
local FireMeter = require(script.Parent.Parent:WaitForChild("Fire"):WaitForChild("FireMeter"))
local ItemsGather = require(Logic:WaitForChild("ItemsGather"))
local HudConfig = require(script.Parent:WaitForChild("HudConfig"))
local DebugChat = require(script.Parent:WaitForChild("DebugChat"))
local Toast = require(script.Parent:WaitForChild("Toast"))
local Feedback = require(script.Parent:WaitForChild("Feedback"))
local CraftPanel = require(script.Parent:WaitForChild("CraftPanel"))
local TargetPrompt = require(script.Parent:WaitForChild("TargetPrompt"))
local OnboardingHints = require(script.Parent:WaitForChild("OnboardingHints"))
local QABridge = require(script.Parent:WaitForChild("QABridge"))
local PlacementGhost = require(script.Parent:WaitForChild("PlacementGhost"))

local HOTBAR_KEYS: { Enum.KeyCode } = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}
local WHEEL_ACTION = "ArcticHotbarWheel"
local RECENT_SECONDS = 2 -- window in which an inventory change is credited to our own request (onboarding)
local WATCH_SECONDS = 2 -- how long a hit target's attributes are watched for the confirm

local HudController = {}

local started = false

-- Phase 3 structure interactions (brief 17): set by ProgressionClient. peek gives the prompt for the
-- current context (nil = nothing to do); run performs it and returns true if it handled the action.
export type InteractCtx = {
	action: string,
	slot: number,
	gatherDistance: number?,
	gatherAimed: boolean?,
}
export type InteractPrompt = { target: Instance, text: string, warn: boolean, label: string }
export type InteractHook = {
	peek: (ctx: InteractCtx) -> InteractPrompt?,
	run: (ctx: InteractCtx) -> boolean,
}
local interactHook: InteractHook? = nil
local currentActionName = "none"

function HudController.setInteractHook(hook: InteractHook?)
	interactHook = hook
end

-- Studio-only QA bridge extensions from other client systems (storage, ping): name -> the same
-- function their inputs call. Looked up at invoke time, so systems may register after start.
local qaExtra: { [string]: (...any) -> ...any } = {}
function HudController.addQA(name: string, fn: (...any) -> ...any)
	qaExtra[name] = fn
end

-- The HUD's current context action ("gather", "eat", "none", ...), for systems that share the input.
function HudController.currentAction(): string
	return currentActionName
end

type Slot = { button: TextButton, name: TextLabel, count: TextLabel, stroke: UIStroke }
type Watch = { conns: { RBXScriptConnection }, expires: number }

local function addCleanup(list: { () -> () }, fn: () -> ())
	table.insert(list, fn)
end

local function connect(
	list: { () -> () },
	signal: RBXScriptSignal,
	fn: (...any) -> ()
): RBXScriptConnection
	local c = signal:Connect(fn)
	addCleanup(list, function()
		c:Disconnect()
	end)
	return c
end

local function make<T>(className: string, props: { [string]: any }, parent: Instance?): T
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst :: any
end

local function constrain(parent: Instance, minSize: Vector2?, maxSize: Vector2?)
	make("UISizeConstraint", {
		MinSize = minSize or Vector2.new(0, 0),
		MaxSize = maxSize or Vector2.new(math.huge, math.huge),
	}, parent)
end

local function textProps(
	size: UDim2,
	position: UDim2,
	text: string,
	maxText: number
): { [string]: any }
	return {
		BackgroundTransparency = 1,
		Size = size,
		Position = position,
		Text = text,
		TextColor3 = HudConfig.TextColor,
		TextScaled = true,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Center,
		_maxText = maxText,
	}
end

local function makeLabel(parent: Instance, props: { [string]: any }): TextLabel
	local maxText = props._maxText :: number
	props._maxText = nil
	local label = make("TextLabel", props, parent) :: TextLabel
	make("UITextSizeConstraint", { MaxTextSize = maxText, MinTextSize = 8 }, label)
	return label
end

local function panel(
	parent: Instance,
	name: string,
	size: UDim2,
	position: UDim2,
	anchor: Vector2
): Frame
	local f = make("Frame", {
		Name = name,
		Size = size,
		Position = position,
		AnchorPoint = anchor,
		BackgroundColor3 = HudConfig.PanelColor,
		BackgroundTransparency = HudConfig.PanelTransparency,
		BorderSizePixel = 0,
	}, parent) :: Frame
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, f)
	return f
end

local function positionOf(inst: Instance): Vector3?
	if inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Model") then
		return inst:GetPivot().Position
	end
	return nil
end

function HudController.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local cleanups: { () -> () } = {}
	local destroyed = false
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local inputHint = if touchOnly then "[Act]" else "[Click/E]"

	-- Our hotbar replaces the default backpack (it would fight over keys 1-9 and the held Tool).
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local gui = make("ScreenGui", {
		Name = HudConfig.GuiName,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		DisplayOrder = HudConfig.DisplayOrder,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui

	-- Stats (top-left): health, warmth, hunger.
	local stats =
		panel(gui, "Stats", UDim2.fromScale(0.3, 0.13), UDim2.fromScale(0.015, 0.02), Vector2.zero)
	constrain(stats, Vector2.new(150, 66), Vector2.new(300, 110))
	make("UIPadding", {
		PaddingTop = UDim.new(0.08, 0),
		PaddingBottom = UDim.new(0.08, 0),
		PaddingLeft = UDim.new(0.04, 0),
		PaddingRight = UDim.new(0.04, 0),
	}, stats)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0.04, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, stats)

	type Bar = { fill: Frame, label: TextLabel, name: string }
	local bars: { [string]: Bar } = {}
	for i, key in { "health", "warmth", "hunger" } do
		local row = make("Frame", {
			Name = key,
			LayoutOrder = i,
			Size = UDim2.fromScale(1, 0.29),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, stats) :: Frame
		make("UICorner", { CornerRadius = UDim.new(0, 5) }, row)
		local fill = make("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = (HudConfig.BarColors :: { [string]: Color3 })[key],
			BorderSizePixel = 0,
		}, row) :: Frame
		local label = makeLabel(row, textProps(UDim2.fromScale(1, 1), UDim2.new(), key, 14))
		label.Name = "Label"
		label.ZIndex = 2
		bars[key] = { fill = fill, label = label, name = key }
	end

	-- Day counter (top-center).
	local dayPanel = panel(
		gui,
		"Day",
		UDim2.fromScale(0.2, 0.06),
		UDim2.fromScale(0.5, 0.02),
		Vector2.new(0.5, 0)
	)
	constrain(dayPanel, Vector2.new(80, 26), Vector2.new(180, 44))
	local dayLabel = makeLabel(
		dayPanel,
		textProps(UDim2.fromScale(1, 0.8), UDim2.fromScale(0, 0.1), "Day 1", 22)
	)

	-- Compass to camp (below the day counter).
	local compass = panel(
		gui,
		"Compass",
		UDim2.fromScale(0.1, 0.1),
		UDim2.fromScale(0.5, 0.09),
		Vector2.new(0.5, 0)
	)
	constrain(compass, Vector2.new(48, 48), Vector2.new(84, 84))
	make("UIAspectRatioConstraint", { AspectRatio = 1 }, compass)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, compass)
	local arrowHolder = make("Frame", {
		Name = "ArrowHolder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.6, 0.6),
		BackgroundTransparency = 1,
	}, compass) :: Frame
	local arrow = makeLabel(arrowHolder, textProps(UDim2.fromScale(1, 1), UDim2.new(), "^", 36))
	arrow.TextColor3 = HudConfig.AccentColor
	arrow.Font = Enum.Font.GothamBold
	local distLabel = makeLabel(
		compass,
		textProps(UDim2.fromScale(1, 0.26), UDim2.fromScale(0, 0.72), "camp", 12)
	)

	-- Hotbar (bottom-center); the selected item name floats above it, the reactive hint above that.
	local slotCount = Config.Inventory.HotbarSize
	local hotbar = make("Frame", {
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.98),
		Size = UDim2.fromScale(0.7, 0.1),
		BackgroundTransparency = 1,
	}, gui) :: Frame
	constrain(
		hotbar,
		Vector2.new(HudConfig.MinWidth, 0),
		Vector2.new(HudConfig.MaxWidth, math.huge)
	)
	make(
		"UIAspectRatioConstraint",
		{ AspectRatio = slotCount * 1.0, DominantAxis = Enum.DominantAxis.Width },
		hotbar
	)

	local slots: { [number]: Slot } = {}
	for i = 1, slotCount do
		local button = make("TextButton", {
			Name = `Slot{i}`,
			AutoButtonColor = true,
			Text = "",
			Position = UDim2.new((i - 1) / slotCount, 2, 0, 0),
			Size = UDim2.new(1 / slotCount, -4, 1, 0),
			BackgroundColor3 = HudConfig.PanelColor,
			BackgroundTransparency = HudConfig.PanelTransparency,
			BorderSizePixel = 0,
		}, hotbar) :: TextButton
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, button)
		local stroke = make("UIStroke", {
			Color = HudConfig.SelectedColor,
			Thickness = 3,
			Enabled = false,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, button) :: UIStroke
		local keyLabel = makeLabel(
			button,
			textProps(UDim2.fromScale(0.35, 0.3), UDim2.fromScale(0.04, 0.03), tostring(i), 12)
		)
		keyLabel.TextTransparency = 0.4
		local nameLabel = makeLabel(
			button,
			textProps(UDim2.fromScale(0.9, 0.35), UDim2.fromScale(0.05, 0.3), "", 14)
		)
		local countLabel = makeLabel(
			button,
			textProps(UDim2.fromScale(0.6, 0.28), UDim2.fromScale(0.37, 0.68), "", 12)
		)
		countLabel.TextXAlignment = Enum.TextXAlignment.Right
		slots[i] = { button = button, name = nameLabel, count = countLabel, stroke = stroke }
	end

	local itemLabel =
		makeLabel(hotbar, textProps(UDim2.fromScale(0.6, 0.38), UDim2.new(0.2, 0, 0, -6), "", 18))
	itemLabel.Name = "ItemName"
	itemLabel.AnchorPoint = Vector2.new(0, 1)
	itemLabel.BackgroundTransparency = HudConfig.PanelTransparency
	itemLabel.BackgroundColor3 = HudConfig.PanelColor
	itemLabel.Font = Enum.Font.GothamBold
	itemLabel.Visible = false
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, itemLabel)

	local hintLabel =
		makeLabel(hotbar, textProps(UDim2.fromScale(1, 0.45), UDim2.new(0, 0, -0.45, -12), "", 18))
	hintLabel.AnchorPoint = Vector2.new(0, 1)
	hintLabel.BackgroundTransparency = HudConfig.PanelTransparency
	hintLabel.BackgroundColor3 = HudConfig.PanelColor
	hintLabel.Visible = false
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, hintLabel)

	-- Mobile context action button (bottom-right).
	local actionButton: TextButton? = nil
	if UserInputService.TouchEnabled then
		local b = make("TextButton", {
			Name = "Action",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(0.97, 0.78),
			Size = UDim2.fromScale(0.16, 0.16),
			BackgroundColor3 = HudConfig.AccentColor,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Text = "Act",
			TextColor3 = HudConfig.PanelColor,
			TextScaled = true,
			Font = Enum.Font.GothamBold,
		}, gui) :: TextButton
		constrain(
			b,
			Vector2.new(72, 72),
			Vector2.new(HudConfig.ActionButtonSize + 24, HudConfig.ActionButtonSize + 24)
		)
		make("UIAspectRatioConstraint", { AspectRatio = 1 }, b)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, b)
		make("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 10 }, b)
		actionButton = b
	end

	-- State mirrored from the server (display and intent choice only).
	local meters = { health = 0, warmth = 0, hunger = 0, day = 1, isNight = false }
	local stacks: { [number]: { id: string, count: number, durability: number? } } = {}
	local counts: { [string]: number } = {}
	local hasItems = false
	local selectedSlot = 1 -- server-confirmed
	local pendingSlot: number? = nil -- predicted while a SelectSlotRequest is in flight
	local pendingAt = 0.0
	local lastSelectSent = -math.huge
	local selectQueued = false
	local lastUserSelectAt = -math.huge
	local itemLabelUntil = 0.0
	local shownHints: { [string]: boolean } = {}
	local hintUntil = 0.0
	local lastDist = -1
	local targetKind = "none"
	local targetInstance: Instance? = nil
	local targetDistance: number? = nil -- studs to targetInstance (nil = none)
	local targetAimed = false -- true when the cursor/aim picked it (not just the closest)
	local fireInstance: Instance? = nil
	local fireDist = math.huge
	local benchInstance: Instance? = nil -- nearest crafting station in range
	local benchDist = math.huge
	local recent: { [string]: number } = {} -- our last request time per intent (onboarding credit)
	local watches: { [Instance]: Watch } = {}

	local prompt = TargetPrompt.new(playerGui)
	addCleanup(cleanups, prompt.destroy)
	local hints = OnboardingHints.new(gui)
	addCleanup(cleanups, hints.destroy)

	local function shownSlot(): number
		if pendingSlot and os.clock() - pendingAt < 1 then
			return pendingSlot
		end
		return selectedSlot
	end

	-- Interact context for the structure hook: the HUD action plus the gather target's distance/aim, so a
	-- chest closer than a tree (and not under the aim) is picked instead of the tree.
	local function interactCtx(action: string): InteractCtx
		return {
			action = action,
			slot = shownSlot(),
			gatherDistance = if targetKind == "gather" then targetDistance else nil,
			gatherAimed = targetKind == "gather" and targetAimed,
		}
	end

	local function selectedDef(): ItemCatalog.ItemDef?
		local stack = stacks[shownSlot()]
		return if stack then ItemCatalog.Items[stack.id] else nil
	end

	-- Stations in range (display only; the server re-checks at the craft action).
	local function nearStations(): Crafting.Near
		local near: Crafting.Near = {}
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return near
		end
		for name, station in Config.Craft.Stations do
			for _, inst in CollectionService:GetTagged(station.Tag) do
				local pos = positionOf(inst)
				if pos and (pos - root.Position).Magnitude <= station.Range then
					near[name] = true
					break
				end
			end
		end
		return near
	end

	local craftPanel: CraftPanel.Panel
	craftPanel = CraftPanel.new(gui, function(recipeId: string)
		recent["craft"] = os.clock()
		Remotes.event(Remotes.CraftRequest):FireServer(recipeId)
	end, function(text: string)
		Feedback.sound("DenySound", nil)
		Toast.show(text)
	end, function()
		hints.complete("openCraft")
		craftPanel.refresh(counts, nearStations())
	end)
	addCleanup(cleanups, craftPanel.destroy)

	-- Soft radius rings; the build ring shows while a build-limited placeable is selected.
	addCleanup(
		cleanups,
		RadiusRing.start({
			isPlacing = function(): boolean
				local def = selectedDef()
				return def ~= nil
					and def.kind == "placeable"
					and def.structureId ~= nil
					and Config.Build.RangeExempt[def.structureId] ~= true
			end,
			onUpgraded = function(fire: Instance, _tier: number)
				local pos = positionOf(fire)
				Feedback.sound("CraftSound", pos)
				Feedback.burst(pos or Vector3.zero)
			end,
		})
	)

	-- World-space burn-time bars above every campfire.
	addCleanup(cleanups, FireMeter.start())

	-- Placement preview (shared validator; the server re-validates at the place action).
	local ghost = PlacementGhost.start({
		selectedStructure = function(): string?
			local def = selectedDef()
			return if def ~= nil and def.kind == "placeable" then def.structureId else nil
		end,
		itemCount = function(structureId: string): number
			local def = ItemCatalog.Structures[structureId]
			return if def then counts[def.itemId] or 0 else 0
		end,
	})
	addCleanup(cleanups, ghost.destroy)

	local function showItemName()
		local def = selectedDef()
		if def == nil then
			itemLabel.Visible = false
			return
		end
		local suffix = if def.kind == "food"
			then `  {inputHint} eat`
			elseif def.kind == "placeable" then `  {inputHint} place`
			else ""
		itemLabel.Text = def.name .. suffix
		itemLabel.Visible = true
		itemLabelUntil = if suffix ~= ""
			then math.huge
			else os.clock() + Config.Feedback.ItemNameSeconds
	end

	local function renderSelection()
		local shown = shownSlot()
		for i, slot in slots do
			slot.stroke.Enabled = i == shown
			slot.button.BackgroundTransparency = if i == shown
				then 0.1
				else HudConfig.PanelTransparency
		end
		showItemName()
	end

	local function confirmSelected(selected: number)
		selectedSlot = selected
		if pendingSlot == selected then
			pendingSlot = nil
		end
		local stack = stacks[selected]
		if stack and stack.id == "Axe" and os.clock() - lastUserSelectAt < RECENT_SECONDS then
			hints.complete("equipAxe")
		end
		renderSelection()
	end

	-- Hotbar select (keys, click/tap, wheel, QA): predicted highlight now, request throttled to the
	-- server's Net.SelectRateInterval; the server's InventoryUpdate/attribute confirms.
	local function sendSelect()
		local slot = pendingSlot
		if slot == nil or destroyed then
			return
		end
		lastSelectSent = os.clock()
		Remotes.event(Remotes.SelectSlotRequest):FireServer(slot)
	end
	local function requestSelect(slot: number)
		if type(slot) ~= "number" or slot < 1 or slot > slotCount then
			return
		end
		slot = math.floor(slot)
		lastUserSelectAt = os.clock()
		if slot == selectedSlot and pendingSlot == nil then
			confirmSelected(slot) -- re-pressing the current slot still counts as equipping it
			return
		end
		pendingSlot, pendingAt = slot, os.clock()
		renderSelection()
		local wait = Config.Net.SelectRateInterval - (os.clock() - lastSelectSent)
		if wait <= 0 then
			sendSelect()
		elseif not selectQueued then
			selectQueued = true
			task.delay(wait + 0.01, function()
				selectQueued = false
				sendSelect()
			end)
		end
	end

	local recordHintDay = 0
	local function applyMeters()
		local values = {
			health = Config.Meters.MaxHealth,
			warmth = Config.Meters.MaxWarmth,
			hunger = Config.Meters.MaxHunger,
		}
		for key, bar in bars do
			local v = (meters :: any)[key] :: number
			local frac = HudMath.fraction(v, (values :: any)[key])
			bar.fill.Size = UDim2.fromScale(frac, 1)
			bar.label.Text = `{bar.name} {math.floor(v + 0.5)}`
		end
		dayLabel.Text = if meters.isNight then `Day {meters.day} (night)` else `Day {meters.day}`
		-- Record chase: "N days to your record" from the saved best (Player BestDays), once per day.
		if meters.day ~= recordHintDay then
			recordHintDay = meters.day
			local best = player:GetAttribute(Config.Meta.BestDaysAttribute)
			local hint = MetaSnapshot.recordHint(
				meters.day,
				if type(best) == "number" then best else 0,
				Config.Meta.RecordHintDays
			)
			if hint then
				Toast.show(hint)
			end
		end
	end

	-- Target pick: on PC the candidate nearest the mouse ray (within AimSlack) wins, else the nearest
	-- within ActionRange. Tagged instances only; never scans Workspace.
	local function pickTarget()
		targetKind, targetInstance, fireInstance = "none", nil, nil
		targetDistance, targetAimed = nil, false
		fireDist, benchInstance, benchDist = math.huge, nil, math.huge
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		local camera = Workspace.CurrentCamera
		local ray: Ray? = nil
		if camera and not touchOnly then
			local m = UserInputService:GetMouseLocation()
			ray = camera:ViewportPointToRay(m.X, m.Y)
		end
		local bestNear, bestAim = HudConfig.ActionRange, Config.Feedback.AimSlack
		local nearKind, nearInst, aimKind, aimInst =
			"none", nil :: Instance?, "none", nil :: Instance?
		local function scan(tag: string, kind: string)
			for _, inst in CollectionService:GetTagged(tag) do
				if
					inst ~= character
					and inst:GetAttribute(ItemCatalog.NodeDepletedAttribute) ~= true
				then
					local pos = positionOf(inst)
					if pos then
						local d = (pos - root.Position).Magnitude
						if d <= HudConfig.ActionRange then
							if d <= bestNear then
								bestNear, nearKind, nearInst = d, kind, inst
							end
							if ray then
								local off = pos - ray.Origin
								local along = off:Dot(ray.Direction.Unit)
								local perp = (off - ray.Direction.Unit * along).Magnitude
								if along > 0 and perp <= bestAim then
									bestAim, aimKind, aimInst = perp, kind, inst
								end
							end
						end
					end
				end
			end
		end
		scan(Config.Gather.NodeTag, "gather")
		scan(Config.Mobs.Tag, "attack")
		if aimInst then
			targetKind, targetInstance = aimKind, aimInst
			targetAimed = true
			local aimPos = positionOf(aimInst)
			targetDistance = if aimPos then (aimPos - root.Position).Magnitude else nil
		else
			targetKind, targetInstance = nearKind, nearInst
			targetDistance = if nearInst then bestNear else nil
		end
		local fireBest = Config.Fire.AddFuelRange
		for _, inst in CollectionService:GetTagged(Config.Fire.Tag) do
			local pos = positionOf(inst)
			if pos and (pos - root.Position).Magnitude <= fireBest then
				fireBest, fireInstance = (pos - root.Position).Magnitude, inst
				fireDist = fireBest
			end
		end
		for _, station in Config.Craft.Stations do
			for _, inst in CollectionService:GetTagged(station.Tag) do
				local pos = positionOf(inst)
				if pos then
					local d = (pos - root.Position).Magnitude
					if d <= station.Range and d < benchDist then
						benchDist, benchInstance = d, inst
					end
				end
			end
		end
	end

	-- The fire in reach if it can still be upgraded (top tier fires offer no upgrade).
	local function upgradableFire(): Instance?
		local fire = fireInstance
		if fire == nil or fireDist > Config.Fire.UpgradeRange then
			return nil
		end
		local tier = FireTiers.clamp(fire:GetAttribute(Config.Fire.TierAttribute))
		return if FireTiers.nextCost(tier) ~= nil then fire else nil
	end

	local function itemName(id: string): string
		local def = ItemCatalog.Items[id]
		return if def then def.name else id
	end

	local function currentAction(): string
		local def = selectedDef()
		local canUpgrade = upgradableFire() ~= nil
		return ActionPick.choose({
			craftStation = benchInstance ~= nil and not (canUpgrade and fireDist < benchDist),
			upgradeAvailable = canUpgrade,
			fireInRange = fireInstance ~= nil,
			hasWood = (counts["Wood"] or 0) > 0,
			targetKind = targetKind,
			selectedKind = if def then def.kind else nil,
			selectedId = if def then def.id else nil,
		})
	end

	-- Hit confirm: watch a target we just hit for the server's attribute change (HitsLeft / Depleted /
	-- MobHealth), then burst + sound (+ flash for mobs). Short-lived connections, swept in the loop.
	local function watch(inst: Instance, isMob: boolean)
		local now = os.clock()
		local w = watches[inst]
		if w then
			w.expires = now + WATCH_SECONDS
			return
		end
		local conns: { RBXScriptConnection } = {}
		local function confirm()
			local pos = positionOf(inst)
			if pos then
				Feedback.burst(pos)
				Feedback.sound(if isMob then "MobHitSound" else "ChopSound", pos)
			end
			if isMob then
				Feedback.flash(inst)
			end
		end
		if isMob then
			table.insert(
				conns,
				inst:GetAttributeChangedSignal(Config.Mobs.HealthAttribute):Connect(confirm)
			)
		else
			table.insert(
				conns,
				inst:GetAttributeChangedSignal(ItemCatalog.NodeHitsAttribute):Connect(confirm)
			)
			table.insert(
				conns,
				inst:GetAttributeChangedSignal(ItemCatalog.NodeDepletedAttribute):Connect(function()
					if inst:GetAttribute(ItemCatalog.NodeDepletedAttribute) == true then
						confirm()
					end
				end)
			)
		end
		watches[inst] = { conns = conns, expires = now + WATCH_SECONDS }
	end
	local function sweepWatches(force: boolean)
		local now = os.clock()
		for inst, w in watches do
			if force or now > w.expires or inst.Parent == nil then
				for _, c in w.conns do
					c:Disconnect()
				end
				watches[inst] = nil
			end
		end
	end
	addCleanup(cleanups, function()
		sweepWatches(true)
	end)

	-- Intent senders (shared by keys, click, tap, the Act button and the QA bridge).
	local function gather(node: Instance?)
		local target = node or targetInstance
		Feedback.swing()
		if target == nil then
			return
		end
		watch(target, false)
		recent["gather"] = os.clock()
		Remotes.event(Remotes.GatherRequest):FireServer(target)
	end
	local function attack(mob: Instance?)
		local target = mob or targetInstance
		Feedback.swing()
		if target == nil then
			return
		end
		watch(target, true)
		Remotes.event(Remotes.AttackRequest):FireServer(target)
	end
	local function eat()
		recent["eat"] = os.clock()
		Remotes.event(Remotes.UseItemRequest):FireServer(shownSlot())
	end
	local function fuel(fire: Instance?)
		local target = fire or fireInstance
		if target then
			recent["fuel"] = os.clock()
			Remotes.event(Remotes.AddFuelRequest):FireServer(target)
		end
	end
	-- Upgrade: affordable -> request; otherwise a toast with the cost (the server re-checks both).
	local function upgradeFire(fire: Instance?)
		local target = fire or upgradableFire()
		if target == nil then
			return
		end
		local tier = FireTiers.clamp(target:GetAttribute(Config.Fire.TierAttribute))
		local cost = FireTiers.nextCost(tier)
		if cost == nil then
			Toast.show("Fire is fully upgraded")
			return
		end
		if not FireTiers.canAfford(counts, cost) then
			Feedback.sound("DenySound", nil)
			Toast.show(`Upgrade needs {FireTiers.costText(cost, itemName)}`)
			return
		end
		recent["upgrade"] = os.clock()
		Remotes.event(Remotes.UpgradeFireRequest):FireServer(target)
	end
	local function place()
		local def = selectedDef()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if def and def.structureId and root and root:IsA("BasePart") then
			-- Aim at the ghost when it is up; the server snaps and re-validates either way.
			local t = ghost.target()
			if t and t.structureId == def.structureId then
				recent["place"] = os.clock()
				Remotes.event(Remotes.PlaceRequest)
					:FireServer(t.structureId, t.position, t.rotation)
				return
			end
			local look = root.CFrame.LookVector
			local _, yaw, _ = root.CFrame:ToOrientation()
			recent["place"] = os.clock()
			Remotes.event(Remotes.PlaceRequest):FireServer(
				def.structureId,
				root.Position + look * HudConfig.PlaceDistance,
				math.deg(yaw)
			)
		end
	end

	local function doAction(): string
		pickTarget()
		local action = currentAction()
		currentActionName = action
		local hook = interactHook
		if hook and hook.run(interactCtx(action)) then
			return "interact"
		end
		if action == "fuel" then
			fuel(nil)
		elseif action == "gather" then
			gather(nil)
		elseif action == "attack" then
			attack(nil)
		elseif action == "eat" then
			eat()
		elseif action == "place" then
			place()
		elseif action == "craft" then
			craftPanel.setOpen(true)
		elseif action == "upgrade" then
			upgradeFire(nil)
		else
			local def = selectedDef()
			if def and (def.kind == "tool" or def.kind == "weapon") then
				Feedback.swing()
			end
		end
		return action
	end

	if actionButton then
		connect(cleanups, actionButton.Activated, function()
			doAction()
		end)
	end
	for i, slot in slots do
		connect(cleanups, slot.button.Activated, function()
			-- Tapping the already-selected food slot eats it; otherwise select.
			local stack = stacks[i]
			local def = if stack then ItemCatalog.Items[stack.id] else nil
			if i == shownSlot() and def and def.kind == "food" then
				eat()
			else
				requestSelect(i)
			end
		end)
	end

	-- Server -> client updates. Remotes.event may yield, so connect from a spawned thread.
	task.spawn(function()
		local ev = Remotes.event(Remotes.MetersUpdate)
		if destroyed then
			return
		end
		connect(cleanups, ev.OnClientEvent, function(p: any)
			if
				type(p) ~= "table"
				or type(p.health) ~= "number"
				or type(p.warmth) ~= "number"
				or type(p.hunger) ~= "number"
			then
				return
			end
			meters.health, meters.warmth, meters.hunger = p.health, p.warmth, p.hunger
			meters.day = if type(p.day) == "number" then p.day else meters.day
			meters.isNight = p.isNight == true
			applyMeters()
		end)
	end)
	task.spawn(function()
		local ev = Remotes.event(Remotes.InventoryUpdate)
		if destroyed then
			return
		end
		connect(cleanups, ev.OnClientEvent, function(p: any)
			if type(p) ~= "table" or type(p.slots) ~= "table" then
				return
			end
			local before = table.clone(counts)
			table.clear(stacks)
			table.clear(counts)
			hasItems = false
			for i, stack in p.slots do
				if
					type(i) == "number"
					and type(stack) == "table"
					and type(stack.id) == "string"
				then
					local n = if type(stack.count) == "number" then stack.count else 1
					stacks[i] = {
						id = stack.id,
						count = n,
						durability = if type(stack.durability) == "number"
							then stack.durability
							else nil,
					}
					counts[stack.id] = (counts[stack.id] or 0) + n
					hasItems = true
				end
			end
			for i, slot in slots do
				local stack = stacks[i]
				local def = if stack then ItemCatalog.Items[stack.id] else nil
				slot.name.Text = if def then def.name elseif stack then stack.id else ""
				local itemDef = if stack then ItemCatalog.Items[stack.id] else nil
				slot.count.Text = if stack and stack.count > 1
					then `x{stack.count}`
					elseif
						stack
						and itemDef
						and stack.durability ~= nil
					then Repair.durabilityLabel(itemDef, stack.durability) or ""
					else ""
			end
			-- Onboarding credit from real inventory changes.
			local now = os.clock()
			local function delta(id: string): number
				return (counts[id] or 0) - (before[id] or 0)
			end
			if delta("Wood") > 0 then
				hints.complete("chop")
			end
			if delta("Campfire") > 0 then
				hints.complete("craftCampfire")
				Feedback.sound("CraftSound", nil)
			end
			if delta("Campfire") < 0 and now - (recent["place"] or -math.huge) < RECENT_SECONDS then
				hints.complete("placeCampfire")
				Feedback.sound("CraftSound", nil)
			end
			if delta("Wood") < 0 and now - (recent["fuel"] or -math.huge) < RECENT_SECONDS then
				hints.complete("addWood")
			end
			if delta("RawMeat") < 0 and now - (recent["eat"] or -math.huge) < RECENT_SECONDS then
				hints.complete("eat")
			end
			if type(p.selected) == "number" then
				confirmSelected(p.selected)
			else
				renderSelection()
			end
			if craftPanel.isOpen() then
				craftPanel.refresh(counts, nearStations())
			end
		end)
	end)

	connect(cleanups, player:GetAttributeChangedSignal(Config.Inventory.SlotAttribute), function()
		local v = player:GetAttribute(Config.Inventory.SlotAttribute)
		if type(v) == "number" then
			confirmSelected(v)
		end
	end)

	connect(cleanups, UserInputService.InputBegan, function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			doAction()
			return
		end
		if input.KeyCode == HudConfig.ActionKey then
			doAction()
			return
		end
		if input.KeyCode == HudConfig.CraftKey then
			craftPanel.toggle()
			return
		end
		local idx = table.find(HOTBAR_KEYS, input.KeyCode)
		if idx and idx <= slotCount then
			requestSelect(idx)
		end
	end)

	-- Mouse wheel cycles the hotbar. Bound above the camera's zoom binding and sunk so it does not
	-- also zoom; hold Shift to zoom with the wheel instead.
	ContextActionService:BindActionAtPriority(
		WHEEL_ACTION,
		function(
			_name: string,
			state: Enum.UserInputState,
			input: InputObject
		): Enum.ContextActionResult
			if
				state ~= Enum.UserInputState.Change
				or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			then
				return Enum.ContextActionResult.Pass
			end
			local dz = input.Position.Z
			if dz == 0 then
				return Enum.ContextActionResult.Pass
			end
			requestSelect(HudMath.cycleSlot(shownSlot(), if dz < 0 then 1 else -1, slotCount))
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.UserInputType.MouseWheel
	)
	addCleanup(cleanups, function()
		ContextActionService:UnbindAction(WHEEL_ACTION)
	end)

	local function promptFor(): (Instance?, string, number?, boolean)
		local action = currentAction()
		currentActionName = action
		local hook = interactHook
		local interact = if hook then hook.peek(interactCtx(action)) else nil
		if interact then
			return interact.target, interact.text, nil, interact.warn
		end
		if action == "fuel" and fireInstance then
			return fireInstance, `Add wood {inputHint}`, nil, false
		end
		if action == "craft" and benchInstance then
			return benchInstance, `Craft {inputHint}`, nil, false
		elseif action == "upgrade" then
			local fire = upgradableFire()
			local cost = if fire
				then FireTiers.nextCost(
					FireTiers.clamp(fire:GetAttribute(Config.Fire.TierAttribute))
				)
				else nil
			if fire and cost then
				local affordable = FireTiers.canAfford(counts, cost)
				return fire,
					`Upgrade fire ({FireTiers.costText(cost, itemName)}) {inputHint}`,
					nil,
					not affordable
			end
		end
		local target = targetInstance
		if target == nil then
			return nil, "", nil, false
		end
		if targetKind == "gather" then
			local kind = target:GetAttribute(ItemCatalog.NodeKindAttribute)
			local node = if type(kind) == "string" then ItemCatalog.Nodes[kind] else nil
			if node == nil then
				return nil, "", nil, false
			end
			local hits = target:GetAttribute(ItemCatalog.NodeHitsAttribute)
			local progress = if type(hits) == "number"
				then hits / Config.Gather.HitsToDeplete
				else nil
			local stack = stacks[shownSlot()]
			local ok = ItemsGather.canHarvest(
				node.kind,
				if stack then { id = stack.id, count = stack.count } else nil
			)
			local tool = ItemCatalog.Items[node.toolId]
			if ok then
				return target, `{node.verb} {inputHint}`, progress, false
			end
			return target,
				`{node.verb}: needs {if tool then tool.name else node.toolId}`,
				progress,
				true
		elseif targetKind == "attack" then
			local hp = target:GetAttribute(Config.Mobs.HealthAttribute)
			local humanoid = target:FindFirstChildOfClass("Humanoid")
			local progress = if type(hp) == "number"
					and humanoid
					and humanoid.MaxHealth > 0
				then hp / humanoid.MaxHealth
				else nil
			local name = HudConfig.MobNames[target.Name] or target.Name
			return target, `Hunt {name} {inputHint}`, progress, false
		end
		return nil, "", nil, false
	end

	-- One visual loop: compass every frame; target/prompt/hints at a low rate.
	local accumulator = 0.0
	local promptAccum = 0.0
	connect(cleanups, RunService.RenderStepped, function(dt: number)
		local camera = Workspace.CurrentCamera
		local camp = Workspace:GetAttribute(HudConfig.CampAttribute)
		if camera and typeof(camp) == "Vector3" then
			local look = camera.CFrame.LookVector
			local offset = camp - camera.CFrame.Position
			arrowHolder.Rotation = HudMath.compassAngle(look.X, look.Z, offset.X, offset.Z)
			arrow.Visible = true
			local dist = math.floor(Vector3.new(offset.X, 0, offset.Z).Magnitude + 0.5)
			if dist ~= lastDist then
				lastDist = dist
				distLabel.Text = `{dist}`
			end
		else
			arrow.Visible = false
			distLabel.Text = "camp ?"
			lastDist = -1
		end

		promptAccum += dt
		if promptAccum >= HudConfig.PromptInterval then
			promptAccum = 0
			pickTarget()
			local t, text, progress, warn = promptFor()
			prompt.set(t, text, progress, warn)
			if actionButton then
				local hook = interactHook
				local interact = if hook then hook.peek(interactCtx(currentAction())) else nil
				actionButton.Text = if interact
					then interact.label
					else (ActionPick.Labels[currentAction()] or ActionPick.Labels.none)
			end
		end

		accumulator += dt
		if accumulator < HudConfig.HintCheckInterval then
			return
		end
		accumulator = 0
		local now = os.clock()
		sweepWatches(false)
		if itemLabel.Visible and now >= itemLabelUntil then
			itemLabel.Visible = false
		end
		if craftPanel.isOpen() then
			craftPanel.refresh(counts, nearStations())
		end
		if hintLabel.Visible and now >= hintUntil then
			hintLabel.Visible = false
		end
		if not hintLabel.Visible then
			local id = HudMath.nextHint(HudConfig.Hints, shownHints, {
				warmth = meters.warmth,
				hunger = meters.hunger,
				health = meters.health,
				isNight = meters.isNight,
				hasItems = hasItems,
			})
			if id then
				shownHints[id] = true
				for _, hint in HudConfig.Hints do
					if hint.id == id then
						hintLabel.Text = hint.text
						hintLabel.Visible = true
						hintUntil = now + HudConfig.HintSeconds
					end
				end
			end
		end
	end)

	addCleanup(cleanups, DebugChat.start())
	addCleanup(
		cleanups,
		Toast.start(gui, function(kind: string, _text: string)
			if HudConfig.DenyKinds[kind] then
				Feedback.sound("DenySound", nil)
			end
		end)
	)

	-- Studio-only QA bridge: the same handlers the inputs call.
	addCleanup(
		cleanups,
		QABridge.start(setmetatable({
			selectSlot = function(slot: number)
				requestSelect(slot)
			end,
			selectItem = function(id: string): number?
				for i = 1, slotCount do
					local stack = stacks[i]
					if stack and stack.id == id then
						requestSelect(i)
						return i
					end
				end
				return nil
			end,
			wheel = function(delta: number)
				requestSelect(HudMath.cycleSlot(shownSlot(), delta, slotCount))
			end,
			toggleCraft = function()
				craftPanel.toggle()
			end,
			craft = function(recipeId: string)
				craftPanel.click(recipeId)
			end,
			action = function(): string
				return doAction()
			end,
			gather = function(node: Instance?)
				gather(node)
			end,
			attack = function(mob: Instance?)
				attack(mob)
			end,
			place = function()
				-- Legacy QA semantics: aim PlaceDistance ahead of the player (no cursor in a script).
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					ghost.setAim(root.Position + root.CFrame.LookVector * HudConfig.PlaceDistance)
				end
				place()
				ghost.setAim(nil)
			end,
			ghostAim = function(point: Vector3?)
				ghost.setAim(point)
			end,
			ghostState = function(): { [string]: any }
				return ghost.state()
			end,
			ghostRotate = function()
				ghost.rotate()
			end,
			ghostTouch = function(value: boolean?)
				ghost.setTouch(value)
			end,
			eat = function()
				eat()
			end,
			fuel = function(fire: Instance?)
				fuel(fire)
			end,
			upgrade = function(fire: Instance?)
				upgradeFire(fire)
			end,
			craftStatus = function(recipeId: string): string
				craftPanel.refresh(counts, nearStations())
				return craftPanel.statusOf(recipeId)
			end,
			state = function(): { [string]: any }
				pickTarget()
				local character = player.Character
				local tool = character and character:FindFirstChildOfClass("Tool")
				local _, ptext = promptFor()
				return {
					selected = selectedSlot,
					shown = shownSlot(),
					counts = table.clone(counts),
					held = if tool then tool:GetAttribute("ItemId") else nil,
					itemName = if itemLabel.Visible then itemLabel.Text else "",
					target = targetKind,
					targetName = if targetInstance then targetInstance.Name else "",
					prompt = ptext,
					action = currentAction(),
					craftOpen = craftPanel.isOpen(),
					benchNear = nearStations().workbench == true,
					onboarding = hints.current(),
					hunger = meters.hunger,
				}
			end,
		}, { __index = qaExtra }) :: any)
	)

	local function teardown()
		if destroyed then
			return
		end
		destroyed = true
		for _, fn in cleanups do
			pcall(fn)
		end
		table.clear(cleanups)
		started = false
	end
	connect(cleanups, gui.Destroying, teardown)
	addCleanup(cleanups, function()
		gui:Destroy()
	end)

	applyMeters()
	renderSelection()
	gui.Parent = playerGui
end

return HudController
