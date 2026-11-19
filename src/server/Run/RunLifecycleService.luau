--!strict
-- Run lifecycle: starts the run from validated teleport data, mirrors downed/dead state into RunState,
-- holds disconnected players for Config.Run.RejoinWindowSeconds, ends the run when nobody can act,
-- saves stats through DataService, sends summaries and returns the party to the lobby via TeleportAdapter.
-- Players cannot damage each other: AttackRequest only resolves mobs (MobService), nothing here changes that.
-- Started by init.server (run mode only). Party members who never arrive count as disconnected from the
-- start (held for the rejoin window, then dead). A held player who never rejoins forfeits their payout.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local RunPayout = require(Shared.logic.RunPayout)
local TeleportData = require(Shared.logic.TeleportData)
local ReturnPlan = require(Shared.logic.ReturnPlan)
local Guard = require(script.Parent.Parent.Net.Guard)
local DataService = require(script.Parent.Parent.Data.DataService)
local DebugService = require(script.Parent.Parent.Debug.DebugService)
local DayNightService = require(script.Parent.Parent.Survival.DayNightService)
local SurvivalService = require(script.Parent.Parent.Survival.SurvivalService)
local TeleportAdapter = require(script.Parent.Parent.Party.TeleportAdapter)
local MetaService = require(script.Parent.Parent.Meta.MetaService)
local RunState = require(script.Parent.RunState)

export type Results = {
	daysSurvived: number,
	kills: number,
	bossKills: number,
	cause: string?,
	players: { { userId: number, coinsEarned: number, personalBest: boolean, saved: boolean } },
}

local RunLifecycleService = {}

-- Coins earned by picking up nodes and relics, claimed once per settle (wired from init.server: ForageService).
local forageCreditProvider: ((player: Player) -> number)? = nil

function RunLifecycleService.setForageCreditProvider(fn: ((player: Player) -> number)?)
	forageCreditProvider = fn
end

local run: RunState.Run? = nil
local seed = 0
local studioFallback = false
local ended = false
local started = false
local accumulator = 0
local connections: { RBXScriptConnection } = {}
local callbacks: { (Results) -> () } = {}
local lastResults: Results? = nil
local friendCounts: { [number]: number } = {} -- userId -> party members who are Roblox friends
local settled: { [number]: boolean } = {} -- members already paid out (returned to the lobby early)
local returning: { [Player]: boolean } = {} -- a return teleport is in flight for this player

local function now(): number
	return os.clock()
end

local RETURN_TEXTS: ReturnPlan.Texts = {
	StudioFallback = Config.Run.ReturnStudioText,
	TeleportFailed = Config.Run.ReturnFailedToast,
}

local function toastPlayers(targets: { Player }, text: string)
	for _, p in targets do
		if p.Parent == Players then
			Remotes.event(Remotes.Notify):FireClient(p, Config.Run.ReturnNotifyKind, text)
		end
	end
end

local function returnToLobby(targets: { Player })
	if #targets == 0 then
		return
	end
	local plan = ReturnPlan.decide(RunService:IsStudio(), true, RETURN_TEXTS)
	local current = run
	local partyIds: { number } = current and table.clone(current.order) or {}
	if #partyIds == 0 then
		for _, p in targets do
			table.insert(partyIds, p.UserId)
		end
	end
	local data = TeleportData.build(Config.Teleport.ModeLobby, seed, partyIds)
	local success = false
	if data then
		for attempt = 1, Config.Run.ReturnRetryCount do
			local ok = TeleportAdapter.teleportParty(targets, data) -- never throws
			if ok then
				success = true
				break
			end
			if attempt < Config.Run.ReturnRetryCount then
				task.wait(Config.Teleport.RetryDelay * 2 ^ (attempt - 1))
			end
		end
	end
	if plan.kind == "studioFallback" then
		-- Studio cannot teleport (the adapter fake only records the call): persist the lobby mode override
		-- for the next Test and say so, instead of silently doing nothing.
		if plan.setStudioLobbyMode then
			DebugService.run(targets[1], "mode", Config.Teleport.ModeLobby)
		end
		if plan.toast then
			toastPlayers(targets, plan.toast)
		end
		return
	end
	if not success then
		-- Visible failure; the player stays and can press Return again (the lock clears after SummarySeconds).
		warn("RunLifecycleService: return to lobby failed")
		toastPlayers(targets, ReturnPlan.failureToast(nil, RETURN_TEXTS))
	end
