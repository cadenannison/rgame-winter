--!strict
-- Roblox Terrain voxel adapter for the pure height field (shared/logic/World). Terrain voxels are not
-- BaseParts, so they never count toward Config.Perf.MaxLiveParts. Per chunk: one FillBlock per run of
-- equal-height blocks along X (cheap). Builds are a work queue: a Heartbeat drains it under
-- Config.Terrain.BuildBlocksPerTick / BuildMsPerTick so streaming never hitches (shared/logic/TerrainPlan
-- is the deterministic, resumable cursor). cancel() clears whatever a half-built chunk already filled.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local World = require(Shared:WaitForChild("logic"):WaitForChild("World"))
local TerrainPlan = require(Shared:WaitForChild("logic"):WaitForChild("TerrainPlan"))

local TERRAIN = Config.Terrain
local MS_PER_SECOND = 1000

local BIOME_MATERIAL: { [string]: Enum.Material } = {
	SnowyForest = Enum.Material.Snow,
	FrozenLake = Enum.Material.Ice,
	MountainsCaves = Enum.Material.Rock,
	DeepTundra = Enum.Material.Glacier,
}

local TerrainBuilder = {}

export type Built = { minY: number, maxY: number }
type Job = { key: number, cx: number, cz: number, cursor: TerrainPlan.Cursor, queued: boolean }

local queue: { Job } = {} -- FIFO; ChunkService enqueues nearest first
local jobs: { [number]: Job } = {}
local conn: RBXScriptConnection? = nil

-- Surface material of the biome at (x, z) (site grounding fills use the same one: no grey pads).
function TerrainBuilder.materialAt(x: number, z: number): Enum.Material
	return BIOME_MATERIAL[World.biomeAt(x, z)] or Enum.Material.Snow
end

local function emit(run: TerrainPlan.Run)
	local size = TERRAIN.BlockSize
	local depth = TERRAIN.ColumnDepth
	local material = TerrainBuilder.materialAt(run.x, run.z)
	Workspace.Terrain:FillBlock(
		CFrame.new(run.x + (run.n - 1) * size / 2, run.height - depth / 2, run.z),
		Vector3.new(run.n * size, depth, size),
		material
	)
end

local function builtOf(job: Job): Built
	return { minY = job.cursor.minY, maxY = job.cursor.maxY }
end

-- Takes a job off the work queue (it stays in jobs until cancel() so its filled extent can be cleared).
local function dequeue(job: Job)
	job.queued = false
	local i = table.find(queue, job)
	if i then
		table.remove(queue, i)
	end
end

local function step()
	local blocksLeft = TERRAIN.BuildBlocksPerTick
	local deadline = os.clock() + TERRAIN.BuildMsPerTick / MS_PER_SECOND
	local function overTime(): boolean
		return os.clock() >= deadline
	end
	while blocksLeft > 0 and #queue > 0 and not overTime() do
		local job = queue[1]
		local before = job.cursor.blocksDone
		local done = TerrainPlan.advance(job.cursor, blocksLeft, emit, overTime)
		blocksLeft -= job.cursor.blocksDone - before
		if done then
			dequeue(job)
		end
	end
end

local function ensureConnection()
	if not conn then
		conn = RunService.Heartbeat:Connect(step)
	end
end

-- Queues the chunk square (center cx, cz; side Config.World.ChunkSize) built from the seeded height field.
-- key identifies the job (chunk index). flatX/flatZ: camp position (flat start area).
function TerrainBuilder.queue(
	key: number,
	seed: number,
	cx: number,
	cz: number,
	flatX: number,
	flatZ: number
)
	if jobs[key] then
		return
	end
	local job: Job = {
		key = key,
		cx = cx,
		cz = cz,
		cursor = TerrainPlan.newCursor(seed, cx, cz, flatX, flatZ),
		queued = true,
	}
	jobs[key] = job
	table.insert(queue, job)
	ensureConnection()
end

-- Finishes a queued job now (spawn and teleport loads, which must have ground under the player).
function TerrainBuilder.flush(key: number)
	local job = jobs[key]
	if not job or not job.queued then
		return
	end
	TerrainPlan.advance(job.cursor, TerrainPlan.totalBlocks(), emit, nil)
	dequeue(job)
end

function TerrainBuilder.isPending(key: number): boolean
	local job = jobs[key]
	return job ~= nil and job.queued
end

function TerrainBuilder.pendingCount(): number
	return #queue
end

-- Unload: stops a queued or half-built job and clears the voxels filled so far (Air over the chunk square
-- and the filled Y extent). Also clears a finished chunk. No-op for an unknown key.
function TerrainBuilder.cancel(key: number)
	local job = jobs[key]
	if not job then
		return
	end
	jobs[key] = nil
	dequeue(job)
	if job.cursor.minY <= job.cursor.maxY then
		TerrainBuilder.clear(job.cx, job.cz, builtOf(job))
	end
end

-- Air over the chunk square and a Y extent.
function TerrainBuilder.clear(cx: number, cz: number, built: Built)
	local side = Config.World.ChunkSize
	local height = built.maxY - built.minY + TERRAIN.BlockSize
	Workspace.Terrain:FillBlock(
		CFrame.new(cx, built.minY + height / 2, cz),
		Vector3.new(side, height, side),
		Enum.Material.Air
	)
end

function TerrainBuilder.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	table.clear(queue)
	table.clear(jobs)
end

return TerrainBuilder
