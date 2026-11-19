--!strict
-- Item icons for every slot (hotbar, backpack grid, equipment, chest). create(parent, itemId, size) returns a
-- handle {frame, setItem, destroy}. Backend 2 first: Shared/IconAssets[itemId] -> ImageLabel. Else backend 1: a
-- ViewportFrame showing a cached ItemModels 'icon' model through ONE shared camera setup. A viewport exists only
-- while its slot is occupied AND visible; the number alive is capped (Config.ArtItems.MaxLiveViewports) and
-- slots beyond the cap show a letter tile. One shared sweep loop (not a loop per icon) re-checks visibility.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local IconAssets = require(Shared:WaitForChild("IconAssets"))
local ItemCatalog = require(Shared:WaitForChild("ItemCatalog"))
local ItemModels = require(Shared:WaitForChild("ItemModels"))

export type ItemIconHandle = {
	frame: GuiObject,
	setItem: (string?) -> (),
	destroy: () -> (),
}

type Backend = "none" | "image" | "viewport" | "text"
type State = {
	order: number,
	frame: Frame,
	itemId: string?,
	backend: Backend,
	content: GuiObject?,
	destroyed: boolean,
}

local ItemIcon = {}

local A = Config.ArtItems
local states: { [number]: State } = {}
local nextOrder = 0
local liveViewports = 0
local sweepConnection: RBXScriptConnection? = nil
local templates: { [string]: Model } = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- Whether a GuiObject is actually drawn: itself and every ancestor visible, inside an enabled ScreenGui.
local function isShown(frame: GuiObject): boolean
	local node: Instance? = frame
	while node ~= nil do
		if node:IsA("GuiObject") then
			if not node.Visible then
				return false
			end
		elseif node:IsA("LayerCollector") then
			return node.Enabled
		end
		node = node.Parent
	end
	return false
end

local function template(itemId: string): Model?
	local cached = templates[itemId]
	if cached then
		return cached
	end
	local model = ItemModels.build(itemId, "icon")
	if model then
		templates[itemId] = model -- parented to nothing: only ever cloned
	end
	return model
end

-- The single shared camera/lighting configuration for every viewport icon.
local function makeViewport(itemId: string): ViewportFrame?
	local source = template(itemId)
	if source == nil then
		return nil
	end
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Icon3D"
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = rgb(A.IconAmbient)
	viewport.LightColor = rgb(A.IconLightColor)
	local lightDir = A.IconLightDirection
	viewport.LightDirection = Vector3.new(lightDir[1], lightDir[2], lightDir[3])
	local copy = source:Clone()
	local center = copy:GetBoundingBox().Position
	local radius = ItemModels.bounds(itemId).Magnitude / 2
	local d = A.IconCameraDirection
	local direction = Vector3.new(d[1], d[2], d[3]).Unit
	local camera = Instance.new("Camera")
	camera.FieldOfView = A.IconCameraFov
	camera.CFrame = CFrame.lookAt(center + direction * radius * A.IconCameraDistanceScale, center)
	copy.Parent = viewport
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport
end

local function makeImage(image: string): ImageLabel
	local label = Instance.new("ImageLabel")
	label.Name = "Icon2D"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Image = image
	label.ScaleType = Enum.ScaleType.Fit
	label.Position = UDim2.fromScale(A.IconImagePaddingScale, A.IconImagePaddingScale)
	label.Size = UDim2.fromScale(1 - 2 * A.IconImagePaddingScale, 1 - 2 * A.IconImagePaddingScale)
	return label
end

local function makeTile(itemId: string): Frame
	local def = ItemCatalog.Items[itemId]
	local name = if def then def.name else itemId
	local tile = Instance.new("Frame")
	tile.Name = "IconText"
	tile.AnchorPoint = Vector2.new(0.5, 0.5)
	tile.Position = UDim2.fromScale(0.5, 0.5)
	tile.Size = UDim2.fromScale(0.8, 0.8)
	tile.BackgroundColor3 = rgb(A.FallbackTileColor)
	tile.BackgroundTransparency = A.FallbackTileTransparency
	tile.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = tile
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Text = string.upper(string.sub(name, 1, A.FallbackLetters))
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.Parent = tile
	return tile
end

local function release(state: State)
	if state.content then
		state.content:Destroy()
		state.content = nil
	end
	if state.backend == "viewport" then
		liveViewports -= 1
	end
	state.backend = "none"
end

local function acquire(state: State, itemId: string)
	local image = IconAssets[itemId]
	local content: GuiObject? = nil
	local backend: Backend = "text"
	if image ~= nil and image ~= "" then
		content = makeImage(image)
		backend = "image"
	elseif liveViewports < A.MaxLiveViewports then
		content = makeViewport(itemId)
		if content then
			backend = "viewport"
			liveViewports += 1
		end
	end
	local shown: GuiObject = content or makeTile(itemId)
	if content == nil then
		backend = "text"
	end
	shown.Parent = state.frame
	state.content = shown
	state.backend = backend
end

-- Brings a slot's backend in line with (occupied, visible, capacity).
local function sync(state: State)
	if state.destroyed then
		return
	end
	local itemId = state.itemId
	if itemId == nil or not isShown(state.frame) then
		if state.backend ~= "none" then
			release(state)
		end
		return
	end
	if
		state.backend == "text"
		and liveViewports < A.MaxLiveViewports
		and ItemModels.has(itemId)
	then
		release(state) -- a viewport slot opened up: upgrade the letter tile
	end
	if state.backend == "none" then
		acquire(state, itemId)
	end
end

local function sweep()
	local ordered: { State } = {}
	for _, state in states do
		table.insert(ordered, state)
	end
	table.sort(ordered, function(a: State, b: State)
		return a.order < b.order
	end)
	for _, state in ordered do
		sync(state) -- older icons (the HUD hotbar) claim viewports first
	end
end

local function ensureLoop()
	if sweepConnection then
		return
	end
	local elapsed = 0
	sweepConnection = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= A.IconSweepSeconds then
			elapsed = 0
			sweep()
		end
	end)
end

local function stopLoopIfIdle()
	if next(states) == nil and sweepConnection then
		sweepConnection:Disconnect()
		sweepConnection = nil
	end
end

function ItemIcon.create(parent: Instance, itemId: string, size: UDim2): ItemIconHandle
	local frame = Instance.new("Frame")
	frame.Name = "ItemIcon"
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = size
	nextOrder += 1
	local state: State = {
		order = nextOrder,
		frame = frame,
		itemId = if itemId ~= "" then itemId else nil,
		backend = "none",
		content = nil,
		destroyed = false,
	}
	states[state.order] = state
	ensureLoop()
	frame.Parent = parent
	sync(state)

	local function destroy()
		if state.destroyed then
			return
		end
		state.destroyed = true
		release(state)
		states[state.order] = nil
		stopLoopIfIdle()
		frame:Destroy()
	end
	frame.Destroying:Once(function()
		if not state.destroyed then
			state.destroyed = true
			release(state)
			states[state.order] = nil
			stopLoopIfIdle()
		end
	end)

	return {
		frame = frame,
		setItem = function(newId: string?)
			local normalized = if newId == "" then nil else newId
			if normalized == state.itemId then
				return
			end
			release(state)
			state.itemId = normalized
			sync(state)
		end,
		destroy = destroy,
	}
end

-- Live viewport count (tests / debug).
function ItemIcon.liveViewports(): number
	return liveViewports
end

return ItemIcon
