# Spec: Survival systems

- Three meters: health, warmth, hunger.
- Campfire, food, gathering, crafting tiers, durability, inventory.
- About 12 structures, grid-snapped and server-validated.

Source: split from docs/GDD.md. Index: docs/GDD.md.

## Survival systems

Three meters drive survival: health, warmth and hunger. Warmth and hunger tick down over time. Health falls when either reaches zero or when a player is attacked, and recovers slowly while both are healthy.

**Campfire.** It needs wood as fuel and goes out without it. Upgrades widen the warm radius and extend burn time. Most hostiles are repelled at the edge of the radius, though ranged and heavy mobs can break through. Extra campfires can be built elsewhere.

**Food.** Players hunt animals and forage for raw food. Cooking at a campfire or cooking station restores more hunger and adds a short buff. Raw food restores little or carries a downside.

**Gathering.** Trees, rocks and ore are resource nodes that need the right tool tier. Nodes respawn slowly. Far biomes hold higher-tier nodes.

**Crafting.** Crafting runs in workbench tiers: tier 0 by hand, tier 1 at the workbench, tier 2 at the forge. Recipes are shared by the whole party. Clothing comes in tiers that cut warmth drain, and the far biomes are cold enough that low tiers cannot survive there.

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
