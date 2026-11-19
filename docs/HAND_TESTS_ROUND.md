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


## Round 3: items, world, HUD (nothing played in Studio; PC and phone emulation)
- `/debug structures` and `/debug tp` to the beacon (ResearchStation): 3-4 chests spread over rooms/depth, exactly one top-rarity, short beams, nothing floating or buried. Repeat with 3 seeds (`/debug seed n`). Other classes: small 1-2, medium 2-3, massive 3-5.
- Beams: only rare+, <= 12 studs, vanish beyond ~60 studs, no sky pillar. FPS fine; only one massive structure live at a time.
- Fire and workbench placed on a slope sit flush; no half-sunk structures; no grey hard-edged pad; skirt blends into the snow.
- Mobs never spawn inside a structure footprint. Giant tree: chop from the ground. First chest ever opened shows the one-time hint.
- Backpack: button and B toggle (Tab does nothing); drag/drop, merge, swap, split (right-click, long-press), shift-click; phone tap-then-tap. Hotbar always visible.
- Equip each of the 8 slots (wrong slot shakes); cold resistance x/12 changes; carried-only clothing no longer counts; gear persists after rejoin.
- Craft a storage chest (8 wood, workbench), place it (ghost, snap), open it, share with a second player (both edit at once); cannot pick up while non-empty; 5th chest refused with a toast.
- Wood stacks to 20 then overflows to a new slot; with a full inventory pickup shows "Inventory full".
- HUD: Craft, Map, Settings, Backpack do not overlap (desktop + phone, clear of jump/Ping/Act); chat does not cover the bars.
- Real death: readable summary with Return to lobby / Play again; `/debug respawn` clears the panel instantly and nothing blocks input. Check a dead player is not auto-respawned past spectate (known SpawnService gap).
- Axe slot shows no "n/a" durability.

## Round 4: token-cost refactor (no behavior change; nothing played in Studio)
- HUD after the HudController split: bars/day/compass/hotbar look and lay out as before (desktop + phone); hotbar keys 1-9, click, mouse wheel (Shift zooms), tap-selected food eats; prompts (gather/hunt/fuel/craft/upgrade/structure) and the Act button label update; hit bursts/sounds on chop and mob hits; onboarding hints and the record toast still fire.
- World art after the WorldProps split: trees, rocks/ore (and depleted rubble/stump), decor, and every POI (cabin, plane, cave, ruin, campsite, hot spring steam, hearth light) render as before; `/debug gallery world` shows each prop.
- Config split: any value tweak in src/shared/Config/<Module>.luau still takes effect (spot-check one per module you touch).

## Inventory UI round (Agent 1)
- Drag an item and release outside the panel, on the panel title, or on a wrong equipment slot: it springs back to its origin slot, nothing lost. Open a drag then press B (or Close) mid-drag: panel closes, item still in its slot.
- Drop: select a slot (click/tap) then press Q or the Drop button: the stack (or the picked half) appears at your feet and can be picked up. Q does not open the Ping wheel while the Backpack is open. With nothing selected the Drop button is dimmed.
- Highlight on every slot type (hotbar row, grid, equipment, chest grid, HUD hotbar): a click/tap shows a white outline + tint; a tap-picked (or dragged) slot turns gold; valid destinations glow green, the one under the pointer brighter; all clear after the move.
- HUD hotbar drag: drag a hotbar slot onto another hotbar slot (swap/merge) and onto a Backpack grid slot while the panel is open; releasing elsewhere cancels. A plain click still selects.
- Backpack toggles with B only (Tab does nothing).

## World and session round (Agent 2)
- `/debug tp research` and `/debug tp ring 3` on 3 seeds (`/debug seed n` then rejoin or new run): you land on the ground (never in the void or under terrain) and chat/output prints the resolved name and coordinates. Also try `tp beacon`, `tp research 2`, `tp mine`, `tp ring3`, a player name prefix. `tp banana` and `tp ring 9` print a clear error and do not move you.
- Starting campfire on 5 seeds: the fire and the spawn pad sit on the snow surface (not buried), you spawn standing beside it.
- Die during a run: you stay in spectate (no timer respawn); a teammate revive or `/debug respawn` brings you back once, no double character.
- Finish a run, start a new one: worn gear is gone (starter gear only from meta unlocks).
- Night: ground and tree silhouettes readable without the fire, clearly darker than day; a dark event (False Night, blizzard) can still go darker. Tune in Config/Lighting.luau (MoonAmbient, MoonOutdoorAmbient, MoonBrightness, MoonExposure).
- Press E on trees, a door, a chest, a crafting station: no swing/hit/craft sound spam (interaction is silent for now; hook points in docs/ART.md).
- POIs (cabin, plane, ruin, campsite): floors never sit under terrain.
- Round 4 audit checks: HUD (bars/day/compass/hotbar, keys 1-9, wheel, tap-to-eat, prompts, Act button, onboarding hints, record toast) lays out and behaves as before on desktop + phone; world props (trees, rocks/ore + depleted rubble/stump, decor, all POIs incl. hot spring steam and hearth light) render as before and `/debug gallery world` shows each; spot-check one Config value tweak per module still takes effect.

