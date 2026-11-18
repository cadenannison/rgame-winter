--!strict
-- Pure, seed-deterministic terrain height (no Roblox APIs). Owner: contracts round; heightAt tests: terrain agent.
-- Terrain is a grid of flat-topped square blocks (Config.Terrain.BlockSize). heightAt returns the block top Y.
-- Smooth: two octaves of smoothstep value noise scaled by a per-biome amplitude that blends across ring
-- boundaries and flattens to BaseHeight around an optional flat centre (camp). Edge-adjacent blocks differ
-- by at most Config.Terrain.MaxStep (verified by a scan test, not enforced per call).

local Config = require("../Config")
local Biomes = require("../data/Biomes")
local WorldLayout = require("./WorldLayout")

local World = {}

local MOD = 4294967296

local function hash(seed: number, a: number, b: number, octave: number): number
	local h = bit32.bxor(
		(seed * 2654435 + octave * 40503) % MOD,
		(a * 374761393) % MOD,
		(b * 668265263) % MOD
	)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = (h * 1274126177) % MOD
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = (h * 2246822519) % MOD
	h = bit32.bxor(h, bit32.rshift(h, 15))
	return h / MOD * 2 - 1 -- [-1, 1)
end

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

local function valueNoise(
	seed: number,
	x: number,
	z: number,
	wavelength: number,
	octave: number
): number
	local fx, fz = x / wavelength, z / wavelength
	local ix, iz = math.floor(fx), math.floor(fz)
	local tx, tz = smooth(fx - ix), smooth(fz - iz)
	local a = hash(seed, ix, iz, octave)
	local b = hash(seed, ix + 1, iz, octave)
	local c = hash(seed, ix, iz + 1, octave)
	local d = hash(seed, ix + 1, iz + 1, octave)
	local top = a + (b - a) * tx
	local bottom = c + (d - c) * tx
	return top + (bottom - top) * tz
end

-- World half extent in studs (map is square, centred on the origin).
function World.halfExtent(): number
	return Config.World.GridSize * Config.World.ChunkSize / 2
end

-- Biome ring (0 = centre) of a position.
function World.ringAt(x: number, z: number): number
	local ring = math.floor(math.max(math.abs(x), math.abs(z)) / Config.World.ChunkSize)
	return math.clamp(ring, 0, WorldLayout.maxRing(Config.World.GridSize))
end

-- Biome id ("SnowyForest", "FrozenLake", "MountainsCaves", "DeepTundra") at a position.
function World.biomeAt(x: number, z: number): string
	return Biomes.forRing(World.ringAt(x, z)).id
end

local function ringAmplitude(ring: number): number
	local def = Config.Terrain.Biomes[Biomes.forRing(ring).id]
	return if def then def.Amplitude else 0
end

-- Blended per-biome amplitude at a position. The blend zone at each ring boundary lies entirely inside
-- the ring with the LARGER amplitude, so a low-relief biome (frozen lake) never exceeds its own amplitude.
function World.amplitudeAt(x: number, z: number): number
	local t = Config.Terrain
	local chunk = Config.World.ChunkSize
	local maxRing = WorldLayout.maxRing(Config.World.GridSize)
	local d = math.max(math.abs(x), math.abs(z))
	local ring = World.ringAt(x, z)
	if ring < maxRing then -- outer boundary of this ring (ring + 1)
		local a0, a1 = ringAmplitude(ring), ringAmplitude(ring + 1)
		local start = (ring + 1) * chunk - t.BlendWidth
		if a0 > a1 and d > start then
			return a0 + (a1 - a0) * smooth((d - start) / t.BlendWidth)
		end
	end
	if ring > 0 then -- inner boundary of this ring (ring)
		local a0, a1 = ringAmplitude(ring - 1), ringAmplitude(ring)
		local stop = ring * chunk + t.BlendWidth
		if a1 > a0 and d < stop then
			return a0 + (a1 - a0) * smooth((d - ring * chunk) / t.BlendWidth)
		end
	end
	return ringAmplitude(ring)
end

-- Block grid ----------------------------------------------------------------------------------------

-- Integer block indices containing (x, z).
function World.blockIndex(x: number, z: number): (number, number)
	local size = Config.Terrain.BlockSize
	return math.floor(x / size), math.floor(z / size)
end

-- World-space centre (x, z) of block (ix, iz).
function World.blockCenter(ix: number, iz: number): (number, number)
	local size = Config.Terrain.BlockSize
	return (ix + 0.5) * size, (iz + 0.5) * size
end

-- Min corner (x, z) of the block containing (x, z): the origin used to snap parts/voxels.
function World.blockOrigin(x: number, z: number): (number, number)
	local size = Config.Terrain.BlockSize
	return math.floor(x / size) * size, math.floor(z / size) * size
end

-- Block top height of block (ix, iz). flatX/flatZ: optional flat centre (camp); default the origin.
function World.blockHeight(
	seed: number,
	ix: number,
	iz: number,
	flatX: number?,
	flatZ: number?
): number
	local t = Config.Terrain
	local cx, cz = World.blockCenter(ix, iz)
	local amp = World.amplitudeAt(cx, cz)
	local dist = math.sqrt((cx - (flatX or 0)) ^ 2 + (cz - (flatZ or 0)) ^ 2)
	local ramp = math.clamp((dist - t.CampFlatRadius) / t.CampRampWidth, 0, 1)
	amp *= smooth(ramp)
	if amp <= 0 then
		return t.BaseHeight
	end
	local low = valueNoise(seed, cx, cz, t.LowWavelength, 1)
	local high = valueNoise(seed, cx, cz, t.HighWavelength, 2)
	local n = low * t.LowShare + high * (1 - t.LowShare)
	local h = n * amp
	return t.BaseHeight + math.floor(h / t.HeightQuantum + 0.5) * t.HeightQuantum
end

-- Terrain top Y at (x, z): pure function of (seed, x, z[, flat centre]). Same seed => same height.
function World.heightAt(seed: number, x: number, z: number, flatX: number?, flatZ: number?): number
	local ix, iz = World.blockIndex(x, z)
	return World.blockHeight(seed, ix, iz, flatX, flatZ)
end

-- Edge / kill ---------------------------------------------------------------------------------------

-- True when (x, z) is beyond the world border by more than Terrain.EdgeMargin (the player fell off).
function World.isPastEdge(x: number, z: number): boolean
	return math.max(math.abs(x), math.abs(z)) > World.halfExtent() + Config.Terrain.EdgeMargin
end

-- True when a root Y is below the kill height.
function World.belowKillHeight(y: number): boolean
	return y < Config.Terrain.KillHeight
end

-- Either condition: the character should be killed/respawned.
function World.shouldKill(x: number, y: number, z: number): boolean
	return World.belowKillHeight(y) or World.isPastEdge(x, z)
end

return World
