# Spec: Horror and tension

- Subtle PG dread: the Stalker, lurkers, phantom scares, dark events.
- Driven by a hidden per-party Dread value and a scare budget.
- Isolated players are the prey; groups prevent big events.

Source: split from docs/GDD.md. Index: docs/GDD.md.

## Horror and tension

The horror is subtle: dread, not gore. It stays PG with no blood, and a scare budget keeps the effects rare enough to stay unsettling.

**The Stalker.** Each run has one tall, pale snow creature that lurks beyond the firelight.

- A per-party Dread value rises when players are far from camp, alone, in the dark or in a blizzard, and falls near fire.
- Higher Dread raises the chance of a hunt. There are no hunts on day 1, and a cooldown follows every hunt.
- When a hunt starts, the Stalker picks its target by isolation: a player alone is the most likely, a pair is next, and players traveling in a large group are rarely chosen.
- It always telegraphs: wildlife goes silent, frost creeps in at the screen edges, snow crunches behind the player and nearby fires gutter. Players who read the signs can run for a warm spot or light a torch.
- It never enters a campfire radius or warm spot and backs off from torches and flares. A hit deals moderate damage, knocks the player back and drops warmth sharply, but never kills from full health. The Stalker then retreats for a short time, giving the player a window to run, and teammates can revive anyone who goes down.
- It can never be killed, unlike the later mini-bosses. It is a pressure system meant to scare players and push them back toward camp, much like the leviathans in Subnautica. Torches and flares end a hunt sooner.

**Small scares with no enemy.** Phantom footsteps behind you (audio only), a silhouette at the tree line that is gone when you look again, a shadow passing the edge of the fire at night, cracking ice on the frozen lake, whispers or radio static in the tundra ruins, and frozen campsites with found notes that hint at earlier survivors.

**Lurkers (always just out of sight).** Ambient creatures that are never seen clearly and never attack directly. They make the world feel watched, and each one changes how players move or light their way. They vanish when approached or looked at head-on.

- **Tree watchers (forest).** Tall shapes standing between distant trees. Seeing one raises Dread, so lingering far from camp makes a Stalker hunt more likely.
- **Ice scratchers (frozen lake).** Scratching and thumping from beneath the ice. Marked thin-ice patches near them crack and drop players into freezing water, which costs warmth, so players learn to route around them.
- **Eyes in the dark (caves).** Pairs of glowing eyes that back away from torchlight. If a torch runs out, they close in and Dread rises quickly, so players must carry fuel.

**Dark events.** Random events that change the rules for a few minutes. They never overlap with a blizzard, have a minimum gap between them, start no earlier than day 3 and become only slightly more frequent as the day count rises, up to a hard cap. Each has a short warning, such as birds falling silent or the light flickering.

- **False night.** The sky goes dark in the middle of the day. Night rules apply: faster warmth drain, night hostiles spawn, vision drops and Dread climbs. Players must rush back to camp or light lanterns.
- **The quiet.** All sound stops and wildlife vanishes for a minute, then the Stalker's hunt chance spikes. It is a cue to get near fire.
- **Deep freeze.** Fires burn fuel faster and warmth drains faster until it passes, so players need a stockpile of wood.

Surviving a dark event counts toward achievements and pays a small coin reward. Lanterns and torches are the counter-play.

**Scare budget.** Cooldowns and per-day caps limit the phantom effects. None fire while players shelter in a blizzard, and a setting reduces audio and visual scares. All frequencies live in Config.

**Gentle scaling.** Danger rises slowly, not steeply. Dread gain, Stalker hunt chance, dark-event frequency, lurker density and mob spawn rates grow only slightly with days survived and with depth into the world, and each has a hard cap in Config. The goal is pressure that deters progress and stretches a run out, not a wall that makes exploring impossible. Every scary system keeps its counter-play at every depth: warm spots, fuel, torches and the fire radius. The tuning rule is that a prepared party can always reach the deepest ring, and an unprepared one pays heavily for trying.

**Hidden metrics, cues only.** Dread, hunt chance, event timers and every other danger value are never shown to players. There is no bar and no number. Players read the world instead: as Dread rises, ambient sound thins and a low rumble builds, the screen edges desaturate and frost creeps in, wildlife goes quiet and fires gutter. Cues strengthen with danger and fade as it passes, and each dark event has its own audio and lighting tell.

**Lone players are the prey.** Isolation decides who the horror picks.

- Each player gets an isolation weight from how many teammates are within range. A player alone has the highest weight, a pair a lower one, and a larger group much lower.
- The Stalker, lurkers and phantom scares are weighted by isolation, so a lone player is the most likely target of all of them.
- A full group traveling together (the whole party within range) prevents the bigger events: Stalker hunts, false night and the quiet. Ambient scares such as phantom footsteps can still happen to a group, just rarely.
- Bigger events roll against the most isolated player, so they only fire when someone has strayed.
- In a one-player party, the isolation weight uses a reduced solo baseline from Config, so solo runs are tense but not harsher than a duo or a group.

**Build phase.** The Stalker, Dread and its tells land in Phase 3. The lurkers and dark events land in Phase 3 once Dread exists. The small scares and audio polish land in Phase 4.
