--!strict
-- Phase 3 server boot hook for brief 13 (WorldGen). ChunkService (and PoiService through it) is started
-- by init.server before this; this starts the biome ring tracker and the fog-of-war map.
-- Cross-brief setters (thin-ice cold shock, hearth fuel item, mob bias near hot springs) are wired by brief 18.

local ServerScriptService = game:GetService("ServerScriptService")

local World = ServerScriptService:WaitForChild("Server"):WaitForChild("World")
local BiomeService = require(World:WaitForChild("BiomeService"))
local MapService = require(World:WaitForChild("MapService"))

local WorldGenBoot = {}

function WorldGenBoot.start()
	BiomeService.start()
	MapService.start()
end

return WorldGenBoot