end

local function refuse(player: Player)
	task.spawn(function()
		if player.Parent ~= Players then
			return
		end
		local ok = pcall(function()
			player:Kick(Config.Run.RefusedMessage)
		end)
		if not ok then
			warn("RunLifecycleService: could not refuse player")
		end
	end)
end

local function sendSummary(player: Player, summary: RunPayout.Summary, cause: string?)
	local payload: Remotes.RunSummaryPayload = {
		daysSurvived = summary.daysSurvived,
		kills = summary.kills,
		bossKills = summary.bossKills,
		coinsEarned = summary.coinsEarned,
		personalBest = summary.personalBest,
		newAchievements = summary.newAchievements,
		cause = cause,
		tip = RunPayout.tip(cause),
		previousBest = summary.previousBest,
		rankChange = nil, -- the board lives on lobby servers; the lobby shows rank on return
	}
	Remotes.event(Remotes.RunSummary):FireClient(player, payload)
end

-- Forage coins for this player (0 without a provider or on error). Taken even when the profile is missing,
-- so a credit is never paid twice.
local function claimForageCredit(player: Player): number
	local provider = forageCreditProvider
	if not provider then
		return 0
	end
	local ok, value = pcall(provider, player)
	return if ok and type(value) == "number" then value else 0
end

-- Pays one member out (stats, coins, achievements). Returns the results row plus the summary to show.
local function settle(
	player: Player,
	current: RunState.Run,
	days: number,
	kills: number,
	bossKills: number
): (
	{ userId: number, coinsEarned: number, personalBest: boolean, saved: boolean },
	RunPayout.Summary
)
	local userId = player.UserId
	settled[userId] = true
	local profile = DataService.get(player)
	local member = RunState.get(current, userId)
	local summary = RunPayout.summarize({
		daysSurvived = days,
		kills = kills,
		bossKills = bossKills,
		partners = friendCounts[userId] or 0,
		darkEventsSurvived = if member then member.darkEvents else 0,
		forageCoins = claimForageCredit(player),
	}, profile and profile.maxDays or nil)
	if profile then
		RunPayout.apply(profile, summary)
		local ok, unlocked = pcall(
			MetaService.onRunEnd,
			player,
			#current.order >= 2,
			(friendCounts[userId] or 0) > 0
		)
		if ok and type(unlocked) == "table" then
			summary.newAchievements = unlocked
		end
	else
		summary.coinsEarned = 0 -- nothing saved, nothing shown as earned
	end
	return {
		userId = userId,
		coinsEarned = summary.coinsEarned,
		personalBest = summary.personalBest,
		saved = profile ~= nil,
	},
		summary
end

local function endRun()
	local current = run
	if ended or not current then
		return
	end
	ended = true
	local days = DayNightService.getDay()
	local kills, bossKills = RunState.totals(current)
	local cause = current.cause or Config.Run.DefaultCause
	local results: Results =
		{ daysSurvived = days, kills = kills, bossKills = bossKills, cause = cause, players = {} }
	local present: { Player } = {}
	for _, userId in current.order do
		local player = Players:GetPlayerByUserId(userId)
		if player and not settled[userId] then
			table.insert(present, player)
			local row, summary = settle(player, current, days, kills, bossKills)
			table.insert(results.players, row)
			sendSummary(player, summary, cause)
		end
	end
	lastResults = results
	for _, callback in callbacks do
		local ok = pcall(callback, results)
		if not ok then
			warn("RunLifecycleService: RunEnded callback failed")
		end
	end
	task.delay(Config.Run.SummarySeconds, function()
		local targets: { Player } = {}
		for _, player in present do
			if player.Parent == Players and not returning[player] then
				table.insert(targets, player)
			end
		end
		returnToLobby(targets)
	end)
