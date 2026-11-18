--!strict
-- HUD-local constants (visual layout, hints). Gameplay numbers stay in shared/Config.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Structures = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("data"):WaitForChild("Structures")
)

export type Hint = { id: string, kind: string, threshold: number?, text: string }

local HudConfig = {
	-- Workspace attribute (Vector3) the server publishes for the camp position.
	CampAttribute = Config.World.CampAttribute,
	GuiName = "Hud",
	DisplayOrder = 5,
	-- Phone-safe: bars/hotbar scale with an aspect-locked, size-capped container.
	MinWidth = 280,
	MaxWidth = 520,
	BarColors = {
		health = Color3.fromRGB(214, 76, 76),
		warmth = Color3.fromRGB(240, 160, 70),
		hunger = Color3.fromRGB(120, 190, 110),
	},
	PanelColor = Color3.fromRGB(18, 28, 40),
	TextColor = Color3.fromRGB(232, 242, 250),
	AccentColor = Color3.fromRGB(120, 190, 230),
	SelectedColor = Color3.fromRGB(120, 190, 230),
	PanelTransparency = 0.35,
	ActionButtonSize = 96,
	ActionRange = Config.Feedback.PromptRange, -- studs; client target pick only, server re-validates
	PlaceDistance = 8, -- studs in front of the player the place request aims (server snaps/validates)
	ToastSeconds = 3,
	ToastMaxChars = 80,
	HintSeconds = 6,
	HintCheckInterval = 1,
	PromptInterval = 0.15, -- seconds between target picks / prompt refreshes
	Hints = {
		{
			id = "cold",
			kind = "warmthLow",
			threshold = 40,
			text = "You are freezing. Stand near a fire.",
		},
		{
			id = "hungry",
			kind = "hungerLow",
			threshold = 40,
			text = "Hungry. Eat food from your hotbar.",
		},
		{
			id = "night",
			kind = "night",
			text = "Night falls. Wolves hunt in the dark; stay by the fire.",
		},
		{
			id = "hurt",
			kind = "healthLow",
			threshold = 30,
			text = "Health is low. Warm up and eat to recover.",
		},
	} :: { Hint },
	-- Server Notify reason codes -> player text (unknown text is shown as-is).
	NotifyText = {
		MissingMaterials = "Not enough materials.",
		NeedStation = "Needs a crafting station nearby.",
		OutOfBuildRange = "Too far from the fire",
		InventoryFull = "Inventory full.",
		UnknownRecipe = "Unknown recipe.",
		Full = "You are full.",
		Dead = "You are dead.",
		Downed = "You are downed.",
		NotFood = "You cannot eat that.",
		OutOfRange = "Too far away to place.",
		TooClose = "Too close to another structure.",
		StructureCap = "You have built too many structures.",
		FireCap = "Too many campfires.",
		MissingItem = "You do not have that item.",
		NoGround = "No ground there.",
		BadPosition = "Cannot place there.",
		RoleCap = "You have placed the most of those allowed.",
	} :: { [string]: string },
	-- Notify kinds that mean "refused" (deny sound).
	DenyKinds = { gather = true, craft = true, build = true, fire = true } :: { [string]: boolean },
	MobNames = { ArcticHare = "Hare", Caribou = "Caribou", Wolf = "Wolf" } :: { [string]: string },
	CraftKey = Enum.KeyCode.C,
	ActionKey = Enum.KeyCode.E,
	CraftPanelWidth = 0.42, -- scale of screen width (capped by CraftPanelMax)
	CraftPanelMax = Vector2.new(460, 420),
	CraftPanelMin = Vector2.new(260, 220),
	CraftRowHeight = 44, -- px per recipe row
	DisabledTransparency = 0.6, -- text transparency of unaffordable recipes
	-- First-run hint chain (shared/logic/Onboarding.STEPS order); each completes on the real action.
	OnboardingText = {
		equipAxe = "Press 1 (or tap the Axe slot) to equip your Axe.",
		chop = "Walk to a tree and click (E / Act) to chop it until it drops Wood.",
		openCraft = "Press C (or the Craft button) to open crafting.",
		craftCampfire = "Craft a Campfire: 5 Wood + 2 Stone (craft a Pickaxe to mine rocks).",
		placeCampfire = "Select the Campfire and click (E / Act) to place it.",
		addWood = "Hold Wood next to a fire and press E (Act) to add fuel.",
		eat = "Hunt a hare (click it with your Axe), then select Raw Meat and press E to eat.",
	} :: { [string]: string },
	OnboardingDoneText = "You know the basics. Survive the nights!",
	OnboardingDoneSeconds = 5,
	-- Phase 3 structures and progression (brief 17). Gameplay numbers stay in Config / data; these are UI.
	Progression = {
		-- HUD actions that keep priority over a structure interaction (they are what E / Act does).
		HudFirstActions = { gather = true, attack = true, place = true, fuel = true } :: {
			[string]: boolean,
		},
		InteractRange = Structures.Tuning.InteractRange, -- studs, client pick (server re-checks)
		Labels = {
			OpenChest = "Open chest",
			OpenDoor = "Open door",
			CloseDoor = "Close door",
			Cook = "Cook",
			Repair = "Repair",
			Use = "Use",
		},
		Ping = {
			Key = Enum.KeyCode.Q,
			ButtonSize = 56, -- px (>= 44), right edge, clear of Act (y .62-.78) and the jump button
			ButtonPosition = UDim2.fromScale(0.97, 0.4),
			WheelRadiusPx = 84,
			WheelButtonSize = 56,
			MarkerSize = UDim2.fromOffset(110, 44),
			MarkerMaxCount = 24, -- client cap on live markers (server caps per player already)
			AimMaxDistance = 600, -- studs: client aim ray length (server clamps to Config.Ping.MaxRange)
			Labels = { Go = "Go", Danger = "Danger", Loot = "Loot", Help = "Help" } :: {
				[string]: string,
			},
			Colors = {
				Go = Color3.fromRGB(110, 200, 120),
				Danger = Color3.fromRGB(220, 80, 70),
				Loot = Color3.fromRGB(235, 200, 90),
				Help = Color3.fromRGB(110, 170, 235),
			} :: { [string]: Color3 },
		},
		Storage = {
			CellPx = 52, -- px (>= 44) slot buttons
			GapPx = 4,
			PanelMaxWidth = 340,
			PanelWidthScale = 0.9,
			PanelHeightScale = 0.8,
			CloseButtonSize = 44,
		},
		-- Under the stats panel (top-left): cold resistance, buff chips, underdressed warning.
		Status = {
			Position = UDim2.fromScale(0.015, 0.155),
			Width = 220,
			RowHeight = 22,
			UpdateSeconds = 0.5,
			WarnColor = Color3.fromRGB(230, 110, 90),
		},
		-- First-run hints for the new mechanics; each completes on its real action (never a timer).
		HintPosition = UDim2.fromScale(0.015, 0.56),
		HintWidth = 260,
		HintDoneFlashSeconds = 1.5,
		HintDamagedPercent = 50, -- a tool at or under this durability triggers the repair hint
		PlaceHintIds = {
			"Forge",
			"CookingStation",
			"Wall",
			"Watchtower",
			"SleepingBag",
			"MapTable",
		},
		PlaceHint = "Select the {name} on your hotbar and click (E / Act) to place it.",
		Hints = {
			{
				id = "chest",
				have = "StorageChest",
				done = "chestOpened",
				text = "Place the chest, then stand next to it and press E (Act) to open it. Click an item to move it.",
			},
			{
				id = "cook",
				have = "RawMeat",
				done = "cooked",
				text = "Stand by a lit fire or cooking station and press E (Act) with Raw Meat selected to cook it.",
			},
			{
				id = "cookFish",
				have = "RawFish",
				done = "cooked",
				text = "Cook Raw Fish at a fire first: raw fish makes you queasy.",
			},
			{
				id = "repair",
				damaged = true,
				done = "repaired",
				text = "Stand by a workbench with the damaged tool selected and press E (Act) to repair it.",
			},
			{
				id = "door",
				have = "Door",
				done = "doorToggled",
				text = "Place the door in a wall gap. Press E (Act) next to it to open or close it.",
			},
			{
				id = "trap",
				have = "SpikeTrap",
				done = "placed:SpikeTrap",
				text = "Spike traps hurt mobs, never players. Place one where mobs walk.",
			},
			{
				id = "ping",
				party = true,
				done = "pinged",
				text = "Press Q (or tap Ping) to mark Go, Danger, Loot or Help for your team.",
			},
		} :: { { [string]: any } },
	},
}

return HudConfig
