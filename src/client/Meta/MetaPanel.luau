--!strict
-- Lobby meta panel: Shop, Perks, Style (cosmetics), Titles, Goals (achievements). Read-only view of the
-- MetaState snapshot; the only intents sent are ids (buy, equip, Robux prompt). Opened with [B] or the
-- Shop menu button (tap). Rows have >= 44 px buttons; unavailable options are greyed with the reason.
-- Coin and Robux purchases need a second tap ("Confirm?") so a stray tap never spends.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Shop = require(Shared:WaitForChild("data"):WaitForChild("Shop"))
local Achievements = require(Shared:WaitForChild("data"):WaitForChild("Achievements"))
local Types = require(Shared:WaitForChild("data"):WaitForChild("Types"))
local LobbyConfig = require(script.Parent.Parent:WaitForChild("Lobby"):WaitForChild("LobbyConfig"))
local UiKit = require(script.Parent.Parent:WaitForChild("Lobby"):WaitForChild("UiKit"))
local MetaUiConfig = require(script.Parent.MetaUiConfig)

local MetaPanel = {}

export type Snapshot = Remotes.MetaStatePayload

local active: {
	toggle: () -> (),
	close: () -> (),
	setSnapshot: (unknown) -> (),
	purchaseResult: (unknown) -> (),
	qa: { [string]: any },
}? =
	nil

function MetaPanel.toggle()
	if active then
		active.toggle()
	end
end

function MetaPanel.close()
	if active then
		active.close()
	end
end

-- Studio QA bridge handlers (real client paths).
function MetaPanel.qa(): { [string]: any }
	return if active then active.qa else {}
end

local function stringSet(list: unknown): { [string]: boolean }
	local set: { [string]: boolean } = {}
	if type(list) == "table" then
		for _, value in list :: { unknown } do
			if type(value) == "string" then
				set[value] = true
			end
		end
	end
	return set
end

-- Returns a validated snapshot (display only); nil for a malformed payload.
local function parseSnapshot(payload: unknown): Snapshot?
	if type(payload) ~= "table" then
		return nil
	end
	local data = payload :: any
	if type(data.coins) ~= "number" or type(data.stats) ~= "table" then
		return nil
	end
	local function list(value: unknown): { string }
		local out: { string } = {}
		if type(value) == "table" then
			for _, v in value :: { unknown } do
				if type(v) == "string" then
					table.insert(out, v)
				end
			end
		end
		return out
	end
	local stats: { [string]: number } = {}
	for key, value in data.stats do
		if type(key) == "string" and type(value) == "number" then
			stats[key] = value
		end
	end
	return {
		coins = data.coins,
		stats = stats,
		achievements = list(data.achievements),
		ownedCosmetics = list(data.ownedCosmetics),
		equippedCosmetic = if type(data.equippedCosmetic) == "string"
			then data.equippedCosmetic
			else "",
		equippedPerk = if type(data.equippedPerk) == "string" then data.equippedPerk else "",
		unlockedGear = list(data.unlockedGear),
		titles = list(data.titles),
		equippedTitle = if type(data.equippedTitle) == "string" then data.equippedTitle else "",
		settings = {
			reduceScares = type(data.settings) == "table" and data.settings.reduceScares == true,
		},
		hintsSeen = list(data.hintsSeen),
	}
end

local function requirementText(req: Types.StatCondition): string
	local label = MetaUiConfig.StatLabels[req.stat] or req.stat
	return `Reach {req.atLeast} {label}`
end

local function perkText(item: Types.ShopItemDef): string
	local perk = item.perk
	if not perk then
		return ""
	end
	local label = MetaUiConfig.PerkStatLabels[perk.stat] or perk.stat
	local percent = math.floor(math.abs(perk.amount) * 100 + 0.5)
	return `{if perk.amount < 0 then "-" else "+"}{percent}% {label}`
end

