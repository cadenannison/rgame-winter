--!strict
-- Lobby side menu: Stats [T], Top days [L], Shop [B], Daily [G]. Read-only views of server-published
-- attributes (LobbyLogic.ATTR); the only intent sent is DailyClaimRequest. The menu sits mid-left,
-- clear of the thumbstick (bottom-left) and jump button (bottom-right).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local LobbyLogic = require(Shared:WaitForChild("logic"):WaitForChild("LobbyLogic"))
local LobbyConfig = require(script.Parent.LobbyConfig)
local UiKit = require(script.Parent.UiKit)
local LobbyState = require(script.Parent.LobbyState)
local MetaPanel = require(script.Parent.Parent:WaitForChild("Meta"):WaitForChild("MetaPanel"))
local InputGuard = require(script.Parent.Parent:WaitForChild("Input"):WaitForChild("InputGuard"))

local MenuPanels = {}

local ATTR = LobbyLogic.ATTR

local function numberAttr(instance: Instance, name: string): number
	local value = instance:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

-- qa (optional): filled with the real handlers for the Studio-only client QA bridge.
function MenuPanels.start(gui: ScreenGui, state: LobbyState.State, qa: { [string]: any }?): () -> ()
	local player = Players.LocalPlayer
	local cleanups: { () -> () } = {}
	local destroyed = false
	local panels: { [string]: Frame } = {}
	local fillers: { [string]: () -> () } = {}
	local announcedDaily = false

	local claimRemote = Remotes.event(Remotes.DailyClaimRequest)
	local resultRemote = Remotes.event(Remotes.DailyClaimResult)

	local menu = Instance.new("Frame")
	menu.Name = "Menu"
	menu.AnchorPoint = Vector2.new(0, 0.5)
	menu.Position = UDim2.new(0, 8, 0.45, 0)
	menu.Size = UDim2.fromOffset(LobbyConfig.MenuWidth, 4 * (LobbyConfig.MinButton + 6))
	menu.BackgroundTransparency = 1
	local menuLayout = Instance.new("UIListLayout")
	menuLayout.Padding = UDim.new(0, 6)
	menuLayout.Parent = menu
	menu.Parent = gui
	table.insert(cleanups, function()
		menu:Destroy()
	end)

	local function closeAll()
		for _, frame in panels do
			frame.Visible = false
		end
	end

	local function toggle(name: string)
		local frame = panels[name]
		if not frame or not state.isLobby() then
			return
		end
		local show = not frame.Visible
		closeAll()
		if show then
			local fill = fillers[name]
			if fill then
				fill()
			end
		end
		frame.Visible = show
	end

	-- Builds a modal panel with a title, close button and a scrolling body.
	local function makePanel(name: string, titleText: string): ScrollingFrame
		local frame = UiKit.panel(gui, name, LobbyConfig.PanelMaxSize, Vector2.new(0.7, 0.7))
		panels[name] = frame
		local head =
			UiKit.label(frame, "Title", titleText, UDim2.new(1, -LobbyConfig.MinButton - 8, 0, 30))
		head.Font = Enum.Font.GothamBold
		local close = UiKit.button(
			frame,
			"Close",
			"X",
			UDim2.fromOffset(LobbyConfig.MinButton, LobbyConfig.MinButton)
		)
		close.AnchorPoint = Vector2.new(1, 0)
		close.Position = UDim2.fromScale(1, 0)
		close.MouseButton1Click:Connect(function()
			frame.Visible = false
		end)
		local body = Instance.new("ScrollingFrame")
		body.Name = "Body"
		body.Position = UDim2.fromOffset(0, LobbyConfig.MinButton + 6)
		body.Size = UDim2.new(1, 0, 1, -(LobbyConfig.MinButton + 6))
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
		table.insert(cleanups, function()
			frame:Destroy()
		end)
		return body
	end

	local function clearBody(body: ScrollingFrame)
		for _, child in body:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function addRow(
		body: ScrollingFrame,
		text: string,
		order: number,
		color: Color3?
	): TextLabel
		local rowLabel = UiKit.label(body, `Row{order}`, text, UDim2.new(1, -8, 0, 26))
		rowLabel.LayoutOrder = order
		if color then
			rowLabel.TextColor3 = color
		end
		return rowLabel
	end

	local menuButtons: { [string]: TextButton } = {}
	local function addMenuButton(name: string, text: string)
		local button = UiKit.button(menu, name, text, UDim2.new(1, 0, 0, LobbyConfig.MinButton))
		button.MouseButton1Click:Connect(function()
			if name == "Daily" then
				return
			end
			if name == "Shop" then
				closeAll()
				MetaPanel.toggle()
				return
			end
			MetaPanel.close()
			toggle(name)
		end)
		menuButtons[name] = button
	end

	-- Stats
	local statsBody = makePanel("Stats", "Your stats")
	fillers.Stats = function()
		clearBody(statsBody)
		local order = 0
		local function row(text: string, color: Color3?)
			order += 1
			addRow(statsBody, text, order, color)
		end
		row(`Best run: {numberAttr(player, ATTR.MaxDays)} days`)
		row(`Runs: {numberAttr(player, ATTR.Runs)}`)
		row(
			`Kills: {numberAttr(player, ATTR.Kills)}   Bosses: {numberAttr(player, ATTR.BossKills)}`
		)
		row(`Items crafted: {numberAttr(player, ATTR.Crafted)}`)
		row(`Coins: {numberAttr(player, ATTR.Coins)}`)
		row("Achievements", LobbyConfig.AccentColor)
		local ids = LobbyLogic.decodeAchievements(player:GetAttribute(ATTR.Achievements))
		if #ids == 0 then
			row("None yet. Survive longer to earn some.", LobbyConfig.MutedColor)
		end
		for i, id in ids do
			if i > LobbyConfig.MaxAchievementsShown then
				break
			end
			row(`* {LobbyLogic.achievementTitle(id)}`, LobbyConfig.GoodColor)
		end
	end

	-- Leaderboard
	local boardBody = makePanel("Top", "Most days survived")
	fillers.Top = function()
		clearBody(boardBody)
		local entries = LobbyLogic.decodeBoard(Workspace:GetAttribute(ATTR.Board), 10)
		if #entries == 0 then
			addRow(boardBody, "No scores yet.", 1, LobbyConfig.MutedColor)
		end
		for i, entry in entries do
			local mine = entry.name == player.Name
			addRow(
				boardBody,
				`{i}. {entry.name}  -  {entry.score} days`,
				i,
				if mine then LobbyConfig.GoodColor else nil
			)
		end
	end

	addMenuButton("Stats", "Stats [T]")
	addMenuButton("Top", "Top [L]")
	addMenuButton("Shop", "Shop [B]")
	addMenuButton("Daily", "Daily [G]")

	-- Daily reward (UTC day). The server enforces; this only enables/greys the button.
	local dailyButton = menuButtons.Daily
	local function dailyReady(): boolean
		return LobbyLogic.canClaimDaily(numberAttr(player, ATTR.LastDailyClaim), os.time())
	end
	local function refreshDaily()
		if destroyed then
			return
		end
		local ready = dailyReady()
		dailyButton.Text = if ready then "Daily [G]!" else "Daily [G]"
		dailyButton.BackgroundColor3 = if ready
			then LobbyConfig.GoodColor
			else LobbyConfig.ButtonColor
		menu.Visible = state.isLobby()
		if not state.isLobby() then
			closeAll()
		elseif ready and not announcedDaily and player:GetAttribute(ATTR.Coins) ~= nil then
			announcedDaily = true
			state.toast(LobbyConfig.Tips.Daily)
		end
	end
	local function claimDaily()
		if not state.isLobby() then
			return
		end
		if dailyReady() then
			claimRemote:FireServer()
			state.toast("Claiming...")
		else
			local wait = LobbyLogic.nextUtcMidnight(os.time()) - os.time()
			state.toast(`Already claimed. Next reward in {LobbyLogic.formatWait(wait)}.`)
		end
	end
	dailyButton.MouseButton1Click:Connect(claimDaily)

	local resultConn = resultRemote.OnClientEvent:Connect(function(payload: unknown)
		if type(payload) ~= "table" then
			return
		end
		local data = payload :: { ok: unknown, coins: unknown, nextClaimAt: unknown }
		if data.ok == true and type(data.coins) == "number" then
			state.cue("DailyClaim")
			state.toast(`Daily reward: +{math.floor(data.coins)} coins!`)
		else
			local nextAt = if type(data.nextClaimAt) == "number" then data.nextClaimAt else nil
			local suffix = if nextAt
				then ` Next in {LobbyLogic.formatWait(nextAt - os.time())}.`
				else ""
			state.toast(`Daily reward not available.{suffix}`)
		end
	end)
	table.insert(cleanups, function()
		resultConn:Disconnect()
	end)

	local keys: { [Enum.KeyCode]: string } = {
		[LobbyConfig.Keys.Stats] = "Stats",
		[LobbyConfig.Keys.Leaderboard] = "Top",
	}
	local input = UserInputService.InputBegan:Connect(
		function(event: InputObject, processed: boolean)
			if InputGuard.blocked(processed) then
				return
			end
			local name = keys[event.KeyCode]
			if event.KeyCode == LobbyConfig.Keys.Shop then
				closeAll()
				MetaPanel.toggle()
			elseif name then
				MetaPanel.close()
				toggle(name)
			elseif event.KeyCode == LobbyConfig.Keys.Daily then
				claimDaily()
			elseif event.KeyCode == LobbyConfig.Keys.Close then
				closeAll()
				MetaPanel.close()
			end
		end
	)
	table.insert(cleanups, function()
		input:Disconnect()
	end)

	-- Hub world prompts (shop window, stats board, cosmetic mirror) open the same panels as the menu.
	local function onPrompt(prompt: ProximityPrompt)
		if not state.isLobby() then
			return
		end
		local tags = Config.Art.Hub.Tags
		if
			CollectionService:HasTag(prompt, tags.ShopPrompt)
			or CollectionService:HasTag(prompt, tags.MirrorPrompt)
		then
			closeAll()
			MetaPanel.toggle()
		elseif CollectionService:HasTag(prompt, tags.StatsPrompt) then
			MetaPanel.close()
			toggle("Stats")
		end
	end
	local promptConn = ProximityPromptService.PromptTriggered:Connect(onPrompt)
	table.insert(cleanups, function()
		promptConn:Disconnect()
	end)

	local boardConn = Workspace:GetAttributeChangedSignal(ATTR.Board):Connect(function()
		if panels.Top.Visible then
			fillers.Top()
		end
	end)
	table.insert(cleanups, function()
		boardConn:Disconnect()
	end)
	for _, name in { ATTR.Coins, ATTR.LastDailyClaim } do
		local conn = player:GetAttributeChangedSignal(name):Connect(refreshDaily)
		table.insert(cleanups, function()
			conn:Disconnect()
		end)
	end

	task.spawn(function()
		while not destroyed do
			refreshDaily()
			task.wait(LobbyConfig.TimerStepSeconds * 4)
		end
	end)
	refreshDaily()

	if qa then
		qa.claimDaily = claimDaily
		qa.dailyReady = dailyReady
		qa.triggerPrompt = onPrompt
		qa.panelOpen = function(name: string): boolean
			local frame = panels[name] :: Frame?
			return frame ~= nil and frame.Visible
		end
	end
	return function()
		destroyed = true
		for _, fn in cleanups do
			fn()
		end
		table.clear(cleanups)
	end
end

return MenuPanels
