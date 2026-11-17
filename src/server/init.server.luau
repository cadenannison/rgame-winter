--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Characters load only after the profile is loaded (SpawnService); must be off before any player can load.
Players.CharacterAutoLoads = false

local Guard = require(script.Net.Guard)
local DataService = require(script.Data.DataService)
local Spawn = require(script.Spawn.SpawnService)
local DebugService = require(script.Debug.DebugService)
local ChunkService = require(script.World.ChunkService)
local DayNightService = require(script.Survival.DayNightService)
local SurvivalService = require(script.Survival.SurvivalService)
local FireService = require(script.Survival.FireService)
local InventoryService = require(script.Items.InventoryService)
local CraftingService = require(script.Items.CraftingService)
local FoodService = require(script.Items.FoodService)
local PlacementService = require(script.Items.PlacementService)
local MobService = require(script.Mobs.MobService)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- Make sure the remote folder and every remote exist before clients connect.
Remotes.createAll()

-- Cross-system wiring (set before start so no request can arrive unwired).
FireService.setWoodSpender(function(player: Player, amount: number): boolean
	return InventoryService.remove(player, "Wood", amount)
end)
FoodService.install()
Spawn.setSpawnProvider(ChunkService.getCampSpawnPosition)

-- Studio-only QA bridge targets (the bridge itself exists only in Studio; see DebugService).
DebugService.expose("Debug", DebugService)
DebugService.expose("Chunk", ChunkService)
DebugService.expose("Fire", FireService)
DebugService.expose("Survival", SurvivalService)
DebugService.expose("Gather", require(script.Items.GatherService))
DebugService.expose("Inventory", InventoryService)
DebugService.expose("Crafting", CraftingService)
DebugService.expose("Placement", PlacementService)
DebugService.expose("Mobs", MobService)

-- Studio-only QA commands (DebugService validates the arg against ItemCatalog / Config.Debug.MobKinds).
local DebugConfig = require(ReplicatedStorage.Shared.Config).Debug
DebugService.register("give", function(player: Player, itemId: unknown)
	InventoryService.add(player, itemId :: string, DebugConfig.GiveCount)
end)
DebugService.register("spawnMob", function(player: Player, kind: unknown)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local at = root.Position + root.CFrame.LookVector * DebugConfig.SpawnMobDistance
		MobService.spawn(kind :: string, at - Vector3.new(0, DebugConfig.SpawnMobDrop, 0))
	end
end)

-- Start systems here, each exactly once. ChunkService before Spawn so the camp exists before any
-- LoadCharacter; Spawn starts after every gameplay system so characters never load unwired.
DataService.start()
DebugService.start() -- no-op outside Studio
ChunkService.start() -- builds the camp chunk, camp fire, and registers tree/rock gather nodes
DayNightService.start()
SurvivalService.start()
FireService.start()
InventoryService.start()
CraftingService.start() -- also starts GatherService
PlacementService.start()
MobService.start()
Spawn.start()

local function onPlayerAdded(player: Player)
	-- Per-player setup goes here.
	print(`Player ready: {player.Name}`)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(Guard.cleanup)

-- PlayerAdded race: handle players who joined before this script ran.
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
