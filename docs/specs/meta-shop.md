# Spec: Meta-progression, shop and engagement

- Account-level stats, achievements, coins, shop, daily reward.
- Robux purchases are server-side; saves via ProfileStore with versioned schema.
- Includes engagement and reward loops and their guardrails.

Source: split from docs/GDD.md. Index: docs/GDD.md.

## Meta-progression, shop and saves

Only account-level data persists between runs. Everything about a run itself is discarded when it ends.

- **Stats.** Max days survived, total runs, mobs killed, bosses defeated and items crafted. Max days feeds the global leaderboard, and stats show on the lobby board and above a player's head.
- **Achievements.** About 20-30 across days survived, kills, bosses, crafting and co-op feats. Each pays coins and some grant titles.
- **Coins.** Earned at run end from days survived and achievements. Coins buy shop items.
- **Unlockable starter gear.** Milestone-based permanent unlocks, such as better starting coats or tools.
- **Shop.** Cosmetics (outfits, trails, camp decorations, pets), starter gear tiers and run-start perks. A player equips one perk per run, and perks are capped so none trivializes survival.
- **Robux.** Three coin pack sizes and a few Robux-only cosmetics. All purchases are handled server-side through MarketplaceService receipts.
- **Daily login reward.** The only retention feature in v1.
- **Saves.** ProfileStore holds the profile with a versioned schema. Every gameplay action and purchase is validated on the server, and the client can only send requests.

## Engagement and reward loops

These are proposed defaults. They layer short, medium and long reward cycles so there is always a next thing within reach.

**Every few seconds.**

- Juicy feedback: hit sparks, a resource pop, a satisfying craft chime and small popups.
- Variable loot: points-of-interest chests roll a rarity tier, with a glow and sound for rare drops.

**Every few minutes.**

- Expeditions: farther biomes pay better loot, so every trip is a visible risk against reward.
- Exploration: each biome shows percent explored, with lore notes to find.
- Tech ladder: new workbench and forge recipes unlock steadily.

**Every day.**

- A dawn banner ("Day N survived") with a small fanfare. Beating your personal best triggers a bigger moment, and the HUD shows "2 days to your record" when you are close.
- Surviving a blizzard counts as a milestone with a reward.

**Every run.**

- A summary where coins pay out even on a bad run, plus "what got you" and one tip. A one-tap re-queue keeps the loop short.
- Personal best and leaderboard rank change shown on the summary.

**Across runs.**

- Achievements and titles, cosmetic sets to collect, starter gear tiers, and the daily reward.
- A small coin bonus per friend in the party.

**Social.**

- Roles emerge (hunter, builder, cook) with small synergies such as shared meal buffs.
- A party camp name and banner, and a shareable run card.

**Guardrails.** Many players are young, so skip paid random boxes (Roblox also requires odds disclosure for them), avoid countdown pressure to buy, and keep every reward earnable by playing.
