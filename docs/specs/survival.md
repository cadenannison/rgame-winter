# Spec: Survival systems

- Three meters: health, warmth, hunger.
- Campfire, food, gathering, crafting tiers, durability, inventory.
- About 12 structures, grid-snapped and server-validated.

Source: split from docs/GDD.md. Index: docs/GDD.md.

## Survival systems

Three meters drive survival: health, warmth and hunger. Warmth and hunger tick down over time. Health falls when either reaches zero or when a player is attacked, and recovers slowly while both are healthy.

**Campfire.** It needs wood as fuel and goes out without it. Upgrades widen the warm radius and extend burn time. Most hostiles are repelled at the edge of the radius, though ranged and heavy mobs can break through. Extra campfires can be built elsewhere.

**Campfire tiers and build range.** Tiers are data (Config.Fire.Tiers): each raises warm radius, burn time (fuel cap and burn per wood), build radius and light range. A fire carries Attributes Tier, WarmRadius, BuildRadius, LightRange; wolves repel at the warm radius plus Night.RepelMargin. Warm radius = (2 + tier) x R0 (Config.Fire.BaseRadius = 18; tiers 54/72/90, each upgrade adds R0); build radius 90/126/162; light range 72/90/108. Ring dots keep a fixed spacing (Ring.Spacing) with per-layer and total caps. Structures can only be placed within the build radius of a lit campfire (server-checked at the place action; toast "Too far from the fire"). Exempt by Config.Build.RangeExempt: extra campfire (starts a new camp) and sleeping bag (travel). Upgrade: stand at the fire and use the context action "Upgrade fire"; if the materials are missing the prompt and a toast show the cost. A soft dotted ring on the ground marks the warm radius (and the build radius while a placeable is selected).

**Food.** Players hunt animals and forage for raw food. Cooking at a campfire or cooking station restores more hunger and adds a short buff. Raw food restores little or carries a downside.

**Gathering.** Trees, rocks and ore are resource nodes that need the right tool tier. Nodes respawn slowly. Far biomes hold higher-tier nodes.

**Crafting.** Crafting runs in workbench tiers: tier 0 by hand, tier 1 at the workbench, tier 2 at the forge. A recipe's station field (Config.Craft.Stations) must be within range of the player, checked by the server when crafting; near a station the context action reads "Craft", away the recipes are greyed with "needs workbench". Recipes are shared by the whole party. Clothing comes in tiers that cut warmth drain, and the far biomes are cold enough that low tiers cannot survive there.

**Durability.** Tools and weapons wear out with use. Repair at a workbench costs materials.

**Inventory.** Each player has a small hotbar and limited slots. Placeable team chests at camp provide shared storage.

**Structures (about 12 in v1).**

1. Workbench
2. Forge
3. Cooking station
4. Storage chest
5. Wall
6. Door
7. Spike trap
8. Watchtower
9. Sleeping bag or bed, which stops warmth drain for players near it
10. Extra campfire
11. Campfire upgrades
12. Map table, which crafts the fog-of-war map

Structures snap to a grid. The server validates every placement.
