--!strict
-- Cue presentation table (pure data): cue key -> sound and particle Assets keys. Owner: brief 20
-- (atmosphere). Contract shape: data/Types.luau (brief 21). Every Config.Cue.Kinds entry has a row
-- (tested), plus extra keys for events, the Stalker, world ambience, combat, UI and meta. Assets ids
-- are placeholders ("" = silent / no particle until supplied; see docs/ART.md). Rows with scary = true
-- are scaled by Config.Settings.ReducedScareVisualMultiplier when the player's reduceScares is on.
-- Presentation only: a row never carries a hidden metric (the Cue payload only has a coarse level).

local Types = require("./Types")

local AudioCues = {}

AudioCues.Groups = { "horror", "event", "world", "combat", "ui", "meta" }

local function cue(
	key: string,
	group: string,
	sound: string?,
	particle: string?,
	volume: number,
	loop: boolean,
	scary: boolean
): Types.AudioCueDef
	return {
		key = key,
		group = group,
		sound = sound,
		particle = particle,
		volume = volume,
		loop = loop,
		scary = scary,
	}
end

AudioCues.List = {
	-- Config.Cue.Kinds: horror (sent by the Horror system)
	cue("DreadLevel", "horror", "DreadRumbleSound", "FrostMistParticle", 0.5, true, true),
	cue("StalkerTell", "horror", "FrostCreepSound", "FrostMistParticle", 0.6, false, true),
	cue("Footsteps", "horror", "StalkerCrunchSound", "SnowPuffParticle", 0.7, false, true),
	cue("FireGutter", "horror", "FireGutterSound", "SmokeParticle", 0.6, false, true),
	cue("StalkerRetreat", "horror", "StalkerRetreatSound", "SnowPuffParticle", 0.5, false, true),
	cue("LurkerSighted", "horror", "LurkerWhisperSound", nil, 0.4, false, true),
	cue("IceCrack", "world", "IceCrackSound", "IceShardParticle", 0.8, false, false),
	-- Config.Cue.Kinds: events (sent by EventService) and bosses
	cue("WarnBlizzard", "event", "EventWarningSound", nil, 0.7, false, false),
	cue("BlizzardForecast", "event", "EventWarningSound", nil, 0.5, false, false), -- silent until an id is supplied
	cue("WarnFalseNight", "event", "EventWarningSound", nil, 0.7, false, false),
	cue("WarnTheQuiet", "event", "EventWarningSound", nil, 0.7, false, false),
	cue("WarnDeepFreeze", "event", "EventWarningSound", nil, 0.7, false, false),
	cue("EventStart", "event", "EventWarningSound", nil, 0.8, false, false),
	cue("EventEnd", "event", "EventEndSound", nil, 0.6, false, false),
	cue("BossWarning", "event", "BossRoarSound", nil, 0.9, false, false),
	-- Event loops (keyed by Events id / "Blizzard"; driven by the DarkEvent / Blizzard Attributes)
	cue("Blizzard", "event", "BlizzardWindSound", "BlizzardParticle", 0.6, true, false),
	cue("FalseNight", "event", "DarkAmbientSound", "FrostMistParticle", 0.4, true, true),
	cue("TheQuiet", "event", nil, nil, 0, true, true), -- silence is the cue
	cue("DeepFreeze", "event", "DeepFreezeSound", "IceShardParticle", 0.5, true, false),
	-- Stalker and bosses
	cue("StalkerStrike", "horror", "StalkerStrikeSound", "HitSparkParticle", 0.9, false, true),
	cue("BossRoar", "combat", "BossRoarSound", nil, 0.9, false, false),
	-- World ambience
	cue("WindAmbient", "world", "WindAmbientSound", "SnowParticle", 0.3, true, false),
	cue("FireCrackle", "world", "FireCrackleSound", "EmberParticle", 0.5, true, false),
	cue("Dusk", "world", "DuskSound", nil, 0.5, false, false),
	cue("Dawn", "world", "DawnSound", nil, 0.5, false, false),
	cue("DayBanner", "world", "DayBannerSound", nil, 0.6, false, false),
	-- Combat and gathering
	cue("Swing", "combat", "SwingSound", nil, 0.5, false, false),
	cue("Chop", "combat", "ChopSound", "ResourcePopParticle", 0.6, false, false),
	cue("MobHit", "combat", "MobHitSound", "HitSparkParticle", 0.6, false, false),
	cue("Bite", "combat", "BiteSound", "HitSparkParticle", 0.7, false, false),
	cue("BowShot", "combat", "BowShotSound", nil, 0.6, false, false),
	cue("ArrowHit", "combat", "ArrowHitSound", "HitSparkParticle", 0.6, false, false),
	-- UI and interaction
	cue("Craft", "ui", "CraftSound", "ResourcePopParticle", 0.6, false, false),
	cue("Deny", "ui", "DenySound", nil, 0.5, false, false),
	cue("Ping", "ui", "PingSound", nil, 0.6, false, false),
	cue("ChestOpen", "ui", "ChestOpenSound", nil, 0.6, false, false),
	cue("Cook", "ui", "CookSound", "SmokeParticle", 0.6, false, false),
	cue("Repair", "ui", "RepairSound", nil, 0.6, false, false),
	cue("MapOpen", "ui", "MapOpenSound", nil, 0.6, false, false),
	-- Meta (lobby and run summary)
	cue("AchievementUnlocked", "meta", "AchievementSound", "CoinBurstParticle", 0.8, false, false),
	cue("PurchaseSuccess", "meta", "PurchaseSound", "CoinBurstParticle", 0.8, false, false),
	cue("PurchaseFailed", "meta", "DenySound", nil, 0.5, false, false),
	cue("Equip", "meta", "EquipSound", nil, 0.6, false, false),
	cue("CoinGain", "meta", "CoinSound", "CoinBurstParticle", 0.7, false, false),
	cue("PersonalBest", "meta", "RecordSound", "CoinBurstParticle", 0.9, false, false),
	cue("DailyClaim", "meta", "DailyClaimSound", "CoinBurstParticle", 0.7, false, false),
} :: { Types.AudioCueDef }

AudioCues.ByKey = {} :: { [string]: Types.AudioCueDef }
for _, row in AudioCues.List do
	AudioCues.ByKey[row.key] = row
end

return AudioCues
