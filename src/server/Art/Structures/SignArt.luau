--!strict
-- Sign and note text for structures. Text lives in a SurfaceGui on the sign part itself, so it is fixed in
-- the world (never a BillboardGui, never faces the camera). Face = the part's NormalId that carries the text.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ArtKit = require(Shared:WaitForChild("ArtKit"))

local P = ArtKit.palette(Config.Art.World.Palette)

local NOTE_BG_TRANSPARENCY = 0.25
local SIGN_BG_TRANSPARENCY = 0.4

local SignArt = {}

-- Adds the SurfaceGui to `part` and returns it. faceName nil = Config.ArtStructures.SignFace.
function SignArt.attach(
	part: BasePart,
	text: string,
	isNote: boolean,
	faceName: string?
): SurfaceGui
	local A = Config.ArtStructures
	local gui = Instance.new("SurfaceGui")
	gui.Name = if isNote then "NoteText" else "SignText"
	gui.Face = (Enum.NormalId :: any)[faceName or A.SignFace] or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = A.SignPixelsPerStud
	gui.MaxDistance = if isNote then A.NoteMaxDistance else A.SignMaxDistance
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = if isNote then NOTE_BG_TRANSPARENCY else SIGN_BG_TRANSPARENCY
	label.BackgroundColor3 = P.Scorch
	label.TextColor3 = P.Snow
	label.Font = if isNote then Enum.Font.SpecialElite else Enum.Font.GothamBold
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = text
	label.Parent = gui
	gui.Parent = part
	return gui
end

return SignArt
