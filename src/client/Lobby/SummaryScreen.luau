--!strict
-- Run summary modal (RunSummary remote): days, kills, bosses, coins, new achievements, what got you,
-- a tip. In the lobby it offers "Queue again" (R); in a run server it counts down to the return.
-- Close with the X button or X. Read-only except PadJoinRequest.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local LobbyLogic = require(Shared:WaitForChild("logic"):WaitForChild("LobbyLogic"))
local DeathPanelState = require(Shared:WaitForChild("logic"):WaitForChild("DeathPanelState"))
local LobbyConfig = require(script.Parent.LobbyConfig)
local UiKit = require(script.Parent.UiKit)
local LobbyState = require(script.Parent.LobbyState)
local InputGuard = require(script.Parent.Parent:WaitForChild("Input"):WaitForChild("InputGuard"))

local SummaryScreen = {}

-- Run-end look: opaque dark panel, big white outlined text (readable on a phone over the snow).
local LOOK = {
	PanelColor = Color3.fromRGB(8, 11, 16),
	PanelScale = Vector2.new(0.92, 0.88),
	PanelMaxSize = Vector2.new(520, 480),
	TitleMaxText = 48,
	RowMaxText = 34,
	RowHeight = 44,
	ButtonHeight = 56, -- phone-safe big buttons
	ContentZ = 16, -- above the opaque background (panel ZIndex 15)
	StrokeThickness = 2,
	StrokeColor = Color3.new(0, 0, 0),
	TextColor = Color3.new(1, 1, 1),
	ReturnColor = Color3.fromRGB(150, 60, 50),
}

-- White-outlined text at a larger cap than the lobby labels.
local function outline(target: TextLabel | TextButton, maxText: number)
	local label: any = target -- both classes share these properties (the union type does not)
	label.TextColor3 = LOOK.TextColor
	local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
	if limit then
		limit.MaxTextSize = maxText
	end
	local stroke = Instance.new("UIStroke")
	stroke.Color = LOOK.StrokeColor
	stroke.Thickness = LOOK.StrokeThickness
	stroke.Parent = label
end

local MAX_TEXT = 60 -- cap on server-provided strings

local function cleanText(value: unknown): string?
	if type(value) ~= "string" or value == "" then
		return nil
	end
	return string.sub(value, 1, MAX_TEXT)
end

local function countOf(value: unknown): number
	return if type(value) == "number" and value == value then math.max(0, math.floor(value)) else 0
end

