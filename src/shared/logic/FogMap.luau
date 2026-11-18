--!strict
-- Pure fog-of-war grid. World is centred on (0, 0); cells are 1-based row-major over cellsPerSide^2.
-- Only explored cells are ever exposed. Owner: brief 13.

export type Fog = {
	cellSize: number,
	cellsPerSide: number,
	explored: { [number]: boolean },
	count: number,
}

local FogMap = {}

function FogMap.new(worldSize: number, cellSize: number): Fog
	return {
		cellSize = cellSize,
		cellsPerSide = math.ceil(worldSize / cellSize),
		explored = {},
		count = 0,
	}
end

local function axis(fog: Fog, v: number): number
	local half = fog.cellsPerSide * fog.cellSize / 2
	return math.clamp(math.floor((v + half) / fog.cellSize) + 1, 1, fog.cellsPerSide)
end

function FogMap.cellIndex(fog: Fog, x: number, z: number): number
	return (axis(fog, z) - 1) * fog.cellsPerSide + axis(fog, x)
end

-- Marks cells whose centre lies within radius of (x, z). Returns how many were newly explored.
function FogMap.mark(fog: Fog, x: number, z: number, radius: number): number
	local added = 0
	local lo_x, hi_x = axis(fog, x - radius), axis(fog, x + radius)
	local lo_z, hi_z = axis(fog, z - radius), axis(fog, z + radius)
	local half = fog.cellsPerSide * fog.cellSize / 2
	for cz = lo_z, hi_z do
		for cx = lo_x, hi_x do
			local px = (cx - 0.5) * fog.cellSize - half
			local pz = (cz - 0.5) * fog.cellSize - half
			if (px - x) ^ 2 + (pz - z) ^ 2 <= radius ^ 2 then
				local index = (cz - 1) * fog.cellsPerSide + cx
				if not fog.explored[index] then
					fog.explored[index] = true
					fog.count += 1
					added += 1
				end
			end
		end
	end
	local own = FogMap.cellIndex(fog, x, z)
	if not fog.explored[own] then
		fog.explored[own] = true
		fog.count += 1
		added += 1
	end
	return added
end

-- Sorted explored indices, at most maxCells.
function FogMap.list(fog: Fog, maxCells: number): { number }
	local out: { number } = {}
	for index in fog.explored do
		table.insert(out, index)
	end
	table.sort(out)
	while #out > maxCells do
		table.remove(out)
	end
	return out
end

return FogMap
