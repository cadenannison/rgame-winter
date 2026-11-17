# Mobs
Tier: full
Purpose: Server-run capped mob spawns near players; AI runs only near players. Hare and caribou flee, wolf hunts at night and is repelled at the campfire edge. Players melee mobs via AttackRequest.
Owner files: src/server/Mobs/MobService.luau, src/shared/logic/MobAI.luau, src/shared/logic/MobRules.luau, tests/MobTests.luau
Public API: MobService.start(); MobService.AIStepCount (debug counter). Remote AttackRequest (client -> server, target: Instance?). Pure: MobAI.decide, MobRules.{selectActive, shouldDespawn, budget, scaledStat, pickWeighted, spawnDistanceOk, canMelee}.
Data touched: Workspace attrs Config.Time.DayAttribute / IsNightAttribute (read); Player attrs Config.Downed.StateAttribute, Config.Debug.PlayerInvincibleAttribute (read); CollectionService tags Config.Mobs.Tag (mobs, set), Config.Fire.Tag (campfires, read); mob model attrs MobKind, MobHealth; Workspace.Mobs folder.
Invariants: (1) no mob AI step runs when no player is within AIActiveRadius (MobRules.selectActive, tested); (2) live mobs never exceed the scaled budget at spawn time; (3) budget and stat scaling are capped; (4) mobs despawn when no player is within DespawnDistance; (5) damage and distance on attacks are recomputed server-side; (6) one Heartbeat connection drives all mobs.
Exploit surface: Spoofed or non-mob target -> rejected (typeof + registry lookup). Spam -> Guard rate limit plus per-player melee cooldown. Out-of-range hits -> server distance check (MeleeRange + LagCompensation). Downed/dead attackers rejected. Client never supplies damage.
Playtest checklist: 1. Start play with local player; confirm Workspace.Mobs fills up to budget within ~30s. 2. Walk toward a hare/caribou; it flees. 3. Set IsNight=true; wolves spawn and chase; wolves stop at a Campfire-tagged part's RepelRadius. 4. Fire AttackRequest at a mob in range: health drops; out of range: no change. 5. Teleport far away: mobs despawn, AIStepCount stops rising. QA script: tools/qa (not yet written).
Status: in progress

## Notes
- Fires: any instance with Config.Fire.Tag counts as active (no Fuel/Lit attribute read yet).
- Weapon damage: fist (Config.Combat.MeleeBaseDamage) only; spear/equipped item not read until the inventory exposes it.
- No drops on death yet.
- Local constants pending Config: wander radius/interval, flee/retreat step, spawn ray, model sizes/colors.
