--!strict
-- HUD-local constants (visual layout, hints). Gameplay numbers stay in shared/Config.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

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
		NeedWorkbench = "Needs a workbench nearby.",
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
	} :: { [string]: string },
	-- Notify kinds that mean "refused" (deny sound).
	DenyKinds = { gather = true, craft = true, build = true } :: { [string]: boolean },
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
}

return HudConfig
