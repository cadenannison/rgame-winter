--!strict
-- Pad UI: a tappable billboard over every tagged pad (status + timer) and a bottom panel while the
-- local player stands on one (countdown, party list, leave, host mode toggle).
-- Input: walk onto a pad (server detects), click/tap its billboard, Q = leave, F = host mode toggle.
-- Sends intent only (PadJoinRequest / PadLeaveRequest / PadModeRequest); the server decides.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
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

local PadHud = {}

type Billboard = { gui: BillboardGui, title: TextLabel, status: TextLabel, button: TextButton }

local function findPad(pads: { LobbyLogic.Pad }, index: number): LobbyLogic.Pad?
	for _, pad in pads do
		if pad.index == index then
			return pad
		end
	end
	return nil
end

local function nameOf(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	return if player then player.DisplayName else "Player"
end

-- qa (optional): filled with the real handlers for the Studio-only client QA bridge.
function PadHud.start(gui: ScreenGui, state: LobbyState.State, qa: { [string]: any }?): () -> ()
	local player = Players.LocalPlayer
	local cleanups: { () -> () } = {}
	local destroyed = false
	local billboards: { [BasePart]: Billboard } = {}
	local joinToken = 0

	local joinRemote = Remotes.event(Remotes.PadJoinRequest)
	local leaveRemote = Remotes.event(Remotes.PadLeaveRequest)
	local modeRemote = Remotes.event(Remotes.PadModeRequest)

	-- Bottom panel (clear of the jump button bottom-right and thumbstick bottom-left).
	local panel = UiKit.panel(gui, "PadPanel", LobbyConfig.PadPanelMaxSize, Vector2.new(0.5, 0.3))
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.fromScale(0.5, 0.97)
	table.insert(cleanups, function()
		panel:Destroy()
	end)
	local title = UiKit.label(panel, "Title", "", UDim2.new(1, 0, 0, 22))
	local timerLabel = UiKit.label(panel, "Timer", "", UDim2.new(1, 0, 0, 22))
	timerLabel.Position = UDim2.fromOffset(0, 24)
	timerLabel.TextColor3 = LobbyConfig.AccentColor
	local members = UiKit.label(panel, "Members", "", UDim2.new(1, 0, 0, 44))
	members.Position = UDim2.fromOffset(0, 48)
	members.TextWrapped = true
	members.TextYAlignment = Enum.TextYAlignment.Top
	local row = Instance.new("Frame")
	row.Name = "Buttons"
	row.AnchorPoint = Vector2.new(0, 1)
	row.Position = UDim2.fromScale(0, 1)
	row.Size = UDim2.new(1, 0, 0, LobbyConfig.MinButton)
	row.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.Parent = row
	row.Parent = panel
	local leaveButton = UiKit.button(row, "Leave", "Leave [Q]", UDim2.new(0.4, -4, 1, 0))
	local modeButton = UiKit.button(row, "Mode", "", UDim2.new(0.6, -4, 1, 0))

	local function myPadIndex(): number
		local value = player:GetAttribute(Config.Lobby.PlayerPadAttribute)
		return if type(value) == "number" then value else 0
	end

	local function myPad(): LobbyLogic.Pad?
		local index = myPadIndex()
		return if index > 0 then findPad(state.pads, index) else nil
	end

	local lastSecond: number? = nil
	local function refresh()
		if destroyed then
			return
		end
		local now = Workspace:GetServerTimeNow()
		local mine = myPad()
		local inLobby = state.isLobby()
		panel.Visible = inLobby and mine ~= nil
		if mine then
			title.Text =
				`Pad {mine.index}: {LobbyLogic.padStatus(mine, Config.Lobby.PadModeFriends)}`
			local left = LobbyLogic.secondsLeft(mine.endsAt, now)
			if mine.launching then
				timerLabel.Text = "Launching..."
			elseif left ~= nil then
				timerLabel.Text = `Departing in {left}s`
				if left <= LobbyConfig.TickSeconds and left ~= lastSecond and left > 0 then
					state.play("PadTickSound")
				end
				lastSecond = left
			else
				timerLabel.Text = "Waiting for the timer"
			end
			local names: { string } = {}
			for _, id in mine.memberIds do
				table.insert(names, if id == mine.hostId then `{nameOf(id)} (host)` else nameOf(id))
			end
			members.Text = `Party: {table.concat(names, ", ")}`
			local isHost = mine.hostId == player.UserId
			local friends = mine.mode == Config.Lobby.PadModeFriends
			if isHost then
				modeButton.Text = if friends then "Friends only [F]" else "Open to all [F]"
			else
				modeButton.Text = if friends then "Friends only (host)" else "Open (host sets)"
			end
			UiKit.setEnabled(modeButton, isHost and not mine.launching)
			UiKit.setEnabled(leaveButton, not mine.launching)
		else
			lastSecond = nil
		end
		for part, board in billboards do
			local index = part:GetAttribute(Config.Lobby.PadIndexAttribute)
			local pad = if type(index) == "number" then findPad(state.pads, index) else nil
			board.gui.Enabled = inLobby and (mine == nil or mine.index ~= index)
			if type(index) == "number" then
				board.title.Text = `Pad {index} (1-{index})`
				if pad then
					local left = LobbyLogic.secondsLeft(pad.endsAt, now)
					local text = LobbyLogic.padStatus(pad, Config.Lobby.PadModeFriends)
					board.status.Text = if left ~= nil and not pad.launching
						then `{text} - {left}s`
						else text
					local ok, reason = LobbyLogic.canJoin(pad, player.UserId)
					UiKit.setEnabled(board.button, ok)
					if not ok and reason then
						board.status.Text = reason
					end
				else
					board.status.Text = "Empty"
					UiKit.setEnabled(board.button, true)
				end
			end
		end
	end

	local function requestJoin(index: number)
		joinRemote:FireServer({ padIndex = index })
		joinToken += 1
		local mine = joinToken
		task.delay(LobbyConfig.JoinConfirmSeconds, function()
			if not destroyed and joinToken == mine and myPadIndex() ~= index then
				state.toast("Could not join that pad. Try another.")
			end
		end)
	end

	local function addBillboard(part: BasePart)
		if destroyed or billboards[part] then
			return
		end
		local board = Instance.new("BillboardGui")
		board.Name = "PadBillboard"
		board.Adornee = part
		board.Size = UDim2.fromOffset(LobbyConfig.BillboardSize.X, LobbyConfig.BillboardSize.Y)
		board.StudsOffset = LobbyConfig.BillboardOffset
		board.MaxDistance = LobbyConfig.BillboardMaxDistance
		board.AlwaysOnTop = true
		board.ResetOnSpawn = false
		local text = UiKit.label(board, "Title", "", UDim2.new(1, 0, 0, 20))
		text.TextXAlignment = Enum.TextXAlignment.Center
		local status = UiKit.label(board, "Status", "", UDim2.new(1, 0, 0, 20))
		status.Position = UDim2.fromOffset(0, 22)
		status.TextXAlignment = Enum.TextXAlignment.Center
		status.TextColor3 = LobbyConfig.MutedColor
		local button =
			UiKit.button(board, "Join", "Join", UDim2.new(1, 0, 0, LobbyConfig.MinButton))
		button.Position = UDim2.fromOffset(0, 44)
		button.MouseButton1Click:Connect(function()
			local index = part:GetAttribute(Config.Lobby.PadIndexAttribute)
			if type(index) == "number" then
				requestJoin(index)
			end
		end)
		board.Parent = gui
		billboards[part] = { gui = board, title = text, status = status, button = button }
		refresh()
	end

	local function removeBillboard(part: Instance)
		local board = billboards[part :: BasePart]
		if board then
			board.gui:Destroy()
			billboards[part :: BasePart] = nil
		end
	end

	local function requestLeave()
		leaveRemote:FireServer()
		state.play("PadLeaveSound")
	end
	leaveButton.MouseButton1Click:Connect(requestLeave)
	modeButton.MouseButton1Click:Connect(function()
		local mine = myPad()
		if mine and mine.hostId == player.UserId then
			local friends = mine.mode == Config.Lobby.PadModeFriends
			modeRemote:FireServer({
				mode = if friends then Config.Lobby.PadModeOpen else Config.Lobby.PadModeFriends,
			})
		end
	end)

	local input = UserInputService.InputBegan:Connect(
		function(event: InputObject, processed: boolean)
			if processed or not panel.Visible then
				return
			end
			if event.KeyCode == LobbyConfig.Keys.Leave then
				requestLeave()
			elseif event.KeyCode == LobbyConfig.Keys.Mode then
				local mine = myPad()
				if mine and mine.hostId == player.UserId and not mine.launching then
					local friends = mine.mode == Config.Lobby.PadModeFriends
					modeRemote:FireServer({
						mode = if friends
							then Config.Lobby.PadModeOpen
							else Config.Lobby.PadModeFriends,
					})
				end
			end
		end
	)
	table.insert(cleanups, function()
		input:Disconnect()
	end)

	for _, part in CollectionService:GetTagged(Config.Lobby.PadTag) do
		if part:IsA("BasePart") then
			addBillboard(part)
		end
	end
	local added = CollectionService:GetInstanceAddedSignal(Config.Lobby.PadTag)
		:Connect(function(part: Instance)
			if part:IsA("BasePart") then
				addBillboard(part)
			end
		end)
	local removed = CollectionService:GetInstanceRemovedSignal(Config.Lobby.PadTag)
		:Connect(removeBillboard)
	table.insert(cleanups, function()
		added:Disconnect()
		removed:Disconnect()
		for part in billboards do
			removeBillboard(part)
		end
	end)

	-- Join/leave feedback from the server-owned player attribute.
	local lastIndex = myPadIndex()
	local attrConn = player
		:GetAttributeChangedSignal(Config.Lobby.PlayerPadAttribute)
		:Connect(function()
			local index = myPadIndex()
			if index > 0 then
				joinToken += 1 -- a join landed: cancel any pending "could not join" toast
			end
			if index > 0 and lastIndex == 0 then
				state.play("PadJoinSound")
				state.toast(`On pad {index}. Q to leave.`)
			elseif index == 0 and lastIndex > 0 then
				state.play("PadLeaveSound")
			end
			lastIndex = index
			refresh()
		end)
	table.insert(cleanups, function()
		attrConn:Disconnect()
	end)
	table.insert(cleanups, state.subscribe(refresh))

	-- One light loop for countdown text.
	task.spawn(function()
		while not destroyed do
			refresh()
			task.wait(LobbyConfig.TimerStepSeconds)
		end
	end)

	refresh()
	if qa then
		-- Same function the pad billboard's Join button calls.
		qa.joinPad = requestJoin
		qa.leavePad = requestLeave
		qa.myPad = myPadIndex
		qa.padPanelVisible = function(): boolean
			return panel.Visible
		end
		qa.padTitle = function(): string
			return title.Text
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

return PadHud
