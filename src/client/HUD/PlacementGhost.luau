--!strict
-- Placement preview: while a placeable is selected, a transparent copy of the structure sits on the
-- ground at the grid-snapped aim point (mouse on PC, screen centre on touch), tinted green when the shared
-- validator (shared/logic/Placement.validate, the same one the server runs) accepts it and red with the
-- reason when not. R (or the on-screen button on touch) rotates; the HUD's Act/click confirms by reading
-- target(). The ghost has no collision, no scripts, CanQuery false, and is destroyed on deselect.
-- Visual and intent only: the server re-validates at the place action.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ItemCatalog = require(Shared:WaitForChild("ItemCatalog"))
local Placement = require(Shared:WaitForChild("logic"):WaitForChild("Placement"))
local SiteGround = require(Shared:WaitForChild("logic"):WaitForChild("SiteGround"))
local InputGuard = require(script.Parent.Parent:WaitForChild("Input"):WaitForChild("InputGuard"))

local B = Config.Build
local G = B.Ghost

export type Options = {
	selectedStructure: () -> string?, -- structure id of the selected placeable, or nil
	itemCount: (structureId: string) -> number, -- how many placeable items the player holds
}

export type Target = {
	structureId: string,
	position: Vector3, -- snapped, on the ground (structure pivot height not included)
	rotation: number, -- degrees, snapped to B.RotationStep
	ok: boolean,
	reason: string, -- validator code
	text: string, -- player-facing reason ("" when ok)
}

export type Ghost = {
	target: () -> Target?,
	rotate: () -> (),
	setAim: (Vector3?) -> (), -- Studio QA: aim at a world point instead of the cursor
	setTouch: (boolean?) -> (), -- Studio QA: force the touch (true) or PC (false) layout; nil = detect
	state: () -> { [string]: any },
	destroy: () -> (),
}

local PlacementGhost = {}

