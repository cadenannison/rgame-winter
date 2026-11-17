--!strict

export type Assets = {
	[string]: string,
}

-- Asset ids ("rbxassetid://..."). Log every imported asset in docs/ART.md.
-- "" = not supplied yet: the client falls back (procedural swing, no sound). rbxasset://sounds/* are
-- engine-bundled placeholders; replace them with real ids (see docs/ART.md "Needed assets").
local Assets: Assets = {
	SwingAnimation = "", -- needed: one-shot tool swing (R15); empty -> procedural arm swing
	SwingSound = "rbxasset://sounds/swordslash.wav", -- placeholder: whoosh on every swing
	ChopSound = "rbxasset://sounds/swordlunge.wav", -- placeholder: wood/stone hit confirm
	MobHitSound = "rbxasset://sounds/swordlunge.wav", -- placeholder: animal hit confirm
	CraftSound = "rbxasset://sounds/electronicpingshort.wav", -- placeholder: craft/place success
	DenySound = "rbxasset://sounds/button.wav", -- placeholder: missing tool / refused
	BiteSound = "rbxasset://sounds/uuhhh.mp3", -- placeholder: player hurt by a mob bite
	WolfGrowlSound = "", -- needed: wolf growl at the start of an attack windup (silent until supplied)
	DuskSound = "", -- needed: soft cue as night falls (silent until supplied)
	DawnSound = "", -- needed: soft cue as day breaks (silent until supplied)
}

return Assets