-- qa (optional): filled with the real handlers for the Studio-only client QA bridge.
function SummaryScreen.start(
	gui: ScreenGui,
	state: LobbyState.State,
	qa: { [string]: any }?
): () -> ()
	local player = Players.LocalPlayer
	local cleanups: { () -> () } = {}
	local destroyed = false
	local shownAt = 0
	local hasSummary = false -- real RunSummary data received (an empty payload never shows the panel)
	local runEnded = false
	local dismissed = false
	local D = Config.Downed

	local joinRemote = Remotes.event(Remotes.PadJoinRequest)
	local summaryRemote = Remotes.event(Remotes.RunSummary)

	local panel = UiKit.panel(gui, "Summary", LOOK.PanelMaxSize, LOOK.PanelScale)
	panel.ZIndex = 15
	panel.BackgroundColor3 = LOOK.PanelColor
	panel.BackgroundTransparency = 0
	table.insert(cleanups, function()
		panel:Destroy()
	end)
	local head =
		UiKit.label(panel, "Title", "Run over", UDim2.new(1, -LobbyConfig.MinButton - 8, 0, 40))
	head.Font = Enum.Font.GothamBold
	outline(head, LOOK.TitleMaxText)
	local close = UiKit.button(
		panel,
		"Close",
		"X",
		UDim2.fromOffset(LobbyConfig.MinButton, LobbyConfig.MinButton)
	)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(0, LobbyConfig.MinButton + 6)
	body.Size = UDim2.new(1, 0, 1, -(LobbyConfig.MinButton + LOOK.ButtonHeight + 18))
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 6
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.Parent = body
	body.Parent = panel
	local requeue =
		UiKit.button(panel, "Requeue", "Queue again [R]", UDim2.new(1, 0, 0, LOOK.ButtonHeight))
	requeue.AnchorPoint = Vector2.new(0, 1)
	requeue.Position = UDim2.fromScale(0, 1)
	outline(requeue, LOOK.RowMaxText)
	-- Run server: "Play again" (= back to the lobby, then queue) and "Return to lobby" side by side.
	local returnButton = UiKit.button(
		panel,
		"ReturnToLobby",
		"Return to lobby",
		UDim2.new(0.5, -4, 0, LOOK.ButtonHeight)
	)
	returnButton.AnchorPoint = Vector2.new(1, 1)
	returnButton.Position = UDim2.fromScale(1, 1)
	returnButton.BackgroundColor3 = LOOK.ReturnColor
	returnButton.Visible = false
	outline(returnButton, LOOK.RowMaxText)
	for _, child in panel:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex = LOOK.ContentZ -- content always above the opaque background
		end
	end
	local returnRemote: RemoteEvent? = nil
	local function requestReturn()
		if state.isLobby() or not panel.Visible then
			return
		end
		returnButton.Text = "Returning..."
		if not returnRemote then
			returnRemote = Remotes.event(Remotes.ReturnToLobbyRequest)
		end
		if returnRemote then
			returnRemote:FireServer()
		end
		state.toast("Returning to the lobby...")
	end

	local refreshRequeue: () -> ()

	-- Visibility comes only from authoritative state (alive/downed/dead attributes, run ended, real data).
	local function applyVisibility()
		local view = DeathPanelState.resolve({
			downed = player:GetAttribute(D.StateAttribute) == true,
			dead = player:GetAttribute(D.DeadAttribute) == true,
			runEnded = runEnded,
			hasSummary = hasSummary,
			inLobby = state.isLobby(),
			dismissed = dismissed,
		})
		local show = view.mode == "summary"
		panel.Visible = show
		panel.Active = show -- a hidden panel never swallows input
		if show then
			refreshRequeue()
		end
	end

	local function hide()
		dismissed = true
		applyVisibility()
	end

	function refreshRequeue()
		if not panel.Visible then
			return
		end
		if state.isLobby() then
			local padIndex = LobbyLogic.pickRequeuePad(state.pads, player.UserId)
			UiKit.setEnabled(requeue, padIndex ~= nil)
			requeue.Text = if padIndex
				then `Queue again: pad {padIndex} [R]`
				else "All pads busy - wait a moment"
			returnButton.Visible = false
			requeue.Size = UDim2.new(1, 0, 0, LOOK.ButtonHeight)
		else
			local left = math.max(0, math.ceil(Config.Run.SummarySeconds - (os.clock() - shownAt)))
			UiKit.setEnabled(requeue, true)
			requeue.Text = `Play again ({left}s)`
			requeue.Size = UDim2.new(0.5, -4, 0, LOOK.ButtonHeight)
			returnButton.Visible = true
		end
	end

	local function doRequeue()
		if not panel.Visible then
			return
		end
		if not state.isLobby() then
			requestReturn() -- run server: Play again = back to the lobby pads
			return
		end
		local padIndex = LobbyLogic.pickRequeuePad(state.pads, player.UserId)
		if padIndex == nil then
			state.toast("All pads are busy. Try again in a moment.")
			return
		end
		joinRemote:FireServer({ padIndex = padIndex })
		state.toast(`Joining pad {padIndex}...`)
		hide()
	end

	local function addRow(text: string, order: number, color: Color3?)
		local rowLabel = UiKit.label(body, `Row{order}`, text, UDim2.new(1, -8, 0, LOOK.RowHeight))
		rowLabel.LayoutOrder = order
		rowLabel.ZIndex = LOOK.ContentZ
		outline(rowLabel, LOOK.RowMaxText)
		if color then
			rowLabel.TextColor3 = color
		end
	end

	local function show(payload: unknown)
		if type(payload) ~= "table" then
			return
		end
		local data = payload :: any
		if type(data.daysSurvived) ~= "number" then
			return -- no real summary data: never show an empty opaque panel
		end
		hasSummary = true
		returnButton.Text = "Return to lobby"
		runEnded = true
		dismissed = false
		for _, child in body:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local order = 0
		local function row(text: string, color: Color3?)
			order += 1
			addRow(text, order, color)
		end
		local cause = cleanText(data.cause)
		head.Text = if cause then "You fell" else "Run complete"
		row(`Days survived: {countOf(data.daysSurvived)}`)
		if data.personalBest == true then
			row("New personal best!", LobbyConfig.GoodColor)
		end
		local previousBest = countOf(data.previousBest)
		if data.personalBest ~= true and previousBest > 0 then
			local gap = previousBest - countOf(data.daysSurvived)
			row(
				if gap > 0
					then `{gap} days short of your record ({previousBest})`
					else `Your record: {previousBest} days`,
				LobbyConfig.MutedColor
			)
		end
		row(`Kills: {countOf(data.kills)}   Bosses: {countOf(data.bossKills)}`)
		row(`Coins earned: +{countOf(data.coinsEarned)}`, LobbyConfig.AccentColor)
		if cause then
			row(`What got you: {cause}`)
		end
		if type(data.newAchievements) == "table" then
			local count = 0
			for _, id in data.newAchievements do
				local text = cleanText(id)
				if text and count < LobbyConfig.MaxAchievementsShown then
					count += 1
					row(`Achievement: {LobbyLogic.achievementTitle(text)}`, LobbyConfig.GoodColor)
				end
			end
		end
		local tip = cleanText(data.tip)
		if tip then
			row(`Tip: {tip}`, LobbyConfig.MutedColor)
		end
		shownAt = os.clock()
		applyVisibility()
		if data.personalBest == true then
			state.cue("PersonalBest")
		else
			state.play("SummarySound")
		end
	end

	close.MouseButton1Click:Connect(hide)
	requeue.MouseButton1Click:Connect(doRequeue)
	returnButton.MouseButton1Click:Connect(requestReturn)

	local remoteConn = summaryRemote.OnClientEvent:Connect(show)
	table.insert(cleanups, function()
		remoteConn:Disconnect()
	end)
	local input = UserInputService.InputBegan:Connect(
		function(event: InputObject, processed: boolean)
			if InputGuard.blocked(processed) or not panel.Visible then
				return
			end
			if event.KeyCode == LobbyConfig.Keys.Requeue then
				doRequeue()
			elseif event.KeyCode == LobbyConfig.Keys.Close then
				hide()
			end
		end
	)
	table.insert(cleanups, function()
		input:Disconnect()
	end)
	table.insert(cleanups, state.subscribe(applyVisibility))
	-- Re-evaluate on every authoritative change: attributes, CharacterAdded (respawn, debug respawn).
	for _, attribute in { D.StateAttribute, D.DeadAttribute } do
		local changed = player:GetAttributeChangedSignal(attribute):Connect(applyVisibility)
		table.insert(cleanups, function()
			changed:Disconnect()
		end)
	end
	local charAdded = player.CharacterAdded:Connect(applyVisibility)
	table.insert(cleanups, function()
		charAdded:Disconnect()
	end)

	if qa then
		qa.requeue = doRequeue -- same function as the button and R
		qa.summary = function(): { [string]: any }
			return {
				visible = panel.Visible,
				title = head.Text,
				requeueText = requeue.Text,
				requeueEnabled = requeue.Active,
			}
		end
	end
	task.spawn(function()
		while not destroyed do
			applyVisibility()
			task.wait(LobbyConfig.TimerStepSeconds * 2)
		end
	end)
	return function()
		destroyed = true
		for _, fn in cleanups do
			fn()
		end
		table.clear(cleanups)
	end
end

return SummaryScreen
