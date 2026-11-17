# ROBLOX_KIT.md — Roblox Game Bootstrap Kit v2 (2026-11-16)

Drop-in kit for a NEW Roblox game repo: Luau + Rojo + Wally + VS Code + Studio MCP + Claude Code agents.
v2 is built from a full real build (the Texans tycoon: v1, polish pass, and a side game). Everything here was hit in practice.

**Executor agent: read this whole file, then run Part A. Do NOT commit or push. Do not ask questions; choose sensible defaults and list them in your report. Verify every CLI flag, package name/version and action version against `--help` / official docs, not memory.**
**Reference repo:** if `~/Desktop/gameDev/texans` exists (override with env `REFERENCE_REPO`), it holds WORKING versions of scripts/check.sh, .githooks, ci.yml, .claude/**, tests/run.luau, Remotes, Guard, DataService, ProfileSchema, loading screen, spawn flow and the tools/qa pattern. Copy and adapt those instead of rewriting; strip all Texans-specific content (tycoon, Rimrock, structure names).

---

## What changed from v1 (and why)
| Fix | Why it was needed |
|---|---|
| check.sh exports `$HOME/.rokit/bin` onto PATH itself | Agent shells are non-interactive and did not load `~/.zshenv`; `stylua: command not found` |
| check.sh runs `mkdir -p Packages ServerPackages build` first | Gitignored and empty with no deps, so `rojo sourcemap` failed; also broke fresh clones and CI |
| default.project.json includes ReplicatedFirst; restart `rojo serve` after any project-file change | Rojo reads the project file only at startup; the loading screen silently did not sync |
| Studio is pinned by placeId, not name or file | Name changed (Texans vs Game.rbxl) after publish; agents stopped at the identity rule |
| Publish to Roblox right after the first Studio open; reopen via File > Open from Roblox | Reopening the stale local file lost unsaved map edits and broke API access linkage |
| Map/art are built by idempotent scripts in `tools/`, reports end with SAVE NEEDED | Place edits are not in git, agents cannot save, and an unsaved session was lost once |
| Playtests are scripts in `tools/qa/` (one MCP call, PASS/FAIL lines) | Improvised MCP playtests cost 50-175K tokens each and were flaky |
| Playtest with a local player (start_play), never server-only | A server-only run has no player, so player-driven systems never ran |
| One owner per shared file per round; no parallel check.sh | Parallel agents overwrote Config.luau; parallel check runs race on build files |
| `.kit-tier` becomes `full` once tests exist; CI runs `wally install` and full tier | Standard tier skipped unit tests in the commit hook; CI could not resolve packages |
| Agents are files in `.claude/agents/`; the /agents wizard no longer exists | Agents load at session start; restart the session after creating them |
| Paste blocks contain no `#` comments, apostrophes or `<angle>` placeholders | zsh interactive treats them as quotes/globs/redirections and breaks the paste |
| DataService has logging, a hard load timeout, kick-on-failure, schema validation | A silent hang with no kick was undiagnosable |
| Structures-style saved maps use string keys (`tostring(id)`) | DataStores reject sparse numeric tables |

---

## Part A — Agent execution plan

### Phase 0 — Detect
- OS (macOS / Windows / Linux). On Windows also create `scripts/check.ps1` mirroring `check.sh`, and use the Windows Studio MCP path (Part F).
- Placeholders: `GAME_NAME` = repo folder name (PascalCase); `GH_USER` from `git config user.name` / the remote. Report both.
- Existing files: never overwrite without reading first; merge.

### Phase 1 — Tools (run as one block; no comments)
```bash
rokit init
rokit add rojo-rbx/rojo
rokit add UpliftGames/wally
rokit add JohnnyMorganz/StyLua
rokit add Kampfkarren/selene
rokit add JohnnyMorganz/luau-lsp
rokit add lune-org/lune
rokit install
selene generate-roblox-std
```
- Ensure `~/.zshenv` sources `~/.rokit/env` (append only if missing). `scripts/check.sh` must NOT depend on it (Part B).
- VS Code extensions (recommend in `.vscode/extensions.json` and install): `JohnnyMorganz.luau-lsp`, `JohnnyMorganz.stylua`, `Kampfkarren.selene-vscode`, `evaera.vscode-rojo`.
- Versions seen working (Nov 2026; re-verify): rokit 1.2.0, rojo 7.7.1, wally 0.3.2, stylua 2.6.0, selene 0.32.0, luau-lsp 1.70.1, lune 0.11.1. `rokit add` pins them in rokit.toml.

### Phase 2 — Create files
Create everything in Part B. Starter Luau must pass `scripts/check.sh`; fix type errors, never loosen `--!strict`.

### Phase 3 — Verify
1. `env -i HOME="$HOME" PATH="/usr/bin:/bin" bash scripts/check.sh` passes (proves PATH self-sufficiency in a bare shell).
2. Fresh-clone test: `git clone` the repo to a temp dir (after the human's first commit, or copy the working tree without ignored files) and run check.sh there (proves missing-folder handling).
3. `rojo build -o build/game.rbxl` works; `rojo serve` starts (then stop it).
4. Agents: every file in `.claude/agents/` has valid frontmatter (name = filename, description, model alias; see below).
5. Report (<=15 lines): files created, defaults chosen, results, unverified items, and the human steps below.

### Human steps (agent prints these at the end; they cannot be automated)
Use placeholder NEWGAME in uppercase, never angle brackets, in blocks you paste into zsh.
1. Git (blocks have no comments):
```
cd ~/Desktop/gameDev/NEWGAME
git init
git branch -m main
git remote add origin https://github.com/GH_USER/NEWGAME.git
git config core.hooksPath .githooks
scripts/check.sh
git add -A
git status --short
git commit -m "Bootstrap Roblox kit"
git push -u origin main
```
Confirm `Packages/`, `ServerPackages/`, `build/`, `sourcemap.json`, `*.rbxl` are NOT in `git status`.
2. Build and open the first place file OUTSIDE the repo (check.sh rebuilds build/game.rbxl every run, so never work in that file):
```
mkdir -p ~/Desktop/gameDev/NEWGAME-place
rojo build default.project.json -o ~/Desktop/gameDev/NEWGAME-place/Game.rbxl
open ~/Desktop/gameDev/NEWGAME-place/Game.rbxl
```
3. In Studio, immediately: File > Publish to Roblox (new private experience). Then File > Game Settings > Security: enable "Enable Studio Access to API Services". Set Max Players if relevant. From now on reopen the game with File > Open from Roblox, not the local file. Turn on Studio Auto-Save in settings.
4. Rojo plugin: `rojo plugin install`, fully quit and reopen Studio, run `rojo serve` in a terminal, then Plugins > Rojo > Connect. Restart `rojo serve` and reconnect after ANY change to default.project.json.
5. MCP: Assistant > "..." > Manage MCP Servers > enable "Enable Studio as MCP server"; quick connect Claude Code. If Claude Code is not listed, from the repo folder run the manual command in Part F. Restart the Claude session. `/mcp` must show Roblox_Studio; Studio shows a green MCP indicator.
6. Claude Code may offer the Chrome extension at startup: choose No (or `/chrome` to turn it off). Roblox work does not need it.
7. Pin the Studio: ask any agent to list open Studios via MCP, then write the placeId into CLAUDE.md and docs/MCP_PLAYBOOK.md (rule in Part B). Close any stray unsaved Studio windows.
8. macOS note: ribbon tabs are menus in the top menu bar (Test > Play, Window > Output). F5 may need Fn.

---

## Part B — Files

### Principles
1. Rojo owns scripts. MCP owns instances, properties, playtesting. Never write script Source through MCP.
2. Everything not in git must be rebuildable: map, art and lighting come from idempotent builders in `tools/`.
3. Server authority: client sends intent, never amounts. Validate at the ACTION, not only at the door (a teleporting exploiter skips the door).
4. `--!strict` everywhere, lint clean, zero warnings.
5. Gates before done: `scripts/check.sh`, then a scripted playtest with a local player.
6. Small context: agents load CLAUDE.md plus the one system doc they touch.
7. Pure logic stays Roblox-free (`src/shared/logic/`) so it is unit tested; Roblox code is a thin adapter.
8. UI is built in code (diffable), never through MCP. MCP builds world/set dressing only.

### Layout
```
.
├── CLAUDE.md                  # <=80 lines
├── ROBLOX_KIT.md
├── default.project.json
├── rokit.toml wally.toml selene.toml stylua.toml .luaurc .gitignore .kit-tier
├── .vscode/{settings.json,extensions.json}
├── .githooks/pre-commit
├── .github/workflows/ci.yml
├── .claude/{settings.json, agents/, commands/}
├── docs/{ARCHITECTURE.md, DECISIONS.md, STATUS.md, ROADMAP.md, ART.md, MCP_PLAYBOOK.md, BRIEF_TEMPLATE.md, ORCHESTRATOR_PROMPT.md, systems/_TEMPLATE.md, briefs/}
├── scripts/{check.sh, check.ps1 (Windows)}
├── src/{first,server,client,shared}/
├── tests/
└── tools/{map/, art/, qa/}
```

### default.project.json
```json
{
  "name": "GAME_NAME",
  "tree": {
    "$className": "DataModel",
    "ReplicatedFirst": {
      "$className": "ReplicatedFirst",
      "Loading": { "$path": "src/first" }
    },
    "ReplicatedStorage": {
      "$className": "ReplicatedStorage",
      "Shared": { "$path": "src/shared" },
      "Packages": { "$path": "Packages" }
    },
    "ServerScriptService": {
      "$className": "ServerScriptService",
      "Server": { "$path": "src/server" },
      "ServerPackages": { "$path": "ServerPackages" }
    },
    "StarterPlayer": {
      "$className": "StarterPlayer",
      "StarterPlayerScripts": {
        "$className": "StarterPlayerScripts",
        "Client": { "$path": "src/client" }
      }
    }
  }
}
```
Note: a folder with `init.server.luau` becomes a Script with the rest as children. Workspace is intentionally absent (world is built by tools/ builders).

### Config files
`stylua.toml`
```toml
column_width = 100
line_endings = "Unix"
indent_type = "Tabs"
indent_width = 4
quote_style = "AutoPreferDouble"
call_parentheses = "Always"
```
`selene.toml`: `std = "roblox"`. `.luaurc`: `{ "languageMode": "strict", "lint": { "*": true } }`. `.kit-tier`: `standard` at first; set to `full` as soon as `tests/` has real tests.
`wally.toml`: package name `GH_USER/game_name`, version 0.1.0, registry `https://github.com/UpliftGames/wally-index`, realm shared, private true, empty `[dependencies]` and `[server-dependencies]`. Session-lock library seen working: `lm-loleris/profilestore` 1.0.3 (verify before use). After `wally install`: `wally-package-types --sourcemap sourcemap.json Packages` if package types are used.
`.gitignore`: `Packages/ ServerPackages/ sourcemap.json build/ .luau-types/ *.rbxl *.rbxl.lock *.rbxlx roblox.yml node_modules/ .DS_Store`.
`.vscode/settings.json`: formatOnSave true; `[luau]` default formatter `JohnnyMorganz.stylua`; `luau-lsp.sourcemap.enabled` true, `autogenerate` true, `rojoProjectFile` `default.project.json`; `luau-lsp.types.roblox` true; hide `sourcemap.json` and `build`. Verify setting names against the current extension docs.

### scripts/check.sh (agent writes; chmod +x)
Required, in this order:
```bash
#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.rokit/bin:$PATH"
cd "$(dirname "$0")/.."
mkdir -p Packages ServerPackages build
TIER="${KIT_TIER:-$(cat .kit-tier)}"
```
- Always: `stylua --check src tests`, `selene src` (print `PASS stylua`, `PASS selene`).
- standard/full: `rojo sourcemap default.project.json -o sourcemap.json`; `luau-lsp analyze` over `src` with the sourcemap and Roblox type definitions (read `luau-lsp analyze --help`; if a definitions file is needed, download once into `.luau-types/`); `rojo build default.project.json -o build/game.rbxl`.
- full: run the test suite (Lune, `tests/run.luau`). Acceptance: at least one real passing test.
- Exit non-zero on first failure; final line `OK tier=<tier>`. Never write outside ignored paths.
- Pure-logic modules in `src/shared/logic/` are tested headless; Roblox behavior is covered by tools/qa playtests.

### .githooks/pre-commit
Runs `scripts/check.sh` at the repo tier. Executable.

### .github/workflows/ci.yml
Checkout, setup-rokit, `rokit install`, `selene generate-roblox-std`, `wally install`, then `KIT_TIER=full scripts/check.sh`. Action versions seen resolving (Nov 2026; re-verify): `actions/checkout@v7.0.1`, `CompeyDev/setup-rokit@v0.2.1`.

### .claude/settings.json
```json
{
  "permissions": {
    "allow": [
      "Bash(scripts/check.sh:*)", "Bash(rojo:*)", "Bash(stylua:*)", "Bash(selene:*)",
      "Bash(wally:*)", "Bash(lune:*)", "Bash(git status:*)", "Bash(git diff:*)"
    ],
    "deny": ["Bash(git commit:*)", "Bash(git push:*)"]
  }
}
```
Merge with existing settings. Do not add MCP tool permissions.

### CLAUDE.md (write verbatim, replace PLACE_ID after step 7; keep <=80 lines)
```
# CLAUDE.md — GAME_NAME
Roblox game. Luau + Rojo + Wally. A PM/orchestrator assigns one task at a time; you execute.

## Hard rules
- Do NOT commit or push. Never edit .git or hooks.
- Load only this file + docs/systems/<system>.md for the system you touch.
- Scripts live in src/ and sync via Rojo. Never write script Source through MCP. UI is built in code.
- Every Luau file starts with --!strict. No warnings.
- Done = scripts/check.sh passes. If behavior changed: scripted playtest (tools/qa), local player, filtered output, no errors.
- After any MCP instance work, end your report with SAVE NEEDED (agents cannot save the place).
- Final report <=10 lines: files changed, check result, playtest result, open issues.

## Studio and MCP
- Act only on the Studio whose placeId is PLACE_ID. Pass its studio id on every call. If more than one Studio is open, stop and ask.
- One agent at a time uses MCP. Playtest with a local player (start_play), never server-only.
- Query by exact path and shallow depth. Read code from disk, never through MCP. Batch edits into one call. No screenshots unless the brief asks (max 5).
- World/art/lighting come from idempotent scripts in tools/ run in one MCP call; leave no script in the place.

## Layout
src/server -> ServerScriptService.Server | src/client -> StarterPlayerScripts.Client | src/shared -> ReplicatedStorage.Shared | src/first -> ReplicatedFirst.Loading
Pure logic (no Roblox APIs) -> src/shared/logic/. System index: docs/ARCHITECTURE.md. One spec per system: docs/systems/.

## Luau conventions
- PascalCase modules/classes/methods; camelCase locals; UPPER_SNAKE constants.
- Services via game:GetService at file top. task.wait/spawn/delay/defer only (never wait/spawn/delay).
- Instance.new(class), set properties, set Parent LAST.
- No magic numbers or asset IDs inline: shared/Config.luau and shared/Assets.luau.
- Replicated state: Attributes. Behavior groups: CollectionService tags. Never scan Workspace.
- Every connection/instance has an owner and cleanup (PlayerRemoving, Destroying). No leaks.
- Heartbeat for simulation; RenderStepped only for camera/visuals. One loop for all players, not a thread per object.
- Handle the PlayerAdded race (also loop Players:GetPlayers()). pcall anything external. Never yield unguarded in handlers.
- Per-tick visual feedback is client-side from Attributes; never a remote per tick.

## Networking and security
- All remotes come from shared/Remotes.luau; one per intent; typed payload.
- Server handler order: type-check -> range/sanity -> rate limit (Guard) -> permission/state/zone -> act.
- Never trust client values. Server recomputes prices, damage, positions. Validate at the action, not only at entry points.
- No InvokeClient. No server->client RemoteFunction.

## Data
- Persistence only through server/Data/DataService. Session locking, retry with backoff, hard load timeout (30s) then kick, validate schema on every load, never overwrite on a failed load.
- Saved tables use string keys. schemaVersion + migrations for every change. Save on PlayerRemoving AND BindToClose.

## Spawn
- Players.CharacterAutoLoads=false. LoadCharacter only after profile loaded and any per-player setup done; plot/spawn is Player.RespawnLocation; handle respawn after death. Custom loading screen in ReplicatedFirst.

## Process
- New system: docs/systems/<name>.md from _TEMPLATE.md first, then code. Architectural choice: one line in docs/DECISIONS.md.
- Shared files (Config, Catalog, Remotes, init.*, ProfileSchema) have one owner per round.
```

### docs
- `ARCHITECTURE.md` (<=60 lines): pitch (3 lines), systems table (`name | tier | purpose | entry file`), data model (what lives in Workspace vs code), networking map (remote -> direction -> handler).
- `DECISIONS.md`: append-only `YYYY-MM-DD — decision — reason`. Seed: Rojo owns scripts, MCP owns instances; place file kept out of git, world rebuilt by tools/ builders; tier system; Studio pinned by placeId.
- `STATUS.md` (<=25 lines): done / in progress / next / open issues / `CHECKPOINT: yes|no`. The orchestrator rewrites it after every milestone so a fresh session can resume.
- `ROADMAP.md`: milestones (Part D). `ART.md`: every imported asset (id, creator, source) and part counts. `BRIEF_TEMPLATE.md`, `systems/_TEMPLATE.md`: below.
- `MCP_PLAYBOOK.md` (<=1 page): division of labor; token discipline (exact paths, shallow depth, filtered output, one batched call, no re-inspection, no whole-tree dumps); verify loop (edit -> check.sh -> Rojo sync -> scripted playtest -> fix; stop after 3 failed fixes); builders are the source of truth; SAVE NEEDED rule; Studio identity by placeId; playtest with a local player; MCP warns clients can read and modify the open place, so run only trusted agents and keep a Version History checkpoint before big edits.

`systems/_TEMPLATE.md`
```
# <System name>
Tier: light | standard | full
Purpose: (2 lines)
Owner files: (paths)
Public API: (module functions, remotes with payload types)
Data touched: (DataService keys / Attributes / Tags)
Invariants: (always true; each testable)
Exploit surface: (what a malicious client tries; how the server blocks it)
Playtest checklist: (numbered steps; the matching tools/qa script)
Status: planned | in progress | done
```
`BRIEF_TEMPLATE.md`
```
Goal: (one sentence)
System doc: docs/systems/<x>.md
Files in scope: (paths; touch nothing else)
Acceptance: (observable checks; check.sh tier; playtest script)
Out of scope: (explicit)
Report: <=10 lines
```

### Tier system
| Tier | Gates | Use for |
|---|---|---|
| light | StyLua + Selene | prototypes, world/art builders |
| standard | light + Luau strict analyze + `rojo build` | default |
| full | standard + unit tests + CI | data, economy, monetization, anything that grants value, anti-exploit |
The strictest tier among touched systems applies. `KIT_TIER` overrides `.kit-tier`.

### Agents (`.claude/agents/*.md`; frontmatter `name` = filename, `description`, `model`; body <=25 lines)
| Agent | Model | Tools | Role |
|---|---|---|---|
| gameplay-dev | sonnet | inherit | server/client gameplay from a brief |
| ui-dev | sonnet | inherit | client UI in code, responsive, no server trust |
| data-security-reviewer | opus | Read, Grep, Glob, Bash | read-only diff review, findings ranked by severity |
| qa-playtester | haiku | inherit | runs tools/qa scripts via MCP, reports PASS/FAIL lines only |
Every body says: follow CLAUDE.md, read one system doc, no commit/push, run scripts/check.sh, use MCP per docs/MCP_PLAYBOOK.md, report <=10 lines. Omit `tools` for MCP-using agents so they inherit MCP tools. Agents load at session start; restart the session after creating or adding them.

Reviewer checklist: remote handlers missing type/range/rate-limit/state/zone checks; client-trusted values; gating only at the door; leaks (connections, per-player tables not cleaned); raw DataStore use, missing pcall/retry/BindToClose, overwrite after failed load, no timeout kick; PlayerAdded races, respawn handling, streaming `WaitForChild`; unguarded yields in handlers; deprecated APIs; hardcoded numbers/asset IDs; code in the wrong realm; per-frame scans, `GetDescendants` in hot paths, unbounded tables; text typed by players shown to others without filtering.

### Commands (`.claude/commands/*.md`, each with a `description`)
`check.md` (run check.sh, summarize failures only), `new-system.md` (create the system doc from the template, add an ARCHITECTURE row, stub files in the right realm), `playtest.md` (run a system's tools/qa script via MCP and report PASS/FAIL).

### tools/ conventions
- `tools/map|art/*.luau`: builders run inside Studio through one MCP Luau-execution call. Idempotent (delete then recreate their own output), deterministic (seeded randomness), no script left behind in the place, values recorded in the system doc. Imported assets: `InsertService:LoadAsset`, then strip every Script/LocalScript/ModuleScript; no branded or copyrighted content; log id/creator/source in docs/ART.md.
- `tools/qa/<system>.luau`: self-contained snippet, one MCP call, prints `PASS name` / `FAIL name: reason` lines, no helper code written through MCP. Target <10K tokens per playtest.
- Contract between code and world: name and Attribute names are defined in the system doc BEFORE both sides are built.

### Core modules (copy from the reference repo if present; otherwise write to these specs)
- `shared/Remotes.luau`: server creates RemoteEvents lazily in `ReplicatedStorage.Remotes`; client `WaitForChild`s; typed accessor.
- `server/Net/Guard.luau`: `rateLimit(player, key, minInterval)`, `cleanup(player)` (must not recreate entries after a player leaves), payload validators.
- `shared/Config.luau` (typed constants), `shared/Assets.luau` (asset IDs).
- `server/Data/DataService.luau` + `ProfileSchema`: ProfileStore-based, `[Data]` logging behind `Config.DEBUG_DATA`, 30s hard load timeout then kick with a message, retries with backoff, schema validation on every load, migrations keyed on schemaVersion, string keys, save on leave and BindToClose, `loading` guard against double loads.
- `server/init.server.luau`: requires services, `DataService.start()` exactly once, `Players.PlayerRemoving` cleanup, PlayerAdded race handled.
- `src/first`: loading screen (removes the default one) with a failure message path. Spawn flow per CLAUDE.md.
- `tests/run.luau`: Lune runner plus at least one real test of a pure module.

---

## Part C — Operating protocol (orchestrator <-> agents)
- The orchestrator plans, briefs, verifies, and updates docs. It never reads system source. Subagents write code and report in <=10 lines.
- Parallel subagents only on disjoint file scopes. They must NOT run check.sh (shared build files); the orchestrator runs it after they return. Shared files have one owner per round (do a sequential "A0" step that pre-registers remotes, config keys and catalog skeletons, then fan out). Do not use git worktrees (Rojo syncs one folder).
- One MCP agent at a time. Batch ALL MCP instance work into one art phase so the human saves once; end it with SAVE NEEDED.
- Gates per milestone: check.sh at the right tier; scripted playtest; data-security-reviewer on the diff for every full-tier system and every remote; fix high findings; max 3 fix attempts, then stop with a precise diagnosis.
- After each milestone update the system doc Status, ARCHITECTURE.md, DECISIONS.md and STATUS.md. If context grows large, write STATUS.md and have the human restart the orchestrator with the same prompt.
- Decide design ambiguities, log them, continue. Stop only for human-only steps: Cmd+S after MCP work, publishing, the multi-player Studio test (Test > Clients and Servers), phone-size UI check, commits at checkpoints, Creator Hub settings.
- Measured costs to beat: art phase ~150K tokens, improvised playtest ~175K, scripted playtest target <10K.
- Safety: no copyrighted or branded content (never real team marks), audio only from sources Roblox currently allows, no chance-based wagering tied to purchasable currency (check current policy), filter any player-typed text shown to others.

---

## Part D — Starting a new game

### Intake questions (ask all before building; recommended defaults first)
1. Platforms: PC + mobile (default) / PC only / + console.
2. Saving: everything (default) / partial / none.
3. Core interaction model and placement (fixed slots default vs free placement).
4. Multiplayer shape: max players per server; solo/co-op/competitive.
5. Leaderboard: live per-server (default) / global / both.
6. Income or reward delivery model.
7. Theme and art source: simple block placeholders first (default) / Creator Store / supplied assets.
8. V1 extras and what is explicitly out of v1 (offline earnings, prestige, monetization, daily rewards).
9. Style target line for art (palette and mood).

### Design doc template (`TEXANS_DESIGN.md`-style, split into docs by the agent, then deleted)
1 Pitch (+ IP caution) · 2 Decisions (one line each, dated) · 3 World layout and naming contract · 4 Catalog with ALL numbers marked TUNE and payback targets · 5 Systems (one spec per system, template above) · 6 Build order · 7 First two briefs.

### Roadmap skeleton
M0 prereqs (human, Part A) · M1 pure logic + tests (catalog, math, number format) · M2 data + core economy (full tier, reviewed) · M3 world greybox via tools/map builder · M4 core loop (placement/purchase flow + HUD) · M5 income/progress loop · M6 leaderboard/social · M7 retention features (daily rewards etc.) · M8 hardening (security review of every remote, multi-player test, performance) · then expansions built on shared systems (Gear, Zones, Collections, Materials) rather than one-off activities.

---

## Part E — Orchestrator prompt template (save as docs/ORCHESTRATOR_PROMPT.md; fill the bracketed parts)
```
From: PM. You are the BUILD ORCHESTRATOR for [GAME]. Resume from docs/STATUS.md (else docs/ROADMAP.md). Goal: [phase goal].
RULES: never commit or push; never read system source; delegate all code to subagents (gameplay-dev, ui-dev, qa-playtester, data-security-reviewer) who read only CLAUDE.md plus their system doc and report in <=10 lines. One MCP agent at a time; Studio pinned by placeId [PLACE_ID]; playtests use start_play. Parallel subagents only on disjoint scopes and they must not run check.sh; you run KIT_TIER=full scripts/check.sh after they return. Shared files have one owner per round (do A0 first). Max 3 fix attempts then stop with a diagnosis. Decide ambiguities, log them in DECISIONS.md, continue. After each milestone update system docs, ARCHITECTURE.md, DECISIONS.md, STATUS.md. Batch all MCP instance work into one art phase and end it with SAVE NEEDED.
PHASES: A code only (A0 pre-register remotes/config/catalog skeletons; then fan out) -> B art and world via idempotent tools/ builders (+ at most 5 screenshots) -> C playtests as code in tools/qa, security review of every remote and full-tier diff, final check.
DEFINITION OF DONE: [observable player journey]; check.sh full passes; every system doc says Status: done.
HUMAN-ONLY (list together at the end): Cmd+S, multi-player test, phone-size check, publishing, commits at checkpoints.
FINAL REPORT <=15 lines: done, failed, token-expensive spots, exact human steps.
```

---

## Part F — Troubleshooting and platform notes
| Symptom | Cause and fix |
|---|---|
| `stylua: command not found` | Shell lacks `~/.rokit/bin`; check.sh must export it; new terminals read `~/.zshenv` |
| `rojo sourcemap` error on `$path: Packages` | Folder missing; `mkdir -p Packages ServerPackages` in check.sh |
| New ReplicatedFirst/project change has no effect | Restart `rojo serve`, reconnect the plugin |
| Map/art vanished after reopening Studio | Edits were unsaved or you opened a stale local file; rebuild with tools/ builders, reopen via File > Open from Roblox |
| Agents not listed / not used | Files must be `.claude/agents/<name>.md` with valid frontmatter; restart the Claude session; /agents wizard no longer exists |
| `Roblox_Studio` missing in `/mcp` | Enable the MCP toggle in Studio, quick connect, or run the manual command below; restart Claude; fully restart Studio |
| Agent refuses: "no Studio named X" | Pin by placeId; close stray Studios; list Studios via MCP |
| Playtest finds no profile | Server-only mode (no player), API services off, place unpublished, or a stale session lock (wait ~2 minutes); read the `[Data]` log lines |
| zsh shows `quote>` or "no matches found" after a paste | Comment, apostrophe, `*` or `<angle>` in the block; remove them |
| Studio panel not found | macOS: menus at the top (Window > Output, Test > Play) |
| Repeated "Asset type does not match" warning | Engine-level noise seen in practice; log and ignore unless it grows |

Manual MCP registration (from the repo folder, then restart Claude): macOS `claude mcp add --transport stdio Roblox_Studio -- /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP`. Windows: command `cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat`. (Per current Roblox docs; re-verify.)

## Known gaps (accepted)
- Non-script instances live only in the Roblox cloud place; mitigation is the tools/ builders, Version History and `.rbxm` exports of critical models.
- Roblox-dependent behavior cannot be unit tested headless; it relies on tools/qa playtests.
- Agents cannot save the place, run the multi-player test, judge mobile layouts, or commit; the human does.
- Tool, package and action versions drift; always re-verify against `--help` and official docs.