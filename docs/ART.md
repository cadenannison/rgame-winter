# Art log
Every imported asset: id, creator, source. No branded or copyrighted content. Strip all scripts from imported models.

| asset | id | creator | source | notes |
|---|---|---|---|---|
| SwingSound, ChopSound, MobHitSound, CraftSound, DenySound | rbxasset://sounds/* | Roblox | engine-bundled | placeholders in src/shared/Assets.luau |

## Needed assets (human must supply ids in src/shared/Assets.luau)
- SwingAnimation: R15 one-shot tool swing (empty now -> procedural arm swing).
- SwingSound, ChopSound (wood chop / stone hit), MobHitSound, CraftSound, DenySound: replace the engine placeholders.

- WolfGrowlSound, DuskSound, DawnSound: empty now (silent). Growl (~1s, low), soft dusk cue, soft dawn cue. BiteSound is the engine placeholder rbxasset://sounds/uuhhh.mp3; replace with a real hurt/bite sound.
- Lobby (brief 10): PadJoinSound, PadLeaveSound, DailyClaimSound are engine placeholders; PadTickSound and SummarySound are empty (silent). Lobby lodge is block placeholders from tools/build_lobby.luau.
- Phase 3 (brief 12 contracts; all empty "" in src/shared/Assets.luau, consumers stay silent / block-out until supplied):
  - Horror (brief 15): DreadRumbleSound (low loop), FrostEdgeTexture (screen-edge frost decal), StalkerCrunchSound, StalkerStrikeSound, FireGutterSound, IceCrackSound, LurkerWhisperSound.
  - Events (brief 14): BlizzardWindSound (loop), EventWarningSound (short sting), DeepFreezeSound (loop).
  - Mobs/bosses (brief 16): BossRoarSound, BowShotSound, ArrowHitSound. Mob models (polar bear, ice wraith, snow lurker, cave crawler, fish, 3 mini-bosses, blizzard boss, Stalker) are block-outs until supplied.
  - Structures/progression (brief 17): PingSound, ChestOpenSound, CookSound, RepairSound.
  - World (brief 13): MapOpenSound; biome ground/props are block-outs (Biomes.color).

- Phase 3 placeholders in the world (block-outs, no ids yet): POI cabins, hearths, hot springs (glass cylinder), thin-ice patches, crash plane, caves, ruins, loot crates (PoiService); IronOre slots; Stalker and lurker models (HorrorWorld.makeModel boxes); structures Forge, CookingStation, StorageChest, Wall, Door, SpikeTrap, Watchtower (+ TrussPart ladder), SleepingBag, MapTable; held items (Config.Held.Visuals blocks incl. Torch/Lantern/Flare/Bow); arrows (ProjectileFired visual).
- Event look (client EventCues): Atmosphere "EventAtmosphere" + ColorCorrection "EventTint" (no assets); Horror frost edges are tinted frames until FrostEdgeTexture is supplied.
- The Stalker strike reuses BiteSound and the bite flash (BiteSeq) until StalkerStrikeSound is supplied.

- Phase 4 (brief 21 contracts; all empty "" in src/shared/Assets.luau; data/AudioCues.luau maps every cue to these):
  - Atmosphere (brief 20) sounds: FrostCreepSound, StalkerRetreatSound, EventEndSound, DarkAmbientSound (loop), WindAmbientSound (loop), FireCrackleSound (loop), DayBannerSound.
  - Atmosphere (brief 20) particle textures: SnowParticle, SnowPuffParticle, FrostMistParticle, BlizzardParticle, IceShardParticle, EmberParticle, SmokeParticle, HitSparkParticle, ResourcePopParticle, CoinBurstParticle.
  - Meta (brief 19) sounds: AchievementSound, PurchaseSound, EquipSound, CoinSound, RecordSound.
  - Shop cosmetics (brief 19; block-outs until supplied): CosmeticFurTrimHood, CosmeticRangerJacket, CosmeticFrostTrail, CosmeticEmberTrail, CosmeticCampBanner, CosmeticLanternString, CosmeticArcticFox, CosmeticSnowOwl, CosmeticAuroraParka, CosmeticNorthernLightsTrail, CosmeticHuskyPup.
  - Developer product ids (not assets) go in Config.Meta.ProductIds: CoinPackSmall, CoinPackMedium, CoinPackLarge, AuroraParka, NorthernLightsTrail, HuskyPup (0 = not for sale yet).

Part counts per built area: (record here)

## Phase 4 integration (brief 21)
- Checked: every key in src/shared/Assets.luau is listed above (script check in brief 21). No new asset keys were added.
- Meta cues now play through AtmosphereFx (one path, no double audio): AchievementUnlocked -> AchievementSound, PurchaseSuccess -> PurchaseSound, PurchaseFailed -> DenySound, DailyClaim -> DailyClaimSound (was played directly by the lobby menu), PersonalBest -> RecordSound (replaces SummarySound on a record run), all with CoinBurstParticle where listed in data/AudioCues.
- Cosmetics are data only on the character: attribute Cosmetic (id) and tag Cosmetic_<slot> (Config.Meta.CosmeticTagPrefix + outfit/trail/camp/pet). Art scripts react to the tag once the Cosmetic<Id> assets exist.
- Still needed before launch (grouped): engine-placeholder sounds (Swing/Chop/MobHit/Craft/Deny/Bite/PadJoin/PadLeave/DailyClaim); every empty "" sound and particle above; SwingAnimation; mob, Stalker, lurker, structure and POI models (block-outs); the 11 Cosmetic<Id> models; developer product ids in Config.Meta.ProductIds.


## Art pass 1: hub (see docs/ART_PLAN.md, docs/ART_STATUS.md)
- Hub is built by tools/build_lobby.luau -> src/server/Art/HubBuilder + HubProps (idempotent, Part-built plus two Creator Store pines). Layout, palette, tags and budgets: Config.Art.Hub. Sanitised models live in ServerStorage.ArtAssets (name = Assets key); a missing model falls back to Part-built pines.
- Swap a model: change its id in src/shared/Assets.luau (HubPineSmall / HubPineLarge), insert the new asset into ServerStorage.ArtAssets under the same name, strip scripts (see docs/CREDITS.md), re-run the builder.
- Needed (silent until supplied): HubWindSound, HubFireCrackleSound, HubMusicSound (loops; hooks already placed in the hub), SnowParticle (hub snow uses the engine sparkle texture until then).
- Review: `/debug gallery hub` (Studio chat) lays out every hub prop in a labelled row; `/debug gallery clear` removes it.
- Billboards over pads (size label, timer, Join) are client UI, not Parts.

## Audio pass: interaction sound hook points
Interaction audio is silent for now (E no longer spams hit sounds). Re-enable by removing names from `Config.Feedback.MutedSounds` (src/shared/Config/Ui.luau) and/or adding calls at these hooks:
- Swing: `Feedback.swing` / `Feedback.swingOther` (src/client/HUD/Feedback.luau) -> SwingSound (muted).
- Chop / mine hit: `HitWatch` confirm (src/client/HUD/HitWatch.luau), node hits attribute -> ChopSound (muted); distinct mine/chop ids should split by node kind there.
- Mob hit: same confirm, isMob -> MobHitSound (muted).
- Pickup: ItemDrop / GatherService pickup notify (no client sound yet; add on the Notify "gather" event).
- Structure interact (door toggled, chest/station use): src/client/HUD/StructureInteract.luau, comments mark the spots (previously CraftSound).
