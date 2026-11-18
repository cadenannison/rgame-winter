--!strict
-- Skeleton checks for the World contract (terrain agent owns the full heightAt tests).
local Config = require("../src/shared/Config")
local World = require("../src/shared/logic/World")

return function(check: (string, boolean) -> ())
	check(
		"terrain same seed same height",
		World.heightAt(7, 300, -500) == World.heightAt(7, 300, -500)
	)
	check("terrain flat at origin", World.heightAt(7, 0, 0) == Config.Terrain.BaseHeight)
	local worst = 0
	local size = Config.Terrain.BlockSize
	for seed = 1, 3 do
		for x = -1280, 1276, size * 3 do
			for z = -1280, 1276, size * 3 do
				local h = World.heightAt(seed, x, z)
				worst = math.max(worst, math.abs(h - World.heightAt(seed, x + size, z)))
				worst = math.max(worst, math.abs(h - World.heightAt(seed, x, z + size)))
			end
		end
	end
	check("terrain step within MaxStep", worst <= Config.Terrain.MaxStep)
	check("terrain edge", World.isPastEdge(2000, 0) and not World.isPastEdge(0, 0))
	check("terrain kill height", World.belowKillHeight(-500) and not World.belowKillHeight(0))
end
