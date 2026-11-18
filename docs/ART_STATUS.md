# ART STATUS
Plan: docs/ART_PLAN.md. Next pass: 2 (WORLD)

## Pass 1: HUB (done, 2026-11-17)
Built: outdoor snowy plaza (tools/build_lobby.luau -> src/server/Art/HubBuilder + HubProps; layout/budgets/palette in Config.Art.Hub). Shop cabin with ProximityPrompt (opens the shop panel), six glowing pulsing pads with big size label + timer + Join billboard (client), global and this-server leaderboards, stats board (+ prompt to full panel), cosmetic mirror (prompt), lamp posts, 4 fire pits, pines (2 Creator Store models, see CREDITS.md), rocks, drifts, crossed-ridge mountains, snowfall, dusk lighting (client, lobby only), spawn arch, silent ambient sound hooks. `/debug gallery hub` / `/debug gallery clear`.
Gates: scripts/check.sh tier=full OK. tools/qa/hub-art 9/9 (client, lobby mode). Gallery verified (14 items, clears).
Regression: the full tools/qa run was started and then stopped by the user's decision (art-only pass, lobby-only visual change). NOT run: lobby-player-path, lobby-to-run, meta-shop, studio-test-boot, and all run-mode scenarios. Run-mode code paths are untouched (the hub is destroyed at run boot; HubFx is inactive outside lobby).
Hand-review list: 1) walk the plaza at dusk: lighting mood, mountains silhouette, brightness on a phone; 2) pad billboards (size label, big timer, Join) - the Studio screenshot tool did not render BillboardGuis, confirm they show; 3) step on a pad: colour shifts to warm, timer counts 20s; 4) shop window prompt opens shop (E / tap); stats board + mirror prompts; 5) boards show global/local/own stats; 6) `/debug gallery hub`; 7) FPS on a phone (hub: 883 parts, 41 lights, 6 emitters, snow rate 45).
Open: lamp/fire light is weak on snow at dusk (tune Config.Art.Hub lamp brightness if wanted); sounds silent until ids supplied (ART.md); Config lights cap raised 36 -> 44; pass 2 must still apply tools/apply_perf.luau.
SAVE NEEDED (hub built into Workspace.Lobby, pines in ServerStorage.ArtAssets; agents cannot save the place).
