--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)

export type MetersPayload = {
	health: number,
	warmth: number,
	hunger: number,
	day: number,
	isNight: boolean,
}
export type ItemStack = { id: string, count: number, durability: number? }
export type InventoryPayload = {
	slots: { [number]: ItemStack? }, -- full snapshot, index = slot
	selected: number,
	equipment: { [string]: ItemStack }?, -- worn gear, Config.Equipment.Slots id -> stack (Items round)
}
export type CraftPayload = { recipeId: string }
export type PlacePayload = { structureId: string, position: Vector3, rotationY: number }
export type GatherPayload = { node: Instance }
export type AttackPayload = { target: Instance? } -- server validates range, cooldown, weapon
-- Phase 2 (lobby, party, run end, daily reward). UserIds are numbers; times are os.time() seconds.
export type PadJoinPayload = { padIndex: number } -- 1..Config.Lobby.PadCount
export type PadModePayload = { mode: string } -- Config.Lobby.PadModeFriends | PadModeOpen; host only
export type PadState = {
	index: number, -- 1..Config.Lobby.PadCount
	capacity: number, -- max players (pad i holds i)
	mode: string, -- Config.Lobby.PadModeFriends | PadModeOpen
	hostId: number?, -- UserId of the host; nil when empty
	memberIds: { number }, -- UserIds in join order (host first)
	endsAt: number?, -- workspace:GetServerTimeNow() when the timer ends; nil when idle
	launching: boolean, -- true while the teleport is in flight
}
export type PartyStatePayload = { pads: { PadState } } -- full snapshot of every pad
export type RunSummaryPayload = {
	daysSurvived: number,
	kills: number,
	bossKills: number,
	coinsEarned: number,
	personalBest: boolean, -- daysSurvived beat the saved maxDays
	newAchievements: { string }, -- achievement ids unlocked this run
	cause: string?, -- "what got you" (e.g. "Wolf", "Cold"); nil if the party won/left
	tip: string?, -- one short tip line
	-- Phase 4 (optional; brief 19 fills): personal best before this run, leaderboard rank change (+ = up)
	previousBest: number?,
	rankChange: number?,
}
export type DailyClaimResultPayload = {
	ok: boolean,
	coins: number, -- coins granted (0 when not ok)
	nextClaimAt: number, -- os.time() when the next claim opens
}
-- Phase 3 (brief 12 contracts). Hidden metrics (Dread, hunt chance, event timers) are never in any payload.
export type PingPayload = { kind: string, position: Vector3 } -- kind in Config.Ping.Kinds; within Config.Ping.MaxRange
export type PingBroadcastPayload = {
	fromUserId: number,
	kind: string,
	position: Vector3,
	expiresAt: number, -- workspace:GetServerTimeNow() (a ping's lifetime is not a hidden metric)
}
export type StorageOpenPayload = { chest: Instance } -- a placed StorageChest within Config.Storage.OpenRange
export type StorageDepositPayload = { chest: Instance, slot: number, count: number } -- player inventory slot
export type StorageWithdrawPayload = { chest: Instance, chestSlot: number, count: number } -- 1..Config.Storage.ChestSlots
export type StorageStatePayload = {
	chest: Instance?, -- nil = closed (out of range, destroyed or StorageCloseRequest)
	slots: { [number]: ItemStack? }, -- full snapshot, index = chest slot
	id: string?, -- chest id string (address id for {kind="chest"})
	rev: number?, -- Config.Storage.RevisionAttribute at snapshot time
}
-- Items round: one move path. Addresses: {kind="inv",slot} | {kind="equip",slot=<slot id>} | {kind="chest",id,slot}.
export type InventoryAddr = { kind: string, slot: number | string, id: string? }
export type InventoryMovePayload = {
	from: InventoryAddr,
	to: InventoryAddr?, -- nil = quick move (shift-click)
	count: number,
	rev: number?, -- chest revision the client saw
	expect: string?, -- item id the client saw at `from` (stale-revision resolution)
}
export type SprintPayload = { active: boolean } -- sprint wanted (hold Shift / touch toggle); server validates and sets speed
export type DropItemPayload = { slot: number, count: number } -- explicit Drop of an inventory stack (or part)
export type InventoryMoveResultPayload = { ok: boolean, reason: string, from: InventoryAddr? }
-- Fog-of-war: explored cells only (1-based row-major index over cellsPerSide^2), never unexplored layout.
export type MapDataPayload = {
	cellSize: number, -- Config.Map.CellSize
	cellsPerSide: number,
	explored: { number }, -- at most Config.Map.MaxCellsPerPayload entries
}
export type RepairPayload = { slot: number } -- inventory slot of a repairable item
export type CookPayload = { slot: number, station: Instance } -- raw food slot; lit campfire or cooking station
export type ShootPayload = { direction: Vector3 } -- unit vector; server uses its own character origin
export type ProjectileFiredPayload = {
	shooterId: number,
	origin: Vector3,
	direction: Vector3,
	speed: number,
} -- visual tracer only; hits are server-resolved
export type DoorTogglePayload = { door: Instance }
-- Sensory cue. kind in Config.Cue.Kinds; level is a coarse 0..Config.Cue.MaxLevel bucket, never a raw value.
export type CuePayload = {
	kind: string,
	level: number?,
	position: Vector3?,
	event: string?, -- EventStart/EventEnd: Events.Dark id or "Blizzard"
}

-- Phase 4 (brief 21 contracts). The client sends ids only; the server recomputes prices, ownership,
-- milestones and caps from data/Shop.luau, data/Achievements.luau and Config.Meta. No hidden metric here.
export type ShopBuyPayload = { itemId: string } -- data/Shop id with currency "coins"
export type RobuxPurchasePayload = { itemId: string } -- data/Shop id with currency "robux"; server prompts
-- reason when not ok: "owned" | "coins" | "locked" | "unavailable" | "cancelled" | "failed"
export type PurchaseResultPayload = {
	ok: boolean,
	itemId: string,
	coins: number, -- coin balance after the purchase
	reason: string?,
}
export type EquipPayload = { id: string } -- owned cosmetic / perk / title id; "" = unequip
export type SettingsSetPayload = { key: string, value: boolean } -- key in Config.Settings.Keys
export type HintSeenPayload = { hintId: string } -- Config.Hints.Ids entry
export type AchievementUnlockedPayload = {
	id: string, -- data/Achievements id
	coins: number, -- coins granted
	title: string?, -- title id granted, if any
}
export type SwingPayload = { userId: number } -- accepted swing by this player (visual only)
-- Full snapshot of the player's own meta state; sent on load and after every change (never per tick).
export type MetaStatePayload = {
	coins: number,
	stats: { [string]: number }, -- ProfileSchema.STAT_FIELDS + PROGRESS_FIELDS (all player-visible)
	achievements: { string }, -- unlocked ids
	ownedCosmetics: { string },
	equippedCosmetic: string,
	equippedPerk: string,
	unlockedGear: { string },
	titles: { string },
	equippedTitle: string,
	settings: { reduceScares: boolean },
	hintsSeen: { string },
}
-- Loot round. Chests are tagged Config.Loot.ChestTag; contents are rolled and kept on the server only.
export type LootOpenPayload = { chest: Instance } -- within Config.Loot.ServerOpenRange; one open per chest
export type LootOpenedPayload = {
	chest: Instance, -- the chest that was just looted
	rarity: string, -- chest rarity (Config.Loot.Rarities)
	items: { ItemStack }, -- what this player received (already in their inventory; overflow stays in the chest)
	overflow: boolean, -- inventory was full: some stacks remain in the chest (chest stays unlooted)
}

local Remotes = {}

-- Remote names (one RemoteEvent per intent). Document payload types and direction here.
Remotes.Notify = "Notify" -- server -> client (kind: string, text: string)
-- Phase 1 (payload types above; client -> server unless noted; server re-validates everything)
Remotes.MetersUpdate = "MetersUpdate" -- server -> client (MetersPayload)
Remotes.InventoryUpdate = "InventoryUpdate" -- server -> client (InventoryPayload)
Remotes.CraftRequest = "CraftRequest" -- client -> server (recipeId: string)
Remotes.PlaceRequest = "PlaceRequest" -- client -> server (structureId: string, position: Vector3, rotationY: number)
Remotes.GatherRequest = "GatherRequest" -- client -> server (node: Instance)
Remotes.AttackRequest = "AttackRequest" -- client -> server (target: Instance?)
Remotes.SelectSlotRequest = "SelectSlotRequest" -- client -> server (slot: number)
Remotes.UseItemRequest = "UseItemRequest" -- client -> server (slot: number), eat/consume
Remotes.AddFuelRequest = "AddFuelRequest" -- client -> server (fire: Instance), spends wood from inventory
Remotes.UpgradeFireRequest = "UpgradeFireRequest" -- client -> server (fire: Instance), spends the tier upgrade cost
Remotes.ReviveRequest = "ReviveRequest" -- client -> server (target: Player)
Remotes.ReturnToLobbyRequest = Config.Downed.ReturnRemoteName -- client -> server (no payload); dead member or ended run only
-- Phase 2 (payload types above)
Remotes.PadJoinRequest = "PadJoinRequest" -- client -> server (PadJoinPayload); stepping on a pad is also detected server-side
Remotes.PadLeaveRequest = "PadLeaveRequest" -- client -> server (no payload); leave the current pad
Remotes.PadModeRequest = "PadModeRequest" -- client -> server (PadModePayload); host sets friends-only / open-fill
Remotes.PartyState = "PartyState" -- server -> client (PartyStatePayload); sent on every pad change, not per tick
Remotes.RunSummary = "RunSummary" -- server -> client (RunSummaryPayload); once per player at run end
Remotes.DailyClaimRequest = "DailyClaimRequest" -- client -> server (no payload); server checks lastDailyClaim
Remotes.DailyClaimResult = "DailyClaimResult" -- server -> client (DailyClaimResultPayload)
-- Phase 3 (payload types above)
Remotes.PingRequest = "PingRequest" -- client -> server (PingPayload); ping wheel
Remotes.PingBroadcast = "PingBroadcast" -- server -> party clients (PingBroadcastPayload)
Remotes.StorageOpenRequest = "StorageOpenRequest" -- client -> server (StorageOpenPayload)
Remotes.StorageCloseRequest = "StorageCloseRequest" -- client -> server (no payload)
Remotes.StorageDepositRequest = "StorageDepositRequest" -- client -> server (StorageDepositPayload)
Remotes.StorageWithdrawRequest = "StorageWithdrawRequest" -- client -> server (StorageWithdrawPayload)
Remotes.StorageState = "StorageState" -- server -> client (StorageStatePayload); on open and on every change
Remotes.MapRequest = "MapRequest" -- client -> server (no payload); needs Config.Map.ItemId in inventory
Remotes.MapData = "MapData" -- server -> client (MapDataPayload)
Remotes.RepairRequest = "RepairRequest" -- client -> server (RepairPayload); near Config.Repair.Station
Remotes.CookRequest = "CookRequest" -- client -> server (CookPayload)
Remotes.ShootRequest = "ShootRequest" -- client -> server (ShootPayload); ranged weapon in the selected slot
Remotes.ProjectileFired = "ProjectileFired" -- server -> all clients (ProjectileFiredPayload); once per shot
Remotes.DoorToggleRequest = "DoorToggleRequest" -- client -> server (DoorTogglePayload); party members only
Remotes.Cue = "Cue" -- server -> client (CuePayload); on change only, never per tick
-- Phase 4 (payload types above)
Remotes.ShopBuyRequest = "ShopBuyRequest" -- client -> server (ShopBuyPayload); lobby only
Remotes.RobuxPurchaseRequest = "RobuxPurchaseRequest" -- client -> server (RobuxPurchasePayload); server prompts
Remotes.PurchaseResult = "PurchaseResult" -- server -> client (PurchaseResultPayload); coins and Robux
Remotes.EquipCosmeticRequest = "EquipCosmeticRequest" -- client -> server (EquipPayload)
Remotes.EquipPerkRequest = "EquipPerkRequest" -- client -> server (EquipPayload); lobby only, one perk
Remotes.EquipTitleRequest = "EquipTitleRequest" -- client -> server (EquipPayload)
Remotes.SettingsSetRequest = "SettingsSetRequest" -- client -> server (SettingsSetPayload)
Remotes.HintSeenRequest = "HintSeenRequest" -- client -> server (HintSeenPayload); first-run hint dismissed
Remotes.MetaStateRequest = "MetaStateRequest" -- client -> server (no payload); resend MetaState
Remotes.MetaState = "MetaState" -- server -> client (MetaStatePayload)
Remotes.AchievementUnlocked = "AchievementUnlocked" -- server -> client (AchievementUnlockedPayload); toast
Remotes.SwingBroadcast = "SwingBroadcast" -- server -> other nearby clients (SwingPayload); once per accepted swing
-- Loot round (payload types above)
Remotes.LootOpenRequest = "LootOpenRequest" -- client -> server (LootOpenPayload); handler: type, range, Guard, state (unlooted, near), roll/grant
Remotes.LootOpened = "LootOpened" -- server -> opening client (LootOpenedPayload); once per open, for feedback/visuals
-- Items round (inventory revamp)
Remotes.InventoryMove = "InventoryMove" -- client -> server (InventoryMovePayload); hotbar, grid, equipment, chests
Remotes.InventoryMoveResult = "InventoryMoveResult" -- server -> client (InventoryMoveResultPayload); refusals only
Remotes.DropItemRequest = "DropItemRequest" -- client -> server (DropItemPayload); the only way items leave the inventory
Remotes.SprintRequest = "SprintRequest" -- client -> server (SprintPayload); server gates on hunger/downed/dead, Guard Sprint.RateInterval
Remotes.DebugCommand = "DebugCommand" -- client -> server, Studio only (command: string, arg: any); not in Remotes.all

-- Every remote the server creates eagerly at startup (so clients never wait on a missing folder).
Remotes.all = {
	Remotes.Notify,
	Remotes.MetersUpdate,
	Remotes.InventoryUpdate,
	Remotes.CraftRequest,
	Remotes.PlaceRequest,
	Remotes.GatherRequest,
	Remotes.AttackRequest,
	Remotes.SelectSlotRequest,
	Remotes.UseItemRequest,
	Remotes.AddFuelRequest,
	Remotes.UpgradeFireRequest,
	Remotes.ReviveRequest,
	Remotes.ReturnToLobbyRequest,
	Remotes.PadJoinRequest,
	Remotes.PadLeaveRequest,
	Remotes.PadModeRequest,
	Remotes.PartyState,
	Remotes.RunSummary,
	Remotes.DailyClaimRequest,
	Remotes.DailyClaimResult,
	Remotes.PingRequest,
	Remotes.PingBroadcast,
	Remotes.StorageOpenRequest,
	Remotes.StorageCloseRequest,
	Remotes.StorageDepositRequest,
	Remotes.StorageWithdrawRequest,
	Remotes.StorageState,
	Remotes.MapRequest,
	Remotes.MapData,
	Remotes.RepairRequest,
	Remotes.CookRequest,
	Remotes.ShootRequest,
	Remotes.ProjectileFired,
	Remotes.DoorToggleRequest,
	Remotes.Cue,
	Remotes.ShopBuyRequest,
	Remotes.RobuxPurchaseRequest,
	Remotes.PurchaseResult,
	Remotes.EquipCosmeticRequest,
	Remotes.EquipPerkRequest,
	Remotes.EquipTitleRequest,
	Remotes.SettingsSetRequest,
	Remotes.HintSeenRequest,
	Remotes.MetaStateRequest,
	Remotes.MetaState,
	Remotes.AchievementUnlocked,
	Remotes.SwingBroadcast,
	Remotes.LootOpenRequest,
	Remotes.LootOpened,
	Remotes.InventoryMove,
	Remotes.InventoryMoveResult,
	Remotes.DropItemRequest,
	Remotes.SprintRequest,
}

local function getFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(Config.RemoteFolderName)
	if existing then
		return existing :: Folder
	end
	if RunService:IsServer() then
		local folder = Instance.new("Folder")
		folder.Name = Config.RemoteFolderName
		folder.Parent = ReplicatedStorage
		return folder
	end
	return ReplicatedStorage:WaitForChild(Config.RemoteFolderName) :: Folder
end

-- Server creates the event lazily; the client waits for it.
function Remotes.event(name: string): RemoteEvent
	local folder = getFolder()
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing :: RemoteEvent
	end
	if RunService:IsServer() then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

-- Server only: create the folder and every remote.
function Remotes.createAll()
	for _, name in Remotes.all do
		Remotes.event(name)
	end
end

return Remotes
