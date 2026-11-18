--!strict
-- Hub boards (art pass 1): draws live content on the tagged board faces built by HubBuilder.
--   LobbyLeaderboard  global max-days top list (Workspace attribute, server published)
--   LobbyLocalBoard   everyone in this server by max days (Player attributes)
--   LobbyStatBoard    the local player's own stats and achievements
-- Display only. SurfaceGuis are client-side instances parented to the board face; the server-built
-- "Static" title gui is hidden locally once the live one exists. One light loop redraws changed boards.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local LobbyLogic = require(Shared:WaitForChild("logic"):WaitForChild("LobbyLogic"))
local LobbyConfig = require(script.Parent.LobbyConfig)
local LobbyState = require(script.Parent.LobbyState)

local HubBoards = {}

local ATTR = LobbyLogic.ATTR
local TAGS = Config.Art.Hub.Tags
local ROW_COUNT = LobbyConfig.BoardRows
local STAT_ROWS = 12

type Row = { left: string, right: string, color: Color3? }
type Board = {
	part: BasePart,
	kind: string,
	gui: SurfaceGui,
	left: { TextLabel },
	right: { TextLabel },
	title: TextLabel,
	signature: string,
}

local function numberAttr(instance: Instance, name: string): number
	local value = instance:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

local function text(
	parent: Instance,
	name: string,
	size: UDim2,
	position: UDim2,
	font: Enum.Font,
	color: Color3,
	align: Enum.TextXAlignment
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextColor3 = color
	label.TextScaled = true
	label.TextXAlignment = align
	label.Text = ""
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 34
	limit.MinTextSize = 8
	limit.Parent = label
	label.Parent = parent
	return label
end

local function makeBoard(part: BasePart, kind: string, rows: number): Board
	local old = part:FindFirstChild("Static")
	if old and old:IsA("SurfaceGui") then
		old.Enabled = false
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Live"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = LobbyConfig.BoardPixelsPerStud
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = LobbyConfig.PanelColor
	back.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = back
	local stroke = Instance.new("UIStroke")
	stroke.Color = LobbyConfig.AccentColor
	stroke.Thickness = 4
	stroke.Transparency = 0.35
	stroke.Parent = back
	back.Parent = gui
	local title = text(
		back,
		"Title",
		UDim2.new(1, -40, 0.13, 0),
		UDim2.fromScale(0.02, 0.02),
		Enum.Font.GothamBlack,
		LobbyConfig.TextColor,
		Enum.TextXAlignment.Center
	)
	title.Text = tostring(part:GetAttribute("BoardTitle") or "")
	local list: { TextLabel } = {}
	local values: { TextLabel } = {}
	local top, span = 0.17, 0.8
	for i = 1, rows do
		local h = span / rows
		local y = top + (i - 1) * h
		list[i] = text(
			back,
			`Row{i}`,
			UDim2.fromScale(0.68, h * 0.92),
			UDim2.fromScale(0.04, y),
			Enum.Font.GothamMedium,
			LobbyConfig.TextColor,
			Enum.TextXAlignment.Left
		)
		values[i] = text(
			back,
			`Value{i}`,
			UDim2.fromScale(0.24, h * 0.92),
			UDim2.fromScale(0.72, y),
			Enum.Font.GothamBold,
			LobbyConfig.AccentColor,
			Enum.TextXAlignment.Right
		)
	end
	gui.Parent = part
	return {
		part = part,
		kind = kind,
		gui = gui,
		left = list,
		right = values,
		title = title,
		signature = "",
	}
end

local function globalRows(me: Player): { Row }
	local out: { Row } = {}
	for i, entry in LobbyLogic.decodeBoard(Workspace:GetAttribute(ATTR.Board), ROW_COUNT) do
		local mine = entry.name == me.Name
		table.insert(out, {
			left = `{i}. {entry.name}`,
			right = `{entry.score}d`,
			color = if mine then LobbyConfig.GoodColor else nil,
		})
	end
	if #out == 0 then
		table.insert(out, { left = "No scores yet", right = "", color = LobbyConfig.MutedColor })
	end
	return out
end

local function localRows(me: Player): { Row }
	local entries: { { name: string, days: number, mine: boolean } } = {}
	for _, p in Players:GetPlayers() do
		table.insert(
			entries,
			{ name = p.DisplayName, days = numberAttr(p, ATTR.MaxDays), mine = p == me }
		)
	end
	table.sort(entries, function(a, b)
		if a.days ~= b.days then
			return a.days > b.days
		end
		return a.name < b.name
	end)
	local out: { Row } = {}
	for i, e in entries do
		if i > ROW_COUNT then
			break
		end
		table.insert(out, {
			left = `{i}. {e.name}`,
			right = `{e.days}d`,
			color = if e.mine then LobbyConfig.GoodColor else nil,
		})
	end
	return out
end

local function statRows(me: Player): { Row }
	local out: { Row } = {
		{ left = "Best run", right = `{numberAttr(me, ATTR.MaxDays)} days` },
		{ left = "Runs", right = tostring(numberAttr(me, ATTR.Runs)) },
		{
			left = "Kills / Bosses",
			right = `{numberAttr(me, ATTR.Kills)} / {numberAttr(me, ATTR.BossKills)}`,
		},
		{ left = "Crafted", right = tostring(numberAttr(me, ATTR.Crafted)) },
		{ left = "Coins", right = tostring(numberAttr(me, ATTR.Coins)) },
		{ left = "Achievements", right = "", color = LobbyConfig.AccentColor },
	}
	local ids = LobbyLogic.decodeAchievements(me:GetAttribute(ATTR.Achievements))
	if #ids == 0 then
		table.insert(
			out,
			{ left = "None yet. Survive longer.", right = "", color = LobbyConfig.MutedColor }
		)
	end
	local room = STAT_ROWS - #out
	for i, id in ids do
		if i > room then
			out[STAT_ROWS] =
				{ left = `+{#ids - room + 1} more [T]`, right = "", color = LobbyConfig.MutedColor }
			break
		end
		table.insert(out, {
			left = `* {LobbyLogic.achievementTitle(id)}`,
			right = "",
			color = LobbyConfig.GoodColor,
		})
	end
	return out
end

local function draw(board: Board, rows: { Row })
	local signature = ""
	for i, row in rows do
		signature ..= `{row.left}|{row.right}|{if row.color then row.color:ToHex() else ""};`
		if i >= #board.left then
			break
		end
	end
	if signature == board.signature then
		return
	end
	board.signature = signature
	for i, label in board.left do
		local row = rows[i]
		label.Text = if row then row.left else ""
		label.TextColor3 = if row and row.color then row.color else LobbyConfig.TextColor
		board.right[i].Text = if row then row.right else ""
		board.right[i].TextColor3 = if row and row.color then row.color else LobbyConfig.AccentColor
	end
end

function HubBoards.start(state: LobbyState.State): () -> ()
	local me = Players.LocalPlayer
	local boards: { [BasePart]: Board } = {}
	local destroyed = false
	local connections: { RBXScriptConnection } = {}

	local function add(instance: Instance, kind: string, rows: number)
		if destroyed or boards[instance :: BasePart] or not instance:IsA("BasePart") then
			return
		end
		boards[instance] = makeBoard(instance, kind, rows)
	end
	local function track(tag: string, kind: string, rows: number)
		for _, instance in CollectionService:GetTagged(tag) do
			add(instance, kind, rows)
		end
		table.insert(
			connections,
			CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance: Instance)
				add(instance, kind, rows)
			end)
		)
		table.insert(
			connections,
			CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance: Instance)
				local board = boards[instance :: BasePart]
				if board then
					board.gui:Destroy()
					boards[instance :: BasePart] = nil
				end
			end)
		)
	end
	track(TAGS.Leaderboard, "global", ROW_COUNT)
	track(TAGS.LocalBoard, "local", ROW_COUNT)
	track(TAGS.Stats, "stats", STAT_ROWS)

	local function refresh()
		if destroyed or not state.isLobby() then
			return
		end
		for _, board in boards do
			local rows = if board.kind == "global"
				then globalRows(me)
				elseif board.kind == "local" then localRows(me)
				else statRows(me)
			draw(board, rows)
		end
	end
	task.spawn(function()
		while not destroyed do
			refresh()
			task.wait(LobbyConfig.BoardRefreshSeconds)
		end
	end)

	return function()
		destroyed = true
		for _, c in connections do
			c:Disconnect()
		end
		table.clear(connections)
		for part, board in boards do
			board.gui:Destroy()
			boards[part] = nil
		end
	end
end

return HubBoards
