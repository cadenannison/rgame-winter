--!strict
-- Fog-of-war map: per-player explored cells, sent only on request and only for explored cells.
-- Never sends unexplored layout. Owner: brief 13.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FogMap = require(Shared:WaitForChild("logic"):WaitForChild("FogMap"))
local Server = ServerScriptService:WaitForChild("Server")
local Guard = require(Server:WaitForChild("Net"):WaitForChild("Guard"))
local InventoryService = require(Server:WaitForChild("Items"):WaitForChild("InventoryService"))

local MAP = Config.Map

local MapService = {}

local fogs: { [Player]: FogMap.Fog } = {}
local requestConn: RBXScriptConnection? = nil
local heartbeatConn: RBXScriptConnection? = nil
local removingConn: RBXScriptConnection? = nil
local accumulator = 0

local function worldSize(): number
	return Config.World.GridSize * Config.World.ChunkSize
end

local function fogFor(player: Player): FogMap.Fog
	local fog = fogs[player]
	if fog == nil then
		fog = FogMap.new(worldSize(), MAP.CellSize)
		fogs[player] = fog
	end
	return fog
end

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp.Position
	end
	return nil
end

-- Reveals cells around a world position for everyone (watchtower viewBonus, flares). Radius is capped.
function MapService.markExplored(position: Vector3, radius: number)
	if type(radius) ~= "number" or radius ~= radius then
		return
	end
	local r = math.clamp(radius, 0, worldSize())
	for _, player in Players:GetPlayers() do
		FogMap.mark(fogFor(player), position.X, position.Z, r)
	end
end

local function onRequest(player: Player)
	-- no payload to type-check; rate limit, then permission (needs the Map item), then act
	if not Guard.rateLimit(player, "MapRequest", Config.Net.MapRateInterval) then
		return
	end
	if InventoryService.count(player, MAP.ItemId) <= 0 then
		Remotes.event(Remotes.Notify):FireClient(player, "gather", "You need a map")
		return
	end
	local fog = fogFor(player)
	local payload: Remotes.MapDataPayload = {
		cellSize = fog.cellSize,
		cellsPerSide = fog.cellsPerSide,
		explored = FogMap.list(fog, MAP.MaxCellsPerPayload),
	}
	Remotes.event(Remotes.MapData):FireClient(player, payload)
end

function MapService.start()
	if heartbeatConn then
		return
	end
	requestConn = Remotes.event(Remotes.MapRequest).OnServerEvent:Connect(onRequest)
	heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < MAP.ExploreTickSeconds then
			return
		end
		accumulator = 0
		for _, player in Players:GetPlayers() do
			local pos = rootPosition(player)
			if pos then
				FogMap.mark(fogFor(player), pos.X, pos.Z, MAP.ExploreRadius)
			end
		end
	end)
	removingConn = Players.PlayerRemoving:Connect(function(player)
		fogs[player] = nil
	end)
end

function MapService.stop()
	if requestConn then
		requestConn:Disconnect()
		requestConn = nil
	end
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
	if removingConn then
		removingConn:Disconnect()
		removingConn = nil
	end
	table.clear(fogs)
end

return MapService
