# Mobs
Tier: full
Purpose: Server-run capped mob spawns near players; AI runs only near players. Hare and caribou flee, wolf hunts at night and is repelled at the campfire edge. Players melee mobs via AttackRequest.
Owner files: src/server/Mobs/MobService.luau, src/shared/logic/MobAI.luau, src/shared/logic/MobRules.luau, tests/MobTests.luau
Public API: MobService.start(); MobService.AIStepCount (debug counter). Remote AttackRequest (client -> server, target: Instance?). Pure: MobAI.decide, MobRules.{selectActive, shouldDespawn, budget, scaledStat, pickWeighted, spawnDistanceOk, canMelee}.
Data touched: Workspace attrs Config.Time.DayAttribute / IsNightAttribute (read); Player attrs Config.Downed.StateAttribute, Config.Debug.PlayerInvincibleAttribute (read); CollectionService tags Config.Mobs.Tag (mobs, set), Config.Fire.Tag (campfires, read); mob model attrs MobKind, MobHealth; Workspace.Mobs folder.
Invariants: (1) no mob AI step runs when no player is within AIActiveRadius (MobRules.selectActive, tested); (2) live mobs never exceed the scaled budget at spawn time; (3) budget and stat scaling are capped; (4) mobs despawn when no player is within DespawnDistance; (5) damage and distance on attacks are recomputed server-side; (6) one Heartbeat connection drives all mobs.
Exploit surface: Spoofed or non-mob target -> rejected (typeof + registry lookup). Spam -> Guard rate limit plus per-player melee cooldown. Out-of-range hits -> server distance check (MeleeRange + LagCompensation). Downed/dead attackers rejected. Client never supplies damage.
Playtest checklist: 1. Start play with local player; confirm Workspace.Mobs fills up to budget within ~30s. 2. Walk toward a hare/caribou; it flees. 3. Set IsNight=true; wolves spawn and chase; wolves retreat at a lit campfire's RepelRadius. 4. Fire AttackRequest at a mob in range: health drops; out of range: no change. 5. Teleport far away: mobs despawn, AIStepCount stops rising. QA script: tools/qa/day3-solo.luau (wolf_repelled).
Status: in progress

## Integration points
- Exposes: MobService.spawn(kindName, position) -> Model? (server/QA), getLastAction(model), handleAttack (QA/server path, full validation), AIStepCount.
- Consumes: FireService.getLitPositions() for the repel edge (only lit fires repel); InventoryService.getSelected for weapon damage (ItemCatalog damage for kind "weapon", else Combat.MeleeBaseDamage) and wearSelected (Combat.WeaponDurabilityPerHit); InventoryService.add for drops (MobStats.DropId/DropCount: hare 1 and caribou 3 RawMeat, wolf 1 Hide) straight to the killer.
- Config: all former local tuning is in Config.Mobs (FolderName, attrs, wander/flee/retreat, spawn ray); budget cap is Scaling.MaxMobBudgetMultiplier; attack rate is Net.AttackRateInterval only.
- Catchable prey (client UX pass): flee runs in bursts (MobStats.FleeBurstSeconds) with pauses (FleeRestSeconds), MobAI.fleeBurst (pure, tested); lastAction "Rest" during pauses. Hare FleeSpeed 12 and caribou 13 are below Config.WALK_SPEED 16. Melee reach = Combat.MeleeRange + MobStats.HitRadius + LagCompensation (server). Gather tools deal Combat.ToolDamage (axe one-shots a day-1 hare), weapons their catalog damage, else MeleeBaseDamage; tools/weapons wear per hit.
- Kill: unregistered at once (tag removed, anchored), MobHealth set to 0, destroyed after Mobs.DeathRemoveDelay so clients play the hit confirm from the attribute.

## Night danger
- Wolf attack: in range + ready -> Windup (Config.Night.WindupSeconds; mob attr Windup true, client growl + tint) -> bite if the target is still within AttackRange + StrikeLeeway (dodgeable). Bite = Wolf.Damage (scaled), AttackCooldown 2s; Player attr BiteSeq bumps (client flash + sound, NightFeedback.luau). MobAI.windupStep (pure).
- Fire repel reads each lit fire's WarmRadius attribute (fallback Fire.WarmRadius via RepelRadius) + Night.RepelMargin; chase targets are clamped outside the circle (FireRepel, pure). Lit = FuelSeconds > 0 on Config.Fire.Tag instances.
- Dawn: night-only mobs decide "Leave" (run from nearest player), despawn after Night.DawnLeaveSeconds.
- Lighting: DayNightService writes Lighting every Lighting.UpdateInterval from LightingMath.nightAmount (dusk/dawn ramp = TwilightPhase). Client adds a PointLight (WarmLight) to lit campfires sized from WarmRadius. Dusk/dawn cues: Assets DuskSound/DawnSound (empty = silent, see ART.md).
- QA: tools/qa/night-danger.luau; sim: tests/sim.luau night-danger section, tests/NightTests.luau.
