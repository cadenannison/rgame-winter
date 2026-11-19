--!strict
-- Config module: ArtGear. Art Pass 4 Agent B knobs: worn gear on the R15 character. Owner: Agent B only.
-- Merged into Config by init.luau (Config.ArtGear.<Key>).

export type PartSpec = {
	name: string, -- suffix of the part name ("<Slot>_<name>")
	rig: string?, -- R15 part to weld to; nil = Rig[slot].part. An override ignores the Rig base offset.
	offset: { number }, -- studs from the rig part centre (Rig[slot].offset is added when rig is nil)
	mult: { number }, -- size = rigPartSize * mult + add (per axis), then x tier scale on X/Z
	add: { number },
	tone: string, -- "main" or "trim" (tier palette)
}

export type TierLook = {
	main: { number }, -- RGB 0-255
	trim: { number },
	material: string, -- Enum.Material name for main
	trimMaterial: string,
	scale: number, -- bulk on X/Z (tier differences without extra parts)
}

export type ArtGearConfig = {
	MaxPartsPerPlayer: number, -- all gear parts on one character, hard cap
	FolderName: string, -- Folder under the character holding every gear part (cleared as one)
	PartAttribute: string, -- attribute stamped on each gear part: the equipSlot it belongs to
	-- slot -> default R15 part + base offset (parts may override the rig part)
	Rig: { [string]: { part: string, offset: { number } } },
	Parts: { [string]: { PartSpec } }, -- per-slot part budget; sum over all slots <= MaxPartsPerPlayer
	TierOrder: { string }, -- item id prefixes, first match wins
	DefaultTier: string,
	Tiers: { [string]: TierLook },
	RetryCount: number, -- re-apply attempts while the rig is still assembling
	RetrySeconds: number,
}

export type Sections = { ArtGear: ArtGearConfig }

local Sections: Sections = {
	ArtGear = {
		MaxPartsPerPlayer = 12,
		FolderName = "Gear",
		PartAttribute = "GearSlot",
		Rig = {
			Head = { part = "Head", offset = { 0, 0.3, 0 } },
			Body = { part = "UpperTorso", offset = { 0, 0, 0 } },
			Legs = { part = "LeftUpperLeg", offset = { 0, -0.05, 0 } },
			Feet = { part = "LeftFoot", offset = { 0, 0.05, 0 } },
			Hands = { part = "RightHand", offset = { 0, 0.18, 0 } }, -- wrist cuff, clear of the grip
			Neck = { part = "UpperTorso", offset = { 0, 0.85, 0 } },
			Accessory1 = { part = "UpperTorso", offset = { 0, -0.1, 0.75 } }, -- back pouch
			Accessory2 = { part = "LowerTorso", offset = { -1.2, 0, 0 } }, -- hip pouch
		},
		-- Budget: Head 2, Body 2, Legs 2, Feet 2, Hands 1, Neck 1, Accessory1 1, Accessory2 1 = 12.
		Parts = {
			Head = {
				{
					name = "Cap",
					offset = { 0, 0, 0 },
					mult = { 0.75, 0, 1.2 },
					add = { 0, 0.5, 0 },
					tone = "main",
				},
				{
					name = "Trim",
					offset = { 0, -0.3, 0 },
					mult = { 0.8, 0, 1.3 },
					add = { 0, 0.18, 0 },
					tone = "trim",
				},
			},
			Body = {
				{
					name = "Coat",
					offset = { 0, 0, 0 },
					mult = { 1.08, 1.02, 1.25 },
					add = { 0, 0, 0 },
					tone = "main",
				},
				{
					name = "Hem",
					rig = "LowerTorso",
					offset = { 0, -0.02, 0 },
					mult = { 1.12, 1, 1.3 },
					add = { 0, 0.05, 0 },
					tone = "trim",
				},
			},
			Legs = {
				{
					name = "L",
					offset = { 0, 0, 0 },
					mult = { 1.12, 0.95, 1.12 },
					add = { 0, 0, 0 },
					tone = "main",
				},
				{
					name = "R",
					rig = "RightUpperLeg",
					offset = { 0, -0.05, 0 },
					mult = { 1.12, 0.95, 1.12 },
					add = { 0, 0, 0 },
					tone = "main",
				},
			},
			Feet = {
				{
					name = "L",
					offset = { 0, 0, 0 },
					mult = { 1.15, 1.5, 1.15 },
					add = { 0, 0, 0.05 },
					tone = "main",
				},
				{
					name = "R",
					rig = "RightFoot",
					offset = { 0, 0.05, 0 },
					mult = { 1.15, 1.5, 1.15 },
					add = { 0, 0, 0.05 },
					tone = "main",
				},
			},
			Hands = {
				{
					name = "Cuff",
					offset = { 0, 0, 0 },
					mult = { 1.15, 0, 1.15 },
					add = { 0, 0.3, 0 },
					tone = "trim",
				},
			},
			Neck = {
				{
					name = "Scarf",
					offset = { 0, 0, 0 },
					mult = { 0.95, 0, 1.25 },
					add = { 0, 0.4, 0 },
					tone = "trim",
				},
			},
			Accessory1 = {
				{
					name = "Pouch",
					offset = { 0, 0, 0 },
					mult = { 0, 0, 0 },
					add = { 1, 1, 0.4 },
					tone = "main",
				},
			},
			Accessory2 = {
				{
					name = "Pouch",
					offset = { 0, 0, 0 },
					mult = { 0, 0, 0 },
					add = { 0.45, 0.55, 0.6 },
					tone = "trim",
				},
			},
		},
		TierOrder = { "Hide", "Fur", "Arctic", "Insulated", "Feather", "Fang", "Aurora" },
		DefaultTier = "Default",
		Tiers = {
			Hide = {
				main = { 112, 98, 86 },
				trim = { 156, 146, 132 },
				material = "Leather",
				trimMaterial = "Fabric",
				scale = 1,
			},
			Fur = {
				main = { 168, 178, 192 },
				trim = { 236, 241, 246 },
				material = "Fabric",
				trimMaterial = "Fabric",
				scale = 1.06,
			},
			Arctic = {
				main = { 52, 104, 158 },
				trim = { 204, 232, 246 },
				material = "Fabric",
				trimMaterial = "SmoothPlastic",
				scale = 1.12,
			},
			Insulated = {
				main = { 66, 82, 108 },
				trim = { 188, 200, 216 },
				material = "Fabric",
				trimMaterial = "Fabric",
				scale = 1.08,
			},
			Feather = {
				main = { 214, 226, 238 },
				trim = { 150, 190, 224 },
				material = "Fabric",
				trimMaterial = "Fabric",
				scale = 1,
			},
			Fang = {
				main = { 108, 82, 58 },
				trim = { 232, 226, 206 },
				material = "Leather",
				trimMaterial = "SmoothPlastic",
				scale = 1,
			},
			Aurora = {
				main = { 232, 192, 72 },
				trim = { 90, 255, 205 },
				material = "Metal",
				trimMaterial = "Neon",
				scale = 1,
			},
			Default = {
				main = { 90, 102, 118 },
				trim = { 168, 180, 192 },
				material = "Fabric",
				trimMaterial = "Fabric",
				scale = 1,
			},
		},
		RetryCount = 8,
		RetrySeconds = 0.25,
	},
}

return Sections
