# Spec: Combat, mobs and bosses

- Third-person tool melee and ranged combat; friendly fire only via projectiles.
- Roster of animals, hostiles, mini-bosses and a blizzard boss.
- Server-run capped spawn budget with gradual scaling.

Source: split from docs/GDD.md. Index: docs/GDD.md.

## Combat, mobs and bosses

Combat is third-person with simple tool-based melee (spear, axe) and ranged (bow) weapons. Only projectiles can hit teammates. On mobile, one context action button attacks, gathers or interacts depending on the target, and ranged weapons get aim assist.

**Roster (proposed names, all tunable).**

| Type | Mobs |
| --- | --- |
| Huntable animals (3) | Arctic hare, caribou, fish |
| Hostiles (5) | Wolf, polar bear, ice wraith (ranged), snow lurker (ambusher), cave crawler |
| Mini-bosses (3) | One guardian in each far biome (frozen lake, mountains and caves, deep tundra). They spawn later in the run and can be killed |
| Blizzard boss (1) | Attacks camp during selected blizzards |

**Behavior.** Animals roam by day and flee. Hostiles hunt players at night and during blizzards. Fire radius repels most of them. Ranged and heavy mobs and the bosses can break through, so walls, traps and weapons matter.

**Spawning.** The server keeps a capped spawn budget around players. Mobs spawn and despawn near players, and their AI runs only when a player is close. Nothing is pre-spawned across the whole map.

**Scaling.** Mob count, health and spawn rate rise only gradually with days survived and distance from camp, and each has a ceiling so exploration never becomes impossible. A party-size factor keeps solo play fair and larger parties challenged. All constants live in Config.

## Combat balance (round: contracts, agent F)

- Hits to kill with the starting Axe (Combat.ToolDamage 8), day 1, solo, camp ring: hare 3 (Mobs.Hare.Health 20; target Combat.HareHitsMin..HareHitsMax = 2..3), wolf 5 (Mobs.Wolf.Health 35; target WolfHitsMin..WolfHitsMax = 4..5). Better weapons kill in fewer hits (Spear 12, IronSpear 20). Tested in tests/MobTests.luau via MobRules.hitsToKill.
- Health scales by day, ring and party (MobScaling); the hit windows are a day-1 solo target. Wolf health reaches 6 Axe hits from about day 5 (health multiplier above 40/35).
- The starting Axe is unbreakable (Config.Durability.UnbreakableItems): it never needs repair and the HUD shows "n/a". Other tools and weapons still wear.

## Round contracts: fire creature rules and wolf scaling
Config.FireRules (spawn exclusion for hostile/miniboss/boss plus Stalker/Lurker, live tree clearing around fires) and Config.WolfScaling (per-day wolf damage and spawn-rate factors, capped). See docs/INTEGRATION.md.

Wolf difficulty: health stays fixed so the starting Axe always kills a wolf in 4-5 hits; days raise wolf bite damage and spawn frequency (capped). Bosses may break the fire edge but never spawn inside a fire's warm radius.
