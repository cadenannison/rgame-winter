--!strict
-- Pure, resumable terrain build cursor (no Roblox APIs). A chunk's ground is emitted as runs of equal-height
-- blocks along X, row by row. advance() processes at most a block budget per call, so the adapter can spread a
-- chunk over several frames; the emitted runs are identical for any budget (deterministic).

local Config = require("../Config")
local World = require("./World")

export type Run = { x: number, z: number, n: number, height: number } -- x/z = center of the first block, n blocks along +X
export type Cursor = {
	seed: number,
	flatX: number,
	flatZ: number,
	ix0: number,
	iz0: number,
	count: number,
	row: number, -- dz (0-based); count = finished
	col: number, -- run start dx within the row
	pos: number, -- next dx to examine (col < pos <= count)
	runHeight: number?,
	blocksDone: number,
	minY: number,
	maxY: number,
}

local TerrainPlan = {}

function TerrainPlan.newCursor(
	seed: number,
	cx: number,
	cz: number,
	flatX: number,
	flatZ: number
): Cursor
	local size = Config.Terrain.BlockSize
	local half = Config.World.ChunkSize / 2
	local ix0, iz0 = World.blockIndex(cx - half + size / 2, cz - half + size / 2)
	return {
		seed = seed,
		flatX = flatX,
		flatZ = flatZ,
		ix0 = ix0,
		iz0 = iz0,
		count = Config.World.ChunkSize // size,
		row = 0,
		col = 0,
		pos = 1,
		runHeight = nil,
		blocksDone = 0,
		minY = math.huge,
		maxY = -math.huge,
	}
end

function TerrainPlan.isDone(c: Cursor): boolean
	return c.row >= c.count
end

function TerrainPlan.totalBlocks(): number
	local count = Config.World.ChunkSize // Config.Terrain.BlockSize
	return count * count
end

-- Examines up to maxBlocks blocks, calling emit(run) for each completed run. shouldYield (optional) is
-- checked after each emitted run (time budget); at least one block always advances. Returns true when done.
function TerrainPlan.advance(
	c: Cursor,
	maxBlocks: number,
	emit: (Run) -> (),
	shouldYield: (() -> boolean)?
): boolean
	local depth = Config.Terrain.ColumnDepth
	local used = 0
	while c.row < c.count do
		local iz = c.iz0 + c.row
		local runHeight = c.runHeight
		if runHeight == nil then
			runHeight = World.blockHeight(c.seed, c.ix0 + c.col, iz, c.flatX, c.flatZ)
			c.runHeight = runHeight
			c.pos = c.col + 1
		end
		local rh = runHeight :: number
		while c.pos <= c.count do
			if used >= maxBlocks then
				return false
			end
			local h = if c.pos < c.count
				then World.blockHeight(c.seed, c.ix0 + c.pos, iz, c.flatX, c.flatZ)
				else nil
			used += 1
			c.blocksDone += 1
			if h ~= rh then
				local n = c.pos - c.col
				local bx, bz = World.blockCenter(c.ix0 + c.col, iz)
				emit({ x = bx, z = bz, n = n, height = rh })
				c.minY = math.min(c.minY, rh - depth)
				c.maxY = math.max(c.maxY, rh)
				c.col = c.pos
				c.pos += 1
				if h then
					rh = h
					c.runHeight = h
				end
				if shouldYield and shouldYield() and c.pos <= c.count then
					return false
				end
			else
				c.pos += 1
			end
		end
		-- Row finished (the final block always closes its run).
		c.row += 1
		c.col = 0
		c.pos = 1
		c.runHeight = nil
		if used >= maxBlocks and c.row < c.count then
			return false
		end
	end
	return true
end

return TerrainPlan
