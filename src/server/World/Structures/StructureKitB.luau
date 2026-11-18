--!strict
-- Adapter for massive structures B (shipwreck, temple, lodge, ruins): turns a pure PlanKitB plan into
-- terrain edits (flat pad + carved underground), a large-part shell, loot chest slots and near-player
-- dressing. Builders expose build(origin, seed, parent): Handle (see docs/systems/structures-b.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ArtKit = require(Shared:WaitForChild("ArtKit"))
local Logic = Shared:WaitForChild("logic")
local Kit = require(Logic:WaitForChild("PlanKitB"))
local MassiveRules = require(Logic:WaitForChild("MassiveRules"))
local SiteGround = require(Logic:WaitForChild("SiteGround"))
local World = require(Logic:WaitForChild("World"))
local Server = ServerScriptService:WaitForChild("Server")
local PoiStructures = require(Server:WaitForChild("World"):WaitForChild("PoiStructures"))
local SiteGroundTerrain = require(Server:WaitForChild("World"):WaitForChild("SiteGroundTerrain"))
local GroundProbe = require(Server:WaitForChild("World"):WaitForChild("GroundProbe"))

local P = ArtKit.palette(Config.Art.World.Palette)
local MASSIVE = Config.Massive
local DREAD_COOLDOWN = 20 -- seconds between dread hook calls per zone
local QUARTER_TURN = math.pi / 2

local StructureKitB = {}

export type Footprint = { radius: number, halfX: number, halfZ: number }
export type ChestSlot = { Position: Vector3, Depth: number, StructureType: string, Room: string? }
export type DreadZone = { Position: Vector3, Radius: number, Kind: string }
export type Handle = {
	Model: Model,
	Footprint: Footprint,
	ChestSlots: { ChestSlot },
	Update: (playerPositions: { Vector3 }) -> (),
	Destroy: () -> (),
	Origin: Vector3, -- footprint centre at ground level
	DreadZones: { DreadZone },
	-- Server hook: called with a player position and the zone kind ("Crypt"/"Legendary") while a player is
	-- inside a spooky zone (throttled). Wire to DreadService / CueSender in integration.
	DreadListener: ((position: Vector3, kind: string) -> ())?,
}

local KIT_STYLES: { [string]: PoiStructures.Style } = {
	Hull = { color = P.WoodDark, material = Enum.Material.Wood },
	Deck = {
		color = Color3.new(P.Wood.R * 0.8, P.Wood.G * 0.8, P.Wood.B * 0.8),
		material = Enum.Material.WoodPlanks,
	},
	Water = { color = P.Spring, material = Enum.Material.Glass, transparency = 0.5 },
	Ice = { color = P.Ice, material = Enum.Material.Ice },
	Brass = { color = Color3.fromRGB(196, 152, 72), material = Enum.Material.Metal },
}

local function styleOf(name: string): PoiStructures.Style
	return KIT_STYLES[name] or PoiStructures.styleOf(name) or KIT_STYLES.Hull
end

local function makePart(b: Kit.Box, base: CFrame): Part
	local style = styleOf(b.style)
	local part = Instance.new("Part")
	part.Name = b.name
	part.Anchored = true
	part.Size = Vector3.new(b.sx, b.sy, b.sz)
	part.CFrame = base
		* CFrame.new(b.x, b.y, b.z)
		* CFrame.Angles(math.rad(b.rx or 0), math.rad(b.ry or 0), math.rad(b.rz or 0))
	part.Color = style.color
	part.Material = style.material
	part.Transparency = style.transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CastShadow = b.collide
	part.CanTouch = false
	part.CanCollide = b.collide
	part.CanQuery = b.collide
	if b.light then
		local light = Instance.new("PointLight")
		light.Name = "StructureLight"
		light.Color = PoiStructures.lightColor(b.light.color)
		light.Range = b.light.range
		light.Brightness = b.light.brightness
		light.Shadows = false
		light.Parent = part
	end
	if b.fx == "Fire" then
		part.Transparency = 1
		local fire = Instance.new("Fire")
		fire.Size = 5
		fire.Heat = 8
		fire.Parent = part
	elseif b.fx == "Smoke" then
		part.Transparency = 1
		local smoke = Instance.new("Smoke")
		smoke.Size = 3
		smoke.RiseVelocity = 4
		smoke.Opacity = 0.35
		smoke.Parent = part
	elseif b.fx == "Mist" then
		part.Transparency = 1
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = Config.Art.World.ParticleTexture
		emitter.Rate = 3
		emitter.Lifetime = NumberRange.new(4, 6)
		emitter.Speed = NumberRange.new(0.4, 1)
		emitter.Size = NumberSequence.new(5, 8)
		emitter.Transparency = NumberSequence.new(0.88, 1)
		emitter.Color = ColorSequence.new(P.Snow)
		emitter.LightEmission = 0.1
		emitter.Parent = part
	end
	return part
end

type RoomState = {
	room: Kit.Room,
	items: { Kit.Dress },
	folder: Folder?,
	next: number,
}

function StructureKitB.build(
	plan: Kit.Plan,
	origin: Vector3,
	seed: number,
	parent: Instance
): Handle
	-- Terrain: SiteGround levels the whole pad area (Config.SiteGround) with a blended skirt, in the biome
	-- material (no grey hard-edged pad), then every underground volume is carved.
	local pad = plan.pad
	local halfX, halfZ = plan.footprintX / 2, plan.footprintZ / 2
	local siteHalfX = math.max(halfX, if pad then pad.halfX else 0)
	local siteHalfZ = math.max(halfZ, if pad then pad.halfZ else 0)
	if plan.yaw % 2 == 1 then
		siteHalfX, siteHalfZ = siteHalfZ, siteHalfX
	end
	local function heightFn(x: number, z: number): number
		return GroundProbe.groundY(x, z, World.heightAt(seed, x, z)) -- real terrain, planned height as fallback
	end
	local site = SiteGround.plan(heightFn, origin.X, origin.Z, siteHalfX, siteHalfZ)
	local groundY = site.baseY
	local base = CFrame.new(origin.X, groundY, origin.Z)
		* CFrame.Angles(0, plan.yaw * QUARTER_TURN, 0)
	local terrain = Workspace.Terrain
	local ok, err = pcall(SiteGroundTerrain.apply, site, heightFn)
	if not ok then
		warn(`[StructureKitB] site grounding failed: {err}`)
	end
	for _, c in plan.carves do
		terrain:FillBlock(
			base * CFrame.new(c.x, c.y, c.z),
			Vector3.new(c.sx, c.sy, c.sz),
			Enum.Material.Air
		)
	end

	local model = Instance.new("Model")
	model.Name = plan.id
	model:SetAttribute("StructureType", plan.id)
	model:SetAttribute("Seed", seed)
	for _, b in plan.shell do
		makePart(b, base).Parent = model
	end

	local chestSlots: { ChestSlot } = {}
	for _, c in plan.chests do
		table.insert(chestSlots, {
			Position = base:PointToWorldSpace(Vector3.new(c.x, c.y, c.z)),
			Depth = c.depth,
			StructureType = plan.id,
			Room = c.room,
		})
	end

	-- Dressing state per room.
	local states: { RoomState } = {}
	local stateById: { [string]: RoomState } = {}
	for _, room in plan.rooms do
		local st: RoomState = { room = room, items = {}, folder = nil, next = 1 }
		table.insert(states, st)
		stateById[room.id] = st
	end
	for _, d in plan.dressing do
		table.insert(stateById[d.room].items, d)
	end

	local dreadZones: { DreadZone } = {}
	local dreadLast: { [string]: number } = {}
	local dreadRooms: { [string]: string } = {}
	for roomId, kind in plan.dread do
		local room = plan.byId[roomId]
		local centre = base:PointToWorldSpace(
			Vector3.new((room.x1 + room.x2) / 2, room.y + room.height / 2, (room.z1 + room.z2) / 2)
		)
		table.insert(dreadZones, {
			Position = centre,
			Radius = math.max(room.x2 - room.x1, room.z2 - room.z1) / 2,
			Kind = kind,
		})
		dreadRooms[roomId] = kind
	end

	model.Parent = parent

	local destroyed = false
	local lastUpdate = 0
	local handle: Handle -- assigned below

	local function distanceTo(room: Kit.Room, p: Vector3): number
		local dx = math.max(room.x1 - p.X, 0, p.X - room.x2)
		local dy = math.max(room.y - p.Y, 0, p.Y - (room.y + room.height))
		local dz = math.max(room.z1 - p.Z, 0, p.Z - room.z2)
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end

	local function update(playerPositions: { Vector3 })
		if destroyed then
			return
		end
		local now = os.clock()
		if now - lastUpdate < MASSIVE.DressingCheckInterval * 0.9 then
			return
		end
		lastUpdate = now
		local localPositions: { Vector3 } = {}
		for _, p in playerPositions do
			table.insert(localPositions, base:PointToObjectSpace(p))
		end
		local budget = MASSIVE.DressingPartsPerTick
		for _, st in states do
			local nearest = math.huge
			for _, lp in localPositions do
				nearest = math.min(nearest, distanceTo(st.room, lp))
			end
			if nearest <= MASSIVE.DressingSpawnRadius then
				if st.next <= #st.items and budget > 0 then
					local folder: Folder
					local existing = st.folder
					if existing ~= nil then
						folder = existing
					else
						folder = Instance.new("Folder")
						folder.Name = `Dressing_{st.room.id}`
						folder.Parent = model
						st.folder = folder
					end
					while st.next <= #st.items and budget > 0 do
						makePart(st.items[st.next].box, base).Parent = folder
						st.next += 1
						budget -= 1
					end
				end
			elseif nearest > MASSIVE.DressingDespawnRadius then
				local folder = st.folder
				if folder ~= nil then
					folder:Destroy()
					st.folder = nil
					st.next = 1
				end
			end
		end
		-- spooky zones: hook for the Dread cue (server-side, throttled per zone)
		local listener = handle.DreadListener
		if listener ~= nil then
			for roomId, kind in dreadRooms do
				local room = plan.byId[roomId]
				local last = dreadLast[roomId] or -DREAD_COOLDOWN
				if now - last >= DREAD_COOLDOWN then
					for i, lp in localPositions do
						if distanceTo(room, lp) <= 0 then
							dreadLast[roomId] = now
							local position = playerPositions[i]
							pcall(listener, position, kind)
							break
						end
					end
				end
			end
		end
	end

	local function destroy()
		if destroyed then
			return
		end
		destroyed = true
		model:Destroy()
		table.clear(states)
		table.clear(stateById)
		table.clear(dreadLast)
		handle.DreadListener = nil
	end

	handle = {
		Model = model,
		Footprint = {
			radius = MassiveRules.footprintRadius(plan.id),
			halfX = halfX,
			halfZ = halfZ,
		},
		ChestSlots = chestSlots,
		Update = update,
		Destroy = destroy,
		Origin = Vector3.new(origin.X, groundY, origin.Z),
		DreadZones = dreadZones,
		DreadListener = nil,
	}
	return handle
end

return StructureKitB
