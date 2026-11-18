# Horror (Dread, Stalker, lurkers)
Tier: full
Purpose: Hidden per-party Dread drives an unkillable Stalker and ambient lurkers that push isolated players back to fire.
Players only ever see sensory cues (Remotes.Cue) and the creature models themselves; every metric stays on the server.
Owner files: src/shared/logic/DreadLogic.luau, src/shared/logic/Isolation.luau, src/shared/data/Lurkers.luau,
src/server/Horror/{DreadService,StalkerService,LurkerService,CueSender,HorrorWorld}.luau, src/server/Phase3/HorrorBoot.luau,
src/client/Phase3/HorrorClient.luau, src/client/Horror/HorrorCues.luau, tests/HorrorTests.luau
Public API:
- Isolation.weights(points, partySize, cfg?) -> { weight }, .fullGroup(points, cfg?) -> boolean, .pick(weights, roll) -> index?, .mostIsolated(weights) -> index?
- DreadLogic.step(dread, inputs, dt, cfg?) -> dread, .cueLevel(dread, cfg?), .huntChance(dread, day, bonus, cfg?), .canHunt(ctx, cfg?),
  .lurkerDensity(day, ring, isolation, cfg?), .strikeDamage(health, maxHealth, cfg?), .clampOutside(pos, repellers, margin), .stepHunt(hunt, inputs, dt, cfg?)
- DreadService.addSighting(player, amount?), .isFullGroup(), .setPartyProvider/.setCampProvider/.setEventProvider
- StalkerService.isHunting(), .onStrike(cb(player)), .forceHunt(), .setFireProvider/.setWarmSpotProvider/.setLightProvider/.setEventProvider
- LurkerService.start()/stop()
- Remotes.Cue (server -> client, CuePayload): DreadLevel, StalkerTell, Footsteps, FireGutter, StalkerRetreat, LurkerSighted, IceCrack
Data touched: Tags Config.Stalker.Tag / Config.Lurkers.Tag on placeholder models (plus visible LurkerKind attribute). No saved data.
Reads Workspace Day/IsNight/DarkEvent/Blizzard and Player BiomeRing attributes.
Invariants:
- Dread, hunt chance, timers, isolation weights and lurker rolls never leave the server (no attribute, remote field or print).
- DreadLevel cue carries only a coarse level 0..Cue.MaxLevel, sent on change only; every cue is throttled per player per kind.
- Isolation weight order: alone > pair > group; solo party uses SoloBaseline; a full group (party in one connected cluster) blocks hunts.
- Hunt chance <= Stalker.MaxHuntChance; no hunt before Stalker.FirstHuntDay; HuntCooldownSeconds between hunts.
- Dread gain multipliers clamp to MaxDay/MaxRing/Events.MaxDreadGainMultiplier; lurker density clamps to Lurkers.MaxDensity.
- A strike never takes a player from full health to 0; the Stalker always retreats after a strike.
- The Stalker never stands inside a lit fire radius or a warm spot (+FireRepelMargin), and keeps out of torch/flare repel radii.
- The Stalker has no Humanoid and is never a mob: nothing can damage it. Lurkers never attack.
Exploit surface: none client-driven (no client -> server remotes). Light/torch state is read server-side through providers.
Playtest checklist:
1. Day 1: no hunt. Debug `stalker` summon forces a hunt on the most isolated player.
2. Target gets StalkerTell, Footsteps, FireGutter cues for TelegraphSeconds before chase.
3. Stand in fire radius: the Stalker stops at the edge. Hold a flare: hunt ends with StalkerRetreat.
4. Strike from full health leaves health > 0, knocks back, drops warmth; then it retreats.
5. Lurkers spawn out of sight, vanish when approached/faced, LurkerSighted cue; thin ice near scratchers cracks and costs warmth.
QA script: tools/qa/horror.luau (pending; brief 18 runs it).
Status: in progress
