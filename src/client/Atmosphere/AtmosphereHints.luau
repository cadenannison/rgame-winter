--!strict
-- First-run hints for the new systems (brief 20): events, stalker cues, clothing, chest, map, ping.
-- Definitions and completion rules are pure (shared/logic/CueResolve). A hint shows once per session when
-- its trigger holds (for HintShowSeconds) and is completed ONLY by the real action; the completion is sent
-- once (HintSeenRequest, id only) and the hint never shows again. Nothing is shown before the server's
-- MetaState snapshot says which hints were already seen. No hidden metric is read here.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local CueResolve = require(Shared:WaitForChild("logic"):WaitForChild("CueResolve"))
local AtmosphereConfig = require(script.Parent:WaitForChild("AtmosphereConfig"))
local InventoryMirror =
	require(script.Parent.Parent:WaitForChild("Storage"):WaitForChild("InventoryMirror"))

local C = AtmosphereConfig
local FORGE_ITEM = "Forge" -- placeable item id (data/Items) that builds the forge station
local player = Players.LocalPlayer

local AtmosphereHints = {}

local started = false
local seen: { [string]: boolean } = {}
local snapshotLoaded = false
local triggered: { [string]: boolean } = {}
local warnUntil: { [string]: number } = {} -- trigger name -> os.clock() deadline
local shownOnce: { [string]: boolean } = {}
local shownId: string? = nil
local shownAt = 0.0
local label: TextLabel? = nil
local mirror: InventoryMirror.Mirror? = nil
local connections: { RBXScriptConnection } = {}
local sendQueue: { string } = {}
local sending = false

local function knownId(id: string): boolean
	return table.find(Config.Hints.Ids, id) ~= nil
end

-- Persist completions one at a time (the server rate-limits HintSeenRequest).
local function flushQueue()
	if sending then
		return
	end
	sending = true
	task.spawn(function()
		while #sendQueue > 0 do
			local id = table.remove(sendQueue, 1) :: string
			Remotes.event(Remotes.HintSeenRequest):FireServer({ hintId = id })
			task.wait(Config.Net.HintRateInterval + 0.1)
		end
		sending = false
	end)
end

local function render()
	local gui = label
	if gui == nil then
		return
	end
	local id = shownId
	if id == nil then
		gui.Visible = false
		return
	end
	for _, def in CueResolve.HintDefs do
		if def.id == id then
			gui.Text = def.text
			gui.Visible = true
			return
		end
	end
	gui.Visible = false
end

-- Real action reported. Passive actions (reachedFire) only count for hints whose trigger is active.
local function report(action: string, passive: boolean)
	local defs = CueResolve.HintDefs
	if passive then
		local active: { CueResolve.HintDef } = {}
		for _, def in defs do
			if triggered[def.trigger] == true then
				table.insert(active, def)
			end
		end
		defs = active
	end
	for _, id in CueResolve.complete(defs, seen, action) do
		if knownId(id) then
			table.insert(sendQueue, id)
		end
		if shownId == id then
			shownId = nil
			render()
		end
	end
	if #sendQueue > 0 then
		flushQueue()
	end
end

AtmosphereHints.report = report

-- Studio QA (client bridge): whether a hint is completed locally.
function AtmosphereHints.isSeen(id: string): boolean
	return seen[id] == true
end

-- Studio QA only (client bridge): forget a completed hint locally so a scenario can complete it again.
function AtmosphereHints.qaReset(id: string)
	seen[id] = nil
	shownOnce[id] = nil
end

local function warn(trigger: string)
	warnUntil[trigger] = os.clock() + Config.Hints.WarnWindowSeconds
end

-- Cue payloads only open triggers (coarse kinds); they carry no timer.
function AtmosphereHints.onCue(kind: string)
	if kind == "WarnBlizzard" then
		warn("blizzardWarn")
	elseif kind == "WarnFalseNight" or kind == "WarnTheQuiet" or kind == "WarnDeepFreeze" then
		warn("darkEventWarn")
	elseif kind == "StalkerTell" or kind == "Footsteps" then
		warn("stalkerCue")
	elseif kind == "StalkerRetreat" then
		report("stalkerRetreated", false)
	end
end

