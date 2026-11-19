--!strict
-- Art Pass 4: Part-built item models for icons (ViewportFrame), dropped world items and in-hand held visuals.
-- Recipes are pure data in logic/ItemModelSpec (every ItemCatalog id resolves; generic shape per kind).
-- Used by the server (ItemDrop, HeldItem) and the client (ItemIcon). Visual only: no scripts, no collision.

local Config = require("./Config")
local ItemCatalog = require("./ItemCatalog")
local ItemModelSpec = require("./logic/ItemModelSpec")

export type Mode = "icon" | "drop" | "held"

local ItemModels = {}

local MODEL_NAME = "ItemModel"
local ID_ATTRIBUTE = "ItemId"
local QUARTER_TURN = math.rad(90)
local LYING_RATIO = 1.5 -- drop mode: a model taller than this multiple of its width lies on its side

local boundsCache: { [string]: Vector3 } = {}

local function cap(mode: Mode): number
	return if mode == "drop" then Config.ArtItems.DropMaxParts else Config.ArtItems.ModelMaxParts
end

local function scaleFor(mode: Mode): number
	if mode == "drop" then
		return Config.ArtItems.DropScale
	elseif mode == "held" then
		return Config.ArtItems.HeldScale
	end
	return 1
end

local function partCFrame(p: ItemModelSpec.PartSpec, scale: number): CFrame
	local cf = CFrame.new(p.pos[1] * scale, p.pos[2] * scale, p.pos[3] * scale)
	local rot = p.rot
	if rot then
		cf *= CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
	end
	if p.shape == "Cylinder" then
		cf *= CFrame.Angles(0, 0, QUARTER_TURN) -- Roblox cylinders run along X; recipes author them along Y
	end
	return cf
end

local function makePart(p: ItemModelSpec.PartSpec, scale: number, anchored: boolean): BasePart
	local part: BasePart
	if p.shape == "Wedge" then
		part = Instance.new("WedgePart")
	else
		local solid = Instance.new("Part")
		if p.shape == "Ball" then
			solid.Shape = Enum.PartType.Ball
		elseif p.shape == "Cylinder" then
			solid.Shape = Enum.PartType.Cylinder
		else
			solid.Shape = Enum.PartType.Block
		end
		part = solid
	end
	local sx, sy, sz = p.size[1] * scale, p.size[2] * scale, p.size[3] * scale
	if p.shape == "Cylinder" then
		part.Size = Vector3.new(sy, sx, sz) -- {diameter, length, diameter} -> axis along X
	else
		part.Size = Vector3.new(sx, sy, sz)
	end
	part.Color = Color3.fromRGB(p.color[1], p.color[2], p.color[3])
	local material = (Enum.Material :: any)[p.material or "SmoothPlastic"]
	part.Material = if material then material :: Enum.Material else Enum.Material.SmoothPlastic
	part.Transparency = p.transparency or 0
	part.Anchored = anchored
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	return part
end

-- True when the id has a recipe (every ItemCatalog item does).
function ItemModels.has(itemId: string): boolean
	return ItemModelSpec.get(itemId) ~= nil
end

-- Fresh Model for an item, PrimaryPart = the recipe's first part. nil only for an unknown id.
--   icon: anchored, tilted for display.  drop: anchored, lying flat if tall, scaled by ArtItems.DropScale.
--   held: unanchored and welded to the primary part (HeldItem moves the parts into a Tool).
function ItemModels.build(itemId: string, mode: Mode): Model?
	local spec = ItemModelSpec.get(itemId)
	if spec == nil then
		return nil
	end
	local scale = scaleFor(mode)
	local anchored = mode ~= "held"
	local tilt = if mode == "icon"
		then CFrame.Angles(0, 0, math.rad(spec.tilt))
		else CFrame.identity
	local model = Instance.new("Model")
	model.Name = MODEL_NAME
	model:SetAttribute(ID_ATTRIBUTE, itemId)
	local limit = math.min(cap(mode), #spec.parts)
	local primary: BasePart? = nil
	local built: { BasePart } = {}
	for i = 1, limit do
		local p = spec.parts[i]
		local part = makePart(p, scale, anchored)
		part.Name = if i == 1 then "Primary" else `Part{i}`
		part.CFrame = tilt * partCFrame(p, scale)
		part.Parent = model
		if i == 1 then
			primary = part
		end
		table.insert(built, part)
	end
	model.PrimaryPart = primary
	if mode == "held" and primary then
		for i = 2, #built do
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = primary
			weld.Part1 = built[i]
			weld.Parent = built[i]
		end
	end
	if mode == "drop" then
		local size = model:GetExtentsSize()
		if size.Y > math.max(size.X, size.Z) * LYING_RATIO then
			model:PivotTo(model:GetPivot() * CFrame.Angles(0, 0, QUARTER_TURN))
		end
	end
	return model
end

-- Icon-mode model extents (studs), cached per id, for camera framing. Vector3.one for an unknown id.
function ItemModels.bounds(itemId: string): Vector3
	local cached = boundsCache[itemId]
	if cached then
		return cached
	end
	local model = ItemModels.build(itemId, "icon")
	local size = Vector3.one
	if model then
		size = model:GetExtentsSize()
		model:Destroy()
	end
	boundsCache[itemId] = size
	return size
end

-- Handle-local point the hand grips for a held item: Config.Ui.Held grip fraction along the model's height.
function ItemModels.heldGrip(itemId: string): Vector3
	local spec = ItemModelSpec.get(itemId)
	if spec == nil or #spec.parts == 0 then
		return Vector3.zero
	end
	local held = Config.Held
	local def = ItemCatalog.Items[itemId]
	local fraction = held.ItemGrip[itemId] or (def and held.KindGrip[def.kind]) or held.DefaultGrip
	local scale = scaleFor("held")
	local lo, hi = math.huge, -math.huge
	for i = 1, math.min(Config.ArtItems.ModelMaxParts, #spec.parts) do
		local p = spec.parts[i]
		local half = p.size[2] / 2
		lo = math.min(lo, p.pos[2] - half)
		hi = math.max(hi, p.pos[2] + half)
	end
	local gripY = (lo + (hi - lo) * fraction) * scale
	local first = spec.parts[1]
	local handleCF = partCFrame(first, scale)
	return handleCF:PointToObjectSpace(Vector3.new(0, gripY, 0))
end

return ItemModels
