# Massive structures B (shipwreck, temple, lodge, ruins)
Tier: standard
Purpose: Four large enterable structures: frozen shipwreck (lake), ruined temple (deep tundra), ranger lodge (forest), expanded ruins complex. Pure plans (rooms, doors, ramps, chests) plus one thin Roblox adapter.
Owner files: src/shared/logic/{PlanKitB,ShipwreckPlan,TemplePlan,LodgePlan,RuinsPlan}.luau, src/server/World/Structures/{StructureKitB,FrozenShipwreck,RuinedTemple,RangerLodge,RuinsComplex}.luau, src/server/World/PoiStructures.luau (adds styleOf/lightColor), tests/StructureBTests.luau
Public API: each builder `build(origin: Vector3, seed: number, parent: Instance): Handle` (Config.Massive ids: FrozenShipwreck, RuinedTemple, RangerLodge, ExpandedRuins; RuinsComplex.Id = "ExpandedRuins").
Handle = { Model, Footprint {radius, halfX, halfZ}, ChestSlots {{Position, Depth, StructureType}}, Update(playerPositions), Destroy(), Origin (footprint centre at ground), DreadZones {{Position, Radius, Kind}}, DreadListener }.
- Update(positions) every Config.Massive.DressingCheckInterval: spawns each room's dressing when a player is within DressingSpawnRadius (distance to the room box), up to DressingPartsPerTick parts per call, removes it beyond DressingDespawnRadius. Self-throttled.
- Temple dread hook: set `handle.DreadListener = function(position, kind)`; called (pcall, 20 s per zone) while a position is inside a crypt room ("Crypt") or the legendary chamber ("Legendary"). Integration maps the position to a player and calls DreadService.addSighting / a Cue.
- Placement (integration): origin X/Z from the seed within Massive rings; Y is ignored (ground = median World.heightAt over the footprint); reserve MassiveRules.footprintRadius(id); build AFTER the chunk terrain streamed (the builder edits Terrain: a levelled pad then carved voids); Destroy does not refill terrain (chunk regen does).
Data touched: Terrain voxels (FillBlock only), model attributes StructureType/Seed. No Attributes/remotes/persistence.
Invariants (tests/StructureBTests.luau, 24 seeds each): MassiveRules.validatePlan clean; every room reachable from the entrance; every room has a unique landmark prop; doors >= 6 wide, 9 high, ceilings >= 12, ramps 7 wide at 1:3 (18 deg), stair lanes 6; doorways free of walls/landmarks/props; underground rooms carved and below ground; deepest chest in a deepest room; plans deterministic per seed (yaw 0..3 quarter turns).
Layouts: ship = hold/crew/flooded (L0), deck/galley/forecastle (L1), captain (L2), ramps hold->deck->captain, breaches at hull sides, water slab in the flooded deck. Temple/ruins/lodge = surface rooms plus a switchback stair shaft (two ramp flights and a landing) down to carved underground rooms.
Exploit surface: none (server-only, no remotes). Chest slots are data; LootService owns chests.
Playtest checklist (hand): 1 walk into each structure and reach every room; 2 take the stairs/ramps on PC and mobile; 3 check dressing appears/disappears while walking; 4 temple crypt dread hook; 5 ship floats level on ice, lodge hearth burns; 6 part count in the Studio stats stays under Config.Massive budgets.
Status: in progress (headless done; Studio hand-check pending)

Integration: wired by src/server/World/MassiveService.luau + MassivePlacement (see docs/systems/world-gen.md). Studio hand-check pending.

## Items round
The hard-edged `Kit.pad` fill (grey Rock + Slate top) is replaced by SiteGround levelling with a blended skirt in the biome material. Chest slots carry `Room`; chests are on the floor (`y = room.y`). Counts: `Config.Loot.Chests`. See loot.md / world-gen.md.
