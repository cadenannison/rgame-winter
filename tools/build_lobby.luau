--!strict
-- Idempotent lobby lodge builder (block placeholders). Run once in Studio via MCP execute_luau; it
-- deletes and rebuilds Workspace.Lobby, so re-running is safe. Leaves no script in the place.
-- Pads: tagged Config.Lobby.PadTag with attribute Config.Lobby.PadIndexAttribute (pad i holds i).
-- Also builds: spawn, shop counter, stat board, leaderboard board, mirror (all tagged for later art).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local ROOT_NAME = Config.Lobby.RootName
local ORIGIN = Vector3.new(0, 500, 0) -- lodge sits high above the run map; no overlap with chunks
local HALF = 40 -- floor half-extent (80x80)
local WALL_HEIGHT = 24
local WALL_THICK = 2
local PAD_ARC_RADIUS = 24
local PAD_ARC_SPAN = math.rad(120)
local PAD_HEIGHT = 0.5
local PAD_BASE = 6
local PAD_STEP = 1 -- width grows with capacity so bigger parties fit
local BOARD_TAGS = {
	Leaderboard = "LobbyLeaderboard",
	Stats = "LobbyStatBoard",
	Shop = "LobbyShop",
	Mirror = "LobbyMirror",
}
local COLORS = {
	floor = Color3.fromRGB(150, 165, 180),
	wall = Color3.fromRGB(96, 70, 52),
	roof = Color3.fromRGB(70, 52, 40),
	pad = Color3.fromRGB(120, 200, 235),
	board = Color3.fromRGB(40, 52, 66),
}

local existing = Workspace:FindFirstChild(ROOT_NAME)
if existing then
	existing:Destroy()
end

local root = Instance.new("Folder")
root.Name = ROOT_NAME

local function part(
	name: string,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	parent: Instance
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = ORIGIN + offset
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function sign(target: Part, text: string)
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(232, 242, 250)
	label.Text = text
	label.Parent = surface
	surface.Parent = target
end

-- Shell
part("Floor", Vector3.new(HALF * 2, 2, HALF * 2), Vector3.new(0, -1, 0), COLORS.floor, root)
part(
	"Roof",
	Vector3.new(HALF * 2 + 4, WALL_THICK, HALF * 2 + 4),
	Vector3.new(0, WALL_HEIGHT, 0),
	COLORS.roof,
	root
)
local mid = WALL_HEIGHT / 2
part(
	"WallN",
	Vector3.new(HALF * 2, WALL_HEIGHT, WALL_THICK),
	Vector3.new(0, mid, -HALF),
	COLORS.wall,
	root
)
part(
	"WallS",
	Vector3.new(HALF * 2, WALL_HEIGHT, WALL_THICK),
	Vector3.new(0, mid, HALF),
	COLORS.wall,
	root
)
part(
	"WallE",
	Vector3.new(WALL_THICK, WALL_HEIGHT, HALF * 2),
	Vector3.new(HALF, mid, 0),
	COLORS.wall,
	root
)
part(
	"WallW",
	Vector3.new(WALL_THICK, WALL_HEIGHT, HALF * 2),
	Vector3.new(-HALF, mid, 0),
	COLORS.wall,
	root
)

local light = Instance.new("PointLight")
light.Range = 60
light.Brightness = 1.5
light.Parent =
	part("Lamp", Vector3.new(2, 1, 2), Vector3.new(0, WALL_HEIGHT - 2, 0), COLORS.board, root)

-- Spawn (south side, facing the pads which sit north)
local spawn = Instance.new("SpawnLocation")
spawn.Name = Config.Lobby.SpawnName
spawn.Anchored = true
spawn.Neutral = true
spawn.Duration = 0
spawn.Size = Vector3.new(8, 1, 8)
spawn.Position = ORIGIN + Vector3.new(0, 0.5, HALF - 8)
spawn.Transparency = 0.5
spawn.Parent = root

-- Pads: an arc on the north side, numbered 1..PadCount
local padFolder = Instance.new("Folder")
padFolder.Name = "Pads"
padFolder.Parent = root
local count = Config.Lobby.PadCount
for i = 1, count do
	local t = if count > 1 then (i - 1) / (count - 1) else 0.5
	local angle = -PAD_ARC_SPAN / 2 + PAD_ARC_SPAN * t
	local offset = Vector3.new(
		math.sin(angle) * PAD_ARC_RADIUS,
		PAD_HEIGHT / 2,
		-math.cos(angle) * PAD_ARC_RADIUS + 8
	)
	local width = PAD_BASE + (i - 1) * PAD_STEP
	local pad = part(`Pad{i}`, Vector3.new(width, PAD_HEIGHT, width), offset, COLORS.pad, padFolder)
	pad.Material = Enum.Material.Neon
	pad.Transparency = 0.3
	pad.CanCollide = false -- walk onto it; PartyService detects the touch
	pad.CanTouch = true
	pad:SetAttribute(Config.Lobby.PadIndexAttribute, i)
	CollectionService:AddTag(pad, Config.Lobby.PadTag)
	-- Number plate in front of the pad
	local plate = part(
		`PadSign{i}`,
		Vector3.new(4, 2, 0.4),
		offset + Vector3.new(0, 2.5, -width / 2 - 0.5),
		COLORS.board,
		padFolder
	)
	sign(plate, `{i}`)
end

-- Boards along the east/west walls (cosmetic anchors; data is shown by the client UI)
local function board(name: string, tag: string, offset: Vector3, text: string)
	local b = part(name, Vector3.new(14, 9, 1), offset, COLORS.board, root)
	b.Orientation = Vector3.new(0, if offset.X > 0 then -90 else 90, 0)
	sign(b, text)
	CollectionService:AddTag(b, tag)
end
board("LeaderboardBoard", BOARD_TAGS.Leaderboard, Vector3.new(HALF - 2, 9, -14), "TOP DAYS\n[L]")
board("StatBoard", BOARD_TAGS.Stats, Vector3.new(-HALF + 2, 9, -14), "YOUR STATS\n[T]")

-- Shop counter placeholder (opens the Shop panel client-side with B)
local shop =
	part("ShopCounter", Vector3.new(14, 4, 4), Vector3.new(-HALF + 6, 2, 16), COLORS.wall, root)
CollectionService:AddTag(shop, BOARD_TAGS.Shop)
local shopSign =
	part("ShopSign", Vector3.new(10, 3, 0.5), Vector3.new(-HALF + 6, 7, 16), COLORS.board, root)
sign(shopSign, "SHOP [B]")

-- Cosmetic mirror placeholder
local mirror =
	part("Mirror", Vector3.new(6, 9, 0.5), Vector3.new(HALF - 4, 5, 16), COLORS.floor, root)
mirror.Material = Enum.Material.Glass
mirror.Transparency = 0.4
CollectionService:AddTag(mirror, BOARD_TAGS.Mirror)

root.Parent = Workspace
print(`[build_lobby] built {#padFolder:GetChildren() // 2} pads, parts: {#root:GetDescendants()}`)
