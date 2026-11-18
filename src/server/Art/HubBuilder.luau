--!strict
-- Builds the outdoor hub plaza into Workspace[Config.Lobby.RootName]. Idempotent: destroys and rebuilds.
-- Run through tools/build_lobby.luau (one MCP call). Logic (pads, spawn, shop) is untouched: this only
-- builds visuals and tags them. Layout and budgets: Config.Art.Hub.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local ArtKit = require(ReplicatedStorage.Shared.ArtKit)
local HubProps = require(script.Parent.HubProps)

local H = Config.Art.Hub
local V = ArtKit.vec
local P = ArtKit.palette(H.Palette)

local HubBuilder = {}

local function faceCenter(pos: Vector3): CFrame
	local target = Vector3.new(V(H.Origin).X, pos.Y, V(H.Origin).Z + V(H.PadArcCenter).Z)
	return CFrame.lookAt(pos, target)
end

function HubBuilder.build(): string
	local existing = Workspace:FindFirstChild(Config.Lobby.RootName)
	if existing then
		existing:Destroy()
	end
	local O = V(H.Origin)
	local function at(offset: Vector3): Vector3
		return O + offset
	end
	local root = Instance.new("Folder")
	root.Name = Config.Lobby.RootName
	root.Parent = Workspace
	local rng = Random.new(H.Seed)

	local function stage(name: string): Folder
		local f = Instance.new("Folder")
		f.Name = name
		return f
	end
	local function flush(f: Folder)
		f.Parent = root
		task.wait()
	end

	-- Exclusion circles (x, z, radius) so scatter never lands on buildings.
	local keepOut: { { x: number, z: number, r: number } } = {}
	local function exclude(offset: Vector3, r: number)
		table.insert(keepOut, { x = offset.X, z = offset.Z, r = r })
	end
	exclude(V(H.ShopPos), H.ClearRadius)
	exclude(V(H.LeaderboardPos), H.ClearRadius - 4)
	exclude(V(H.LocalBoardPos), H.ClearRadius - 4)
	exclude(V(H.StatsPos), H.ClearRadius - 4)
	exclude(V(H.MirrorPos), H.ClearRadius - 6)
	exclude(V(H.SpawnPos), 18)
	for _, p in H.FirePitPositions do
		exclude(V(p), 14)
	end
	local function free(x: number, z: number, margin: number): boolean
		for _, k in keepOut do
			if (x - k.x) ^ 2 + (z - k.z) ^ 2 < (k.r + margin) ^ 2 then
				return false
			end
		end
		return true
	end
	local function scatter(minR: number, maxR: number, margin: number): Vector3?
		for _ = 1, 12 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = math.sqrt(rng:NextNumber(minR * minR, maxR * maxR))
			local x, z = math.cos(a) * r, math.sin(a) * r
			if free(x, z, margin) then
				return Vector3.new(x, 0, z)
			end
		end
		return nil
	end

	-- 1. Ground, plaza stone, paths, barrier.
	local ground = stage("Ground")
	local function disc(
		name: string,
		radius: number,
		thickness: number,
		topY: number,
		color: Color3,
		material: Enum.Material,
		collide: boolean
	)
		HubProps.part(
			name,
			Vector3.new(thickness, radius * 2, radius * 2),
			CFrame.new(at(Vector3.new(0, topY - thickness / 2, 0)))
				* CFrame.Angles(0, 0, math.pi / 2),
			color,
			material,
			ground,
			{ shape = Enum.PartType.Cylinder, collide = collide }
		)
	end
	disc("Snow", H.GroundRadius, H.GroundThickness, 0, P.Snow, Enum.Material.Snow, true)
	disc("Cobble", H.CobbleRadius, 0.3, 0.12, P.Cobble, Enum.Material.Cobblestone, false)
	disc("CobbleRing", H.CobbleRadius + 3, 0.2, 0.06, P.Path, Enum.Material.Slate, false)
	local function path(from: Vector3, to: Vector3, width: number)
		local a, b = at(from), at(to)
		local len = (b - a).Magnitude
		HubProps.part(
			"Path",
			Vector3.new(width, 0.16, len),
			CFrame.lookAt((a + b) / 2 + Vector3.new(0, 0.08, 0), b + Vector3.new(0, 0.08, 0)),
			P.Path,
			Enum.Material.Slate,
			ground
		)
	end
	path(V(H.SpawnPos), Vector3.new(0, 0, V(H.PadArcCenter).Z + 16), 12)
	path(Vector3.new(0, 0, V(H.PadArcCenter).Z), V(H.ShopPos) + Vector3.new(14, 0, 0), 8)
	path(Vector3.new(0, 0, V(H.PadArcCenter).Z), V(H.LeaderboardPos) + Vector3.new(-16, 0, 6), 8)
	path(V(H.SpawnPos) + Vector3.new(0, 0, -8), V(H.StatsPos) + Vector3.new(12, 0, 0), 6)
	path(V(H.SpawnPos) + Vector3.new(0, 0, -8), V(H.MirrorPos) + Vector3.new(-12, 0, 0), 6)
	local sides = 12
	for i = 1, sides do
		local a = (i / sides) * math.pi * 2
		local r = H.BarrierRadius
		local seg = 2 * r * math.tan(math.pi / sides) + 2
		HubProps.part(
			"Barrier",
			Vector3.new(seg, H.BarrierHeight, 2),
			CFrame.new(at(Vector3.new(math.cos(a) * r, H.BarrierHeight / 2, math.sin(a) * r)))
				* CFrame.Angles(0, -a + math.pi / 2, 0),
			P.Snow,
			Enum.Material.Snow,
			ground,
			{ collide = true, transparency = 1 }
		)
	end
	flush(ground)

	-- 2. Pads, spawn, fire pits, lamps.
	local core = stage("Core")
	HubProps.spawn(core, at(V(H.SpawnPos)))
	local padFolder = Instance.new("Folder")
	padFolder.Name = "Pads"
	padFolder.Parent = core
	local count = Config.Lobby.PadCount
	local half = math.rad(H.PadArcHalfDegrees)
	for i = 1, count do
		local t = if count > 1 then (i - 1) / (count - 1) else 0.5
		local a = -half + 2 * half * t
		local pos = at(
			V(H.PadArcCenter)
				+ Vector3.new(math.sin(a) * H.PadArcRadius, 0, -math.cos(a) * H.PadArcRadius)
		)
		HubProps.pad(padFolder, i, faceCenter(pos))
		if i < count then
			local mid = -half + 2 * half * ((i - 0.5) / (count - 1))
			HubProps.lampPost(
				core,
				at(
					V(H.PadArcCenter)
						+ Vector3.new(
							math.sin(mid) * H.PadArcRadius,
							0,
							-math.cos(mid) * H.PadArcRadius
						)
				),
				9
			)
		end
	end
	for i, p in H.FirePitPositions do
		HubProps.firePit(core, at(V(p)), i == 1)
	end
	for i = 1, H.LampRingCount do
		local a = (i / H.LampRingCount) * math.pi * 2 + math.rad(15)
		local off = Vector3.new(math.cos(a) * H.LampRingRadius, 0, math.sin(a) * H.LampRingRadius)
		if free(off.X, off.Z, 4) then
			HubProps.lampPost(core, at(off), 11)
		end
	end
	for _, sx in { -1, 1 } do
		for k = 0, 1 do
			HubProps.lampPost(core, at(V(H.SpawnPos) + Vector3.new(sx * 9, 0, -14 - k * 18)), 9)
		end
	end
	flush(core)

	-- 3. Buildings and boards.
	local village = stage("Village")
	HubProps.shop(village, faceCenter(at(V(H.ShopPos))))
	HubProps.board(
		village,
		faceCenter(at(V(H.LeaderboardPos))),
		H.Tags.Leaderboard,
		"MOST DAYS: GLOBAL"
	)
	HubProps.board(
		village,
		faceCenter(at(V(H.LocalBoardPos))),
		H.Tags.LocalBoard,
		"MOST DAYS: THIS SERVER"
	)
	HubProps.statsArea(village, faceCenter(at(V(H.StatsPos))))
	HubProps.mirror(village, faceCenter(at(V(H.MirrorPos))))
	flush(village)

	-- 4. Trees.
	local trees = stage("Trees")
	local function plant(minR: number, maxR: number, n: number, collide: boolean)
		for _ = 1, n do
			local p = scatter(minR, maxR, 8)
			if p then
				local large = rng:NextNumber() < 0.45
				HubProps.pine(
					trees,
					at(p),
					if large then "HubPineLarge" else "HubPineSmall",
					rng:NextNumber(0.8, 1.3) * (if large then 0.9 else 1.2),
					rng:NextNumber(0, math.pi * 2),
					collide
				)
			end
		end
	end
	plant(H.TreeInnerMin, H.BarrierRadius - 4, H.TreeCountInner, true)
	plant(H.BarrierRadius + 6, H.TreeOuterMax, H.TreeCountOuter, false)
	flush(trees)

	-- 5. Rocks, drifts, mountains, snowfall, ambience.
	local scenery = stage("Scenery")
	for _ = 1, H.RockCount do
		local p = scatter(40, H.BarrierRadius + 60, 6)
		if p then
			local s = rng:NextNumber(2.5, 7)
			HubProps.rock(
				scenery,
				at(p),
				Vector3.new(s * rng:NextNumber(0.9, 1.5), s, s * rng:NextNumber(0.9, 1.4)),
				rng:NextNumber(0, math.pi * 2)
			)
		end
	end
	for _ = 1, H.DriftCount do
		local p = scatter(30, H.BarrierRadius + 40, 4)
		if p then
			local s = rng:NextNumber(8, 18)
			HubProps.drift(scenery, at(p), Vector3.new(s, s * 0.35, s * rng:NextNumber(0.6, 1)))
		end
	end
	for i = 1, H.MountainCount do
		local a = (i / H.MountainCount) * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local r = H.MountainRadius + rng:NextNumber(-30, 60)
		local height = rng:NextNumber(110, 230)
		HubProps.mountain(
			scenery,
			at(Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)),
			rng:NextNumber(90, 170),
			height,
			rng:NextNumber(170, 260),
			-a + math.pi / 2 + rng:NextNumber(-0.3, 0.3)
		)
	end
	HubProps.snow(scenery, O)
	HubProps.ambience(scenery)
	flush(scenery)

	local parts, lights, emitters, rate = HubProps.count(root)
	local report =
		`[HubBuilder] parts {parts}/{H.MaxParts} lights {lights}/{H.MaxLights} emitters {emitters}/{H.MaxEmitters} rate {rate}/{H.MaxParticleRate}`
	assert(
		parts <= H.MaxParts
			and lights <= H.MaxLights
			and emitters <= H.MaxEmitters
			and rate <= H.MaxParticleRate,
		"over budget: " .. report
	)
	return report
end

return HubBuilder
