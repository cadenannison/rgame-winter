--!strict
-- Studio-only client QA bridge. MCP execute_luau on the Client datamodel runs in another VM (fresh
-- module copies), so it reaches the live HUD input handlers through a BindableFunction in
-- PlayerScripts: bridge:Invoke(fn, ...) -> results. The handlers are the same functions keys, clicks
-- and taps call, so QA exercises the real client path (prediction, feedback, remotes). Inert outside Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local QABridge = {}

-- api: name -> handler. Returns a cleanup function (no-op when not in Studio).
function QABridge.start(api: { [string]: (...any) -> ...any }): () -> ()
	if not RunService:IsStudio() then
		return function() end
	end
	local scripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
	local old = scripts:FindFirstChild(Config.Debug.ClientBridgeName)
	if old then
		old:Destroy()
	end
	local bridge = Instance.new("BindableFunction")
	bridge.Name = Config.Debug.ClientBridgeName
	bridge.OnInvoke = function(fn: unknown, ...: any): ...any
		if type(fn) ~= "string" or type(api[fn]) ~= "function" then
			error(`client bridge: unknown fn {tostring(fn)}`)
		end
		return api[fn](...)
	end
	bridge.Parent = scripts
	return function()
		bridge:Destroy()
	end
end

return QABridge
