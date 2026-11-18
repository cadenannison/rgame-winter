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
	PadJoinSound = "rbxasset://sounds/electronicpingshort.wav", -- placeholder: you stepped onto a pad
	PadLeaveSound = "rbxasset://sounds/button.wav", -- placeholder: you left a pad
	PadTickSound = "", -- needed: soft tick for the last 5 seconds of the pad timer (silent until supplied)
	DailyClaimSound = "rbxasset://sounds/electronicpingshort.wav", -- placeholder: daily reward claimed
	SummarySound = "", -- needed: run summary sting (silent until supplied)
	-- Phase 3 (brief 12): all "" until supplied; consumers stay silent / use block-outs. See docs/ART.md.
	DreadRumbleSound = "", -- low rumble that builds with the DreadLevel cue (brief 15)
	FrostEdgeTexture = "", -- screen-edge frost overlay for DreadLevel / StalkerTell (brief 15)
	StalkerCrunchSound = "", -- snow crunch behind the player (Footsteps cue, brief 15)
	StalkerStrikeSound = "", -- Stalker hit (brief 15)
	FireGutterSound = "", -- fire sputter (FireGutter cue, brief 15)
	IceCrackSound = "", -- thin-ice crack (IceCrack cue, brief 15)
	LurkerWhisperSound = "", -- faint sound on a lurker sighting (brief 15)
	BlizzardWindSound = "", -- blizzard loop (brief 14)
	EventWarningSound = "", -- dark event warning sting (brief 14)
	DeepFreezeSound = "", -- deep freeze ice creak loop (brief 14)
	BossRoarSound = "", -- mini-boss / blizzard boss roar (brief 16)
	BowShotSound = "", -- bow release (brief 16)
	ArrowHitSound = "", -- arrow impact (brief 16)
	PingSound = "", -- ping wheel marker (brief 17)
	ChestOpenSound = "", -- storage chest open (brief 17)
	CookSound = "", -- cooking sizzle (brief 17)
	RepairSound = "", -- repair confirm (brief 17)
	MapOpenSound = "", -- map unfold (brief 13)
	-- Phase 4 (brief 21 contracts; data/AudioCues.luau maps cues to these). All "" until supplied.
	FrostCreepSound = "", -- StalkerTell frost creep (brief 20)
	StalkerRetreatSound = "", -- Stalker backs off (brief 20)
	EventEndSound = "", -- dark event / blizzard over (brief 20)
	DarkAmbientSound = "", -- False Night ambience loop (brief 20)
	WindAmbientSound = "", -- ambient wind loop (brief 20)
	FireCrackleSound = "", -- campfire crackle loop (brief 20)
	DayBannerSound = "", -- "Day N survived" fanfare (brief 20)
	AchievementSound = "", -- achievement unlocked toast (brief 19)
	PurchaseSound = "", -- shop purchase success (brief 19)
	EquipSound = "", -- equip cosmetic / perk / title (brief 19)
	CoinSound = "", -- coins granted (brief 19)
	RecordSound = "", -- new personal best (brief 19)
	SnowParticle = "", -- falling snow texture (brief 20)
	SnowPuffParticle = "", -- snow puff / footstep (brief 20)
	FrostMistParticle = "", -- cold mist for horror cues (brief 20)
	BlizzardParticle = "", -- dense blizzard snow (brief 20)
	IceShardParticle = "", -- ice crack / deep freeze shards (brief 20)
	EmberParticle = "", -- fire embers (brief 20)
	SmokeParticle = "", -- fire gutter / cooking smoke (brief 20)
	HitSparkParticle = "", -- hit sparks (brief 20)
	ResourcePopParticle = "", -- gather / craft pop (brief 20)
	CoinBurstParticle = "", -- coin burst on rewards (brief 19/20)
	-- Phase 4 shop cosmetics (brief 19): meshes/textures by Shop id; "" = block-out
	CosmeticFurTrimHood = "",
	CosmeticRangerJacket = "",
	CosmeticFrostTrail = "",
	CosmeticEmberTrail = "",
	CosmeticCampBanner = "",
	CosmeticLanternString = "",
	CosmeticArcticFox = "",
	CosmeticSnowOwl = "",
	CosmeticAuroraParka = "",
	CosmeticNorthernLightsTrail = "",
	CosmeticHuskyPup = "",
}

return Assets
