--!strict
-- The only module that reads or writes persistent data. Session-locked profile per player,
-- backed by ProfileStore (retry/backoff, autosave, save on release and BindToClose).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local ProfileSchema = require(ReplicatedStorage.Shared.logic.ProfileSchema)
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)

export type Profile = ProfileSchema.Profile

-- Minimal view of a ProfileStore profile (the Wally shim does not re-export its types).
type Signal = { Connect: (self: any, listener: () -> ()) -> any }
type Entry = {
	Data: Profile,
	OnSessionEnd: Signal,
	Reconcile: (self: any) -> (),
	-- Queues the final save and lock release (asynchronous; does not yield) and fires OnSessionEnd.
	EndSession: (self: any) -> (),
	-- Queues an immediate save in its own thread (does not yield).
	Save: (self: any) -> (),
}

local DataService = {}

local store = ProfileStore.New(Config.ProfileStoreName, ProfileSchema.default())

local profiles: { [Player]: Entry } = {}
local loadCallbacks: { (Player, Profile) -> () } = {}
local loading: { [Player]: boolean } = {}
local failed: { [Player]: boolean } = {}
local started = false
local shuttingDown = false

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function profileKey(player: Player): string
	return `{Config.ProfileKeyPrefix}{player.UserId}`
end

-- Nil until loaded (and after release). Mutate profile fields only through the owning system's service.
function DataService.get(player: Player): Profile?
	local entry = profiles[player]
	if entry == nil then
		return nil
	end
	return entry.Data
end

-- Queues an immediate save of a loaded profile (Robux grants). Never yields; false if not loaded/failed.
function DataService.save(player: Player): boolean
	local entry = profiles[player]
	if entry == nil then
		return false
	end
	local ok = pcall(function()
		entry:Save()
	end)
	return ok
end

-- Calls callback for every already-loaded player and each future load. Returns a disconnect function.
function DataService.onLoaded(callback: (Player, Profile) -> ()): () -> ()
	table.insert(loadCallbacks, callback)
	for player, entry in profiles do
		task.spawn(callback, player, entry.Data)
	end
	return function()
		local index = table.find(loadCallbacks, callback)
		if index ~= nil then
			table.remove(loadCallbacks, index)
		end
	end
end

local function log(message: string)
	if Config.DEBUG_DATA then
		print(`[Data] {message}`)
	end
end

local function failLoad(player: Player, message: string, alreadyLoaded: boolean?)
	if failed[player] or player.Parent ~= Players then
		return
	end
	failed[player] = true
	-- Never writes anything: no profile was started, so nothing can overwrite existing data.
	warn(`[Data] kicking {player.Name}: {message}`)
	-- Let the client see LoadFailed (drops the loading screen) before the kick.
	if alreadyLoaded ~= true then
		player:SetAttribute(Config.LoadFailedAttribute, true)
	end
	task.delay(Config.LoadFailKickDelay, function()
		if player:IsDescendantOf(game) then
			player:Kick(message)
		end
	end)
end

-- For other services (SpawnService) that cannot get a player into the world: LoadFailed + kick, once.
function DataService.failPlayer(player: Player, message: string)
	failLoad(player, message)
end

