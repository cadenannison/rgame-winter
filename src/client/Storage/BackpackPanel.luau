--!strict
-- Minecraft-style backpack panel: equipment slots + rotating character, 27-slot grid, hotbar row and (when a
-- storage chest is open) the 9-slot chest grid. Drag and drop (merge, swap), right-click or long-press to split,
-- shift-click quick move, tap-select then tap-destination on phones. Every action sends ONE remote
-- (Remotes.InventoryMove) with typed addresses; the server validates everything. Display and intent only.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Rarity = require(Shared:WaitForChild("data"):WaitForChild("Rarity"))
local Equipment = require(Shared:WaitForChild("logic"):WaitForChild("Equipment"))
local BackpackLayout = require(Shared:WaitForChild("logic"):WaitForChild("BackpackLayout"))
local ItemTooltip = require(Shared:WaitForChild("logic"):WaitForChild("ItemTooltip"))
local InventoryMove = require(Shared:WaitForChild("logic"):WaitForChild("InventoryMove"))
local SlotViewModel = require(Shared:WaitForChild("logic"):WaitForChild("SlotViewModel"))
local SlotLayout = require(Shared:WaitForChild("logic"):WaitForChild("SlotLayout"))
local HudConfig = require(script.Parent.Parent:WaitForChild("HUD"):WaitForChild("HudConfig"))
local EquipmentViewport = require(script.Parent:WaitForChild("EquipmentViewport"))
local InventoryMirror = require(script.Parent:WaitForChild("InventoryMirror"))
local ItemIcon = require(script.Parent:WaitForChild("ItemIcon"))
local NameFit = require(script.Parent:WaitForChild("NameFit"))
local UiConfig = require(script.Parent:WaitForChild("InventoryUiConfig"))
local InputGuard = require(script.Parent.Parent:WaitForChild("Input"):WaitForChild("InputGuard"))

local BackpackPanel = {}

export type ChestInfo = {
	chest: Instance,
	id: string,
	rev: number,
	slots: { [number]: { id: string, count: number, durability: number? } },
}
export type Panel = {
	toggle: () -> (),
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
	setChest: (ChestInfo?) -> (),
	showFull: () -> (), -- "Inventory full" hint for Config.Inventory.FullHintSeconds
	-- QA / tests: the same entry points the pointer handlers use.
	move: (from: InventoryMove.Addr, to: InventoryMove.Addr?, count: number) -> (),
	-- /debug inv: per displayed grid cell, the slot index it reads and what it shows; warns about strays.
	debugLines: () -> { string },
	destroy: () -> (),
}
type Stack = { id: string, count: number, durability: number? }
type SlotView = {
	addr: InventoryMove.Addr,
	button: TextButton,
	inner: Frame,
	icon: ItemIcon.ItemIconHandle,
	caption: TextLabel,
	name: TextLabel,
	count: TextLabel,
	stroke: UIStroke,
	base: Color3, -- resting background color (tinted by highlights, restored on refresh)
	unbindName: () -> (),
}
type Press = {
	view: SlotView,
	input: InputObject,
	start: Vector2,
	half: boolean,
	dragging: boolean,
	touch: boolean,
}

local DROP_ACTION = "BackpackDropItem"
local HL = Config.InventoryUi

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function sameAddr(a: InventoryMove.Addr?, b: InventoryMove.Addr?): boolean
	return a ~= nil and b ~= nil and a.kind == b.kind and a.slot == b.slot and a.id == b.id
end

local function key(addr: InventoryMove.Addr): string
	return `{addr.kind}:{tostring(addr.slot)}`
end

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(class)
	for k, v in props do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end

local function label(
	parent: Instance,
	text: string,
	size: number,
	align: Enum.TextXAlignment?
): TextLabel
	return make("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = UiConfig.Colors.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = size,
		TextXAlignment = align or Enum.TextXAlignment.Left,
	}, parent)
end