local function color(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function pivotOf(i: Instance): Vector3?
	if i:IsA("BasePart") then
		return i.Position
	elseif i:IsA("Model") then
		return i:GetPivot().Position
	end
	return nil
end

function PlacementGhost.start(opts: Options): Ghost
	local player = Players.LocalPlayer
	local validColor, invalidColor = color(G.ValidColor), color(G.InvalidColor)
	local rotateKey = (Enum.KeyCode :: any)[G.RotateKeyName] :: Enum.KeyCode
	local conns: { RBXScriptConnection } = {}
	local destroyed = false

	local part: Part? = nil
	local label: TextLabel? = nil
	local partStructure: string? = nil
	local rotation = 0
	local aim: Vector3? = nil
	local current: Target? = nil
	local accum = G.UpdateInterval

	-- Mobile rotate button (touch only, shown while a ghost is up).
	local screen = Instance.new("ScreenGui")
	screen.Name = "PlacementGhostUI"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 6
	local rotateButton = Instance.new("TextButton")
	rotateButton.Name = "Rotate"
	rotateButton.AnchorPoint = Vector2.new(1, 1)
	rotateButton.Position = UDim2.new(1, -G.RotateButtonOffsetPx, 0.78, 0)
	rotateButton.Size = UDim2.fromOffset(G.RotateButtonSize, G.RotateButtonSize)
	rotateButton.BackgroundColor3 = validColor
	rotateButton.BackgroundTransparency = 0.2
	rotateButton.BorderSizePixel = 0
	rotateButton.Text = "Rotate"
	rotateButton.TextScaled = true
	rotateButton.Font = Enum.Font.GothamBold
	rotateButton.TextColor3 = Color3.new(0, 0, 0)
	rotateButton.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = rotateButton
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MaxTextSize = 18
	textLimit.MinTextSize = 8
	textLimit.Parent = rotateButton
	rotateButton.Parent = screen
	screen.Parent = player:WaitForChild("PlayerGui")

	local touchOverride: boolean? = nil
	local function usesTouch(): boolean
		if touchOverride ~= nil then
			return touchOverride
		end
		return UserInputService:GetLastInputType() == Enum.UserInputType.Touch
			or (UserInputService.TouchEnabled and not UserInputService.MouseEnabled)
	end

	local function clearGhost()
		if part then
			part:Destroy()
		end
		part, label, partStructure, current = nil, nil, nil, nil
		rotateButton.Visible = false
	end

	local function makeGhost(structureId: string)
		local def = ItemCatalog.Structures[structureId]
		if def == nil then
			return
		end
		local p = Instance.new("Part")
		p.Name = G.Name
		p.Size = Vector3.new(def.sizeX, def.sizeY, def.sizeZ)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = G.Transparency
		p.Color = validColor
		local gui = Instance.new("BillboardGui")
		gui.Name = "Reason"
		gui.Size = UDim2.fromOffset(G.LabelWidthPx, G.LabelHeightPx)
		gui.StudsOffsetWorldSpace = Vector3.new(0, def.sizeY / 2 + G.LabelOffsetY, 0)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.TextScaled = true
		text.Font = Enum.Font.GothamBold
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeTransparency = 0.3
		text.Text = ""
		text.Parent = gui
		gui.Parent = p
		p.Parent = Workspace
		part, label, partStructure = p, text, structureId
		rotation = 0
	end

	local function groundParams(): RaycastParams?
		local chunks = Workspace:FindFirstChild(Config.World.ChunkFolderName)
		if chunks == nil then
			return nil
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { chunks, Workspace.Terrain }
		return params
	end

	-- World point under the cursor (PC) or screen centre (touch), or the QA override.
	local function aimPoint(params: RaycastParams): Vector3?
		if aim then
			return aim
		end
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return nil
		end
		local screenPos = if usesTouch()
			then camera.ViewportSize / 2
			else UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(screenPos.X, screenPos.Y)
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * G.PickRange, params)
		return if hit then hit.Position else nil
	end

	local function othersAndCounts(): ({ Placement.Point }, number, number)
		local seen: { [Instance]: boolean } = {}
		local others: { Placement.Point } = {}
		local fireCount = 0
		local owned = 0
		local function add(i: Instance)
			if seen[i] then
				return
			end
			seen[i] = true
			local p = pivotOf(i)
			if p then
				table.insert(others, { x = p.X, z = p.Z })
			end
		end
		for _, i in CollectionService:GetTagged(Config.Fire.Tag) do
			add(i)
			fireCount += 1
		end
		for _, i in CollectionService:GetTagged(ItemCatalog.WorkbenchTag) do
			add(i)
		end
		local folder = Workspace:FindFirstChild(B.FolderName)
		if folder then
			for _, i in folder:GetChildren() do
				add(i)
				if i:GetAttribute(B.OwnerAttribute) == player.UserId then
					owned += 1
				end
			end
		end
		return others, owned, fireCount
	end

	local function litFires(): { Placement.BuildFire }
		local out: { Placement.BuildFire } = {}
		for _, fire in CollectionService:GetTagged(Config.Fire.Tag) do
			local radius = fire:GetAttribute(Config.Fire.BuildRadiusAttribute)
			local p = pivotOf(fire)
			if
				fire:GetAttribute(Config.Fire.LitAttribute) == true
				and p
				and type(radius) == "number"
			then
				table.insert(out, { x = p.X, z = p.Z, buildRadius = radius })
			end
		end
		return out
	end

	local function refresh()
		local structureId = opts.selectedStructure()
		if structureId == nil or ItemCatalog.Structures[structureId] == nil then
			clearGhost()
			return
		end
		if partStructure ~= structureId then
			clearGhost()
			makeGhost(structureId)
		end
		local p, text = part, label
		local def = ItemCatalog.Structures[structureId]
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local params = groundParams()
		if
			p == nil
			or text == nil
			or def == nil
			or params == nil
			or not (root and root:IsA("BasePart"))
		then
			if p then
				p.Transparency = 1
			end
			current = nil
			return
		end
		local point = aimPoint(params)
		if point == nil then
			p.Transparency = 1
			text.Text = ""
			current = nil
			return
		end
		local snapped = Placement.snapPoint(point.X, point.Z, B.GridStep)
		-- Same footprint ground snap as the server's place handler (SiteGround.snapGround).
		local rootY = root.Position.Y
		local groundY = SiteGround.snapGround(function(cx: number, cz: number): number?
			local hit = Workspace:Raycast(
				Vector3.new(cx, rootY + B.GroundRayHeight, cz),
				Vector3.new(0, -B.GroundRayLength, 0),
				params
			)
			return if hit then hit.Position.Y else nil
		end, snapped.x, snapped.z, def.sizeX, def.sizeZ, rotation)
		if groundY == nil then
			p.Transparency = 1
			text.Text = ""
			current = nil
			return
		end
		local others, owned, fireCount = othersAndCounts()
		local result = Placement.validate({
			structureId = structureId,
			target = snapped,
			player = { x = root.Position.X, z = root.Position.Z },
			placeRange = B.PlaceRange,
			minSpacing = B.MinSpacing,
			others = others,
			ownedCount = owned,
			maxOwned = B.MaxStructuresPerPlayer,
			fireCount = fireCount,
			maxFires = Config.Fire.MaxPerTeam,
			itemCount = opts.itemCount(structureId),
			litFires = litFires(),
			buildExempt = B.RangeExempt[structureId] == true,
		})
		local ground = Vector3.new(snapped.x, groundY, snapped.z)
		p.CFrame = CFrame.new(ground + Vector3.new(0, def.sizeY / 2, 0))
			* CFrame.Angles(0, math.rad(rotation), 0)
		p.Transparency = G.Transparency
		p.Color = if result.ok then validColor else invalidColor
		local reasonText = if result.ok then "" else (G.ReasonText[result.reason] or result.reason)
		local touch = usesTouch()
		-- Touch has no R key: no "[R] Rotate" text, the on-screen Rotate button carries the label.
		text.Text = if not result.ok
			then reasonText
			elseif touch then ""
			else `[{G.RotateKeyName}] Rotate`
		rotateButton.Visible = touch
		rotateButton.BackgroundColor3 = if result.ok then validColor else invalidColor
		current = {
			structureId = structureId,
			position = ground,
			rotation = rotation,
			ok = result.ok,
			reason = result.reason,
			text = reasonText,
		}
	end

	local function rotate()
		if part == nil then
			return
		end
		rotation = Placement.snapRotation(rotation + B.RotationStep, B.RotationStep)
		refresh()
	end

	table.insert(
		conns,
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if not InputGuard.blocked(processed) and input.KeyCode == rotateKey then
				rotate()
			end
		end)
	)
	table.insert(conns, rotateButton.Activated:Connect(rotate))
	table.insert(
		conns,
		RunService.RenderStepped:Connect(function(dt: number)
			accum += dt
			if accum < G.UpdateInterval then
				return
			end
			accum = 0
			refresh()
		end)
	)

	local ghost = {} :: Ghost
	ghost.target = function(): Target?
		refresh()
		return current
	end
	ghost.rotate = rotate
	ghost.setTouch = function(value: boolean?)
		touchOverride = value
	end
	ghost.setAim = function(point: Vector3?)
		aim = point
		refresh()
	end
	ghost.state = function(): { [string]: any }
		refresh()
		local p = part
		return {
			visible = p ~= nil and p.Transparency < 1,
			exists = p ~= nil and p.Parent ~= nil,
			ok = if current then current.ok else false,
			reason = if current then current.reason else "",
			text = if current then current.text else "",
			green = p ~= nil and p.Color == validColor,
			red = p ~= nil and p.Color == invalidColor,
			collide = if p then p.CanCollide else false,
			query = if p then p.CanQuery else false,
			scripts = if p
				then #p:GetDescendants() > 0 and p:FindFirstChildWhichIsA(
					"LuaSourceContainer",
					true
				) ~= nil
				else false,
			rotation = rotation,
			label = if label then label.Text else "",
			rotateButton = rotateButton.Visible,
		}
	end
	ghost.destroy = function()
		if destroyed then
			return
		end
		destroyed = true
		for _, c in conns do
			c:Disconnect()
		end
		table.clear(conns)
		clearGhost()
		screen:Destroy()
	end
	return ghost
end

return PlacementGhost
