--!strict
-- Config module: Ui. Client UI values: held-item visuals, feedback, settings keys, first-run hints.
-- Merged into Config by Config/init.luau; public API stays Config.<Section>.<Key>.

-- Size {x, y, z} studs and Color {r, g, b} 0-255 as plain numbers (Config is also loaded by Lune tests).
export type HeldVisual = { Size: { number }, Color: { number }, GripOffset: number }

-- Held item visuals (server builds a Tool in the character hand for the selected slot).
export type HeldConfig = {
	ToolName: string,
	Default: HeldVisual,
	Visuals: { [string]: HeldVisual },
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
		DropKeyName = "Q",
		DropButtonText = "Drop",
		DropButtonWidthPx = 72,
		DragThresholdPx = 8,
	},
	Held = {
		ToolName = "HeldItem", -- name of the server-built Tool in the character (visual only)
		Default = {
			Size = { 0.8, 0.8, 0.8 },
			Color = { 200, 200, 200 },
			GripOffset = 0,
		},
		Visuals = {
			Axe = {
				Size = { 0.4, 3, 0.4 },
				Color = { 150, 110, 70 },
				GripOffset = 1,
			},
			Pickaxe = {
				Size = { 0.4, 3, 0.4 },
				Color = { 120, 120, 130 },
				GripOffset = 1,
			},
			Spear = {
				Size = { 0.3, 5, 0.3 },
				Color = { 170, 140, 90 },
				GripOffset = 1.5,
			},
			Wood = {
				Size = { 0.8, 0.8, 2 },
				Color = { 130, 90, 55 },
				GripOffset = 0,
			},
			Stone = {
				Size = { 1, 0.8, 1 },
				Color = { 130, 130, 135 },
				GripOffset = 0,
			},
			RawMeat = {
				Size = { 1, 0.6, 1 },
				Color = { 190, 70, 70 },
				GripOffset = 0,
			},
			Campfire = {
				Size = { 1.4, 0.6, 1.4 },
				Color = { 230, 120, 40 },
				GripOffset = 0,
			},
			Workbench = {
				Size = { 1.6, 0.8, 1.2 },
				Color = { 140, 100, 60 },
				GripOffset = 0,
			},
			Hide = {
				Size = { 1.2, 0.2, 1.2 },
				Color = { 110, 110, 120 },
				GripOffset = 0,
			},
		},
	},
	Feedback = {
		SwingSeconds = 0.25, -- procedural swing length (used when Assets.SwingAnimation is empty)
		SwingAngle = 70, -- degrees the arm swings
		SoundVolume = 0.6, -- volume of action sounds
		MutedSounds = { SwingSound = true, ChopSound = true, MobHitSound = true }, -- audio pass: remove to enable (docs/ART.md hook points)
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
