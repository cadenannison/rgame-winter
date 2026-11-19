--!strict
-- Crafting panel (C key or the Craft button; the button is visible on every device). Lists recipes up
-- to Config.Craft.MaxTier with materials have/need, greys out what the player cannot craft now, notes
-- "needs workbench", and shows inventory counts. Display only: clicking sends CraftRequest via onCraft.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ItemCatalog = require(Shared:WaitForChild("ItemCatalog"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Crafting = require(Shared:WaitForChild("logic"):WaitForChild("Crafting"))
local WorkbenchTier = require(Shared:WaitForChild("logic"):WaitForChild("WorkbenchTier"))
local ItemTooltip = require(Shared:WaitForChild("logic"):WaitForChild("ItemTooltip"))
local HudConfig = require(script.Parent:WaitForChild("HudConfig"))
local RightStack = require(script.Parent:WaitForChild("RightStack"))

export type Panel = {
	setOpen: (boolean) -> (),
	toggle: () -> (),
	isOpen: () -> boolean,
	refresh: (counts: { [string]: number }, near: Crafting.Near) -> (),
	statusOf: (recipeId: string) -> string, -- last computed status (QA bridge)
	click: (recipeId: string) -> (), -- same path as clicking a recipe row (QA bridge uses it)
	destroy: () -> (),
}

type Row = { button: TextButton, title: TextLabel, detail: TextLabel }

local CraftPanel = {}

local function label(
	parent: Instance,
	name: string,
	size: UDim2,
	pos: UDim2,
	maxText: number
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.TextColor3 = HudConfig.TextColor
	l.TextScaled = true
	l.Font = Enum.Font.GothamMedium
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = ""
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxText
	c.MinTextSize = 8
	c.Parent = l
	l.Parent = parent
	return l
end

local function corner(parent: Instance, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = parent
end

-- onCraft(recipeId) sends the request; onDenied(text) shows why a greyed recipe cannot be crafted.
function CraftPanel.new(
	gui: ScreenGui,
	onCraft: (string) -> (),
	onDenied: (string) -> (),
	onOpened: () -> ()
): Panel
	local connections: { RBXScriptConnection } = {}
	local open = false

	local toggleButton = Instance.new("TextButton")
	toggleButton.Name = "CraftButton"
	toggleButton.BackgroundColor3 = HudConfig.PanelColor
	toggleButton.BackgroundTransparency = HudConfig.PanelTransparency
	toggleButton.TextColor3 = HudConfig.TextColor
	toggleButton.Font = Enum.Font.GothamBold
	toggleButton.TextScaled = true
	toggleButton.Text = "Craft (C)"
	toggleButton.BorderSizePixel = 0
	corner(toggleButton, 8)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = toggleButton
	RightStack.attach(toggleButton, "Craft")

	local frame = Instance.new("Frame")
	frame.Name = "CraftPanel"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.45)
	frame.Size = UDim2.fromScale(HudConfig.CraftPanelWidth, 0.6)
	frame.BackgroundColor3 = HudConfig.PanelColor
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.ZIndex = 5
	corner(frame, 10)
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = HudConfig.CraftPanelMin
	limit.MaxSize = HudConfig.CraftPanelMax
	limit.Parent = frame

	local title = label(frame, "Title", UDim2.new(1, -60, 0, 28), UDim2.fromOffset(12, 6), 22)
	title.Font = Enum.Font.GothamBold
	title.Text = "Crafting"
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -6, 0, 6)
	close.Size = UDim2.fromOffset(40, 28)
	close.Text = "X"
	close.Font = Enum.Font.GothamBold
	close.TextScaled = true
	close.TextColor3 = HudConfig.TextColor
	close.BackgroundColor3 = HudConfig.PanelColor
	close.BorderSizePixel = 0
	corner(close, 6)
	close.Parent = frame
	local benchNote =
		label(frame, "BenchNote", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 34), 14)
	benchNote.TextColor3 = HudConfig.AccentColor

	local list = Instance.new("ScrollingFrame")
	list.Name = "Recipes"
	list.Position = UDim2.fromOffset(8, 56)
	list.Size = UDim2.new(1, -16, 1, -56 - 70)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	list.Parent = frame

	local invTitle =
		label(frame, "InvTitle", UDim2.new(1, -24, 0, 16), UDim2.new(0, 12, 1, -66), 14)
	invTitle.Font = Enum.Font.GothamBold
	invTitle.Text = "Inventory"
	local invText =
		label(frame, "Inventory", UDim2.new(1, -24, 0, 44), UDim2.new(0, 12, 1, -48), 14)
	invText.TextWrapped = true
	invText.TextYAlignment = Enum.TextYAlignment.Top
	-- Hover (PC) / long-press (touch) tooltip for a recipe's output item: name, Warmth +N, Armor.
	local tip = label(frame, "Tooltip", UDim2.new(1, -24, 0, 48), UDim2.new(0, 12, 1, -118), 14)
	tip.ZIndex = 7
	tip.BackgroundTransparency = 0.1
	tip.BackgroundColor3 = Color3.new(0, 0, 0)
	tip.TextWrapped = true
	tip.TextYAlignment = Enum.TextYAlignment.Top
	tip.Visible = false
	frame.Parent = gui

	local lastCounts: { [string]: number } = {}
	local lastNear: Crafting.Near = {}
	local function partyTier(): number
		return WorkbenchTier.clamp(Workspace:GetAttribute(Config.Workbench.TierAttribute))
	end

	local rows: { [string]: Row } = {}
	local status: { [string]: string } = {}
	local function click(id: string)
		local s = status[id] or "MissingMaterials"
		if s == "Ok" then
			onCraft(id)
		else
			local stationId = Crafting.requiredStation(id)
			local station = if stationId then Config.Craft.Stations[stationId] else nil
			if s == "NeedStation" and station then
				onDenied(`Needs a {station.Label} nearby`)
			else
				onDenied(HudConfig.NotifyText[s] or s)
			end
		end
	end
	for order, id in Crafting.listForTier(Config.Craft.MaxTier) do
		local button = Instance.new("TextButton")
		button.Name = id
		button.LayoutOrder = order
		button.Size = UDim2.new(1, -8, 0, HudConfig.CraftRowHeight)
		button.BackgroundColor3 = Color3.new(0, 0, 0)
		button.BackgroundTransparency = 0.6
		button.BorderSizePixel = 0
		button.Text = ""
		corner(button, 6)
		local t = label(button, "Title", UDim2.new(1, -12, 0.5, 0), UDim2.fromOffset(8, 2), 18)
		t.Font = Enum.Font.GothamBold
		local d = label(button, "Detail", UDim2.new(1, -12, 0.45, 0), UDim2.new(0, 8, 0.5, 0), 14)
		button.Parent = list
		rows[id] = { button = button, title = t, detail = d }
		table.insert(
			connections,
			button.Activated:Connect(function()
				click(id)
			end)
		)
		local outId = ItemCatalog.Recipes[id].output.id
		local function showTip()
			tip.Text = ItemTooltip.text(outId)
			tip.Visible = true
		end
		table.insert(connections, button.MouseEnter:Connect(showTip))
		table.insert(
			connections,
			button.MouseLeave:Connect(function()
				tip.Visible = false
			end)
		)
		local pressToken = 0
		table.insert(
			connections,
			button.InputBegan:Connect(function(input: InputObject)
				if input.UserInputType ~= Enum.UserInputType.Touch then
					return
				end
				pressToken += 1
				local mine = pressToken
				task.delay(Config.Inventory.SplitHoldSeconds, function()
					if mine == pressToken then
						showTip()
					end
				end)
			end)
		)
		table.insert(
			connections,
			button.InputEnded:Connect(function(input: InputObject)
				if input.UserInputType == Enum.UserInputType.Touch then
					pressToken += 1
					tip.Visible = false
				end
			end)
		)
	end

	-- "Upgrade Workbench" row: lists the next tier's cost; the server recomputes and validates everything.
	local upgradeButton = Instance.new("TextButton")
	upgradeButton.Name = "UpgradeWorkbench"
	upgradeButton.LayoutOrder = 0
	upgradeButton.Size = UDim2.new(1, -8, 0, HudConfig.CraftRowHeight)
	upgradeButton.BackgroundColor3 = HudConfig.AccentColor
	upgradeButton.BackgroundTransparency = 0.7
	upgradeButton.BorderSizePixel = 0
	upgradeButton.Text = ""
	corner(upgradeButton, 6)
	local upTitle =
		label(upgradeButton, "Title", UDim2.new(1, -12, 0.5, 0), UDim2.fromOffset(8, 2), 18)
	upTitle.Font = Enum.Font.GothamBold
	local upDetail =
		label(upgradeButton, "Detail", UDim2.new(1, -12, 0.45, 0), UDim2.new(0, 8, 0.5, 0), 14)
	upgradeButton.Parent = list
	local upgradeStatus = "NeedStation"
	local function clickUpgrade()
		if upgradeStatus == "Ok" then
			Remotes.event(Remotes.UpgradeWorkbench):FireServer()
		elseif upgradeStatus == "NeedStation" then
			onDenied(`Needs a {Config.Craft.Stations.workbench.Label} nearby`)
		elseif upgradeStatus == "MaxTier" then
			onDenied("The workbench is fully upgraded")
		else
			onDenied(HudConfig.NotifyText[upgradeStatus] or "Not enough materials")
		end
	end
	table.insert(connections, upgradeButton.Activated:Connect(clickUpgrade))

	local panel: Panel
	local function setOpen(v: boolean)
		open = v
		frame.Visible = v
		if v then
			onOpened()
		end
	end
	table.insert(
		connections,
		Workspace:GetAttributeChangedSignal(Config.Workbench.TierAttribute):Connect(function()
			if open and panel then
				panel.refresh(lastCounts, lastNear) -- newly unlocked recipes appear at once
			end
		end)
	)
	table.insert(
		connections,
		toggleButton.Activated:Connect(function()
			setOpen(not open)
		end)
	)
	table.insert(
		connections,
		close.Activated:Connect(function()
			setOpen(false)
		end)
	)

	panel = {
		setOpen = setOpen,
		toggle = function()
			setOpen(not open)
		end,
		click = click,
		isOpen = function(): boolean
			return open
		end,
		statusOf = function(recipeId: string): string
			return status[recipeId] or "Unknown"
		end,
		refresh = function(counts: { [string]: number }, near: Crafting.Near)
			lastCounts, lastNear = counts, near
			local tier = partyTier()
			local here: { string } = {}
			for name, station in Config.Craft.Stations do
				if near[name] then
					table.insert(here, station.Label)
				end
			end
			table.sort(here)
			benchNote.Text = if #here > 0
				then `At a {table.concat(here, ", ")}: its recipes are unlocked`
				else "No station nearby: hand recipes only"
			-- Upgrade row (hidden once the bench is at max tier).
			local nextCost = WorkbenchTier.nextCost(tier)
			upgradeStatus = WorkbenchTier.status(counts, tier, near.workbench == true)
			upgradeButton.Visible = nextCost ~= nil
			if nextCost then
				local nextDef = Config.Workbench.Tiers[tier + 1]
				upTitle.Text = `{Config.Workbench.UpgradeRowText}: {nextDef.Label}`
				upDetail.Text = WorkbenchTier.costText(nextCost, counts)
				local dimUp = if upgradeStatus == "Ok" then 0 else HudConfig.DisabledTransparency
				upTitle.TextTransparency = dimUp
				upDetail.TextTransparency = dimUp
				upgradeButton.AutoButtonColor = upgradeStatus == "Ok"
			end
			for id, row in rows do
				local recipe = ItemCatalog.Recipes[id]
				row.button.Visible = WorkbenchTier.recipeAvailable(id, tier) -- higher tiers stay hidden
				local s = Crafting.status(counts, id, near, tier)
				status[id] = s
				local parts: { string } = {}
				for _, input in recipe.inputs do
					local def = ItemCatalog.Items[input.id]
					table.insert(
						parts,
						`{if def then def.name else input.id} {counts[input.id] or 0}/{input.count}`
					)
				end
				local outDef = ItemCatalog.Items[recipe.output.id]
				local warmth = ItemTooltip.warmthLine(recipe.output.id)
				row.title.Text = (if outDef then outDef.name else id)
					.. (if warmth then `  ({warmth})` else "")
				row.detail.Text = table.concat(parts, "   ")
					.. (
						if s == "NeedStation"
							then `   (needs {Config.Craft.Stations[recipe.station or ""].Label})`
							else ""
					)
				local dim = if s == "Ok" then 0 else HudConfig.DisabledTransparency
				row.title.TextTransparency = dim
				row.detail.TextTransparency = dim
				row.button.AutoButtonColor = s == "Ok"
			end
			local inv: { string } = {}
			for id, n in counts do
				local def = ItemCatalog.Items[id]
				if n > 0 then
					table.insert(inv, `{if def then def.name else id} x{n}`)
				end
			end
			table.sort(inv)
			invText.Text = if #inv > 0 then table.concat(inv, ", ") else "(empty)"
		end,
		destroy = function()
			for _, c in connections do
				c:Disconnect()
			end
			table.clear(connections)
			frame:Destroy()
			toggleButton:Destroy()
		end,
	}
	return panel
end

return CraftPanel
