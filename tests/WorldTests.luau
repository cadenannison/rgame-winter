--!strict
local WorldLayout = require("../src/shared/logic/WorldLayout")

local PARAMS: WorldLayout.Params = {
	GridSize = 8,
	ChunkSize = 320,
	StartForestRing = 1,
	CampMinRingDistance = 1,
	CampGuaranteedWoodCount = 6,
	CampGuaranteedFoodCount = 3,
	CampGuaranteeRadius = 80,
	StreamInRadius = 400,
	StreamOutRadius = 520,
	TreesPerChunk = 12,
	RocksPerChunk = 5,
	SpawnZonesPerChunk = 2,
}

return function(check: (string, boolean) -> ())
	local a = WorldLayout.generate(12345, PARAMS)
	local b = WorldLayout.generate(12345, PARAMS)
	local c = WorldLayout.generate(54321, PARAMS)
	check("world same seed same layout", WorldLayout.serialize(a) == WorldLayout.serialize(b))
	check("world different seed differs", WorldLayout.serialize(a) ~= WorldLayout.serialize(c))
	check("world 64 chunks", #a.chunks == 64)

	local camp = a.camp
	local campChunk = a.chunks[camp.chunkIndex]
	check("world camp in start forest", campChunk.ring == PARAMS.StartForestRing)
	check("world camp wood count", #camp.wood == PARAMS.CampGuaranteedWoodCount)
	check("world camp food count", #camp.food == PARAMS.CampGuaranteedFoodCount)
	local near = true
	for _, v in camp.wood do
		near = near
			and math.sqrt((v.x - camp.position.x) ^ 2 + (v.z - camp.position.z) ^ 2)
				<= PARAMS.CampGuaranteeRadius
	end
	for _, v in camp.food do
		near = near
			and math.sqrt((v.x - camp.position.x) ^ 2 + (v.z - camp.position.z) ^ 2)
				<= PARAMS.CampGuaranteeRadius
	end
	check("world camp resources within radius", near)
	check("world camp in one chunk", WorldLayout.distanceToChunk(a, campChunk, camp.position) == 0)

	local allCampOk = true
	for seed = 1, 50 do
		local l = WorldLayout.generate(seed, PARAMS)
		allCampOk = allCampOk and l.chunks[l.camp.chunkIndex].ring == PARAMS.StartForestRing
	end
	check("world camp ring over 50 seeds", allCampOk)

	local loaded: { [number]: boolean } = {}
	local toLoad = WorldLayout.streamDiff(a, PARAMS, { camp.position }, loaded, {})
	check("world stream loads near chunks", #toLoad >= 1 and #toLoad < 64)
	for _, i in toLoad do
		loaded[i] = true
	end
	local _, unloadNear = WorldLayout.streamDiff(a, PARAMS, { camp.position }, loaded, {})
	check("world stream stable when still", #unloadNear == 0)
	local far: WorldLayout.Vec2 = { x = camp.position.x + 5000, z = camp.position.z }
	local _, unloadFar = WorldLayout.streamDiff(a, PARAMS, { far }, loaded, {})
	check("world stream unloads far", #unloadFar == #toLoad)
	local _, unloadKeep = WorldLayout.streamDiff(
		a,
		PARAMS,
		{ far },
		loaded,
		{ [camp.chunkIndex] = true }
	)
	check("world stream keeps pinned", #unloadKeep == #toLoad - 1)
end
