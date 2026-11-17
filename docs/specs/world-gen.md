# Spec: World generation

- About 64 hand-built modular chunks in an 8x8 grid, arranged in four biome rings.
- One server-picked seed decides layout, camp site and points of interest.
- Deterministic generation with StreamingEnabled chunk loading.

Source: split from docs/GDD.md. Index: docs/GDD.md.

## World generation

The world is a square of about 2-3k studs, built from roughly 64 hand-built modular chunks (an 8 by 8 grid, so about 300-400 studs per chunk) and assembled differently each run from a seed.

- **Seed.** The server picks one seed at run start. The same seed decides the chunk layout, camp site, points of interest and resource placement, so every player in the party sees the same world.
- **Biomes in rings.** Four biomes sit in concentric rings around the map center: snowy forest (start), frozen lake, mountains and caves, then deep tundra with ruins at the edge. Cold, mob strength and loot tier rise with each ring.
- **Chunks.** Each biome has several chunk variants with slots for resource nodes, points of interest and spawn zones. The generator picks variants by seed and rotates them to avoid repetition.
- **Streaming.** Chunks load around players and unload behind them, and Roblox StreamingEnabled handles replication to clients. The server never builds the whole map at once.
- **Camp.** The camp site is random inside the start forest, with guaranteed wood and food within a short walk.
- **Points of interest.** Each chunk can host slots for abandoned cabins, crashed planes, caves and similar. Loot quality scales with distance from camp.
- **Determinism.** Given the same seed, generation produces the same world, which makes bugs reproducible.

* **Warm-up spots.** Three kinds exist out in the world: abandoned cabins with a hearth that needs wood and gives a small warm radius; hot springs in the mountain and tundra rings that are always warm but attract mobs; and player-built extra campfires and sleeping bags. Each stops warmth drain, and the Stalker will not enter them.
