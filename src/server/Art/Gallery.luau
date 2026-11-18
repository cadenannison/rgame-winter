--!strict
-- Studio-only art review aid: "/debug gallery <set>" lays every asset of an art pass out in one labelled
-- row in front of the caller; "/debug gallery clear" removes it. Each pass adds a set to SETS (and its
-- name to Config.Art.GallerySets). Items are built detached and stripped of gameplay tags so they never
-- register as real pads.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local HubProps = require(script.Parent.HubProps)

local Gallery = {}

type Item = { label: string, width: number, build: (parent: Instance, cf: CFrame) -> () }

local function hubItems(): { Item }
	local P = Config.Art.Hub.Tags
	return {
		{
			label = "Pine small",
			width = 14,
			build = function(parent, cf)
				HubProps.pine(parent, cf.Position, "HubPineSmall", 1.2, 0, false)
			end,
		},
		{
			label = "Pine large",
			width = 30,
			build = function(parent, cf)
				HubProps.pine(parent, cf.Position, "HubPineLarge", 0.9, 0, false)
			end,
		},
		{
			label = "Rock",
			width = 14,
			build = function(parent, cf)
				HubProps.rock(parent, cf.Position, Vector3.new(6, 5, 6), 0.4)
			end,
		},
		{
			label = "Drift",
			width = 20,
			build = function(parent, cf)
				HubProps.drift(parent, cf.Position, Vector3.new(14, 5, 10))
			end,
		},
		{
			label = "Lamp post",
			width = 10,
			build = function(parent, cf)
				HubProps.lampPost(parent, cf.Position, 10)
			end,
		},
		{
			label = "Fire pit",
			width = 26,
			build = function(parent, cf)
				HubProps.firePit(parent, cf.Position, false)
			end,
		},
		{
			label = "Bonfire",
			width = 34,
			build = function(parent, cf)
				HubProps.firePit(parent, cf.Position, true)
			end,
		},
		{
			label = "Pad 3",
			width = 26,
			build = function(parent, cf)
				HubProps.pad(parent, 3, cf)
			end,
		},
		{
			label = "Pad 6",
			width = 34,
			build = function(parent, cf)
				HubProps.pad(parent, 6, cf)
			end,
		},
		{
			label = "Board",
			width = 34,
			build = function(parent, cf)
				HubProps.board(parent, cf, P.Leaderboard, "BOARD")
			end,
		},
		{
			label = "Shop",
			width = 44,
			build = function(parent, cf)
				HubProps.shop(parent, cf)
			end,
		},
		{
			label = "Stats area",
			width = 34,
			build = function(parent, cf)
				HubProps.statsArea(parent, cf)
			end,
		},
		{
			label = "Mirror",
			width = 24,
			build = function(parent, cf)
				HubProps.mirror(parent, cf)
			end,
		},
		{
			label = "Mountain (small)",
			width = 70,
			build = function(parent, cf)
				HubProps.mountain(parent, cf.Position + Vector3.new(0, 30, 0), 40, 30, 36, 0)
			end,
		},
	}
end

local SETS: { [string]: () -> { Item } } = {
	hub = hubItems,
}

local function clear()
	local folder = Workspace:FindFirstChild(Config.Art.GalleryRoot)
	if folder then
		folder:Destroy()
	end
end

-- DebugService handler: (player, setName).
function Gallery.handle(player: Player, arg: unknown)
	clear()
	if arg == "clear" or type(arg) ~= "string" then
		return
	end
	local make = SETS[arg]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (make and root and root:IsA("BasePart")) then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = Config.Art.GalleryRoot
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local right = flat:Cross(Vector3.yAxis)
	local ground = Vector3.new(root.Position.X, root.Position.Y - 3, root.Position.Z)
		+ flat * Config.Art.GalleryDistance
	local items = make()
	local total = 0
	for _, item in items do
		total += item.width
	end
	local cursor = -total / 2
	for _, item in items do
		local pos = ground + right * (cursor + item.width / 2)
		cursor += item.width
		local cf = CFrame.lookAt(pos, Vector3.new(root.Position.X, pos.Y, root.Position.Z))
		local holder = Instance.new("Model")
		holder.Name = item.label
		item.build(holder, cf)
		local tag = Instance.new("Part")
		tag.Name = "Label"
		tag.Anchored = true
		tag.CanCollide = false
		tag.CanQuery = false
		tag.Transparency = 1
		tag.Size = Vector3.one
		tag.Position = pos + Vector3.new(0, 1, 0)
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(180, 36)
		gui.StudsOffset = Vector3.new(0, -1.5, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 400
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundColor3 = Color3.fromRGB(18, 28, 40)
		text.BackgroundTransparency = 0.2
		text.TextColor3 = Color3.fromRGB(232, 242, 250)
		text.Font = Enum.Font.GothamBold
		text.TextScaled = true
		text.Text = item.label
		text.Parent = gui
		gui.Parent = tag
		tag.Parent = holder
		holder.Parent = folder
	end
	for _, d in folder:GetDescendants() do
		CollectionService:RemoveTag(d, Config.Lobby.PadTag)
	end
	folder.Parent = Workspace
end

function Gallery.clear()
	clear()
end

return Gallery