## Bug fixes / sprint / forage / blizzard round
- Typing in chat while pressing B, G, C, M, 1-9, E, Q: nothing triggers.
- `/debug groundcheck` near the fire on 5 seeds: delta ~0, fire never below ground; spawn pad and structures sit on ground.
- Q pings, G drops. A dropped axe keeps its durability after pickup. No sounds on E / deny / craft.
- Sprint: hold LeftShift (touch: toggle button) ~+30% speed, extra hunger cost, HUD indicator only while sprinting, blocked when hungry/downed. `/debug sprint on|off`.
- Forage and nodes per ring (`/debug forage` spawns one of each): E pick, tool tier gates, respawn at dawn, 3 recipes work, nothing inside structures, part count < 6000.
- `/debug blizzard start`: no screen tint, whipped streak snow, whiteout to ~60 studs, fire still visible, smooth ~20s ease in/out, lasts ~9 min. Also `stop` and `intensity 0.5`.

## Art Pass 3: creatures + 8 new mobs (nothing played in Studio yet)
Use `/debug mob <id>` (spawns in front) and `/debug mobs` (nearby list with State). Ids: ArcticHare Caribou Fish Wolf PolarBear IceWraith SnowLurker CaveCrawler IceWarden CaveMatriarch RuinColossus WhiteoutBeast + SnowGrouse RidgeStag LakeSeal RimeWolverine ScrapHound CarrionCrow FrostboundBrute AuroraWisp. Also Stalker and lurkers (TreeWatcher, IceScratcher, EyesInDark) via their normal triggers.
- Per mob: silhouette reads in moonlight and whiteout; Idle/Walk/Run/Alert/Telegraph/Attack/Hurt/Death look right (limbs hinge at joints, faces forward, no detached parts); `/debug mobs` State matches what you see; death fades then removes.
- Behaviors: grouse flees in bursts and returns; stag Alert on approach, herd joins when one is hit; seal rears up (Alert) then attacks only if you keep closing (~9 studs), calms after ~8s; wolverine crouch then charge at your old spot (sidestep); hounds x3 flank then rush (night, ring 3); crows circle, scatter within 16 studs or toward the Stalker's heading (check Heading attr); brute 1.6s slam, ground ring fills, leave its reach to dodge; wisp drifts, lures toward hazards, touch = -4 warmth (max 12 per wisp).
- Toughness (hits to kill): grouse < hare < stag < seal < wolverine < wolf < hounds < brute.
- Drops + recipes: Feather, Venison, Blubber, Claw, Fang, DenseHide, CrystalShard, AuroraDust drop and have uses; craft InsulatedCoat, BlubberTorch (hand-craft), FangSpear, AuroraTorch.
- Rings: teleport to each ring (`/debug tp ring N`) and watch spawn mix; outer rings meaner (more hostiles, more aggression, capped scaling).
- Dread: alone attracts more crows/wisps, a full group suppresses them; no visible meters.
- Perf: many mobs live, parts stay under 6000 (watch MaxMobParts 600); mobs beyond ~120 studs freeze; wisp PointLights <= 4; phone emulation framerate.


## Bug-fix round 2 (nothing played in Studio)
- Chat `/debug forage`, `/debug sprint`, `/debug sprint off`, `/debug groundcheck`, `/debug blizzard start`, `/debug blizzard stop`, `/debug blizzard intensity 0.5`, `/debug respawn`, `/debug mobs`, `/debug mob Wolf`: each runs, none says "needs a number".
- Campfire: hold Blubber (get from a seal/polar kill or /debug give Blubber), stand at a fire, press E: fuel rises more than for Wood, prompt reads "Add Blubber". Same with Stick (short burn). Wood still works; with nothing fuel-like held the Act button is not "Add fuel". Far away or at full fuel: rejected.
- Pick up coal / ice block / crystal / relic fragment nodes, then end the run: the summary coins include them (also when you leave mid-run).
- Forage (sticks, berries) you picked grows back at the next dawn (Day counter ticks at 08:00 after the night), not before.
- Walk a forage-dense area with 4 players: FPS fine; check Perf part count still under 6000.
- Craft: Storage Chest and Bow now need 1 Rope; Rope crafts by hand from 3 Frozen Reed.
- Brute (`/debug mob FrostboundBrute`): telegraph ring is 10 studs radius and the slam hits exactly inside it (step just outside the ring: no damage); model size looks right (5x7x5 root).
- Blizzard: fires still glow faintly through the whiteout.
- Lobby: step on a pad, press V (or tap Leave) to leave; Q does nothing there; the Leave button reads "Leave [V]". In a run, Q still opens the ping wheel.
