--!strict
-- Shared client view of lobby state: latest PartyState pads, mode check, toasts and sounds.
-- Display only; everything comes from server remotes/attributes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Assets = require(Shared:WaitForChild("Assets"))
local LobbyLogic = require(Shared:WaitForChild("logic"):WaitForChild("LobbyLogic"))
local LobbyConfig = require(script.Parent.LobbyConfig)

export type State = {
	pads: { LobbyLogic.Pad },
	lastToast: string, -- most recent toast text (QA reads it)
	isLobby: () -> boolean,
	subscribe: (() -> ()) -> () -> (),
	setPads: ({ LobbyLogic.Pad }) -> (),
	toast: (string) -> (),
	play: (string) -> (),
	cue: (string) -> (), -- AudioCues key through AtmosphereFx (nil-safe; never also play()ed)
	destroy: () -> (),
}

local LobbyState = {}

-- gui hosts the toast and sounds; destroy() clears the toast timer and listeners.
function LobbyState.new(gui: ScreenGui): State
	local listeners: { () -> () } = {}
	local destroyed = false
	local toastToken = 0

	local toastLabel = Instance.new("TextLabel")
	toastLabel.Name = "LobbyToast"
	toastLabel.AnchorPoint = Vector2.new(0.5, 0)
	toastLabel.Position = UDim2.fromScale(0.5, 0.12)
	toastLabel.Size = UDim2.fromOffset(360, 36)
	toastLabel.BackgroundColor3 = LobbyConfig.PanelColor
	toastLabel.BackgroundTransparency = 0.2
	toastLabel.TextColor3 = LobbyConfig.TextColor
	toastLabel.Font = Enum.Font.GothamMedium
	toastLabel.TextScaled = true
	toastLabel.BorderSizePixel = 0
	toastLabel.Visible = false
	toastLabel.ZIndex = 20
	local toastLimit = Instance.new("UISizeConstraint")
	toastLimit.MaxSize = Vector2.new(360, 40)
	toastLimit.Parent = toastLabel
	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 8)
	toastCorner.Parent = toastLabel
	toastLabel.Parent = gui

	local state: State
	state = {
		pads = {},
		lastToast = "",
		isLobby = function(): boolean
			return Workspace:GetAttribute(Config.Teleport.ServerModeAttribute)
				== Config.Teleport.ModeLobby
		end,
		subscribe = function(fn: () -> ()): () -> ()
			table.insert(listeners, fn)
			return function()
				local at = table.find(listeners, fn)
				if at then
					table.remove(listeners, at)
				end
			end
		end,
		setPads = function(pads: { LobbyLogic.Pad })
			state.pads = pads
			for _, fn in table.clone(listeners) do
				fn()
			end
		end,
		toast = function(text: string)
			if destroyed or text == "" then
				return
			end
			toastToken += 1
			state.lastToast = text
			local mine = toastToken
			toastLabel.Text = text
			toastLabel.Visible = true
			task.delay(LobbyConfig.ToastSeconds, function()
				if toastToken == mine and not destroyed then
					toastLabel.Visible = false
				end
			end)
		end,
		cue = function(key: string)
			local folder = script.Parent.Parent:FindFirstChild("Atmosphere")
			local module = folder and folder:FindFirstChild("AtmosphereFx")
			if destroyed or not (module and module:IsA("ModuleScript")) then
				return
			end
			pcall(function()
				(require(module) :: any).play(key)
			end)
		end,
		play = function(key: string)
			local id = (Assets :: { [string]: string })[key]
			if destroyed or id == nil or id == "" then
				return -- missing ids fall back to silence (listed in docs/ART.md)
			end
			local sound = Instance.new("Sound")
			sound.SoundId = id
			sound.Volume = 0.6
			sound.Parent = gui
			sound.Ended:Once(function()
				sound:Destroy()
			end)
			task.delay(LobbyConfig.SoundLifetime, function()
				sound:Destroy()
			end)
			sound:Play()
		end,
		destroy = function()
			destroyed = true
			table.clear(listeners)
			toastLabel:Destroy()
		end,
	}
	return state
end

return LobbyState
