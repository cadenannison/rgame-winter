# Known issues

- Onboarding progress is per session. The hint chain restarts on rejoin; persisting it needs a ProfileSchema field + migration (DataService owner).
- Swing animation and action sounds use fallbacks. Assets.SwingAnimation is empty (procedural arm swing, local only, other players do not see it) and the sounds are engine rbxasset placeholders; ids listed in docs/ART.md.
- Studio logs one warning not from this repo: rbxassetid://203785492 "Asset type does not match requested type" (place content or a plugin).
- Run summary "Queue again" is only actionable in the lobby. Run servers show the summary with a disabled "Back to the lobby in Ns" countdown; the lobby server does not resend the summary after the return (that needs the summary persisted, e.g. a ProfileSchema field). Integration choice: honest button in run servers.
- Disconnect hold keeps meters and inventory, not the character or its position; a rejoining player respawns at camp. A held player who never rejoins forfeits the run payout (accepted).
- Studio lobby play needs Workspace attribute ServerMode = "lobby" preset in edit mode; clear it before saving or Studio play boots the lobby.
- Thin ice has no hole: a broken patch turns to water color but stays solid (damage + warmth penalty + IceCrack cue only).
- Lurker "looked at" uses a look-direction heuristic (camera look dot > Lurkers.LookDotThreshold), not a real line-of-sight test.
- Stalker knockback moves the character directly (PivotTo), not with physics; it can clip on uneven ground.
- Storage chests are per chest (9 slots, one revision counter each) and open to the whole party on that run server; each player may place at most Config.Storage.MaxPerPlayer.
- Map notifications reuse an existing Notify kind (no dedicated "map" toast style).
- Sleeping bag respawnPoint flag is not implemented: the spawn provider has no per-player hook and Player.RespawnLocation needs a SpawnLocation per bag; players always respawn at camp. The bag still acts as a warm spot.
- E/Act prefers gather when a tree/rock is within prompt range, even if a chest/door is closer; a chest placed beside a tree opens only after stepping away from the tree.
- Event warning cue level (1..Cue.MaxLevel) rises through the warning, so it coarsely hints how close a blizzard/dark event is (allowed coarse level per the contract; no timer is sent).
- Buff speed sets Humanoid.WalkSpeed each survival tick while a speed buff/debuff is active; any other system that changes WalkSpeed for a non-downed player would be overwritten.
- Studio Play uses real DataStores ("Roblox API services available"): scenarios that end runs or claim the daily (lobby-player-path, day3-solo crafting/placing) add real stats to the test profile "cannison". meta-shop, settings-player-path, far-biome (as run in brief 21) and lobby-to-run back up and restore the meta fields.
- Perf* Workspace attributes (AtmosphereBoot) exist only in Studio (published behind RunService:IsStudio()); a client-side "no hidden attribute" sweep in Studio sees them. They carry no hidden metric.
- tools/apply_perf.luau (StreamingEnabled true, radii from Config.Perf) has NOT been applied to the place: tools/qa/perf.luau does not need it and client QA has only been verified without streaming. Apply it and re-run the client scenarios before publishing.
- RunSummary.rankChange is always nil (no cheap rank lookup from a run server); the summary shows the record gap instead.
- Equip feedback: equipping a cosmetic/perk/title shows the panel state change but plays no Equip cue (AudioCues row exists, unused).
- Robux purchases (prompt, ProcessReceipt on a live server, force-save) are hand-tests: ProductIds are 0, so the server never prompts.
- The gatherSpeed perk adds bonus yield (about +10% wood/stone over time), it does not shorten the swing.

