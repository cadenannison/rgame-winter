# Hand tests: terrain / forest / structures / fire / death / balance round
Nothing here has been played in Studio. Check on PC and phone emulation. Place id 130366229723914.

## Terrain
- Spawn and camp sit on flat ground; no gaps or seams at chunk borders; no hitch when a chunk streams in (FillBlock is synchronous; if it hitches, it needs yielding).
- Walk every biome: gradual ups/downs, never needs a jump; lake nearly flat, mountains largest. Terrain colours look right (Snow/Ice/Rock/Glacier).
- Walk off the world edge: no invisible wall; falling below kill height (-120) ends you once (cause Fall, not downed, not revivable). A mob that falls despawns.

## Forest and shadows
- Trees stand on terrain (no floating/buried, also on slopes); trunks block you, foliage does not.
- Dense near camp, clear area at the fire, giants visible; no tree overlaps a POI or the camp, including across chunk borders.
- Chop a giant: trunk in reach, vanishes whole, respawns. Wood always reachable near camp.
- Forest floor dim by day; night still readable on a phone. Part count under 6000 near camp with 4 players; FPS ok.

## Structures
- Cabin (3 variants): walk through the doorway, warm light, bed, chest, hearth where present; camera fits inside.
- Plane: walk the fuselage. Ruins: dark walkable chambers. Cave: walkable, has depth. Watchtower: climb the stairs to the deck, no jumping.
- Door sill ok on sloped ground; loot tier rules unchanged; a wolf can run through doorways.

## Fire radius
- Warm ring 54/72/90 and build ring 162 draw correctly on uneven ground; dot cap holds on mobile (about 56 / 101 dots at top tier, total cap 220).
- Warmth, wolf repel (warm + 6) and build range match the rings. Mobs do not spawn inside the safe zone or walk into the repel circle.
- Night fire light acceptable with the 60-stud clamp. Fire meter shows at 100 studs.
- Placing a fire or structure on a slope works; ghost shows, no "NoGround".

## Death and revive
- Zero health: no joint scatter, lying/crawling pose, body flat on the floor (also R6).
- Teammate holds E (PC) or the on-screen button (phone) for 4 s to revive; release or walking off cancels. Button clear of Act and jump. E still talks/gathers normally when no downed teammate is near.
- Window expires or nobody left: dead, spectate living teammates (Prev/Next/Z). Run ends when all are down or dead.
- "Return to lobby" always available after death; "Play again" after run end; Studio fallback does not kick; real TeleportAsync on a published place.
- Summary panel: dark opaque, large outlined text, readable on a phone, stats visible.

## Balance
- Axe durability never drops; Pickaxe and others still do; repair UI shows n/a for the Axe and no repair prompt at the workbench.
- Day-1 hare 3 axe hits, wolf 5 (4-5 target; 6 from about day 5 by scaling). Better weapons kill faster.


## Round 2: loot, massive structures, trees, fixes (nothing played in Studio)
### Loot and chests
- Five chests look clearly different (wood / iron / frost-steel blue glow / spectral purple / gold with beam); rare+ beams visible from far; only nearest ~8 glow; FPS ok in chest-heavy structures.
- "Open" prompt coloured by rarity; E, phone tap, gamepad X work; button >= 44 px; epic/legendary hold bar.
- Open: items land in inventory; full inventory drops overflow at feet (pickup works); reopen does nothing; chest dims and stays open after the structure rebuilds; second player gets a different chest; chests gone after run reset.
- Better chests farther out; low chests never give epic gear. Kit B chests (shipwreck/temple/lodge/ruins) not floating or sunk.
### Massive structures (each: minutes of exploring, no getting lost)
- Research station (mountains/deep tundra), mine complex (mountains/caves): surface wings + 2-3 underground levels, ramps/stairs easy on mobile, lights flicker, notes readable at ~14 studs, eyes in the dark, a way back to the surface everywhere.
- Shipwreck on lake ice level; flooded deck; temple pad blends in, crypt + legendary chamber, Dread rises in crypt; lodge feels warm and safe (hearth fire/smoke); expanded ruins multi-chamber with courtyard and cellar.
- Dressing appears near (~90 studs) and vanishes far (~130) without pops or hitches; carved voids/edges look right; walk away and back: no holes, terrain regenerates after destroy.
- No trees/rocks/ore inside footprints; ground decor patches inside footprints (known gap); mobs may spawn inside footprints (known gap).
- Streaming near two live structures: outer chunks may defer (known); FPS and part count stay under 6000.
### Trees
- Walk under canopies with no leaf collision, trunk blocks; lowest foliage clear above your head; giants much taller; axe a giant from the ground (bare trunk ~18); shadows and depletion hide the whole tree.
### Fixes
- Stalker never strikes inside fire warm radius; lurkers never attack and do not spawn near fire; boss may break through; mobs do not bite into warm zone.
- Sprint through new terrain: no visible gaps or hitching (chunks fill over a few frames).
- Place/upgrade a fire in a forest: trees within the clear radius vanish and stay gone after reload.
- Wolf takes 4-5 Axe hits on day 1 and day 5+, bites harder / spawns more later.
