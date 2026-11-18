--!nocheck
-- QA scenario hub-art (art pass 1): CLIENT datamodel during Play in LOBBY mode (default Studio Test),
-- local player, ONE MCP call. Prints <= 10 lines `PASS hub-art/check` or `FAIL hub-art/check: reason`.
-- Checks the built hub against Config.Art.Hub budgets and drives the REAL client handlers through the
-- lobby QA bridge: shop prompt opens the shop panel, stats prompt opens the stats panel, boards draw.
local NAME = "hub-art"
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local Config = require(RS.Shared.Config)
local H = Config.Art.Hub
local lines, fails = {}, {}
local function chk(name, ok, why)
	if ok then
		table.insert(lines, `PASS {NAME}/{name}`)
	else
		table.insert(fails, `FAIL {NAME}/{name}: {why or "failed"}`)
	end
end

local P = Players.LocalPlayer
local deadline = os.clock() + 25
repeat
	task.wait(0.3)
until (P:GetAttribute(Config.ReadyAttribute) and P.Character and P.Character:FindFirstChild("HumanoidRootPart")) or os.clock() > deadline
local root = Workspace:FindFirstChild(Config.Lobby.RootName)
if not root then
	print(`FAIL {NAME}/lobby: no Workspace.{Config.Lobby.RootName}`)
	return
end

-- Budgets
local parts, lights, rate, emitters = 0, 0, 0, 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	elseif d:IsA("PointLight") or d:IsA("SpotLight") then
		lights += 1
	elseif d:IsA("ParticleEmitter") then
		emitters += 1
		rate += d.Rate
	elseif d:IsA("Fire") or d:IsA("Smoke") then
		emitters += 1
	end
end
chk("budget", parts <= H.MaxParts and lights <= H.MaxLights and emitters <= H.MaxEmitters and rate <= H.MaxParticleRate, `parts {parts}/{H.MaxParts} lights {lights}/{H.MaxLights} emitters {emitters}/{H.MaxEmitters} rate {rate}/{H.MaxParticleRate}`)

-- Logic anchors kept: spawn, 6 pads with indexes, no scripts
local spawn = root:FindFirstChild(Config.Lobby.SpawnName, true)
local pads = CS:GetTagged(Config.Lobby.PadTag)
local seen = {}
for _, pad in pads do
	seen[pad:GetAttribute(Config.Lobby.PadIndexAttribute)] = true
end
local scripts = 0
for _, d in root:GetDescendants() do
	if d:IsA("LuaSourceContainer") then
		scripts += 1
	end
end
chk("anchors", spawn ~= nil and #pads == Config.Lobby.PadCount and scripts == 0, `spawn {tostring(spawn)} pads {#pads} scripts {scripts}`)
local allIdx = true
for i = 1, Config.Lobby.PadCount do
	allIdx = allIdx and seen[i] == true
end
chk("pad_indexes", allIdx, "missing pad index")

-- Boards drawn on the client
local gui = P:WaitForChild("PlayerGui")
local bridge = P:WaitForChild("PlayerScripts"):WaitForChild(Config.Debug.ClientBridgeName, 10)
task.wait(1.5)
local drawn = 0
for _, tag in { H.Tags.Leaderboard, H.Tags.LocalBoard, H.Tags.Stats } do
	for _, part in CS:GetTagged(tag) do
		if part:FindFirstChild("Live") then
			drawn += 1
		end
	end
end
chk("boards", drawn == 3, `live boards {drawn}/3`)
local localBoard
for _, part in CS:GetTagged(H.Tags.LocalBoard) do
	localBoard = part:FindFirstChild("Live") and part.Live:FindFirstChild("Row1", true)
end
chk("local_board_self", localBoard ~= nil and string.find(localBoard.Text, P.DisplayName, 1, true) ~= nil, localBoard and localBoard.Text or "no row")

-- Prompts open real panels
local function prompt(tag)
	for _, pp in CS:GetTagged(tag) do
		return pp
	end
end
local shopPrompt, statsPrompt = prompt(H.Tags.ShopPrompt), prompt(H.Tags.StatsPrompt)
chk("prompts", shopPrompt ~= nil and statsPrompt ~= nil and prompt(H.Tags.MirrorPrompt) ~= nil, "missing shop/stats/mirror prompt")
if bridge and statsPrompt then
	bridge:Invoke("triggerPrompt", statsPrompt)
	task.wait(0.2)
	chk("stats_prompt_opens_panel", bridge:Invoke("panelOpen", "Stats") == true, "stats panel closed")
	bridge:Invoke("triggerPrompt", shopPrompt)
	task.wait(0.4)
	local metaOpen = false
	for _, d in gui:GetDescendants() do
		if d:IsA("Frame") and d.Name == "MetaPanel" and d.Visible then
			metaOpen = true
		end
	end
	chk("shop_prompt_opens_shop", metaOpen and bridge:Invoke("panelOpen", "Stats") == false, "shop panel not visible")
	bridge:Invoke("triggerPrompt", shopPrompt) -- toggle closed again
end

-- Pad billboards carry the big size label
local labelOk = false
for _, d in gui:GetDescendants() do
	if d:IsA("BillboardGui") and d.Name == "PadBillboard" and d:FindFirstChild("Timer") then
		labelOk = true
	end
end
chk("pad_labels", labelOk, "no pad billboard with Timer label")

for _, l in fails do
	print(l)
end
for i, l in lines do
	if #fails + i <= 10 then
		print(l)
	end
end