function BackpackPanel.new(mirror: InventoryMirror.Mirror): Panel
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local connections: { RBXScriptConnection } = {}
	local destroyed = false
	local isOpen = false
	local chestInfo: ChestInfo? = nil
	local views: { [string]: SlotView } = {}
	local selection: { addr: InventoryMove.Addr, count: number }? = nil
	local press: Press? = nil
	local ghost: TextLabel? = nil
	local ghostIcon: ItemIcon.ItemIconHandle? = nil
	local tipView: SlotView? = nil -- slot under the pointer (PC); touch falls back to the focused slot
	local lastTarget: SlotView? = nil
	local focus: InventoryMove.Addr? = nil -- last clicked/tapped slot (highlight + Drop target)
	local dragOrigin: InventoryMove.Addr? = nil -- slot being dragged (held highlight while dragging)
	local hoverView: SlotView? = nil -- slot under the pointer during a drag
	local dropButton: TextButton? = nil
	local fullToken = 0

	local gui = make("ScreenGui", {
		Name = UiConfig.GuiName,
		ResetOnSpawn = false,
		DisplayOrder = HudConfig.DisplayOrder + UiConfig.DisplayOrderOffset,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets, -- the panel always sits below the Roblox top bar
	}, nil) :: ScreenGui

	-- Toggle button (always visible, >= 44 px).
	local T = UiConfig.ToggleButton
	local toggleButton = make("TextButton", {
		Name = "BackpackButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(T.RightScale, 0, 0, T.TopPx),
		Size = UDim2.fromOffset(T.WidthPx, T.HeightPx),
		BackgroundColor3 = UiConfig.Colors.Panel,
		BackgroundTransparency = HudConfig.PanelTransparency,
		BorderSizePixel = 0,
		Text = T.Text,
		TextColor3 = UiConfig.Colors.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
	}, gui) :: TextButton
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, toggleButton)

	-- "Inventory full" hint.
	local fullHint = make("TextLabel", {
		Name = "FullHint",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, UiConfig.FullHintY),
		Size = UDim2.fromOffset(UiConfig.FullHintWidthPx, UiConfig.FullHintHeightPx),
		BackgroundColor3 = UiConfig.Colors.Panel,
		BackgroundTransparency = HudConfig.PanelTransparency,
		BorderSizePixel = 0,
		Text = InventoryMove.FullText,
		TextColor3 = UiConfig.Colors.Reject,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		Visible = false,
		ZIndex = 5,
	}, gui) :: TextLabel
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, fullHint)

	-- Panel shell: titled frame with a scrolling body so nothing is ever cut off on a phone.
	local panel = make("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, UiConfig.PanelTopMarginPx),
		BackgroundColor3 = UiConfig.Colors.Panel,
		BackgroundTransparency = UiConfig.PanelTransparency,
		BorderSizePixel = 0,
		Active = true, -- swallows clicks so nothing behind the panel reacts
		Visible = false,
	}, gui) :: Frame
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, panel)
	local title = label(panel, "Backpack", 20)
	title.Name = "Title"
	title.Font = Enum.Font.GothamBold
	title.TextTruncate = Enum.TextTruncate.AtEnd
	local closeButton = make("TextButton", {
		Name = "Close",
		BackgroundColor3 = HudConfig.BarColors.health,
		BorderSizePixel = 0,
		Text = "X",
		TextColor3 = UiConfig.Colors.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 20,
	}, panel) :: TextButton
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, closeButton)
	dropButton = make("TextButton", {
		Name = "DropButton",
		BackgroundColor3 = UiConfig.Colors.Reject,
		BorderSizePixel = 0,
		Text = HL.DropButtonText,
		TextColor3 = UiConfig.Colors.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
	}, panel) :: TextButton
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, dropButton)
	local body = make("ScrollingFrame", {
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, panel) :: ScrollingFrame
	local flow = make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, UiConfig.PadPx),
	}, body) :: UIListLayout

	-- Item detail footer (hover on PC, focused slot on touch): name, then Warmth / Armor / Damage / Fuel lines.
	local footer = make("Frame", {
		Name = "Tooltip",
		BackgroundColor3 = UiConfig.Colors.Equip,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	}, panel) :: Frame
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, footer)
	local tipName = label(footer, "", UiConfig.TooltipNameMax)
	tipName.Name = "TipName"
	tipName.Font = Enum.Font.GothamBold
	tipName.Position = UDim2.fromOffset(UiConfig.PadPx, 2)
	tipName.Size = UDim2.new(1, -UiConfig.PadPx * 2, 0.5, -2)
	tipName.TextTruncate = Enum.TextTruncate.AtEnd
	local tipInfo = label(footer, "", UiConfig.TooltipInfoMax)
	tipInfo.Name = "TipInfo"
	tipInfo.TextColor3 = UiConfig.Colors.Dim
	tipInfo.Position = UDim2.new(0, UiConfig.PadPx, 0.5, 0)
	tipInfo.Size = UDim2.new(1, -UiConfig.PadPx * 2, 0.5, -2)
	tipInfo.TextTruncate = Enum.TextTruncate.AtEnd

	local function section(order: number, name: string): (Frame, TextLabel)
		local frame = make("Frame", {
			Name = name,
			LayoutOrder = order,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.new(),
		}, body) :: Frame
		make("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, UiConfig.GapPx),
		}, frame)
		local header = label(frame, name, 16)
		header.Name = "Header"
		header.LayoutOrder = 0
		header.Font = Enum.Font.GothamBold
		header.Size = UDim2.fromOffset(180, UiConfig.HeaderPx)
		return frame, header
	end

	local equipSection = section(1, UiConfig.Titles.Equipment)
	local packSection = section(2, UiConfig.Titles.Backpack)
	local chestSection, chestHeader = section(3, UiConfig.Titles.Chest)
	chestSection.Visible = false
	chestHeader.Text = UiConfig.Titles.Chest

	-- Equipment row: left column, character viewport, right column.
	local equipRow = make("Frame", {
		Name = "Row",
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
	}, equipSection) :: Frame
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, UiConfig.GapPx * 2),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, equipRow)
	local leftCol = make("Frame", {
		Name = "Left",
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
	}, equipRow) :: Frame
	make(
		"UIListLayout",
		{ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, UiConfig.GapPx) },
		leftCol
	)
	local viewportHolder = make("Frame", {
		Name = "ViewportHolder",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(UiConfig.ViewportWidthPx, UiConfig.ViewportHeightPx),
	}, equipRow) :: Frame
	local rightCol = make("Frame", {
		Name = "Right",
		LayoutOrder = 3,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
	}, equipRow) :: Frame
	make(
		"UIListLayout",
		{ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, UiConfig.GapPx) },
		rightCol
	)
	local viewport = EquipmentViewport.new(viewportHolder)

	local function grid(parent: Instance, order: number): (Frame, UIGridLayout)
		local frame = make("Frame", {
			Name = "Grid",
			LayoutOrder = order,
			BackgroundTransparency = 1,
			Size = UDim2.new(),
			AutomaticSize = Enum.AutomaticSize.XY,
		}, parent) :: Frame
		local layout = make("UIGridLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			CellSize = UDim2.fromOffset(UiConfig.CellPx, UiConfig.CellPx),
			CellPadding = UDim2.fromOffset(UiConfig.GapPx, UiConfig.GapPx),
			FillDirectionMaxCells = Config.Inventory.Columns,
		}, frame) :: UIGridLayout
		return frame, layout
	end
	local packGrid, packLayout = grid(packSection, 1)
	local hotbarHeader = label(packSection, UiConfig.Titles.Hotbar, 14)
	hotbarHeader.LayoutOrder = 2
	hotbarHeader.Size = UDim2.fromOffset(180, UiConfig.HeaderPx)
	hotbarHeader.TextColor3 = UiConfig.Colors.Dim
	local hotGrid, hotLayout = grid(packSection, 3)
	local chestGrid, chestLayout = grid(chestSection, 1)
	local gridLayouts: { UIGridLayout } = { packLayout, hotLayout, chestLayout }

	local function refresh() end -- assigned below

	local updateTip: () -> () = function() end -- assigned after stackAt

	local function showFull()
		fullToken += 1
		local token = fullToken
		fullHint.Visible = true
		task.delay(Config.Inventory.FullHintSeconds, function()
			if fullToken == token and not destroyed then
				fullHint.Visible = false
			end
		end)
	end

	local function stackAt(addr: InventoryMove.Addr): Stack?
		if addr.kind == "inv" then
			return mirror.slots()[addr.slot :: number]
		elseif addr.kind == "equip" then
			return mirror.equipment()[addr.slot :: string]
		elseif chestInfo and addr.id == chestInfo.id then
			return chestInfo.slots[addr.slot :: number]
		end
		return nil
	end

	-- Footer text for the hovered slot, else the focused one (touch has no hover).
	updateTip = function()
		local stack: Stack? = nil
		if tipView then
			stack = stackAt(tipView.addr)
		end
		if stack == nil and focus then
			stack = stackAt(focus)
		end
		if stack == nil then
			tipName.Text = ""
			tipInfo.Text = ""
			return
		end
		local lines = ItemTooltip.lines(stack.id)
		tipName.Text = lines[1] or SlotViewModel.name(stack)
		table.remove(lines, 1)
		tipInfo.Text = table.concat(lines, "   ")
	end

	local function send(from: InventoryMove.Addr, to: InventoryMove.Addr?, count: number)
		local payload: Remotes.InventoryMovePayload = {
			from = from,
			to = to,
			count = count,
			rev = if chestInfo then chestInfo.rev else nil,
			expect = (function(): string?
				local s = stackAt(from)
				return if s then s.id else nil
			end)(),
		}
		Remotes.event(Remotes.InventoryMove):FireServer(payload)
	end

	local function shake(view: SlotView?)
		if view == nil then
			return
		end
		task.spawn(function()
			local started = os.clock()
			local duration = Config.Equipment.ShakeSeconds
			view.stroke.Color = UiConfig.Colors.Reject
			view.stroke.Enabled = true
			while not destroyed and view.inner.Parent ~= nil do
				local t = os.clock() - started
				if t >= duration then
					break
				end
				local falloff = 1 - t / duration
				view.inner.Position = UDim2.fromOffset(
					math.sin(t * UiConfig.ShakeFrequency) * UiConfig.ShakeAmplitudePx * falloff,
					0
				)
				task.wait()
			end
			if view.inner.Parent ~= nil then
				view.inner.Position = UDim2.new()
			end
			refresh()
		end)
	end

	-- One move from the UI. Wrong equipment slots are rejected locally with a shake (the server also checks).
	local function requestMove(from: InventoryMove.Addr, to: InventoryMove.Addr?, count: number)
		local s = stackAt(from)
		if s == nil then
			return
		end
		if to ~= nil then
			if to.kind == "equip" and not Equipment.accepts(to.slot :: string, s.id) then
				shake(views[key(to)])
				return
			end
			if to.kind == from.kind and to.slot == from.slot and to.id == from.id then
				return
			end
			lastTarget = views[key(to)]
		end
		send(from, to, math.clamp(count, 1, s.count))
	end

	local function makeSlot(
		parent: Instance,
		addr: InventoryMove.Addr,
		order: number,
		caption: string?
	): SlotView
		local button = make("TextButton", {
			Name = `Slot_{key(addr)}`,
			LayoutOrder = order,
			AutoButtonColor = false,
			BackgroundColor3 = if addr.kind == "equip"
				then UiConfig.Colors.Equip
				else UiConfig.Colors.Slot,
			BackgroundTransparency = UiConfig.SlotTransparency,
			BorderSizePixel = 0,
			Text = "",
			Size = UDim2.fromOffset(UiConfig.CellPx, UiConfig.CellPx),
			ClipsDescendants = false,
		}, parent) :: TextButton
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, button)
		local stroke = make("UIStroke", {
			Color = UiConfig.Colors.SlotSelected,
			Thickness = 2,
			Enabled = false,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, button) :: UIStroke
		local inner = make("Frame", {
			Name = "Inner",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, button) :: Frame
		local cap = label(inner, caption or "", 11, Enum.TextXAlignment.Left)
		cap.Name = "Caption"
		cap.Position = UDim2.fromOffset(3, 1)
		cap.Size = UDim2.new(1, -6, 0, 13)
		cap.TextColor3 = UiConfig.Colors.Dim
		cap.ZIndex = 3
		local I = UiConfig.IconBox
		local icon = ItemIcon.create(inner, "", UDim2.fromScale(I.W, I.H))
		icon.frame.Position = UDim2.fromScale(I.X, I.Y)
		icon.frame.ZIndex = 2
		local N = UiConfig.NameBox
		local name = label(inner, "", UiConfig.NameMaxPx, Enum.TextXAlignment.Center)
		name.Name = "Name"
		name.Font = UiConfig.NameFont
		name.TextWrapped = true
		name.TextYAlignment = Enum.TextYAlignment.Top
		name.Position = UDim2.fromScale(N.X, N.Y)
		name.Size = UDim2.fromScale(N.W, N.H)
		name.ZIndex = 3
		local C = UiConfig.CountBox
		local count = label(inner, "", 12, Enum.TextXAlignment.Right)
		count.Name = "Count"
		count.Font = Enum.Font.GothamBold
		count.TextStrokeTransparency = 0.4
		count.Position = UDim2.fromScale(C.X, C.Y)
		count.Size = UDim2.fromScale(C.W, C.H)
		count.ZIndex = 4
		local unbindName = NameFit.bind(name, UiConfig.NameMaxPx, UiConfig.NameMinPx)
		local view: SlotView = {
			addr = addr,
			button = button,
			inner = inner,
			icon = icon,
			caption = cap,
			name = name,
			count = count,
			stroke = stroke,
			base = button.BackgroundColor3,
			unbindName = unbindName,
		}
		views[key(addr)] = view
		return view
	end

	for slotId, id in Config.Equipment.Slots do
		local addr: InventoryMove.Addr = { kind = "equip", slot = id }
		local column = if slotId <= #Config.Equipment.Slots / 2 then leftCol else rightCol
		makeSlot(column, addr, slotId, Config.Equipment.SlotLabels[id])
	end
	for slot = SlotLayout.HotbarFirst, SlotLayout.HotbarLast do
		makeSlot(hotGrid, { kind = "inv", slot = slot }, slot, tostring(slot))
	end
	for cell = 1, SlotLayout.GridCells do
		local slot = SlotLayout.gridCellToSlot(cell) :: number
		makeSlot(packGrid, { kind = "inv", slot = slot }, slot, nil)
	end
	for slot = SlotLayout.ChestFirst, SlotLayout.ChestLast do
		makeSlot(chestGrid, { kind = "chest", id = "", slot = slot }, slot, nil)
	end

	local function chestAddr(slot: number): InventoryMove.Addr
		return { kind = "chest", id = if chestInfo then chestInfo.id else "", slot = slot }
	end

	-- Whether a held stack could be dropped into this slot (equipment slots only take their gear).
	local function canReceive(addr: InventoryMove.Addr, held: Stack): boolean
		if addr.kind == "equip" then
			return Equipment.accepts(addr.slot :: string, held.id)
		elseif addr.kind == "chest" then
			return chestInfo ~= nil
		end
		return true
	end

	-- The inventory slot a Drop acts on: the picked-up stack, else the last clicked slot.
	local function dropTarget(): (InventoryMove.Addr?, number)
		local addr = if selection then selection.addr else focus
		if addr == nil or addr.kind ~= "inv" then
			return nil, 0
		end
		local s = stackAt(addr)
		if s == nil then
			return nil, 0
		end
		return addr, if selection then math.min(selection.count, s.count) else s.count
	end

	refresh = function()
		local selectedHot = mirror.selectedSlot()
		local heldAddr = if dragOrigin then dragOrigin elseif selection then selection.addr else nil
		local heldStack = if heldAddr then stackAt(heldAddr) else nil
		for _, view in views do
			local addr = view.addr
			if addr.kind == "chest" then
				addr = chestAddr(addr.slot :: number)
				view.addr = addr
			end
			local stack = stackAt(addr)
			local v = SlotViewModel.view(stack)
			view.name.Text = v.name
			view.count.Text = v.countText
			view.icon.setItem(if stack then stack.id else nil)
			view.caption.Visible = not v.occupied or #view.caption.Text <= UiConfig.CaptionMaxChars
			local rarityColor: Color3? = nil
			if v.occupied and v.rarity ~= "common" then
				local c = Rarity.Colors[v.rarity]
				if c then
					rarityColor = Color3.fromRGB(c[1], c[2], c[3])
				end
			end
			local style: typeof(HL.Held)? = nil
			if sameAddr(addr, heldAddr) then
				style = HL.Held
			elseif heldStack ~= nil and canReceive(addr, heldStack) then
				style = if view == hoverView and dragOrigin ~= nil then HL.Hover else HL.Target
			elseif sameAddr(addr, focus) then
				style = HL.Focus
			end
			view.button.BackgroundColor3 = if style then rgb(style.Tint) else view.base
			view.stroke.Thickness = if style then style.Thickness else 2
			if style then
				view.stroke.Color = rgb(style.Stroke)
				view.stroke.Enabled = true
			elseif addr.kind == "inv" and addr.slot == selectedHot then
				view.stroke.Color = UiConfig.Colors.Hotbar
				view.stroke.Enabled = true
			elseif rarityColor then
				view.stroke.Color = rarityColor
				view.stroke.Enabled = true
			else
				view.stroke.Enabled = false
			end
		end
		local button = dropButton
		if button then
			local target = dropTarget()
			button.BackgroundTransparency = if target then 0 else 0.7
			button.TextTransparency = if target then 0 else 0.5
		end
		updateTip()
	end

	-- Layout: the panel hangs below the top bar; header row (title | Drop | X), scrolling body, detail footer.
	-- Wide screens put equipment | backpack | chest in one row, narrow ones stack them (columns shrink but cells
	-- stay >= UiConfig.MinCellPx). Header math is BackpackLayout (headless-tested at phone and PC widths).
	local function relayout()
		local guiSize = gui.AbsoluteSize
		local camera = Workspace.CurrentCamera
		local fallback = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local guiW = if guiSize.X > 0 then guiSize.X else fallback.X
		local guiH = if guiSize.Y > 0 then guiSize.Y else fallback.Y
		local rect = BackpackLayout.panel(
			guiW,
			guiH,
			UiConfig.PanelWidthScale,
			UiConfig.PanelMaxWidth,
			UiConfig.PanelMaxHeight,
			UiConfig.PanelTopMarginPx,
			UiConfig.PanelBottomMarginPx
		)
		panel.Size = UDim2.fromOffset(rect.w, rect.h)
		panel.Position = UDim2.new(0.5, 0, 0, rect.y)
		local header = BackpackLayout.header(rect.w, {
			pad = UiConfig.PadPx,
			gap = UiConfig.HeaderGapPx,
			button = UiConfig.CloseButtonPx,
			dropWidth = HL.DropButtonWidthPx,
			topInset = UiConfig.HeaderTopPx,
		})
		title.Position = UDim2.fromOffset(header.title.x, header.title.y)
		title.Size = UDim2.fromOffset(header.title.w, header.title.h)
		local drop = dropButton :: TextButton
		drop.Position = UDim2.fromOffset(header.drop.x, header.drop.y)
		drop.Size = UDim2.fromOffset(header.drop.w, header.drop.h)
		closeButton.Position = UDim2.fromOffset(header.close.x, header.close.y)
		closeButton.Size = UDim2.fromOffset(header.close.w, header.close.h)
		local footerH = UiConfig.TooltipPx
		local bodyH = rect.h - header.height - footerH - UiConfig.PadPx * 2
		body.Position = UDim2.fromOffset(UiConfig.PadPx, header.height)
		body.Size = UDim2.fromOffset(rect.w - UiConfig.PadPx * 2, math.max(bodyH, 0))
		footer.Position = UDim2.fromOffset(UiConfig.PadPx, rect.h - UiConfig.PadPx - footerH)
		footer.Size = UDim2.fromOffset(rect.w - UiConfig.PadPx * 2, footerH)
		local avail = rect.w - UiConfig.PadPx * 2 - 8
		local gap = UiConfig.GapPx
		local cell = UiConfig.CellPx
		local columns = Config.Inventory.Columns
		local equipW = 2 * (cell + gap) + UiConfig.ViewportWidthPx + gap * 4
		local packW = columns * (cell + gap)
		local chestOpen = chestInfo ~= nil
		local chestW = UiConfig.WideChestColumns * (cell + gap)
		local wideNeeded = equipW + packW + gap * 4 + (if chestOpen then chestW + gap * 2 else 0)
		local wide = wideNeeded <= avail
		flow.FillDirection = if wide
			then Enum.FillDirection.Horizontal
			else Enum.FillDirection.Vertical
		local chestColumns = UiConfig.WideChestColumns
		if not wide then
			if columns * (cell + gap) > avail then
				cell = UiConfig.MinCellPx
				columns = math.max(4, math.floor(avail / (cell + gap)))
			end
			chestColumns = math.min(columns, Config.Storage.ChestSlots)
		end
		for _, layout in gridLayouts do
			layout.CellSize = UDim2.fromOffset(cell, cell)
			layout.FillDirectionMaxCells = if layout == chestLayout then chestColumns else columns
		end
		for _, view in views do
			view.button.Size = UDim2.fromOffset(cell, cell)
		end
	end

	local function endGhost()
		if ghostIcon then
			ghostIcon.destroy()
			ghostIcon = nil
		end
		if ghost then
			ghost:Destroy()
			ghost = nil
		end
	end

	-- Drops every transient interaction (drag, held pick, focus, hover). Used when the panel closes, the window
	-- loses focus or a drag ends somewhere invalid: nothing was sent, so the item stays in its origin slot.
	local function cancelInteraction()
		press = nil
		selection = nil
		focus = nil
		dragOrigin = nil
		hoverView = nil
		endGhost()
	end

	-- Explicit Drop of the held/focused inventory stack. The only path that removes items from the inventory.
	local function dropSelected()
		local addr, count = dropTarget()
		if addr == nil or count < 1 then
			return
		end
		local payload: Remotes.DropItemPayload = { slot = addr.slot :: number, count = count }
		Remotes.event(Remotes.DropItemRequest):FireServer(payload)
		selection = nil
		focus = nil
		refresh()
	end

	-- While open, the Drop key (G) is sunk so nothing else reacts to it.
	local function bindDrop()
		ContextActionService:BindActionAtPriority(
			DROP_ACTION,
			function(_: string, state: Enum.UserInputState, _input: InputObject)
				if InputGuard.blocked(false) then
					return Enum.ContextActionResult.Pass
				end
				if state == Enum.UserInputState.Begin then
					dropSelected()
				end
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.ContextActionPriority.High.Value,
			(Enum.KeyCode :: any)[HL.DropKeyName] :: Enum.KeyCode
		)
	end

	local function setOpen(open: boolean)
		if open == isOpen or destroyed then
			return
		end
		isOpen = open
		panel.Visible = open
		if open then
			bindDrop()
			relayout()
			viewport.refresh()
		else
			cancelInteraction()
			if chestInfo then
				Remotes.event(Remotes.StorageCloseRequest):FireServer()
				chestInfo = nil
				chestSection.Visible = false
			end
		end
		if not open then
			ContextActionService:UnbindAction(DROP_ACTION)
		end
		refresh()
	end

	local function slotUnder(position: Vector2): SlotView?
		for _, object in playerGui:GetGuiObjectsAtPosition(position.X, position.Y) do
			for _, view in views do
				if
					view.button == object
					and view.button:IsDescendantOf(panel)
					and view.button.Visible
				then
					if view.addr.kind ~= "chest" or chestInfo ~= nil then
						return view
					end
				end
			end
		end
		return nil
	end

	local function beginGhost(view: SlotView, at: Vector2)
		local stack = stackAt(view.addr)
		if stack == nil then
			return
		end
		local g = make("TextLabel", {
			Name = "DragGhost",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(UiConfig.GhostPx, UiConfig.GhostPx),
			Position = UDim2.fromOffset(at.X, at.Y),
			BackgroundColor3 = UiConfig.Colors.SlotSelected,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			Text = "",
			ZIndex = 20,
		}, gui) :: TextLabel
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, g)
		local gi = ItemIcon.create(g, stack.id, UDim2.fromScale(0.9, 0.9))
		gi.frame.Position = UDim2.fromScale(0.05, 0.05)
		gi.frame.ZIndex = 21
		ghostIcon = gi
		ghost = g
	end

	-- A click or tap (no drag): quick move with shift, else select / move the selected stack here.
	local function clickSlot(view: SlotView, half: boolean, shiftHeld: boolean)
		local stack = stackAt(view.addr)
		if shiftHeld and stack and selection == nil then
			send(view.addr, nil, stack.count)
			return
		end
		local picked = selection
		if picked == nil then
			focus = view.addr
			if stack then
				local count = if half then math.ceil(stack.count / 2) else stack.count
				selection = { addr = view.addr, count = count }
			end
			refresh()
			return
		end
		selection = nil
		if sameAddr(picked.addr, view.addr) then
			focus = view.addr
			refresh()
			return
		end
		focus = nil
		requestMove(picked.addr, view.addr, if half and picked.count > 1 then 1 else picked.count)
		refresh()
	end

	local function wire(view: SlotView)
		table.insert(
			connections,
			view.button.MouseEnter:Connect(function()
				tipView = view
				updateTip()
			end)
		)
		table.insert(
			connections,
			view.button.MouseLeave:Connect(function()
				if tipView == view then
					tipView = nil
					updateTip()
				end
			end)
		)
		table.insert(
			connections,
			view.button.InputBegan:Connect(function(input: InputObject)
				local kind = input.UserInputType
				local isTouch = kind == Enum.UserInputType.Touch
				if
					kind ~= Enum.UserInputType.MouseButton1
					and kind ~= Enum.UserInputType.MouseButton2
					and not isTouch
				then
					return
				end
				local p: Press = {
					view = view,
					input = input,
					start = Vector2.new(input.Position.X, input.Position.Y),
					half = kind == Enum.UserInputType.MouseButton2,
					dragging = false,
					touch = isTouch,
				}
				press = p
				if isTouch then
					-- Long press = pick up half the stack (then tap the destination).
					task.delay(Config.Inventory.SplitHoldSeconds, function()
						if press == p and not p.dragging and selection == nil then
							local stack = stackAt(view.addr)
							if stack and stack.count > 1 then
								press = nil
								focus = view.addr
								selection = { addr = view.addr, count = math.ceil(stack.count / 2) }
								refresh()
							end
						end
					end)
				end
			end)
		)
	end
	for _, view in views do
		wire(view)
	end

	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			local p = press
			if p == nil then
				return
			end
			local moving = input.UserInputType == Enum.UserInputType.MouseMovement
				or (p.touch and input == p.input)
			if not moving then
				return
			end
			local pos = Vector2.new(input.Position.X, input.Position.Y)
			if
				not p.dragging
				and (pos - p.start).Magnitude >= UiConfig.DragThresholdPx
				and stackAt(p.view.addr)
			then
				p.dragging = true
				dragOrigin = p.view.addr
				selection = nil
				focus = p.view.addr
				beginGhost(p.view, pos)
				refresh()
			end
			if p.dragging and ghost then
				ghost.Position = UDim2.fromOffset(pos.X, pos.Y)
				local under = slotUnder(pos)
				if under ~= hoverView then
					hoverView = under
					refresh()
				end
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			local p = press
			if
				p == nil or not (input == p.input or input.UserInputType == p.input.UserInputType)
			then
				return
			end
			press = nil
			local pos = Vector2.new(input.Position.X, input.Position.Y)
			if p.dragging then
				-- Valid target: one move request. Anything else (no slot, same slot, outside the panel, wrong
				-- equipment slot) cancels: nothing is sent and the item stays where it was.
				local target = if isOpen then slotUnder(pos) else nil
				local stack = stackAt(p.view.addr)
				local origin = p.view
				cancelInteraction()
				if target and stack and target ~= origin then
					local count = if p.half then math.ceil(stack.count / 2) else stack.count
					requestMove(origin.addr, target.addr, count)
				end
				refresh()
			else
				local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
					or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
				clickSlot(p.view, p.half, shift)
			end
		end)
	)

	table.insert(
		connections,
		UserInputService.WindowFocusReleased:Connect(function()
			cancelInteraction()
			refresh()
		end)
	)

	-- B toggles the panel; never while typing in a text box.
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if
				InputGuard.blocked(processed)
				or input.UserInputType ~= Enum.UserInputType.Keyboard
			then
				return
			end
			if input.KeyCode == UiConfig.ToggleKey then
				setOpen(not isOpen)
			end
		end)
	)
	table.insert(
		connections,
		toggleButton.Activated:Connect(function()
			setOpen(not isOpen)
		end)
	)
	table.insert(
		connections,
		(dropButton :: TextButton).Activated:Connect(function()
			dropSelected()
		end)
	)
	table.insert(
		connections,
		closeButton.Activated:Connect(function()
			setOpen(false)
		end)
	)
	mirror.onChange(function()
		if isOpen then
			refresh()
		end
	end)
	table.insert(
		connections,
		gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if isOpen then
				relayout()
			end
		end)
	)

	-- Server refusals: shake the target slot (wrong slot, busy, full).
	task.spawn(function()
		local ev = Remotes.event(Remotes.InventoryMoveResult)
		if destroyed then
			return
		end
		table.insert(
			connections,
			ev.OnClientEvent:Connect(function(p: any)
				if type(p) ~= "table" or p.ok == true then
					return
				end
				if p.reason == "Full" then
					showFull()
				end
				if isOpen and p.reason ~= "Same" then
					shake(lastTarget)
				end
				lastTarget = nil
			end)
		)
		-- Pickups blocked by a full inventory arrive as a plain Notify (gather, loot, drops).
		table.insert(
			connections,
			Remotes.event(Remotes.Notify).OnClientEvent:Connect(function(_: any, text: any)
				if text == InventoryMove.FullText then
					showFull()
				end
			end)
		)
	end)

	gui.Parent = playerGui
	refresh()

	return {
		toggle = function()
			setOpen(not isOpen)
		end,
		open = function()
			setOpen(true)
		end,
		close = function()
			setOpen(false)
		end,
		isOpen = function(): boolean
			return isOpen
		end,
		debugLines = function(): { string }
			local lines: { string } = {}
			local shown: { [number]: boolean } = {}
			for cell = 1, SlotLayout.GridCells do
				local slot = SlotLayout.gridCellToSlot(cell) :: number
				local view = views[key({ kind = "inv", slot = slot })]
				local stack = mirror.slots()[slot]
				shown[slot] = true
				table.insert(
					lines,
					`grid cell {cell} reads slot {slot}: mirror={if stack
						then `{stack.id} x{stack.count}`
						else "empty"} ui="{if view then view.name.Text else "NO VIEW"}" "{if view
						then view.count.Text
						else ""}"`
				)
			end
			for slot = SlotLayout.HotbarFirst, SlotLayout.HotbarLast do
				shown[slot] = true
			end
			for slot, stack in mirror.slots() do
				if not shown[slot] then
					table.insert(
						lines,
						`WARNING: client holds {stack.id} x{stack.count} in slot {slot}, outside every displayed area`
					)
				end
			end
			return lines
		end,
		setChest = function(info: ChestInfo?)
			chestInfo = info
			chestSection.Visible = info ~= nil
			if info and not isOpen then
				setOpen(true)
			end
			if isOpen then
				relayout()
			end
			refresh()
		end,
		showFull = function()
			showFull()
		end,
		move = requestMove,
		destroy = function()
			destroyed = true
			ContextActionService:UnbindAction(DROP_ACTION)
			for _, c in connections do
				c:Disconnect()
			end
			table.clear(connections)
			endGhost()
			for _, view in views do
				view.unbindName()
				view.icon.destroy()
			end
			viewport.destroy()
			gui:Destroy()
		end,
	}
end

return BackpackPanel
