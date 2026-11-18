# Hand tests (published place; PC and phone)
Studio/MCP could not verify these. Before starting: save the place (agents cannot), supply asset ids (docs/ART.md), fill Config.Meta.ProductIds, run tools/apply_perf.luau then re-run client QA with streaming, publish.

## Teleport / party (2+ real accounts, one on PC, one on phone)
- [ ] Both stand on a pad: timer shows, resets on join; friends-only vs open-fill; leave cancels.
- [ ] Launch: real TeleportAsync to a reserved run server; same seed for both; arrive near camp with wood and food.
- [ ] Run end (all down/dead): summary shows, stats saved, both return to a PUBLIC lobby (not a run server).
- [ ] Disconnect one player, rejoin within 5 min: meters/inventory kept (character position is not). Rejoin after 5 min: refused.
- [ ] Friend coin bonus; leaderboard (OrderedDataStore; needs API access); daily claim once per UTC day.

## Saves and purchases
- [ ] Rejoin: profile intact (coins, stats, achievements, settings, hints seen). No overwrite after a failed load.
- [ ] Robux coin pack and Robux-only cosmetic: granted once; retry/rejoin does not double grant; profile saved after purchase; no prompt while a product id is 0. No random paid items.
- [ ] Coin shop: price correct, duplicate refused, one perk equipped, perk effects small; cosmetic visible after respawn.

## Survival and world (PC then phone)
- [ ] Camp spawns in start forest with wood/food; four biome rings look distinct; depleted nodes stay depleted after walking away and back.
- [ ] Clothing gate: underdressed in outer ring drains faster, tiered clothing is survivable; hot springs and cabin hearths (needs wood) warm you.
- [ ] Thin ice cracks and chills; chests/doors/forge/cooking/wall/spike trap (mobs only)/watchtower/map table placed with ghost, correct prompts and refusal text; repair at workbench; cooked buffs.
- [ ] Map fills as you explore; ping wheel (Q / phone button) visible to partner.
- [ ] Blizzard (day 4-5): warning cues, escalating, reduced visibility, extra mobs, boss at some. False night / the quiet / deep freeze never before day 3, never during a blizzard.
- [ ] Stalker: lone player hunted more than a group; full group together is left alone; tells (silence, frost, crunch, gutter); strikes hurt but never kill from full health; retreats; never enters fire/warm spots; torch/flare repel; cannot be killed. Nothing on screen shows Dread or timers.
- [ ] Mobs: polar bear, wraith, snow lurker, cave crawler, fish; 3 mini-bosses far out are killable; bow stray shots only hurt players via friendly-fire multiplier, melee never does.
- [ ] Reduce scares: no flicker, softer frost, translucent lurkers; server danger unchanged.

## Phone layout and performance
- [ ] Buttons >= 44 px, no overlap with thumbstick/jump: Act, Rotate, Shoot, Ping, Map (under Craft), Settings, Shop panel tabs, chest panel.
- [ ] Touch placement shows Rotate button, not "[R] Rotate"; E/Act prefers aimed node, then closer of tree vs chest/door.
- [ ] 30+ FPS on a mid-range phone in a blizzard, near the camp with structures, and at 4 players; streaming loads without hitches.
- [ ] Other players see your swings; sounds/particles silent until ids supplied, no errors.

## Known open items
Sleeping bag is warm spot only (no respawn point); summary rank change empty; chests shared server-wide; thin ice has no hole; Stalker knockback is a direct move; Phase 1 human gate still unconfirmed; PLACE_ID placeholder in CLAUDE.md and docs/MCP_PLAYBOOK.md.
