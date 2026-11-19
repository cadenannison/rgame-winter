--!strict
-- Pure chest look table: rarity -> colours, materials, glow, light, particles, beam, open animation.
-- Shared by the server builder (server/Art/ChestArt) and the client effects (client/Loot). No Roblox APIs.
-- Colours are {r, g, b} 0-255. Light/particle numbers must stay inside ChestStyle.Budget (tests check).

local Config = require("../Config")
local Rarity = require("../data/Rarity")

export type Style = {
	bodyColor: { number },
	bodyMaterial: string, -- Enum.Material name
	trimColor: { number },
	trimMaterial: string,
	lidColor: { number }, -- lid differs from the body so each rarity reads at a glance
	lockColor: { number },
	accent: string, -- "none" | "gem" (lock gem) | "crown" (gem + lid ridge): one small gem part, crown adds a lid ridge
	glowColor: { number }?, -- nil = no glow emitters / beam / gem
	glowTransparency: number, -- gem base transparency (client pulses around it)
	glowEmitters: number, -- small client glow emitters (<= Config.ArtStructures.ChestGlowEmitters)
	lightRange: number, -- 0 = no light (client creates it only for nearby chests)
	lightBrightness: number,
	particleRate: number, -- per second per emitter; 0 = none
	particleLifetime: number,
	beamHeight: number, -- studs; 0 = no beam
	beamWidth: number,
	beamTransparency: number,
	openSeconds: number, -- lid tween time
	lidAngle: number, -- degrees the lid opens
	holdSeconds: number, -- prompt hold duration
	burstCount: number, -- particles emitted once on open
	pulseSpeed: number, -- radians per second of the glow pulse
	pulseAmount: number, -- 0..1 transparency swing
	soundKey: string, -- shared/Assets key (nil id = silent hook)
	label: string, -- prompt label
}

local ChestStyle = {}

-- Local budgets (Config has no chest section; listed as an open issue). Particle rate and emitter count
-- derive from Config.Perf. A chest's own server parts are capped; effects exist only on nearby chests.
ChestStyle.Budget = {
	MaxParts = 8, -- server parts per chest model
	MaxLightRange = 24,
	MaxLightBrightness = 3,
	MaxParticleRate = Config.Perf.MaxParticleRate,
	MaxBeamHeight = Config.Loot.Beam.MaxHeight, -- hard cap (12): short beams only, no sky pillars
	MaxBeamWidth = 1.5,
	MaxEffectChests = math.floor(Config.Perf.MaxParticleEmitters / 3), -- nearby chests with live light + emitter
	EffectRadius = 90, -- studs: light/particles/pulse only inside this
	RefreshSeconds = 0.5, -- nearby-set sweep interval
	OpenedDim = 0.5, -- colour multiplier when opened
	PromptDistance = Config.Loot.OpenRange,
	HingeInset = 0.1,
} :: { [string]: number }

local STYLES: { [string]: Style } = {
	common = {
		bodyColor = { 112, 82, 52 },
		bodyMaterial = "Wood",
		trimColor = { 78, 66, 56 },
		trimMaterial = "WoodPlanks",
		lidColor = { 96, 70, 44 },
		lockColor = { 150, 140, 120 },
		accent = "none",
		glowColor = nil,
		glowTransparency = 1,
		glowEmitters = 0,
		lightRange = 0,
		lightBrightness = 0,
		particleRate = 0,
		particleLifetime = 0,
		beamHeight = 0,
		beamWidth = 0,
		beamTransparency = 1,
		openSeconds = 0.35,
		lidAngle = 95,
		holdSeconds = 0,
		burstCount = 0,
		pulseSpeed = 0,
		pulseAmount = 0,
		soundKey = "ChestOpenCommonSound",
		label = "Weathered Chest",
	},
	uncommon = {
		bodyColor = { 92, 70, 48 },
		bodyMaterial = "Wood",
		trimColor = { 120, 124, 132 },
		trimMaterial = "CorrodedMetal",
		lidColor = { 70, 54, 40 },
		lockColor = { 190, 190, 200 },
		accent = "none",
		glowColor = nil,
		glowTransparency = 1,
		glowEmitters = 0,
		lightRange = 0,
		lightBrightness = 0,
		particleRate = 0,
		particleLifetime = 0,
		beamHeight = 0,
		beamWidth = 0,
		beamTransparency = 1,
		openSeconds = 0.4,
		lidAngle = 100,
		holdSeconds = 0,
		burstCount = 4,
		pulseSpeed = 0,
		pulseAmount = 0,
		soundKey = "ChestOpenUncommonSound",
		label = "Iron-Bound Chest",
	},
	rare = {
		bodyColor = { 150, 190, 220 },
		bodyMaterial = "Metal",
		trimColor = { 70, 100, 140 },
		trimMaterial = "Metal",
		lidColor = { 110, 150, 190 },
		lockColor = { 210, 235, 255 },
		accent = "gem",
		glowColor = { 80, 170, 255 },
		glowTransparency = 0.25,
		glowEmitters = 1,
		lightRange = 14,
		lightBrightness = 1.2,
		particleRate = 6,
		particleLifetime = 1.6,
		beamHeight = 6,
		beamWidth = 0.5,
		beamTransparency = 0.72,
		openSeconds = 0.5,
		lidAngle = 105,
		holdSeconds = 0,
		burstCount = 14,
		pulseSpeed = 2.2,
		pulseAmount = 0.2,
		soundKey = "ChestOpenRareSound",
		label = "Frost-Steel Chest",
	},
	epic = {
		bodyColor = { 70, 40, 110 },
		bodyMaterial = "Glass",
		trimColor = { 160, 100, 235 },
		trimMaterial = "Neon",
		lidColor = { 50, 28, 84 },
		lockColor = { 230, 190, 255 },
		accent = "gem",
		glowColor = { 180, 110, 255 },
		glowTransparency = 0.15,
		glowEmitters = 2,
		lightRange = 18,
		lightBrightness = 1.8,
		particleRate = 12,
		particleLifetime = 2,
		beamHeight = 8,
		beamWidth = 0.7,
		beamTransparency = 0.62,
		openSeconds = 0.65,
		lidAngle = 110,
		holdSeconds = 0.25,
		burstCount = 24,
		pulseSpeed = 3,
		pulseAmount = 0.28,
		soundKey = "ChestOpenEpicSound",
		label = "Spectral Chest",
	},
	legendary = {
		bodyColor = { 235, 190, 70 },
		bodyMaterial = "Metal",
		trimColor = { 255, 225, 120 },
		trimMaterial = "Neon",
		lidColor = { 255, 215, 100 },
		lockColor = { 255, 245, 190 },
		accent = "crown",
		glowColor = { 255, 210, 90 },
		glowTransparency = 0.08,
		glowEmitters = 3,
		lightRange = 22,
		lightBrightness = 2.6,
		particleRate = 20,
		particleLifetime = 2.4,
		beamHeight = Config.Loot.Beam.Height,
		beamWidth = 1,
		beamTransparency = 0.5,
		openSeconds = 0.9,
		lidAngle = 115,
		holdSeconds = 0.5,
		burstCount = 40,
		pulseSpeed = 4,
		pulseAmount = 0.35,
		soundKey = "ChestOpenLegendarySound",
		label = "Golden Chest",
	},
}

