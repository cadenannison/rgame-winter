--!strict
-- Config module: Ui. Client UI values: held-item visuals, feedback, settings keys, first-run hints.
-- Merged into Config by Config/init.luau; public API stays Config.<Section>.<Key>.

-- Legacy shape (Config/init.luau still re-exports it); held visuals now come from ItemModels.
export type HeldVisual = { Size: { number }, Color: { number }, GripOffset: number }

-- Held item visuals (server builds a Tool in the character hand for the selected slot from ItemModels 'held').
-- GripFraction: where along the model's long axis the hand grips, 0 = bottom end, 1 = top end.
export type HeldConfig = {
	ToolName: string,
	DefaultGrip: number,
	KindGrip: { [string]: number }, -- by ItemCatalog kind
	ItemGrip: { [string]: number }, -- per-item override
}

-- Client feedback for actions (swing, hit, prompts). Visual only; never gameplay.
export type FeedbackConfig = {
	SwingSeconds: number,
	SwingAngle: number,
	SoundVolume: number,
	MutedSounds: { [string]: boolean }, -- Assets names Feedback.sound skips (no interaction audio until the audio pass)
	HitParticleCount: number,
	HitParticleColor: { number }, -- {r, g, b} 0-255
	HitParticleSpeed: number,
	HitParticleLifetime: number,
	FlashSeconds: number,
	FlashColor: { number }, -- {r, g, b} 0-255
	PromptRange: number,
	AimSlack: number,
	PromptOffsetY: number,
	ItemNameSeconds: number,
}

-- Phase 4 player settings (saved in profile.settings). Boolean settings only.
export type SettingsConfig = {
	Keys: { string }, -- valid SettingsSetRequest keys (profile.settings field names)
	ReduceScares: string, -- key "reduceScares"
	ReduceScaresAttribute: string, -- Player attribute mirrored from profile.settings.reduceScares
	DefaultReduceScares: boolean,
	ReducedScareVisualMultiplier: number, -- client: horror visual/sound intensity when reduced (0..1)
}

-- Phase 4 first-run hints (seen ids saved in profile.hintsSeen).
export type HintsConfig = {
	Ids: { string },
	ShowSeconds: number, -- a shown hint hides after this long (it still completes only on its action)
	CheckInterval: number, -- client seconds between hint trigger checks
	LookupRange: number, -- studs: a chest counts as nearby
	WarnWindowSeconds: number, -- a warning cue keeps its hint triggered this long
}

-- Slot highlight style: outline color (0-255 rgb), background tint, outline thickness px.
export type SlotHighlight = { Stroke: { number }, Tint: { number }, Thickness: number }

-- Inventory UI (Backpack, HUD hotbar, chest grid): slot highlights and input keys.
export type InventoryUiConfig = {
	Focus: SlotHighlight, -- last clicked/tapped slot (also the Drop target)
	Held: SlotHighlight, -- slot picked up for tap-to-move, or being dragged
	Target: SlotHighlight, -- valid destination glow while something is held
	Hover: SlotHighlight, -- valid destination under the pointer during a drag
	ToggleKeyName: string, -- Backpack toggle (B only)
	DropKeyName: string, -- drops the focused/held inventory slot while the Backpack is open
	DropButtonText: string,
	DropButtonWidthPx: number,
	DragThresholdPx: number, -- HUD hotbar pointer travel before a press becomes a drag
}

export type Sections = {
	InventoryUi: InventoryUiConfig,
	Held: HeldConfig,
	Feedback: FeedbackConfig,
	Settings: SettingsConfig,
	Hints: HintsConfig,
}

local Sections: Sections = {
	InventoryUi = {
		Focus = { Stroke = { 255, 255, 255 }, Tint = { 70, 110, 150 }, Thickness = 3 },
		Held = { Stroke = { 255, 200, 60 }, Tint = { 140, 110, 30 }, Thickness = 4 },
		Target = { Stroke = { 110, 230, 150 }, Tint = { 30, 85, 60 }, Thickness = 2 },
		Hover = { Stroke = { 190, 255, 210 }, Tint = { 50, 130, 90 }, Thickness = 3 },
		ToggleKeyName = "B",
		DropKeyName = "G",
		DropButtonText = "Drop",
		DropButtonWidthPx = 72,
		DragThresholdPx = 8,
	},
	Held = {
		ToolName = "HeldItem", -- name of the server-built Tool in the character (visual only)
		DefaultGrip = 0.5,
		KindGrip = {
			tool = 0.25, -- handle low, head above the fist
			weapon = 0.3,
			light = 0.2,
			ammo = 0.5,
			placeable = 0.5,
		},
		ItemGrip = {
			Spear = 0.4,
			IronSpear = 0.4,
			FangSpear = 0.4,
			SunpiercerSpear = 0.4,
			Bow = 0.5,
			Torch = 0.25,
			BlubberTorch = 0.25,
			AuroraTorch = 0.25,
			Lantern = 0.35,
			AuroraLantern = 0.35,
			SunBeacon = 0.35,
		},
	},
	Feedback = {
		SwingSeconds = 0.25, -- procedural swing length (used when Assets.SwingAnimation is empty)
		SwingAngle = 70, -- degrees the arm swings
		SoundVolume = 0.6, -- volume of action sounds
		MutedSounds = {
			SwingSound = true,
			ChopSound = true,
			MobHitSound = true,
			DenySound = true,
			CraftSound = true,
		}, -- audio pass: remove to enable (docs/ART.md hook points)
		HitParticleCount = 10, -- particles per hit burst
		HitParticleColor = { 235, 225, 200 }, -- chips/snow burst color
		HitParticleSpeed = 12, -- studs/s burst speed
		HitParticleLifetime = 0.5, -- seconds a hit particle lives
		FlashSeconds = 0.15, -- mob hit flash length
		FlashColor = { 255, 80, 80 }, -- mob hit flash color
		PromptRange = 12, -- studs: target pick and prompt range (server re-validates its own ranges)
		AimSlack = 4, -- studs from the mouse ray within which a target counts as aimed at (PC)
		PromptOffsetY = 3, -- studs above the target the prompt floats
		ItemNameSeconds = 1.5, -- seconds the selected item name shows above the hotbar
	},
	Settings = {
		Keys = { "reduceScares" },
		ReduceScares = "reduceScares",
		ReduceScaresAttribute = "ReduceScares",
		DefaultReduceScares = false,
		ReducedScareVisualMultiplier = 0.4,
	},
	Hints = {
		Ids = {
			"Biomes",
			"Clothing",
			"Map",
			"Storage",
			"FirstChest",
			"Cooking",
			"Repair",
			"Ping",
			"Bow",
			"Blizzard",
			"DarkEvent",
			"Stalker",
			"Shop",
			"Perks",
			"Achievements",
			"Forge",
		},
		ShowSeconds = 12,
		CheckInterval = 1,
		LookupRange = 30,
		WarnWindowSeconds = 90,
	},
}

return Sections
