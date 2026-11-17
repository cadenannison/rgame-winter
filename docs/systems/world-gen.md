# World generation (ChunkService)
Tier: standard
Purpose: One seed -> deterministic 8x8 chunk layout (phase 1: start-forest variants only) with tree/rock/food/spawn-zone slots and a camp site; chunks stream in/out around players.
Owner files: src/server/World/ChunkService.luau, src/shared/logic/WorldLayout.luau, tests/WorldTests.luau, Config.World
Public API: WorldLayout.generate(seed, params) -> Layout; .serialize, .streamDiff, .ringOf, .ringPosition, .distanceToChunk (pure). ChunkService.start/stop, .ensureLoadedAround(x, z), .getCampPosition() -> Vector3?, .getSeed(). DebugService command "teleportRing" (1 = start forest, outward, clamped).
Data touched: Workspace attributes WorldSeed (number), CampPosition (Vector3). Tag Config.World.ChunkTag on chunk Models (attrs ChunkIndex, Ring, Variant, Rotation). Slot parts tagged per Config.World.SlotTags (TreeSlot, RockSlot, FoodSlot, SpawnZoneSlot). Workspace.Chunks and Workspace.Camp folders.
Invariants: same seed + params -> identical layout (serialize equal); camp chunk is in StartForestRing; camp has CampGuaranteedWood/FoodCount resources within CampGuaranteeRadius, all inside the camp chunk; load within StreamInRadius, unload only beyond StreamOutRadius of every player; camp chunk is never unloaded; the server never builds all 64 chunks at once.
Exploit surface: no remotes. teleportRing is Studio-only via DebugService (validated + rate limited there).
Playtest checklist: 1. Studio play: Workspace.Chunks has only chunks near the camp. 2. Walk away: far chunks unload, new ones load. 3. DebugService.run teleportRing 1..4: player lands in the matching ring and chunks load. Script: tools/qa/runner.luau (scenario world). Headless: lune run tests/run.
Status: in progress (phase 1: no biome variants beyond forest, no POIs)

## Integration points
- Exposes: getCampPosition(), getCampSpawnPosition() (Spawn provider), getCampFire() (camp campfire Part in Workspace.Camp, tagged Config.Fire.Tag), ensureLoadedAround, getSeed; Workspace attrs Config.World.SeedAttribute / CampAttribute (HUD compass).
- Consumes: GatherService.registerNode(slot, "Tree"|"Rock") for every tree/rock slot it builds (tier + respawn from Config via ItemCatalog.Nodes); DebugService.register("teleportRing"). Slot tags live in Config.World.SlotTags (WorldLayout.SlotKinds aliases them).
- Started before SpawnService so the camp exists before any LoadCharacter. Tree/rock slots are visible block-out parts; other slots stay invisible.