end

-- Mirrors SurvivalService into RunState for every present member, then expires limits and checks run end.
local function poll()
	local current = run
	if not current or ended then
		return
	end
	local t = now()
	for _, userId in current.order do
		local player = Players:GetPlayerByUserId(userId)
		local status = RunState.status(current, userId)
		if player and status and status ~= "held" and status ~= "dead" then
			local meters = SurvivalService.getMeters(player)
			if meters then
				if meters.dead then
					RunState.setDead(current, userId)
				elseif meters.downed then
					RunState.setDowned(current, userId, t)
				elseif status == "downed" then
					RunState.revive(current, userId, t)
				end
			end
		end
	end
	RunState.tick(current, t)
	if RunState.isOver(current) then
		endRun()
	end
end

local function startRun(partyIds: { number }, runSeed: number)
	local current = RunState.new(partyIds, {
		rejoinWindow = Config.Run.RejoinWindowSeconds,
		reviveLimit = Config.Downed.BleedoutSeconds,
	})
	run = current
	seed = runSeed
	ended = false
	lastResults = nil
	table.clear(friendCounts)
	table.clear(settled)
	-- Members not here yet are held from the start: arriving counts as a rejoin, never arriving = dead.
	local t = now()
	for _, userId in current.order do
		if Players:GetPlayerByUserId(userId) == nil then
			RunState.disconnect(current, userId, t)
		end
	end
end

