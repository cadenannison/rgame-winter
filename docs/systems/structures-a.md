# Massive structures A (Research Station, Mine Complex)
Tier: full
Purpose: Two genuinely massive explorable structures: an abandoned research station (ring 2-3) and a mine complex (ring 2),
each with 23-25 rooms over 3-4 levels, loot slots weighted by depth, spooky atmosphere (PG) and hidden Horror hooks.
Owner files: src/server/World/Structures/{ResearchStation,MineComplex,StructureKitA}.luau,
src/shared/logic/{StructurePlanKitA,ResearchStationPlan,MineComplexPlan}.luau, tests/StructureATests.luau
Public API:
- `ResearchStation.build(origin, seed, parent): Handle` and `MineComplex.build(origin, seed, parent): Handle` (origin X/Z used; the adapter samples World.heightAt(seed, x, z) over the footprint, sits the entrance floor at the lowest terrain top, rotates by a seed quarter-turn).
- Handle: `Model`, `Footprint {radius, sizeX, sizeZ, center}`, `ChestSlots {{Position, Depth, StructureType}}` (StructureType = Config.Massive id), `Update(playerPositions)`, `Destroy()`.
- Extra server-only Handle data for Horror/audio: `LurkerSpots {Vector3}` (dark rooms, "eyes in the dark"), `CueSpots {{Position, Kind, Room}}` (Drip, Hum, Creak, Wind, Static, Scratch, Whisper, Rumble, Echo), `RoomAt(pos) -> {Id, Name, Level, Dark}?`.
- Pure: `ResearchStationPlan.plan(seed)`, `MineComplexPlan.plan(seed)`, `StructurePlanKitA.validate(plan)` (MassiveRules.validatePlan + reachability, doors, ramps, chests, PG text).
Data touched: Model attribute MassiveId. No saved data, no remotes, no tags. Terrain voxels carved to air (not refilled on Destroy).
Invariants (tested headless in tests/StructureATests.luau):
- Plans meet Config.Massive: footprint, rooms, levels, depth, corridor >= 6, ceiling >= 10, parts/dressing/lights/particles in budget.
- Every room has a path to an exit; rooms never overlap; doors >= 6 wide, 9 high; stair halls are a flat landing plus a ramp <= 30 degrees, side doors only on the landing.
- Dressing never blocks a doorway; chests sit >= 2.5 studs inside walls, depth grows with level (deepest rooms hold depth 4, surface <= 1).
- Notes/signs contain no gore words (PG). Same seed, same plan; seed varies notes, chest corners, flicker.
- Interior dressing exists only while a player is within DressingSpawnRadius (hysteresis DressingDespawnRadius), <= DressingPartsPerTick parts per Update.
- One Heartbeat loop for all live structures (flicker, shy eyes), disconnected when none are live.
Exploit surface: none (server-only, no client input). Dread/lurker data never replicated.
Integration notes: call Update every Config.Massive.DressingCheckInterval; build after the covering terrain chunks exist (carving air into unbuilt chunks is overwritten when they build) and re-run if a chunk rebuilds; place by ring (Config.Massive.Structures[id].Rings) and MinSeparation.
Playtest checklist (hand, Studio):
1. Walk in via the vehicle bay / ore sorting shed; ramps down are smooth on PC and mobile; every room reachable, back to surface via the same ramps.
2. Rooms show a sign, landmark props, notes (read within ~14 studs), claw marks; lights flicker; eyes vanish when approached.
3. Leave the area (>130 studs): dressing disappears; return: it respawns without hitching.
4. Check the terrain around the entrance ramps and the carve edges on a steep mountain site.
Status: in progress (headless done; Studio hand-check pending)

Integration: wired by src/server/World/MassiveService.luau + MassivePlacement (see docs/systems/world-gen.md). Studio hand-check pending.
