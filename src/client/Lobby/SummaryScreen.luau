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
local LobbyConfig = require(script.Parent.LobbyConfig)
local UiKit = require(script.Parent.UiKit)
local LobbyState = require(script.Parent.LobbyState)

local SummaryScreen = {}

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

	local joinRemote = Remotes.event(Remotes.PadJoinRequest)
	local summaryRemote = Remotes.event(Remotes.RunSummary)

	local panel = UiKit.panel(gui, "Summary", LobbyConfig.PanelMaxSize, Vector2.new(0.7, 0.75))
	panel.ZIndex = 15
	table.insert(cleanups, function()
		panel:Destroy()
	end)
	local head =
		UiKit.label(panel, "Title", "Run over", UDim2.new(1, -LobbyConfig.MinButton - 8, 0, 32))
	head.Font = Enum.Font.GothamBold
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
	body.Size = UDim2.new(1, 0, 1, -(LobbyConfig.MinButton * 2 + 18))
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
		UiKit.button(panel, "Requeue", "Queue again [R]", UDim2.new(1, 0, 0, LobbyConfig.MinButton))
	requeue.AnchorPoint = Vector2.new(0, 1)
	requeue.Position = UDim2.fromScale(0, 1)

	local function hide()
		panel.Visible = false
	end

	local function refreshRequeue()
		if not panel.Visible then
			return
		end
		if state.isLobby() then
			local padIndex = LobbyLogic.pickRequeuePad(state.pads, player.UserId)
			UiKit.setEnabled(requeue, padIndex ~= nil)
			requeue.Text = if padIndex
				then `Queue again: pad {padIndex} [R]`
				else "All pads busy - wait a moment"
		else
			local left = math.max(0, math.ceil(Config.Run.SummarySeconds - (os.clock() - shownAt)))
			UiKit.setEnabled(requeue, false)
			requeue.Text = `Back to the lobby in {left}s`
		end
	end

	local function doRequeue()
		if not panel.Visible or not state.isLobby() then
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
		local rowLabel = UiKit.label(body, `Row{order}`, text, UDim2.new(1, -8, 0, 26))
		rowLabel.LayoutOrder = order
		if color then
			rowLabel.TextColor3 = color
		end
	end

	local function show(payload: unknown)
		if type(payload) ~= "table" then
			return
		end
		local data = payload :: any
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
		panel.Visible = true
		if data.personalBest == true then
			state.cue("PersonalBest")
		else
			state.play("SummarySound")
		end
		refreshRequeue()
	end

	close.MouseButton1Click:Connect(hide)
	requeue.MouseButton1Click:Connect(doRequeue)

	local remoteConn = summaryRemote.OnClientEvent:Connect(show)
	table.insert(cleanups, function()
		remoteConn:Disconnect()
	end)
	local input = UserInputService.InputBegan:Connect(
		function(event: InputObject, processed: boolean)
			if processed or not panel.Visible then
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
	table.insert(cleanups, state.subscribe(refreshRequeue))

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
			refreshRequeue()
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
