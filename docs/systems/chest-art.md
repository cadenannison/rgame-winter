# Chest art
Tier: standard
Purpose: five visibly different loot chests by rarity. Each rarity has its own body, lid, lock and trim colours; rare+ add a small lock gem (epic/legendary also glow harder, legendary adds a lid ridge). Glow is a few tiny client particles next to the chest; rare+ show a short client-side beam when you are close. Opened chests dim.
Owner files: src/server/Art/ChestArt.luau (geometry), src/shared/logic/ChestStyle.luau (pure look table + validation), src/client/Loot/{ChestClient,ChestVisuals,ChestPrompt}.luau (effects, prompt UI), tests/ChestTests.luau. Tuning: Config.ArtStructures (ChestGlowMaxStuds, ChestGlowEmitters, BeamMaxStuds, BeamNearStuds) and Config.Loot.Beam. Loot-only gear: LOOT_GEAR in src/shared/ItemCatalog.luau + tags in src/shared/data/Rarity.luau.

## Public API
- `ChestArt.build(rarity, cframe, parent): Model` (cframe = floor point under the chest, front faces -Z). Tags the model Config.Loot.ChestTag, sets attributes ChestRarity / LootOpened, adds an "Open" ProximityPrompt on part "Base". Fixed orientation in the world: nothing rotates a chest toward the player.
- `ChestArt.setOpened(model, true)` (idempotent; chests are never re-closed). LootService calls both through LootService.SetArtBuilder.
- `ChestStyle.get(rarity)`, `.validate`, `.partCount`, `.Budget`. Client: `ChestClient.start()` / `ChestVisuals.start()` (run mode, one require in init.client).

## Look per rarity (ChestStyle)
| Rarity | Body / lid | Accent | Glow emitters | Light | Beam |
|---|---|---|---|---|---|
| common | weathered wood, dark lid | none | 0 | none | none |
| uncommon | iron-bound dark wood | none | 0 | none | none |
| rare | frost-steel blue | lock gem | 1 | yes | short |
| epic | spectral purple | lock gem | 2 | yes | short |
| legendary | gold, bright lid | gem + lid ridge ("crown") | 3 | yes | short |
Rarity differences are colour, material, lid/lock colour and the accent parts, within the part cap below.

## Glow, light and beam (no big glow strip, no server beam)
- Server geometry only: base, lid, two straps, lock, plus the optional gem and lid ridge. <= ChestStyle.Budget.MaxParts (8) parts per chest. There is NO glow strip and NO beam part on the server.
- Glow (client, `ChestVisuals`): 1/2/3 small ParticleEmitters (rare/epic/legendary, never more than Config.ArtStructures.ChestGlowEmitters) on top of the chest. Particles never travel further than Config.ArtStructures.ChestGlowMaxStuds (2 studs) from the chest (speed x lifetime capped). A PointLight and the gem pulse (gem transparency swings by pulseAmount) exist only on the nearest MaxEffectChests chests within EffectRadius (90 studs).
- Beam (client only): rare+ (Config.Loot.Beam.MinRarity), a thin upright neon column created locally for chests within Config.ArtStructures.BeamNearStuds (40) of the local player, at most Beam.MaxActive, height <= min(style.beamHeight, ArtStructures.BeamMaxStuds 14, Config.Loot.Beam.MaxHeight 12). It never exists on the server, never rotates (always vertical), fades by camera distance (`ChestStyle.beamFade`: hidden beyond Beam.VisibleRadius, fading over FadeBand), and is destroyed when out of range or when the chest is opened. No sky pillars.
- Opened chests lose emitters, light, gem glow, beam and prompt; colours dim by OpenedDim; one burst (burstCount) + sound hook plays once.
- One RenderStepped loop for all chests (the beam pass runs on a 0.1 s sweep inside it); all connections and instances are cleaned on untag/destroy.

## Data and exploit surface
Data touched: attributes ChestRarity, LootOpened; tag LootChest; remote LootOpenRequest {chest} (client prompt Triggered, server re-validates range, rate, state, line of sight). The client only displays; nothing visual is trusted or sent to the server. Chest contents never replicate.

## Invariants (tests/ChestTests.luau)
Every rarity validates; parts <= 8; distinct bodyColor/lidColor per rarity; glow emitters <= ChestGlowEmitters; beam only for rare+ and <= both height caps; light/particle numbers inside Budget and Config.Perf.MaxParticleRate.

## Playtest checklist (hand, Studio)
1 Walk up to each rarity: lid/lock/trim differ, label colour matches, E / tap / X opens. 2 Rare+: a few glow particles hug the chest (within ~2 studs), no big glow; the short beam only appears when you are within ~40 studs. 3 Chests never turn to face the camera, from any angle. 4 Open a chest: lid swings, burst, dims, prompt gone, beam and particles vanish. 5 Many chests in a structure: only the nearest glow; FPS ok. 6 Phone emulation: button >= 44 px and tappable; hold chests (epic 0.25 s, legendary 0.5 s) show a fill bar.

Sound hooks: Assets keys ChestOpenCommonSound / ChestOpenUncommonSound / ChestOpenRareSound / ChestOpenEpicSound / ChestOpenLegendarySound and ChestParticle (texture); absent or "" = silent / engine sparkle.
Status: Art Pass 4 code done (headless); Studio hand-check pending.