-- Friend bonus: count party members who are Roblox friends of this player (pcall'd, cached per run).
local function countFriends(player: Player)
	local current = run
	if not current then
		return
	end
	local count = 0
	for _, otherId in current.order do
		if otherId ~= player.UserId then
			local ok, isFriend = pcall(function()
				return player:IsFriendsWithAsync(otherId)
			end)
			if ok and isFriend == true then
				count += 1
			end
		end
	end
	if run == current and player.Parent == Players then
		friendCounts[player.UserId] = count
	end
end

local function onPlayerAdded(player: Player)
	if ended then
		return
	end
	local joinData = player:GetJoinData()
	local parsed = Guard.teleportData(player, joinData.TeleportData, Config.Teleport.ModeRun)
	if not parsed then
		if RunService:IsStudio() and (run == nil or studioFallback) then
			-- Studio has no teleport data: the players present form the party.
			studioFallback = true
			if not run then
				startRun({ player.UserId }, 0)
			else
				RunState.add(run, player.UserId)
			end
			task.spawn(countFriends, player)
		else
			refuse(player)
		end
		return
	end
	if not run then
		startRun(parsed.partyIds, parsed.seed)
	end
	local current = run
	if not current or RunState.get(current, player.UserId) == nil then
		refuse(player)
		return
	end
	task.spawn(countFriends, player)
	local status = RunState.status(current, player.UserId)
	if status == "held" then
		if not RunState.rejoin(current, player.UserId, now()) then
			refuse(player)
		end
	elseif status == "dead" then
		-- Window passed (or died): the run is over for them.
		refuse(player)
	end
end

local function onPlayerRemoving(player: Player)
	returning[player] = nil
	local current = run
	if current and not ended then
		RunState.disconnect(current, player.UserId, now())
	end
end

-- Return-to-lobby request. Allowed for a dead member (spectating) or once the run has ended; a downed or
-- living player cannot leave this way. A member leaving before the run ends is paid out now (days so far)
-- and skipped at run end. Goes through TeleportAdapter (Studio fake records the call and keeps the player).
local function onReturnRequest(player: Player)
	if not Guard.rateLimit(player, "ReturnToLobby", Config.Net.UseRateInterval) then
		return
	end
	local current = run
	if not current or returning[player] then
		return
	end
	local status = RunState.status(current, player.UserId)
	if not ended and status ~= "dead" then
		return
	end
	returning[player] = true
	if not ended and not settled[player.UserId] then
		local kills, bossKills = RunState.totals(current)
		local _row, summary = settle(player, current, DayNightService.getDay(), kills, bossKills)
		sendSummary(player, summary, current.cause or Config.Run.DefaultCause)
	end
	task.spawn(function()
		returnToLobby({ player })
		task.delay(Config.Run.SummarySeconds, function()
			returning[player] = nil -- Studio (no teleport) lets them try again later
		end)
	end)
end

-- Count a kill for a party member (called by MobService wiring in brief 11).
function RunLifecycleService.RecordKill(player: Player, isBoss: boolean)
	local current = run
	if current and not ended then
		RunState.recordKill(current, player.UserId, isBoss)
	end
end

-- A dark event ended with this party member alive (EventService.onEventEnd wiring).
function RunLifecycleService.RecordDarkEventSurvived(player: Player)
	local current = run
	if current and not ended then
		RunState.recordDarkEvent(current, player.UserId)
	end
end

-- Record what downed or killed someone ("Wolf", "Cold"); the last one shown as the cause.
function RunLifecycleService.SetCause(cause: string)
	local current = run
	if current and not ended then
		RunState.setCause(current, cause)
	end
end

-- Fired once at run end, before the summary delay. Returns a disconnect function.
function RunLifecycleService.onRunEnded(callback: (Results) -> ()): () -> ()
	table.insert(callbacks, callback)
	return function()
		local index = table.find(callbacks, callback)
		if index then
			table.remove(callbacks, index)
		end
	end
end

-- True while this player's run state should survive a disconnect (SurvivalService/InventoryService hold).
function RunLifecycleService.ShouldHold(userId: number): boolean
	local current = run
	if not current or ended then
		return false
	end
	local status = RunState.status(current, userId)
	return status == "alive" or status == "downed" or status == "held"
end

-- Studio-only QA: start a run from teleport data as a run server would (lobby-to-run scenario).
function RunLifecycleService.debugBegin(data: unknown): boolean
	if not RunService:IsStudio() then
		return false
	end
	local parsed = TeleportData.parse(data)
	if not parsed or parsed.mode ~= Config.Teleport.ModeRun then
		return false
	end
	startRun(parsed.partyIds, parsed.seed)
	for _, userId in parsed.partyIds do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			task.spawn(countFriends, player)
		end
	end
	return true
end

-- Studio-only QA: end the run now (same path as everyone falling).
function RunLifecycleService.debugEnd(): boolean
	if not RunService:IsStudio() or not run or ended then
		return false
	end
	endRun()
	return true
end

function RunLifecycleService.GetStatus(userId: number): string?
	local current = run
	return current and RunState.status(current, userId)
end

function RunLifecycleService.HasEnded(): boolean
	return ended
end

function RunLifecycleService.GetResults(): Results?
	return lastResults
end

function RunLifecycleService.Start()
	if started then
		return
	end
	started = true
	-- Respawn (SurvivalService.respawn): a downed/dead member becomes alive again in the roster.
	SurvivalService.setRespawnHandler(function(player: Player)
		local current = run
		if current and not ended then
			RunState.respawn(current, player.UserId)
		end
	end)
	table.insert(connections, Players.PlayerAdded:Connect(onPlayerAdded))
	table.insert(connections, Players.PlayerRemoving:Connect(onPlayerRemoving))
	table.insert(
		connections,
		Remotes.event(Remotes.ReturnToLobbyRequest).OnServerEvent:Connect(onReturnRequest)
	)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt: number)
			accumulator += dt
			if accumulator >= Config.Run.PollInterval then
				accumulator = 0
				poll()
			end
		end)
	)
end

function RunLifecycleService.Stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(callbacks)
	run = nil
	ended = false
	started = false
	studioFallback = false
	lastResults = nil
	table.clear(friendCounts)
	table.clear(settled)
	table.clear(returning)
end

return RunLifecycleService
