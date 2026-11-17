# Decisions (append-only: YYYY-MM-DD — decision — reason)
2026-11-17 — Rojo owns scripts, MCP owns instances — script Source set through MCP is overwritten by Rojo sync.
2026-11-17 — Place file kept out of git; world rebuilt by idempotent tools/ builders — place edits are not diffable and agents cannot save.
2026-11-17 — Tier system (light/standard/full), KIT_TIER overrides .kit-tier — match gate cost to risk; .kit-tier is full because tests exist.
2026-11-17 — Studio pinned by placeId, not name or file — the name changes after publish.
2026-11-17 — Wally package name is cadenannison/arctic-survival — Wally allows only lowercase letters, digits and hyphens.
2026-11-17 — Studio-only QA bridge (BindableFunction in ServerStorage, DebugService.expose) — MCP execute_luau runs in another VM, so required modules are fresh copies without live state.
2026-11-17 — Placement lives in the items system (PlacementService), structures cost one crafted placeable item — reuses crafting for material cost; no separate BuildingService until more structures land.
2026-11-17 — Mob drops go straight to the killer's inventory — no world pickup system yet.
2026-11-17 — Held item is a server-built visual Tool in the character; CoreGui Backpack disabled — replicates to everyone with the default hold pose while gameplay keeps reading the server's selected slot.
2026-11-17 — Client QA bridge is a Studio-only BindableFunction in PlayerScripts exposing the HUD input handlers — MCP Client execute_luau runs in another VM, and QA must exercise the real client path, not raw remotes.
2026-11-17 — Hit confirms come from replicated attributes (HitsLeft/Depleted/MobHealth), no new remote; killed mobs linger Mobs.DeathRemoveDelay so the confirm is seen.
2026-11-17 — Placement rules live in one pure shared module (shared/logic/Placement.validate -> {ok, reason}) used by the client ghost and the server place handler — the preview and the authority cannot disagree; server still re-validates with its own data.
