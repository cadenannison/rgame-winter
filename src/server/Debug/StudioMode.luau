--!strict
-- Studio-only server-mode override for "/debug mode run|lobby|clear". The choice lives in a Studio
-- DataStore so it survives into the next Test (the mode is fixed at boot). Inert on published servers.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Guard = require(script.Parent.Parent.Net.Guard)

local D = Config.Debug
local TP = Config.Teleport

local StudioMode = {}

local function getStore(): DataStore?
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(D.ModeStoreName)
	end)
	return if ok then store else nil
end

-- Yields up to Config.Debug.ModeReadTimeout. Returns the stored override or nil (none, no API, timeout).
function StudioMode.read(): string?
	if not RunService:IsStudio() then
		return nil
	end
	local store = getStore()
	if store == nil then
		return nil
	end
	local done = false
	local value: string? = nil
	task.spawn(function()
		local ok, result = pcall(function()
			return store:GetAsync(D.ModeStoreKey)
		end)
		if ok and (result == TP.ModeRun or result == TP.ModeLobby) then
			value = result :: string
		end
		done = true
	end)
	local deadline = os.clock() + D.ModeReadTimeout
	while not done and os.clock() < deadline do
		task.wait()
	end
	return value
end

local function write(arg: string)
	local store = getStore()
	if store == nil then
		warn("[Debug] mode override not saved: DataStore unavailable (enable Studio API access)")
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			if arg == "clear" then
				store:RemoveAsync(D.ModeStoreKey)
			else
				store:SetAsync(D.ModeStoreKey, arg)
			end
		end)
		if ok then
			print(
				`[Debug] next Test server mode: {if arg == "clear"
					then TP.StudioDefaultMode
					else arg}. Stop and press Test again.`
			)
		else
			warn(`[Debug] mode override not saved: {tostring(err)}`)
		end
	end)
end

-- `run` is DebugService.run; wires the command handler and the chat form "/debug mode <arg>" and "/debug gallery <set>".
function StudioMode.start(
	register: (string, (Player, unknown) -> ()) -> () -> (),
	run: (Player, unknown, unknown) -> (boolean, string)
)
	if not RunService:IsStudio() then
		return
	end
	register("mode", function(_player: Player, arg: unknown)
		write(arg :: string)
	end)
	local function hook(player: Player)
		player.Chatted:Connect(function(message: string)
			local command, name, arg = string.match(message, "^/(%a+)%s+(%a+)%s*(%a*)$")
			if
				command ~= "debug"
				or (name ~= "mode" and name ~= "gallery")
				or not Guard.rateLimit(player, "DebugMode", D.CommandRateInterval)
			then
				return
			end
			local ok, reason = run(player, name, arg)
			if not ok then
				warn(`[Debug] /debug {name}: {reason}`)
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

return StudioMode