ChestStyle.Styles = STYLES

-- Style for a rarity; unknown names fall back to common.
function ChestStyle.get(rarity: string): Style
	return STYLES[rarity] or STYLES.common
end

-- Server parts a style needs: Base, Lid, two straps, lock plate; plus a gem (rare+) and a lid ridge (crown).
-- The beam is built on the client near the local player, so it is not a server part.
function ChestStyle.partCount(style: Style): number
	local n = 5
	if style.accent == "gem" then
		n += 1
	elseif style.accent == "crown" then
		n += 2
	end
	return n
end

-- True when this rarity gets a light and emitter on the client.
function ChestStyle.hasEffects(style: Style): boolean
	return style.lightRange > 0 or style.particleRate > 0
end

-- Colour multiplied by factor (opened chests dim). Clamped 0-255.
function ChestStyle.dim(color: { number }, factor: number): { number }
	return {
		math.clamp(math.floor(color[1] * factor + 0.5), 0, 255),
		math.clamp(math.floor(color[2] * factor + 0.5), 0, 255),
		math.clamp(math.floor(color[3] * factor + 0.5), 0, 255),
	}
end

-- Glow transparency at time t (seconds): base pulsing by pulseAmount, clamped 0..1.
function ChestStyle.pulse(style: Style, t: number): number
	if style.pulseSpeed <= 0 then
		return style.glowTransparency
	end
	local s = (math.sin(t * style.pulseSpeed) + 1) * 0.5
	return math.clamp(style.glowTransparency + s * style.pulseAmount, 0, 1)
end

-- Beam fade by camera distance: 0 = fully visible, 1 = hidden (client LocalTransparencyModifier). Visible out to
-- radius - band, fading to hidden at `radius`.
function ChestStyle.beamFade(distance: number, radius: number, band: number): number
	if distance <= radius - band then
		return 0
	end
	if distance >= radius then
		return 1
	end
	return (distance - (radius - band)) / band
end

-- Problems with one style against the budget (empty = OK).
function ChestStyle.validate(rarity: string, style: Style): { string }
	local B = ChestStyle.Budget
	local problems: { string } = {}
	if ChestStyle.partCount(style) > B.MaxParts then
		table.insert(problems, `{rarity}: too many parts`)
	end
	if style.lightRange > B.MaxLightRange or style.lightBrightness > B.MaxLightBrightness then
		table.insert(problems, `{rarity}: light over budget`)
	end
	if style.particleRate > B.MaxParticleRate then
		table.insert(problems, `{rarity}: particle rate over budget`)
	end
	if style.glowEmitters > Config.ArtStructures.ChestGlowEmitters then
		table.insert(problems, `{rarity}: too many glow emitters`)
	end
	if style.beamHeight > Config.ArtStructures.BeamMaxStuds then
		table.insert(problems, `{rarity}: beam longer than ArtStructures.BeamMaxStuds`)
	end
	local beamHeight = Config.Loot.Beam
	if
		style.beamHeight > B.MaxBeamHeight
		or style.beamHeight > beamHeight.Height
		or style.beamWidth > B.MaxBeamWidth
	then
		table.insert(problems, `{rarity}: beam over budget`)
	end
	local wantsBeam = Rarity.rank(rarity) >= Rarity.rank(beamHeight.MinRarity)
	if wantsBeam and (style.glowColor == nil or style.beamHeight <= 0) then
		table.insert(
			problems,
			`{rarity}: {beamHeight.MinRarity}+ chests need a glow and a short beam`
		)
	end
	if not wantsBeam and style.beamHeight > 0 then
		table.insert(problems, `{rarity}: below Beam.MinRarity must not have a beam`)
	end
	return problems
end

return ChestStyle