-- toast(text): shows a refusal/confirm message. play(key): optional cue.
function MetaPanel.start(gui: ScreenGui, toast: (string) -> (), play: (string) -> ()): () -> ()
	local snapshot: Snapshot? = nil
	local currentTab = "Shop"
	local pendingKey: string? = nil
	local pendingToken = 0
	local destroyed = false
	local cleanups: { () -> () } = {}

	local equipCosmetic = Remotes.event(Remotes.EquipCosmeticRequest)
	local equipPerk = Remotes.event(Remotes.EquipPerkRequest)
	local equipTitle = Remotes.event(Remotes.EquipTitleRequest)
	local buyRemote = Remotes.event(Remotes.ShopBuyRequest)
	local robuxRemote = Remotes.event(Remotes.RobuxPurchaseRequest)
	local stateRequest = Remotes.event(Remotes.MetaStateRequest)

	local frame = UiKit.panel(gui, "MetaPanel", MetaUiConfig.PanelMaxSize, MetaUiConfig.PanelScale)
	local head =
		UiKit.label(frame, "Title", "Shop", UDim2.new(1, -LobbyConfig.MinButton - 8, 0, 30))
	head.Font = Enum.Font.GothamBold
	local closeButton = UiKit.button(
		frame,
		"Close",
		"X",
		UDim2.fromOffset(LobbyConfig.MinButton, LobbyConfig.MinButton)
	)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.fromScale(1, 0)

	local tabBar = Instance.new("Frame")
	tabBar.Name = "Tabs"
	tabBar.BackgroundTransparency = 1
	tabBar.Position = UDim2.fromOffset(0, LobbyConfig.MinButton + 4)
	tabBar.Size = UDim2.new(1, 0, 0, LobbyConfig.MinButton)
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 4)
	tabLayout.Parent = tabBar
	tabBar.Parent = frame

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	local bodyTop = 2 * LobbyConfig.MinButton + 12
	body.Position = UDim2.fromOffset(0, bodyTop)
	body.Size = UDim2.new(1, 0, 1, -bodyTop)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 6
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body
	body.Parent = frame

	local function clearBody()
		for _, child in body:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local order = 0
	local function addRow(
		title: string,
		sub: string,
		buttonText: string?,
		enabled: boolean,
		onClick: (() -> ())?,
		titleColor: Color3?
	)
		order += 1
		local row = Instance.new("Frame")
		row.Name = `Row{order}`
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -8, 0, MetaUiConfig.RowHeight)
		row.BackgroundColor3 = LobbyConfig.ButtonColor
		row.BackgroundTransparency = 0.7
		row.BorderSizePixel = 0
		UiKit.corner(row)
		local name =
			UiKit.label(row, "Name", title, UDim2.new(1, -MetaUiConfig.RowButtonWidth - 12, 0, 28))
		name.Position = UDim2.fromOffset(6, 4)
		if titleColor then
			name.TextColor3 = titleColor
		end
		local subtitle =
			UiKit.label(row, "Sub", sub, UDim2.new(1, -MetaUiConfig.RowButtonWidth - 12, 0, 22))
		subtitle.Position = UDim2.fromOffset(6, 32)
		subtitle.TextColor3 = LobbyConfig.MutedColor
		if buttonText then
			local button = UiKit.button(
				row,
				"Action",
				buttonText,
				UDim2.fromOffset(MetaUiConfig.RowButtonWidth, LobbyConfig.MinButton)
			)
			button.AnchorPoint = Vector2.new(1, 0.5)
			button.Position = UDim2.new(1, -4, 0.5, 0)
			UiKit.setEnabled(button, enabled)
			button.MouseButton1Click:Connect(function()
				if destroyed then
					return
				end
				if not enabled then
					if sub ~= "" then
						toast(sub)
					end
					return
				end
				if onClick then
					onClick()
				end
			end)
		end
		row.Parent = body
	end

	local render: () -> ()

	-- Two-tap confirm. Returns true on the confirming tap.
	local function confirm(key: string, label: string): boolean
		if pendingKey == key then
			pendingKey = nil
			return true
		end
		pendingKey = key
		pendingToken += 1
		local mine = pendingToken
		toast(label)
		task.delay(MetaUiConfig.ConfirmSeconds, function()
			if pendingToken == mine and not destroyed and pendingKey == key then
				pendingKey = nil
				render()
			end
		end)
		render()
		return false
	end

	local function setOf(items: { string }): { [string]: boolean }
		return stringSet(items)
	end

	local function coinAction(item: Types.ShopItemDef)
		if confirm(`buy:{item.id}`, `Tap again to buy {item.name} for {item.price} coins.`) then
			buyRemote:FireServer({ itemId = item.id })
		end
	end

	local function robuxAction(item: Types.ShopItemDef)
		if confirm(`robux:{item.id}`, `Tap again to open the Robux purchase for {item.name}.`) then
			robuxRemote:FireServer({ itemId = item.id })
		end
	end

	local function buttonLabel(key: string, text: string): string
		return if pendingKey == key then "Confirm?" else text
	end

	local function renderShop(snap: Snapshot)
		local owned = setOf(snap.ownedCosmetics)
		local gear = setOf(snap.unlockedGear)
		local function itemRow(item: Types.ShopItemDef)
			if item.category == "perk" then
				return
			end
			if item.currency == "robux" then
				local productId = (Config.Meta.ProductIds :: { [string]: number })[item.productKey or ""]
					or 0
				local isOwned = item.category == "cosmetic" and owned[item.id] == true
				local detail = if item.category == "coinPack"
					then `+{item.coins} coins (R${item.price})`
					else `{MetaUiConfig.SlotLabels[item.cosmeticSlot or ""] or "Cosmetic"} - R${item.price}`
				if isOwned then
					addRow(item.name, detail, "Owned", false, nil)
				elseif productId <= 0 then
					addRow(item.name, MetaUiConfig.RobuxSoon, "R$", false, nil)
				else
					addRow(
						item.name,
						detail,
						buttonLabel(`robux:{item.id}`, `R${item.price}`),
						true,
						function()
							robuxAction(item)
						end
					)
				end
				return
			end
			-- coins
			local isOwned = if item.category == "gear"
				then gear[item.id] == true
				else owned[item.id] == true
			local detail = if item.category == "gear"
				then `Given every run - {item.price} coins`
				else `{MetaUiConfig.SlotLabels[item.cosmeticSlot or ""] or "Cosmetic"} - {item.price} coins`
			if isOwned then
				addRow(
					item.name,
					if item.category == "gear" then "Unlocked: given each run" else detail,
					"Owned",
					false,
					nil,
					LobbyConfig.GoodColor
				)
				return
			end
			local req = item.requires
			if req and (snap.stats[req.stat] or 0) < req.atLeast then
				addRow(item.name, requirementText(req), "Locked", false, nil)
			elseif snap.coins < item.price then
				addRow(
					item.name,
					`Need {item.price - snap.coins} more coins`,
					`{item.price}`,
					false,
					nil
				)
			else
				addRow(
					item.name,
					detail,
					buttonLabel(`buy:{item.id}`, `Buy {item.price}`),
					true,
					function()
						coinAction(item)
					end
				)
			end
		end
		for _, category in { "cosmetic", "gear", "coinPack" } do
			for _, item in Shop.List do
				if item.category == category then
					itemRow(item)
				end
			end
		end
	end

	local function renderPerks(snap: Snapshot)
		addRow(
			"Run-start perk",
			"One at a time. Small bonuses; change them here in the lobby.",
			nil,
			false,
			nil,
			LobbyConfig.AccentColor
		)
		local owned = setOf(snap.ownedCosmetics)
		for _, item in Shop.List do
			if item.category == "perk" then
				local text = perkText(item)
				if owned[item.id] then
					local equipped = snap.equippedPerk == item.id
					addRow(
						item.name,
						text,
						if equipped then "Unequip" else "Equip",
						true,
						function()
							equipPerk:FireServer({ id = if equipped then "" else item.id })
						end,
						if equipped then LobbyConfig.GoodColor else nil
					)
				elseif snap.coins < item.price then
					addRow(
						item.name,
						`{text} - need {item.price - snap.coins} more coins`,
						`{item.price}`,
						false,
						nil
					)
				else
					addRow(
						item.name,
						`{text} - {item.price} coins`,
						buttonLabel(`buy:{item.id}`, `Buy {item.price}`),
						true,
						function()
							coinAction(item)
						end
					)
				end
			end
		end
	end

	local function renderCosmetics(snap: Snapshot)
		local any = false
		for _, item in Shop.List do
			if item.category == "cosmetic" and table.find(snap.ownedCosmetics, item.id) then
				any = true
				local equipped = snap.equippedCosmetic == item.id
				addRow(
					item.name,
					MetaUiConfig.SlotLabels[item.cosmeticSlot or ""] or "Cosmetic",
					if equipped then "Unequip" else "Equip",
					true,
					function()
						equipCosmetic:FireServer({ id = if equipped then "" else item.id })
					end,
					if equipped then LobbyConfig.GoodColor else nil
				)
			end
		end
		if not any then
			addRow(
				"Nothing yet",
				"Buy cosmetics in the Shop tab.",
				nil,
				false,
				nil,
				LobbyConfig.MutedColor
			)
		end
	end

	local function renderTitles(snap: Snapshot)
		local any = false
		for _, title in Achievements.Titles do
			if table.find(snap.titles, title.id) then
				any = true
				local equipped = snap.equippedTitle == title.id
				addRow(
					title.name,
					"Shown above your head",
					if equipped then "Unequip" else "Equip",
					true,
					function()
						equipTitle:FireServer({ id = if equipped then "" else title.id })
					end,
					if equipped then LobbyConfig.GoodColor else nil
				)
			end
		end
		if not any then
			addRow(
				"No titles yet",
				"Some goals award a title.",
				nil,
				false,
				nil,
				LobbyConfig.MutedColor
			)
		end
	end

	local function renderAchievements(snap: Snapshot)
		local done = setOf(snap.achievements)
		for _, def in Achievements.List do
			local have = math.min(snap.stats[def.condition.stat] or 0, def.condition.atLeast)
			if done[def.id] then
				addRow(
					def.name,
					`{def.description} (+{def.coins} coins)`,
					"Done",
					false,
					nil,
					LobbyConfig.GoodColor
				)
			else
				addRow(
					def.name,
					`{def.description} {have}/{def.condition.atLeast} (+{def.coins} coins)`,
					nil,
					false,
					nil
				)
			end
		end
	end

	local tabButtons: { [string]: TextButton } = {}
	function render()
		if destroyed then
			return
		end
		clearBody()
		order = 0
		local snap = snapshot
		head.Text = if snap then `{currentTab}  -  {math.floor(snap.coins)} coins` else currentTab
		for id, button in tabButtons do
			button.BackgroundColor3 = if id == currentTab
				then LobbyConfig.AccentColor
				else LobbyConfig.ButtonColor
		end
		if not snap then
			addRow(
				"Loading...",
				"Your account is still loading.",
				nil,
				false,
				nil,
				LobbyConfig.MutedColor
			)
			return
		end
		if currentTab == "Shop" then
			renderShop(snap)
		elseif currentTab == "Perks" then
			renderPerks(snap)
		elseif currentTab == "Cosmetics" then
			renderCosmetics(snap)
		elseif currentTab == "Titles" then
			renderTitles(snap)
		else
			renderAchievements(snap)
		end
	end

	for _, tab in MetaUiConfig.Tabs do
		local button = UiKit.button(
			tabBar,
			`Tab{tab.id}`,
			tab.label,
			UDim2.new(0.2, -4, 0, LobbyConfig.MinButton)
		)
		tabButtons[tab.id] = button
		button.MouseButton1Click:Connect(function()
			currentTab = tab.id
			pendingKey = nil
			render()
		end)
	end

	local function close()
		frame.Visible = false
		pendingKey = nil
	end
	closeButton.MouseButton1Click:Connect(close)

	local function toggle()
		if destroyed then
			return
		end
		local show = not frame.Visible
		if show then
			stateRequest:FireServer()
			render()
		end
		frame.Visible = show
	end

	local function setSnapshot(payload: unknown)
		local parsed = parseSnapshot(payload)
		if parsed then
			snapshot = parsed
			if frame.Visible then
				render()
			end
		end
	end

	local function purchaseResult(payload: unknown)
		if type(payload) ~= "table" then
			return
		end
		local data = payload :: { ok: unknown, itemId: unknown, reason: unknown }
		if data.ok == true then
			play("PurchaseSuccess")
			toast(MetaUiConfig.PurchaseOk)
		else
			play("PurchaseFailed")
			local reason = if type(data.reason) == "string" then data.reason else "failed"
			toast(MetaUiConfig.Refusals[reason] or MetaUiConfig.Refusals.failed)
		end
		pendingKey = nil
		if frame.Visible then
			render()
		end
	end

	active = {
		toggle = toggle,
		close = close,
		setSnapshot = setSnapshot,
		purchaseResult = purchaseResult,
		qa = {
			openShop = function()
				if not frame.Visible then
					toggle()
				end
			end,
			metaBuy = function(itemId: string)
				buyRemote:FireServer({ itemId = itemId })
			end,
			metaEquipCosmetic = function(id: string)
				equipCosmetic:FireServer({ id = id })
			end,
			metaSnapshot = function(): Snapshot?
				return snapshot
			end,
		},
	}
	table.insert(cleanups, function()
		active = nil
	end)
	table.insert(cleanups, function()
		destroyed = true
		frame:Destroy()
	end)
	render()
	stateRequest:FireServer()
	return function()
		for _, fn in cleanups do
			fn()
		end
		table.clear(cleanups)
	end
end

-- Remote -> panel routing (kept here so MetaClient stays small).
function MetaPanel.onState(payload: unknown)
	if active then
		active.setSnapshot(payload)
	end
end

function MetaPanel.onPurchase(payload: unknown)
	if active then
		active.purchaseResult(payload)
	end
end

return MetaPanel
