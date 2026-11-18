--!strict
-- Shared chest panel. Opened by StructureInteract (StorageOpenRequest); the server answers with StorageState
-- (the chest and its slots) and closes it again when the player walks away. Tap or click a chest item to
-- take its stack, a backpack item to store its stack. All slot buttons are at least HudConfig CellPx (52).
-- Display and intent only: the server validates range, capacity and counts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ItemCatalog = require(Shared:WaitForChild("ItemCatalog"))
local HudConfig = require(script.Parent.Parent:WaitForChild("HUD"):WaitForChild("HudConfig"))
local InventoryMirror = require(script.Parent:WaitForChild("InventoryMirror"))

local S = HudConfig.Progression.Storage

export type Controller = { isOpen: () -> boolean, close: () -> (), destroy: () -> () }

local StorageController = {}

local function style(label: any, text: string, size: number)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = HudConfig.TextColor
	label.Font = Enum.Font.GothamMedium
	label.TextSize = size
end

function StorageController.start(mirror: InventoryMirror.Mirror, report: (string) -> ()): Controller
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local destroyed = false
	local openChest: Instance? = nil
	local chestSlots: { [number]: { id: string, count: number } } = {}
	local connections: { RBXScriptConnection } = {}

	local gui = Instance.new("ScreenGui")
	gui.Name = "StoragePanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = HudConfig.DisplayOrder + 2
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.48)
	frame.Size = UDim2.fromScale(S.PanelWidthScale, S.PanelHeightScale)
	frame.BackgroundColor3 = HudConfig.PanelColor
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(S.PanelMaxWidth, math.huge)
	limit.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	frame.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -(S.CloseButtonSize + 16), 0, S.CloseButtonSize)
	title.Position = UDim2.fromOffset(10, 4)
	title.TextXAlignment = Enum.TextXAlignment.Left
	style(title, "Shared chest", 20)
	title.Font = Enum.Font.GothamBold
	title.Parent = frame

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -6, 0, 4)
	closeButton.Size = UDim2.fromOffset(S.CloseButtonSize, S.CloseButtonSize)
	closeButton.BackgroundColor3 = HudConfig.BarColors.health
	closeButton.BorderSizePixel = 0
	closeButton.Text = "X"
	closeButton.TextColor3 = HudConfig.TextColor
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 20
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeButton
	closeButton.Parent = frame

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Scroll"
	scroll.Position = UDim2.fromOffset(8, S.CloseButtonSize + 10)
	scroll.Size = UDim2.new(1, -16, 1, -(S.CloseButtonSize + 18))
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = frame
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, S.GapPx * 2)
	list.Parent = scroll

	local function section(order: number, name: string): (TextLabel, Frame)
		local header = Instance.new("TextLabel")
		header.Name = `{name}Header`
		header.LayoutOrder = order * 2
		header.Size = UDim2.new(1, 0, 0, 22)
		header.TextXAlignment = Enum.TextXAlignment.Left
		style(header, name, 16)
		header.Parent = scroll
		local grid = Instance.new("Frame")
		grid.Name = `{name}Grid`
		grid.LayoutOrder = order * 2 + 1
		grid.Size = UDim2.fromScale(1, 0)
		grid.AutomaticSize = Enum.AutomaticSize.Y
		grid.BackgroundTransparency = 1
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.fromOffset(S.CellPx, S.CellPx)
		layout.CellPadding = UDim2.fromOffset(S.GapPx, S.GapPx)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		grid.Parent = scroll
		return header, grid
	end
	local _, chestGrid = section(1, "In the chest")
	local _, packGrid = section(2, "Your inventory (tap to store)")

	local function cell(parent: Frame, index: number, onTap: () -> ()): TextButton
		local b = Instance.new("TextButton")
		b.Name = `Slot{index}`
		b.LayoutOrder = index
		b.BackgroundColor3 = Color3.new(0, 0, 0)
		b.BackgroundTransparency = 0.45
		b.BorderSizePixel = 0
		b.AutoButtonColor = true
		b.TextColor3 = HudConfig.TextColor
		b.Font = Enum.Font.GothamMedium
		b.TextSize = 12
		b.TextWrapped = true
		b.Text = ""
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 6)
		c.Parent = b
		table.insert(connections, b.Activated:Connect(onTap))
		b.Parent = parent
		return b
	end

	local function label(id: string, count: number): string
		local def = ItemCatalog.Items[id]
		local name = if def then def.name else id
		return if count > 1 then `{name}\nx{count}` else name
	end

	local function send(remote: string, payload: { [string]: any })
		Remotes.event(remote):FireServer(payload)
	end

	local chestCells: { TextButton } = {}
	for i = 1, Config.Storage.ChestSlots do
		table.insert(
			chestCells,
			cell(chestGrid, i, function()
				local chest, stack = openChest, chestSlots[i]
				if chest and stack then
					send(
						Remotes.StorageWithdrawRequest,
						{ chest = chest, chestSlot = i, count = stack.count }
					)
				end
			end)
		)
	end
	local packCells: { TextButton } = {}
	for i = 1, Config.Inventory.HotbarSize + Config.Inventory.BackpackSize do
		table.insert(
			packCells,
			cell(packGrid, i, function()
				local chest, stack = openChest, mirror.slots()[i]
				if chest and stack then
					send(
						Remotes.StorageDepositRequest,
						{ chest = chest, slot = i, count = stack.count }
					)
				end
			end)
		)
	end

	local function render()
		for i, b in chestCells do
			local s = chestSlots[i]
			b.Text = if s then label(s.id, s.count) else ""
		end
		local slots = mirror.slots()
		for i, b in packCells do
			local s = slots[i]
			b.Text = if s then label(s.id, s.count) else ""
		end
	end

	local function setOpen(chest: Instance?)
		openChest = chest
		gui.Enabled = chest ~= nil
		if chest == nil then
			table.clear(chestSlots)
		end
		render()
	end

	local function close()
		if openChest then
			Remotes.event(Remotes.StorageCloseRequest):FireServer()
		end
		setOpen(nil)
	end
	table.insert(connections, closeButton.Activated:Connect(close))
	mirror.onChange(function()
		if openChest then
			render()
		end
	end)

	task.spawn(function()
		local ev = Remotes.event(Remotes.StorageState)
		if destroyed then
			return
		end
		table.insert(
			connections,
			ev.OnClientEvent:Connect(function(p: any)
				if type(p) ~= "table" then
					return
				end
				if typeof(p.chest) ~= "Instance" then
					setOpen(nil) -- closed by the server: out of range, destroyed, or we closed it
					return
				end
				table.clear(chestSlots)
				if type(p.slots) == "table" then
					for i, s in p.slots do
						if
							type(i) == "number"
							and type(s) == "table"
							and type(s.id) == "string"
						then
							chestSlots[i] = {
								id = s.id,
								count = if type(s.count) == "number" then s.count else 1,
							}
						end
					end
				end
				if openChest == nil then
					report("chestOpened")
				end
				setOpen(p.chest)
			end)
		)
	end)

	gui.Parent = playerGui
	return {
		isOpen = function(): boolean
			return openChest ~= nil
		end,
		close = close,
		destroy = function()
			destroyed = true
			for _, c in connections do
				c:Disconnect()
			end
			table.clear(connections)
			gui:Destroy()
		end,
	}
end

return StorageController