function AtmosphereHints.onMetaState(payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	local p = payload :: { [string]: unknown }
	local list = p.hintsSeen
	if type(list) == "table" then
		for _, id in list :: { unknown } do
			if type(id) == "string" then
				seen[id] = true
			end
		end
		snapshotLoaded = true
	end
end

local function nearestWithin(tag: string, from: Vector3, range: number): boolean
	for _, inst in CollectionService:GetTagged(tag) do
		local pos = if inst:IsA("BasePart")
			then inst.Position
			elseif inst:IsA("Model") then inst:GetPivot().Position
			else nil
		if pos and (pos - from).Magnitude <= range then
			return true
		end
	end
	return false
end

local function evaluate()
	local now = os.clock()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local from = if root and root:IsA("BasePart") then root.Position else nil

	local ringAttr = player:GetAttribute(Config.Biome.RingAttribute)
	local ring = if type(ringAttr) == "number" then ringAttr else 0
	local resistAttr = player:GetAttribute(Config.Biome.ColdResistanceAttribute)
	local resist = if type(resistAttr) == "number" then resistAttr else 0
	local darkAttr = Workspace:GetAttribute(Config.Events.ActiveAttribute)
	local dark = if type(darkAttr) == "string" then darkAttr else ""

	triggered = {
		blizzardWarn = (warnUntil.blizzardWarn or 0) > now
			or Workspace:GetAttribute(Config.Blizzard.ActiveAttribute) == true,
		darkEventWarn = (warnUntil.darkEventWarn or 0) > now or dark ~= "",
		stalkerCue = (warnUntil.stalkerCue or 0) > now,
		coldRing = ring >= 1 and resist <= 0,
		chestNearby = from ~= nil
			and nearestWithin(Config.Build.StorageTag, from, Config.Hints.LookupRange),
		hasMap = mirror ~= nil and ((mirror.counts()[Config.Map.ItemId] or 0) > 0),
		hasForge = mirror ~= nil and ((mirror.counts()[FORGE_ITEM] or 0) > 0),
		inParty = #Players:GetPlayers() > 1,
	}

	-- Real actions observed from replicated state.
	if from and nearestWithin(Config.Fire.Tag, from, Config.Fire.WarmRadius) then
		report("reachedFire", true)
	end
	if resist > 0 then
		report("clothingWorn", false)
	end
	local open = player:GetAttribute(Config.Storage.OpenAttribute)
	if type(open) == "string" and open ~= "" then
		report("chestOpened", false)
	end

	if not snapshotLoaded then
		return
	end
	if shownId ~= nil and now - shownAt > Config.Hints.ShowSeconds then
		shownId = nil
	end
	if shownId == nil then
		local candidates: { CueResolve.HintDef } = {}
		for _, def in CueResolve.HintDefs do
			if not shownOnce[def.id] then
				table.insert(candidates, def)
			end
		end
		local pick = CueResolve.nextHint(candidates, seen, triggered)
		if pick then
			shownId, shownAt = pick.id, now
			shownOnce[pick.id] = true
		end
	end
	render()
end

function AtmosphereHints.start(isRun: boolean)
	if started then
		return
	end
	started = true
	local gui = Instance.new("ScreenGui")
	gui.Name = "AtmosphereHints"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = C.HintGuiOrder
	local text = Instance.new("TextLabel")
	text.Name = "Hint"
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Position = C.HintPosition
	text.Size = UDim2.fromOffset(C.HintWidth, 0)
	text.AutomaticSize = Enum.AutomaticSize.Y
	text.BackgroundColor3 = C.PanelColor
	text.BackgroundTransparency = 0.25
	text.BorderSizePixel = 0
	text.TextColor3 = C.TextColor
	text.Font = Enum.Font.GothamMedium
	text.TextSize = 15
	text.TextWrapped = true
	text.Visible = false
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = text
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(C.HintWidth, math.huge)
	limit.Parent = text
	text.Parent = gui
	label = text
	gui.Parent = player:WaitForChild("PlayerGui")

	if isRun then
		mirror = InventoryMirror.start()
		table.insert(
			connections,
			Remotes.event(Remotes.MapData).OnClientEvent:Connect(function()
				report("mapOpened", false)
			end)
		)
		-- Forge hint completes when a forge station that this player owns appears (real placement).
		table.insert(
			connections,
			CollectionService:GetInstanceAddedSignal(Config.Craft.Stations.forge.Tag)
				:Connect(function(inst: Instance)
					if inst:GetAttribute(Config.Build.OwnerAttribute) == player.UserId then
						report("forgePlaced", false)
					end
				end)
		)
		table.insert(
			connections,
			Remotes.event(Remotes.PingBroadcast).OnClientEvent:Connect(function(p: unknown)
				if
					type(p) == "table"
					and (p :: { [string]: unknown }).fromUserId == player.UserId
				then
					report("pinged", false)
				end
			end)
		)
	end
	task.spawn(function()
		while started do
			evaluate()
			task.wait(Config.Hints.CheckInterval)
		end
	end)
end

function AtmosphereHints.stop()
	started = false
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	if mirror then
		mirror.destroy()
		mirror = nil
	end
	if label and label.Parent then
		(label.Parent :: Instance):Destroy()
	end
	label = nil
end

return AtmosphereHints
