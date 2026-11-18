--!strict
-- Downed / revive / spectate UI (run servers). Display and intent only; the server decides everything.
--   * You are downed: banner with the revive-window countdown (Player attribute DownedBleed).
--   * A teammate is downed within reach: a Revive prompt (hold E on PC, hold the on-screen button on
--     phone/tablet). While held the client resends ReviveRequest every Downed.ReviveRefreshSeconds; letting
--     go stops the resend and the server cancels the channel. The bar shows the target's ReviveProgress.
--   * You are dead (Player attribute RunDead): you spectate living teammates (Prev/Next buttons, Z for
--     next) and a "Return to lobby" button is always shown.
-- Returns a cleanup function.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local DownedLogic = require(Shared:WaitForChild("logic"):WaitForChild("DownedLogic"))
local DeathPanelState = require(Shared:WaitForChild("logic"):WaitForChild("DeathPanelState"))
local InputGuard = require(script.Parent.Parent:WaitForChild("Input"):WaitForChild("InputGuard"))

local D = Config.Downed

local UI = {
	GuiName = "DownedUi",
	DisplayOrder = 5,
	MinButton = 48, -- px, phone-safe
	PanelColor = Color3.fromRGB(10, 14, 20),
	PanelTransparency = 0.12, -- only the run summary is fully opaque (SummaryScreen)
	TextColor = Color3.fromRGB(255, 255, 255),
	DangerColor = Color3.fromRGB(255, 120, 110),
	AccentColor = Color3.fromRGB(255, 214, 110),
	ButtonColor = Color3.fromRGB(44, 74, 104),
	BarColor = Color3.fromRGB(110, 210, 130),
	StrokeColor = Color3.new(0, 0, 0),
	StrokeThickness = 2,
	ReviveMargin = 1, -- studs inside ReviveRange the prompt stays visible (server uses the full range)
	ScanSeconds = 0.1,
	NextKey = Enum.KeyCode.Z,
	ReviveKey = Enum.KeyCode.E,
	ReviveAction = "ReviveTeammate",
	ReviveButtonSize = Vector2.new(190, 64),
}

local DownedUi = {}

local function styleText(target: TextLabel | TextButton, maxSize: number)
	local label: any = target -- both classes share these properties (the union type does not)
	label.TextColor3 = UI.TextColor
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	local stroke = Instance.new("UIStroke")
	stroke.Color = UI.StrokeColor
	stroke.Thickness = UI.StrokeThickness
	stroke.Parent = label
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = maxSize
	limit.MinTextSize = 10
	limit.Parent = label
end

