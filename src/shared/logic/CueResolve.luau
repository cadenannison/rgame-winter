--!strict
-- Pure presentation logic (brief 20): cue key -> audio/particle presentation with reduce-scares scaling,
-- first-run hint definitions and completion, and the structure-vs-gather interact choice. No Roblox APIs.
-- Presentation only: nothing here carries or derives a hidden metric (Dread, hunt chance, timers).

local Config = require("../Config")
local AudioCues = require("../data/AudioCues")
local Assets = require("../Assets")

local CueResolve = {}

export type Presentation = {
	key: string,
	soundId: string, -- "" = silent
	particleId: string, -- "" = no particle
	volume: number,
	particleScale: number, -- multiplies particle rate
	loop: boolean,
	flash: boolean, -- a brief screen flash is allowed (never under reduce-scares)
}

-- Kinds whose sound the horror client (HorrorCues) already plays; the router adds only their particles.
CueResolve.HorrorOwnsSound = {
	DreadLevel = true,
	Footsteps = true,
	FireGutter = true,
	LurkerSighted = true,
	IceCrack = true,
} :: { [string]: boolean }

-- Intensity multiplier for a row: scary rows shrink under reduce-scares, others are unchanged.
function CueResolve.scale(scary: boolean, reduce: boolean): number
	if scary and reduce then
		return Config.Settings.ReducedScareVisualMultiplier
	end
	return 1
end

-- Resolve one cue key. nil when no row exists. A missing asset id is "" (silent), never an error.
function CueResolve.resolve(key: string, reduce: boolean): Presentation?
	local row = AudioCues.ByKey[key]
	if row == nil then
		return nil
	end
	local s = CueResolve.scale(row.scary, reduce)
	local soundId = if row.sound then (Assets :: any)[row.sound] else nil
	local particleId = if row.particle then (Assets :: any)[row.particle] else nil
	return {
		key = key,
		soundId = if type(soundId) == "string" then soundId else "",
		particleId = if type(particleId) == "string" then particleId else "",
		volume = row.volume * s,
		particleScale = s,
		loop = row.loop,
		flash = row.scary and not reduce,
	}
end

-- ===== First-run hints =====
-- A hint is shown when its trigger holds, and completes ONLY on its real action. Completion is persisted
-- once (HintSeenRequest) and never shown again. `done` lists the real actions that complete it.
export type HintDef = {
	id: string, -- Config.Hints.Ids entry
	trigger: string, -- client condition name (see AtmosphereHints)
	done: { string }, -- real action names that complete it
	text: string,
}

CueResolve.HintDefs = {
	{
		id = "Blizzard",
		trigger = "blizzardWarn",
		done = { "reachedFire" },
		text = "A blizzard is coming. Get close to a fire and keep it fed.",
	},
	{
		id = "DarkEvent",
		trigger = "darkEventWarn",
		done = { "reachedFire" },
		text = "Something is wrong with the night. Stay by a fire with a friend.",
	},
	{
		id = "Stalker",
		trigger = "stalkerCue",
		done = { "reachedFire", "stalkerRetreated" },
		text = "The cold is closing in. Light is safety: get near a fire.",
	},
	{
		id = "Clothing",
		trigger = "coldRing",
		done = { "clothingWorn" },
		text = "Deeper rings are colder. Craft and carry clothing to resist the cold.",
	},
	{
		id = "Storage",
		trigger = "chestNearby",
		done = { "chestOpened" },
		text = "A storage chest keeps your spare gear. Use it to open.",
	},
	{
		id = "Map",
		trigger = "hasMap",
		done = { "mapOpened" },
		text = "You have a map. Open it to see the places you have explored.",
	},
	{
		id = "Ping",
		trigger = "inParty",
		done = { "pinged" },
		text = "Tell your party where to go: open the ping wheel and pick a call.",
	},
	{
		id = "Forge",
		trigger = "hasForge",
		done = { "forgePlaced" },
		text = "You have a Forge. Select it and place it near your fire to craft metal gear.",
	},
} :: { HintDef }

-- First unseen, triggered hint in definition order (nil when none). seen/triggered: id -> true.
function CueResolve.nextHint(
	defs: { HintDef },
	seen: { [string]: boolean },
	triggered: { [string]: boolean }
): HintDef?
	for _, def in defs do
		if not seen[def.id] and triggered[def.trigger] == true then
			return def
		end
	end
	return nil
end

-- Marks every hint whose `done` includes the action as seen. Returns the ids newly completed (the caller
-- sends HintSeenRequest for each). A hint completes on its action even if it was never shown.
function CueResolve.complete(
	defs: { HintDef },
	seen: { [string]: boolean },
	action: string
): { string }
	local newly: { string } = {}
	for _, def in defs do
		if not seen[def.id] and table.find(def.done, action) then
			seen[def.id] = true
			table.insert(newly, def.id)
		end
	end
	return newly
end

-- ===== Interact pick =====
-- E / Act picks the aimed target; when nothing is aimed, the closest of a gather node and a structure.
-- A structure never loses to a gather node that is farther and not under the aim.
function CueResolve.structureBeatsGather(
	gatherDistance: number?,
	gatherAimed: boolean,
	structureDistance: number
): boolean
	if gatherDistance == nil then
		return true
	end
	if gatherAimed then
		return false
	end
	return structureDistance < gatherDistance
end

return CueResolve
