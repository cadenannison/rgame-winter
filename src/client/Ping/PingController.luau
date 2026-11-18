--!strict
-- Ping wheel and markers. PC: Q opens a wheel of Config.Ping.Kinds; tap/click a kind to ping where the cursor
-- pointed when it opened. Mobile: the Ping button opens the same wheel and aims at the screen centre.
-- The server clamps range, rate and the per-player cap, then broadcasts to the party; markers here are
-- client-local billboards that expire on the server's clock. Display and intent only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local HudConfig = require(script.Parent.Parent:WaitForChild("HUD"):WaitForChild("HudConfig"))
local Toast = require(script.Parent.Parent:WaitForChild("HUD"):WaitForChild("Toast"))
local Feedback = require(script.Parent.Parent:WaitForChild("HUD"):WaitForChild("Feedback"))
local InputGuard = require(script.Parent.Parent:WaitForChild("Input"):WaitForChild("InputGuard"))

local P = HudConfig.Progression.Ping
local DISTANCE_REFRESH = 0.25 -- seconds between marker distance/expiry sweeps

export type Controller = {
	openWheel: () -> (),
	send: (string) -> (),
	openWheelAt: (Vector3?) -> (),
	destroy: () -> (),
}

type Marker = {
	gui: BillboardGui,
	anchor: Attachment,
	expiresAt: number,
	label: TextLabel,
	base: string,
	position: Vector3,
}

local PingController = {}

