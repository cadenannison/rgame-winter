# Decisions (append-only: YYYY-MM-DD — decision — reason)
2026-11-17 — Rojo owns scripts, MCP owns instances — script Source set through MCP is overwritten by Rojo sync.
2026-11-17 — Place file kept out of git; world rebuilt by idempotent tools/ builders — place edits are not diffable and agents cannot save.
2026-11-17 — Tier system (light/standard/full), KIT_TIER overrides .kit-tier — match gate cost to risk; .kit-tier is full because tests exist.
2026-11-17 — Studio pinned by placeId, not name or file — the name changes after publish.
2026-11-17 — Wally package name is cadenannison/arctic-survival — Wally allows only lowercase letters, digits and hyphens.
2026-11-17 — Studio-only QA bridge (BindableFunction in ServerStorage, DebugService.expose) — MCP execute_luau runs in another VM, so required modules are fresh copies without live state.
2026-11-17 — Placement lives in the items system (PlacementService), structures cost one crafted placeable item — reuses crafting for material cost; no separate BuildingService until more structures land.
2026-11-17 — Mob drops go straight to the killer's inventory — no world pickup system yet.