local function newPanel(parent: Instance, name: string, size: UDim2, position: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = UI.PanelColor
	frame.BackgroundTransparency = UI.PanelTransparency
	frame.Active = false -- only shown panels take input (set in refresh)
	frame.BorderSizePixel = 0
	frame.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	frame.Parent = parent
	return frame
end

local function newLabel(
	parent: Instance,
	name: string,
	size: UDim2,
	position: UDim2,
	maxSize: number
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Text = ""
	styleText(label, maxSize)
	label.Parent = parent
	return label
end

local function newButton(
	parent: Instance,
	name: string,
	text: string,
	size: UDim2,
	position: UDim2
): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = UI.ButtonColor
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Text = text
	styleText(button, 22)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	local min = Instance.new("UISizeConstraint")
	min.MinSize = Vector2.new(UI.MinButton, UI.MinButton)
	min.Parent = button
	button.Parent = parent
	return button
end

local function isFlag(player: Player, attribute: string): boolean
	return player:GetAttribute(attribute) == true
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid.RootPart
end

function DownedUi.start(): () -> ()
	local localPlayer = Players.LocalPlayer
	local cleanups: { () -> () } = {}
	local destroyed = false
	local touch = UserInputService.TouchEnabled

	local gui = Instance.new("ScreenGui")
	gui.Name = UI.GuiName
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = UI.DisplayOrder
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	table.insert(cleanups, function()
		gui:Destroy()
	end)

	-- Downed banner (top centre).
	local downPanel =
		newPanel(gui, "DownBanner", UDim2.new(0.8, 0, 0, 92), UDim2.new(0.5, 0, 0, 56))
	local downSize = Instance.new("UISizeConstraint")
	downSize.MaxSize = Vector2.new(520, 120)
	downSize.Parent = downPanel
	local downTitle =
		newLabel(downPanel, "Title", UDim2.new(1, -16, 0, 44), UDim2.fromOffset(8, 6), 34)
	downTitle.TextColor3 = UI.DangerColor
	local downSub =
		newLabel(downPanel, "Sub", UDim2.new(1, -16, 0, 30), UDim2.fromOffset(8, 54), 22)

	-- Revive prompt (lower centre, clear of the Act button and the jump button).
	local revivePanel = newPanel(
		gui,
		"RevivePrompt",
		UDim2.fromOffset(UI.ReviveButtonSize.X + 20, 108),
		UDim2.fromScale(0.5, 0.55)
	)
	local reviveName =
		newLabel(revivePanel, "Name", UDim2.new(1, -12, 0, 26), UDim2.fromOffset(6, 6), 20)
	local reviveButton = newButton(
		revivePanel,
		"Hold",
		if touch then "Hold to revive" else "Revive [hold E]",
		UDim2.fromOffset(UI.ReviveButtonSize.X, UI.ReviveButtonSize.Y),
		UDim2.fromOffset(10, 36)
	)
	local barBack = Instance.new("Frame")
	barBack.Name = "Bar"
	barBack.Size = UDim2.new(1, -20, 0, 6)
	barBack.Position = UDim2.new(0, 10, 1, -10)
	barBack.BackgroundColor3 = Color3.new(0, 0, 0)
	barBack.BorderSizePixel = 0
	local barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.BackgroundColor3 = UI.BarColor
	barFill.BorderSizePixel = 0
	barFill.Parent = barBack
	barBack.Parent = revivePanel

	-- Spectator bar (bottom centre): who you watch, Prev/Next, Return to lobby (always).
	local deadPanel =
		newPanel(gui, "DeadBar", UDim2.new(0.92, 0, 0, 150), UDim2.new(0.5, 0, 1, -164))
	local deadSize = Instance.new("UISizeConstraint")
	deadSize.MaxSize = Vector2.new(560, 160)
	deadSize.Parent = deadPanel
	local deadTitle =
		newLabel(deadPanel, "Title", UDim2.new(1, -16, 0, 40), UDim2.fromOffset(8, 6), 32)
	deadTitle.TextColor3 = UI.DangerColor
	deadTitle.Text = "You died"
	local watching =
		newLabel(deadPanel, "Watching", UDim2.new(1, -16, 0, 28), UDim2.fromOffset(8, 48), 22)
	local prevButton = newButton(
		deadPanel,
		"Prev",
		"< Prev",
		UDim2.new(0.3, -8, 0, UI.MinButton),
		UDim2.new(0, 8, 1, -(UI.MinButton + 8))
	)
	local nextButton = newButton(
		deadPanel,
		"Next",
		if touch then "Next >" else "Next > [Z]",
		UDim2.new(0.3, -8, 0, UI.MinButton),
		UDim2.new(0.3, 8, 1, -(UI.MinButton + 8))
	)
	local returnButton = newButton(
		deadPanel,
		"Return",
		"Return to lobby",
		UDim2.new(0.4, -16, 0, UI.MinButton),
		UDim2.new(0.6, 8, 1, -(UI.MinButton + 8))
	)
	returnButton.BackgroundColor3 = Color3.fromRGB(150, 60, 50)

	-- State.
	local reviveTarget: Player? = nil
	local holding = false
	local lastSend = 0
	local spectated: Player? = nil
	local lastCycle = 0

	local function sendRevive()
		local target = reviveTarget
		if target and holding then
			lastSend = os.clock()
			Remotes.event(Remotes.ReviveRequest):FireServer(target)
		end
	end

	local function setHolding(on: boolean)
		if on and reviveTarget == nil then
			return
		end
		if on == holding then
			return
		end
		holding = on
		if on then
			sendRevive()
		end
	end

	-- Revive input: E (PC) is bound above the HUD's action and sunk only while a target is in reach.
	ContextActionService:BindActionAtPriority(
		UI.ReviveAction,
		function(
			_name: string,
			state: Enum.UserInputState,
			_input: InputObject
		): Enum.ContextActionResult
			if InputGuard.blocked(false) then
				return Enum.ContextActionResult.Pass
			end
			if state == Enum.UserInputState.Begin then
				if reviveTarget == nil then
					return Enum.ContextActionResult.Pass
				end
				setHolding(true)
				return Enum.ContextActionResult.Sink
			elseif state == Enum.UserInputState.End then
				if holding then
					setHolding(false)
					return Enum.ContextActionResult.Sink
				end
			end
			return Enum.ContextActionResult.Pass
		end,
		false,
		Enum.ContextActionPriority.High.Value + 1,
		UI.ReviveKey
	)
	table.insert(cleanups, function()
		ContextActionService:UnbindAction(UI.ReviveAction)
	end)
	local function bindHold(button: TextButton)
		button.InputBegan:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				setHolding(true)
			end
		end)
		button.InputEnded:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				setHolding(false)
			end
		end)
	end
	bindHold(reviveButton)

	-- Spectating: living (not dead) teammates in a stable order.
	local function spectateCandidates(): { Player }
		local list: { Player } = {}
		for _, other in Players:GetPlayers() do
			if other ~= localPlayer and not isFlag(other, D.DeadAttribute) then
				local character = other.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					table.insert(list, other)
				end
			end
		end
		table.sort(list, function(a: Player, b: Player)
			return a.UserId < b.UserId
		end)
		return list
	end

	local function cycle(dir: number, force: boolean)
		local now = os.clock()
		if not force and now - lastCycle < D.SpectateCycleInterval then
			return
		end
		lastCycle = now
		local list = spectateCandidates()
		local ids: { number } = {}
		for _, p in list do
			table.insert(ids, p.UserId)
		end
		local current = spectated
		local nextId = DownedLogic.nextSpectate(ids, if current then current.UserId else nil, dir)
		spectated = if nextId then Players:GetPlayerByUserId(nextId) else nil
	end
	prevButton.MouseButton1Click:Connect(function()
		cycle(-1, false)
	end)
	nextButton.MouseButton1Click:Connect(function()
		cycle(1, false)
	end)
	returnButton.MouseButton1Click:Connect(function()
		Remotes.event(Remotes.ReturnToLobbyRequest):FireServer()
		returnButton.Text = "Returning..."
	end)
	local keyConn = UserInputService.InputBegan:Connect(
		function(input: InputObject, processed: boolean)
			if
				not InputGuard.blocked(processed)
				and input.KeyCode == UI.NextKey
				and deadPanel.Visible
			then
				cycle(1, false)
			end
		end
	)
	table.insert(cleanups, function()
		keyConn:Disconnect()
	end)

	local function ownHumanoid(): Humanoid?
		local character = localPlayer.Character
		return character and character:FindFirstChildOfClass("Humanoid")
	end

	local function refresh()
		local meDowned = isFlag(localPlayer, D.StateAttribute)
		local meDead = isFlag(localPlayer, D.DeadAttribute)
		local me: DownedLogic.Actor = { downed = meDowned, dead = meDead }

		-- Authoritative state -> visibility (pure mapping, re-evaluated every scan, CharacterAdded and respawn).
		local panelView = DeathPanelState.resolve({
			downed = meDowned,
			dead = meDead,
			runEnded = false,
			hasSummary = false,
			inLobby = false,
			dismissed = false,
		})

		-- Own downed banner.
		downPanel.Visible = panelView.showRevive
		downPanel.Active = panelView.showRevive
		if meDowned then
			local left = localPlayer:GetAttribute(D.BleedAttribute)
			local secs = if type(left) == "number" then left else 0
			downTitle.Text = `YOU ARE DOWN  {secs}s`
			downSub.Text = "Crawl toward a teammate. They can revive you."
		end

		-- Revive prompt.
		local candidates: { DownedLogic.Candidate } = {}
		local myRoot = rootOf(localPlayer)
		if myRoot then
			for _, other in Players:GetPlayers() do
				local root = rootOf(other)
				if other ~= localPlayer and root then
					table.insert(candidates, {
						id = other.UserId,
						dist = (root.Position - myRoot.Position).Magnitude,
						downed = isFlag(other, D.StateAttribute),
						dead = isFlag(other, D.DeadAttribute),
					})
				end
			end
		end
		local pick = DownedLogic.pickReviveTarget(me, candidates, D.ReviveRange - UI.ReviveMargin)
		reviveTarget = if pick then Players:GetPlayerByUserId(pick) else nil
		local target = reviveTarget
		if target then
			revivePanel.Visible = true
			reviveName.Text = `{target.DisplayName} is down`
			local progress = target:GetAttribute(D.ReviveProgressAttribute)
			barFill.Size = UDim2.fromScale(
				if type(progress) == "number" then math.clamp(progress, 0, 1) else 0,
				1
			)
		else
			revivePanel.Visible = false
			barFill.Size = UDim2.fromScale(0, 1)
			if holding then
				holding = false
			end
		end
		if holding and target and os.clock() - lastSend >= D.ReviveRefreshSeconds then
			sendRevive()
		end

		-- Spectator mode.
		deadPanel.Visible = panelView.showSpectate
		deadPanel.Active = panelView.showSpectate
		gui.Enabled = panelView.visible or revivePanel.Visible
		if panelView.showSpectate then
			if D.SpectateOnDeath then
				local current = spectated
				local stillValid = false
				if current then
					for _, p in spectateCandidates() do
						if p == current then
							stillValid = true
							break
						end
					end
				end
				if not stillValid then
					cycle(1, true)
				end
				local view = spectated
				local humanoid = if view and view.Character
					then view.Character:FindFirstChildOfClass("Humanoid")
					else nil
				local camera = Workspace.CurrentCamera
				if view and humanoid and camera then
					watching.Text = `Spectating {view.DisplayName}`
					if camera.CameraSubject ~= humanoid then
						camera.CameraSubject = humanoid
					end
				else
					watching.Text = "Nobody left to watch"
				end
			else
				watching.Text = ""
			end
			prevButton.Visible = D.SpectateOnDeath
			nextButton.Visible = D.SpectateOnDeath
		else
			if spectated ~= nil then
				spectated = nil
				local camera = Workspace.CurrentCamera
				local own = ownHumanoid()
				if camera and own then
					camera.CameraSubject = own
				end
			end
			returnButton.Text = "Return to lobby"
		end
	end

	-- Re-evaluate immediately on every authoritative state change (not only on the scan tick).
	for _, attribute in { D.StateAttribute, D.DeadAttribute } do
		local changed = localPlayer:GetAttributeChangedSignal(attribute):Connect(refresh)
		table.insert(cleanups, function()
			changed:Disconnect()
		end)
	end
	local charAdded = localPlayer.CharacterAdded:Connect(refresh)
	table.insert(cleanups, function()
		charAdded:Disconnect()
	end)

	task.spawn(function()
		while not destroyed do
			refresh()
			task.wait(UI.ScanSeconds)
		end
	end)
	table.insert(cleanups, function()
		destroyed = true
	end)
	return function()
		for _, fn in cleanups do
			fn()
		end
		table.clear(cleanups)
	end
end

return DownedUi