function PingController.start(report: (string) -> ()): Controller
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local connections: { RBXScriptConnection } = {}
	local markers: { Marker } = {}
	local destroyed = false
	local aimPoint: Vector3? = nil
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	local gui = Instance.new("ScreenGui")
	gui.Name = "PingUi"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = HudConfig.DisplayOrder + 1
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local wheel = Instance.new("Frame")
	wheel.Name = "Wheel"
	wheel.AnchorPoint = Vector2.new(0.5, 0.5)
	wheel.Position = UDim2.fromScale(0.5, 0.5)
	wheel.Size = UDim2.fromOffset(
		P.WheelRadiusPx * 2 + P.WheelButtonSize,
		P.WheelRadiusPx * 2 + P.WheelButtonSize
	)
	wheel.BackgroundTransparency = 1
	wheel.Visible = false
	wheel.Parent = gui

	local function aim(): Vector3?
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return nil
		end
		local at = if touchOnly
			then camera.ViewportSize / 2
			else UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(at.X, at.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = if player.Character then { player.Character } else {}
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * P.AimMaxDistance, params)
		return if hit then hit.Position else nil
	end

	local function setWheel(open: boolean)
		wheel.Visible = open
		if open then
			aimPoint = aim()
		end
	end

	local function send(kind: string)
		setWheel(false)
		local point = aimPoint
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if point == nil or not (root and root:IsA("BasePart")) then
			Toast.show("Aim at something to ping it")
			Feedback.sound("DenySound", nil)
			return
		end
		if (point - root.Position).Magnitude > Config.Ping.MaxRange then
			Toast.show("Too far away to ping")
			Feedback.sound("DenySound", nil)
			return
		end
		report("pinged")
		Remotes.event(Remotes.PingRequest):FireServer({ kind = kind, position = point })
	end

	local kinds = Config.Ping.Kinds
	for i, kind in kinds do
		local angle = (i - 1) / #kinds * math.pi * 2 - math.pi / 2
		local b = Instance.new("TextButton")
		b.Name = kind
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.new(
			0.5,
			math.cos(angle) * P.WheelRadiusPx,
			0.5,
			math.sin(angle) * P.WheelRadiusPx
		)
		b.Size = UDim2.fromOffset(P.WheelButtonSize, P.WheelButtonSize)
		b.BackgroundColor3 = P.Colors[kind] or HudConfig.AccentColor
		b.BackgroundTransparency = 0.15
		b.BorderSizePixel = 0
		b.Text = P.Labels[kind] or kind
		b.TextColor3 = HudConfig.PanelColor
		b.TextScaled = true
		b.Font = Enum.Font.GothamBold
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = b
		local tc = Instance.new("UITextSizeConstraint")
		tc.MaxTextSize = 18
		tc.MinTextSize = 10
		tc.Parent = b
		table.insert(
			connections,
			b.Activated:Connect(function()
				send(kind)
			end)
		)
		b.Parent = wheel
	end

	-- Mobile button (also visible on touch laptops); PC uses the key.
	if UserInputService.TouchEnabled then
		local button = Instance.new("TextButton")
		button.Name = "PingButton"
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = P.ButtonPosition
		button.Size = UDim2.fromOffset(P.ButtonSize, P.ButtonSize)
		button.BackgroundColor3 = HudConfig.AccentColor
		button.BackgroundTransparency = 0.25
		button.BorderSizePixel = 0
		button.Text = "Ping"
		button.TextColor3 = HudConfig.PanelColor
		button.TextScaled = true
		button.Font = Enum.Font.GothamBold
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = button
		local tc = Instance.new("UITextSizeConstraint")
		tc.MaxTextSize = 18
		tc.MinTextSize = 10
		tc.Parent = button
		table.insert(
			connections,
			button.Activated:Connect(function()
				setWheel(not wheel.Visible)
			end)
		)
		button.Parent = gui
	end

	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if InputGuard.blocked(processed) then
				return
			end
			if input.KeyCode == P.Key then
				setWheel(not wheel.Visible)
			elseif input.KeyCode == Enum.KeyCode.Escape and wheel.Visible then
				setWheel(false)
			end
		end)
	)

	local function removeMarker(m: Marker)
		m.gui:Destroy()
		m.anchor:Destroy()
		local i = table.find(markers, m)
		if i then
			table.remove(markers, i)
		end
	end

	local function addMarker(p: any)
		if
			type(p) ~= "table"
			or type(p.kind) ~= "string"
			or typeof(p.position) ~= "Vector3"
			or type(p.expiresAt) ~= "number"
			or table.find(Config.Ping.Kinds, p.kind) == nil
		then
			return
		end
		while #markers >= P.MarkerMaxCount do
			removeMarker(markers[1])
		end
		local anchor = Instance.new("Attachment")
		anchor.Name = "PingAnchor"
		anchor.WorldPosition = p.position
		anchor.Parent = Workspace.Terrain
		local bb = Instance.new("BillboardGui")
		bb.Name = "PingMarker"
		bb.Size = P.MarkerSize
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.Adornee = anchor
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundColor3 = P.Colors[p.kind] or HudConfig.AccentColor
		text.BackgroundTransparency = 0.25
		text.BorderSizePixel = 0
		text.TextColor3 = HudConfig.PanelColor
		text.TextScaled = true
		text.Font = Enum.Font.GothamBold
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = text
		local tc = Instance.new("UITextSizeConstraint")
		tc.MaxTextSize = 18
		tc.MinTextSize = 8
		tc.Parent = text
		text.Parent = bb
		local from = if type(p.fromUserId) == "number"
			then Players:GetPlayerByUserId(p.fromUserId)
			else nil
		local base = `{P.Labels[p.kind] or p.kind}{if from then " - " .. from.DisplayName else ""}`
		text.Text = base
		bb.Parent = playerGui
		table.insert(markers, {
			gui = bb,
			anchor = anchor,
			expiresAt = p.expiresAt,
			label = text,
			base = base,
			position = p.position,
		})
		Feedback.sound("CraftSound", p.position)
	end

	task.spawn(function()
		local ev = Remotes.event(Remotes.PingBroadcast)
		if destroyed then
			return
		end
		table.insert(connections, ev.OnClientEvent:Connect(addMarker))
	end)

	local accumulator = 0.0
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt: number)
			accumulator += dt
			if accumulator < DISTANCE_REFRESH then
				return
			end
			accumulator = 0
			local now = Workspace:GetServerTimeNow()
			local camera = Workspace.CurrentCamera
			for i = #markers, 1, -1 do
				local m = markers[i]
				if now >= m.expiresAt then
					removeMarker(m)
				elseif camera then
					m.label.Text = `{m.base} {math.floor(
						(m.position - camera.CFrame.Position).Magnitude + 0.5
					)}`
				end
			end
		end)
	)

	gui.Parent = playerGui
	return {
		openWheel = function()
			setWheel(true)
		end,
		send = send, -- what a wheel button press calls (QA bridge)
		-- QA bridge: open the wheel as Q / the Ping button does; a script has no cursor, so it may pass the
		-- aim point (like the placement ghost's ghostAim).
		openWheelAt = function(point: Vector3?)
			setWheel(true)
			if point then
				aimPoint = point
			end
		end,
		destroy = function()
			destroyed = true
			for _, c in connections do
				c:Disconnect()
			end
			table.clear(connections)
			for i = #markers, 1, -1 do
				removeMarker(markers[i])
			end
			gui:Destroy()
		end,
	}
end

return PingController