local function loadPlayer(player: Player)
	if profiles[player] ~= nil or loading[player] then
		log(`loadPlayer skipped for {player.Name} (already loaded/loading)`)
		return
	end
	loading[player] = true
	log(`loading {player.Name}`)
	if
		RunService:IsStudio()
		and (
			Config.DebugForceLoadFailure
			or ReplicatedStorage:GetAttribute(Config.QAForceFailureAttribute)
				== Config.QAForceData
		)
	then
		loading[player] = nil
		failLoad(player, Config.LoadFailKickMessage)
		return
	end

	local startClock = os.clock()
	local timedOut = false
	local attempts = 0
	-- Watchdog: even if StartSessionAsync is stuck, nobody is left in limbo past the timeout.
	local watchdog = task.delay(Config.DATA_LOAD_TIMEOUT, function()
		if loading[player] then
			timedOut = true
			warn(`[Data] load timeout for {player.Name} after {Config.DATA_LOAD_TIMEOUT}s`)
			failLoad(player, Config.LoadFailKickMessage)
		end
	end)

	log(`StartSessionAsync begin {player.Name}`)
	local ok, result = pcall(function()
		return store:StartSessionAsync(profileKey(player), {
			Cancel = function()
				-- Polled by ProfileStore while it waits on a session lock or retries a failed request.
				attempts += 1
				local elapsed = os.clock() - startClock
				if attempts > 1 then
					log(
						`retry #{attempts - 1} for {player.Name} ({math.floor(elapsed * 1000)}ms elapsed, session lock held or request failed)`
					)
				end
				return player.Parent ~= Players or timedOut or elapsed >= Config.DATA_LOAD_TIMEOUT
			end,
		})
	end)
	task.cancel(watchdog)
	local entry = if ok then result else nil
	local elapsedMs = math.floor((os.clock() - startClock) * 1000)

	if not ok then
		warn(
			`[Data] StartSessionAsync errored for {player.Name} after {elapsedMs}ms: {tostring(
				result
			)}`
		)
	end
	if entry == nil then
		warn(`[Data] load failed for {player.Name} after {elapsedMs}ms`)
		loading[player] = nil
		failLoad(player, Config.LoadFailKickMessage)
		return
	end
	if timedOut or player.Parent ~= Players then
		log(`late/abandoned session for {player.Name}; ending without changes`)
		loading[player] = nil
		entry:EndSession()
		return
	end
	-- Unusable or newer-schema data: release without altering it and kick.
	-- Migrate a copy; stored data is replaced only if migration and validation both pass.
	local migrated: any = deepCopy(entry.Data)
	local migrateOk = ProfileSchema.migrate(migrated)
	if not migrateOk or not ProfileSchema.validate(migrated) then
		warn(`[Data] profile for {player.Name} failed migration/validation`)
		loading[player] = nil
		entry:EndSession()
		failLoad(player, Config.LoadFailKickMessage)
		return
	end
	local data: any = entry.Data
	for k in data do
		data[k] = nil
	end
	for k, v in migrated do
		data[k] = v
	end
	entry:Reconcile()

	entry.OnSessionEnd:Connect(function()
		log(`session end for {player.Name}`)
		-- Self-initiated ends (release, shutdown) already cleared profiles[player]; only kick otherwise.
		if profiles[player] ~= entry or player.Parent ~= Players then
			return
		end
		profiles[player] = nil
		log(`profile released (session ended externally) for {player.Name}`)
		if shuttingDown then
			return
		end
		failLoad(player, Config.SessionEndKickMessage, true)
	end)

	loading[player] = nil
	profiles[player] = entry
	log(`profile stored for {player.Name}`)
	log(`loaded {player.Name} in {elapsedMs}ms`)
	for _, callback in loadCallbacks do
		task.spawn(callback, player, entry.Data)
	end
end

local function releasePlayer(player: Player)
	loading[player] = nil
	failed[player] = nil
	local entry = profiles[player]
	if entry ~= nil then
		log(`save on leave {player.Name}`)
		profiles[player] = nil
		log(`profile released for {player.Name}`)
		entry:EndSession() -- queues the final save + lock release; ProfileStore completes it in the background
	end
end

-- Idempotent. Autosave and BindToClose saving are handled by ProfileStore.
function DataService.start()
	log(`start() called (already started: {started})`)
	if started then
		return
	end
	started = true
	ProfileStore.SetConstant("AUTO_SAVE_PERIOD", Config.AutoSavePeriod)
	Players.PlayerAdded:Connect(function(player)
		log(`PlayerAdded {player.Name}`)
		task.spawn(loadPlayer, player)
	end)
	Players.PlayerRemoving:Connect(releasePlayer)
	-- ProfileStore saves every live session on shutdown; this only reports it.
	game:BindToClose(function()
		shuttingDown = true
		local count = 0
		for _ in profiles do
			count += 1
		end
		log(`BindToClose: ProfileStore saving {count} active profile(s)`)
	end)
	-- PlayerAdded race: players who joined before start.
	for _, player in Players:GetPlayers() do
		log(`existing player {player.Name}`)
		task.spawn(loadPlayer, player)
	end
end

return DataService
