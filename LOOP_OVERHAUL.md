# Plush Crawl — Gameplay Loop Overhaul

A design proposal in response to the "play it once and put it down" problem.

---

## The problem

We've spent ~30 sessions adding mechanics — boons, bombs, biomes, bosses, hazards, traps, weapons. The **moment-to-moment combat** is solid. What isn't solid is the **reason to start another run** after the first.

Concretely, after one full playthrough you've already seen:
- Both biomes
- Both bosses (Mirror Bear + Desert Boss)
- All 13 boons (statistically you'll have seen most by Floor 12)
- All 3 weapons (bomb / scatter / homing)
- All 4 Workshop upgrades (maxable in ~3 runs of Fluff farming)

Once Workshop is maxed, the game has nothing left to give. The currency keeps accumulating but doesn't buy anything new. There's no "I'm trying to unlock the X" loop.

This is the same problem every Hades clone hits in development — the systems exist, but the *discovery cadence* is wrong.

---

## What the best roguelites steal from each other

| Game | The hook | How it's structured |
|---|---|---|
| **Hades** | "Beat dad" + lore/dialogue drip | Each run advances a tiny bit of story; multiple weapons + weapon "aspects" to unlock; Mirror of Night skill tree expands gradually |
| **Dead Cells** | "Unlock the next weapon into the pool" | Cells (currency) spent at vendors to **add new items to the run drop pool** — meta-progression makes runs *more varied*, not *more powerful* |
| **Risk of Rain 2** | Character roster + item discovery | 12+ playable survivors unlocked via in-game challenges; each survivor plays radically differently |
| **Vampire Survivors** | Character roster + evolutions checklist | Tons of characters, each unlocked by an action you naturally do; evolutions are hidden puzzle-pairs you discover by playing |
| **Binding of Isaac** | Endings + items + hidden bosses | 13+ endings, ~700 items, dozens of secret bosses; achievement-driven completionism |
| **Slay the Spire** | Ascension ladder + character variety | 4 characters; after each beats the game, an Ascension level unlocks (1-20) layering small modifiers |

**The pattern across all of them:** the meta-progression isn't *"get stronger"* — it's *"get more options."* You unlock characters, weapons, items, modifiers. Each playthrough is structurally different from the last.

Our current Workshop violates this principle. It just makes the bear flat-out stronger, which makes the game easier *and* runs out of things to buy.

---

## The proposal

A **multi-character, multi-weapon, ascension-laddered, story-light** redesign of the meta-progression layer. We do NOT touch the moment-to-moment combat — that's working.

### 1. Character roster (3-5 plushies)

Each character is one of your *actual* plushies, with a one-line identity and a passive. Stats variance is small (no character is "objectively better") so it feels like a playstyle pick, not a power pick.

| Character | Identity | Passive | Unlock |
|---|---|---|---|
| **The Bear** (current) | Balanced | — none — | Default |
| **The Brown Bear** (current enemy texture) | Slow tank | +2 max HP, -10% move speed, +1 base pizza damage | Beat the game (Floor 10 boss) once |
| **(future plushie A)** | Glass cannon | -1 max HP, +30% pizza throw rate, +25% pizza speed | Clear a run without picking up any Plush Armor |
| **(future plushie B)** | Mage / range | -1 max HP, starts each run holding 6 homing pizzas | Clear a Desert boss without taking damage |
| **(future plushie C)** | Brawler | +1 max HP, starts with a melee swipe instead of pizza | Beat the game 3 times |

Visually: a **Character Select screen** between title and the run. Shows your unlocked characters with a small portrait + their passive line.

This is where the photo plushies the user is sending become content. Each one = a character.

### 2. Weapon roster (starting-weapon picks)

We already have **bomb**, **scatter**, **homing** as in-run weapons. Promote them (and add 2-3 new ones) to **starting weapons** that the player picks before a run.

| Weapon | Feel | Mechanic | Unlock |
|---|---|---|---|
| **The Pizza** (current default) | balanced | bouncing, 1 dmg | Default |
| **The Scatter** | crowd-clear | 3 pizzas in a cone every throw | Beat Floor 6 once |
| **The Homing** | tracker | slower pizza that follows nearest enemy | Beat Floor 6 once |
| **The Bomb Volley** | nuker | thrown bomb with fuse (current pickup) | Beat Floor 9 once |
| **The Yarn Ball** *(new)* | utility | rolls along ground, infinite bounces, lower damage | Beat the game once |
| **The Tea Cup** *(new)* | support | short-range melee whack, heals 1 HP per 10 hits | Find the Lost Mouse hidden NPC |
| **The Star Slice** *(new)* | precision | piercing pizza that travels in straight line, no bounce | Achievement: kill 500 enemies cumulative |

In-game weapon pickups (the current bomb/scatter/homing drops) still exist — they're **temporary overrides** for variety mid-run. Starting weapons are your **build identity**.

### 3. Win condition + Ascension

**Floor 10 is now the final boss arena.** Beating it ends the run with a victory screen, not "keep going forever."

After your first win:
- Unlock **Ascension 1** — voluntary modifier you can enable from a new pre-run screen. Levels 1-5, each adds one curse:
  - Asc 1: 50% more enemies per floor
  - Asc 2: + bosses gain 30% HP
  - Asc 3: + pizza bounces removed
  - Asc 4: + you start with 3 HP instead of 5
  - Asc 5: + final boss has a phase 3
- Higher ascensions multiply Fluff earned
- Each ascension level has a separate "beaten" flag — bragging rights / achievement

This gives players who've "won" the game a reason to keep climbing.

### 4. Cotton Threads — rare meta-currency

Existing **Fluff** stays as the everyday currency for character/weapon **unlocks** (re-purposed from "stat upgrades"). Add a second currency **Cotton Threads**:

- **Drops only from bosses** (5 per boss) and **floor-10 final boss** (50)
- Spent in a new Workshop tab on **cosmetic/expressive unlocks** + ascension catch-up:
  - Alt color palettes for unlocked characters
  - "First Try" insurance — start one run with 2 bombs if you've died on Floor 10 specifically
  - Codex entries about NPCs / lore (cheap, atmospheric)

Two currencies = two pacings. Common currency for the unlock grind, rare currency for the prestige stuff.

### 5. Achievement grid (10-15 specific goals)

These drive discovery without dialogue or lore:

- First Stitch — clear Floor 1
- A Cold Slice — wasted heal at full HP
- Crumb Trail — 100 enemies killed cumulatively
- Stuffed — buy all four Workshop upgrades to max
- A Quiet Floor — clear a floor without taking damage
- Soft Knock — beat a boss on Nap
- Insomnia — beat a boss on Nightmare
- Up the Stairs — reach Floor 10
- You Beat It — beat the final boss once
- The Long Night — die 25 times
- Five Stitches — beat Ascension 5
- Pacifist — beat any boss without throwing a single bomb/scatter/homing
- Untouchable — clear a boss without taking damage

Each one shown in a new **ACHIEVEMENTS** title-screen panel as a checklist. No popups, just quiet check marks.

### 6. Story drip (small)

We do not write a novella. We add **20-30 one-line dialogue beats** that drip out across runs, said by **NPCs at the new hub between runs**.

- Replace title screen with a **hub scene** (the bear in a small "den" room with a sleeping baby in the corner — implies "you've come home")
- 2-3 NPCs in the hub: the Tailor (Workshop), the Soldier (weapon unlocks), the Owl (lore lines, codex)
- Each milestone (boss beaten, biome cleared, achievement earned) unlocks 1-2 lines of NPC dialogue
- Lines are *atmospheric*, not plot-driving. *"The flowers in the kitchen are still in their vase."* *"The baby hasn't moved since the night the lights went out."*

This costs basically nothing and gives the run-to-run experience a sense of *something happening* even without a real story engine. Players who don't read it lose nothing.

---

## What we keep, what we cut, what we rework

| Keep | Rework | Cut / defer |
|---|---|---|
| All combat mechanics (pizza, boons, bombs, hazards, traps, ponds) | Workshop: instead of stat upgrades, unlocks-for-Fluff | Stat-upgrade Workshop in current form |
| Boons (commons + rares + legendaries) | Lucky Start moves from "starting bombs" to character-specific | Lucky Start meta upgrade as currently implemented |
| Boss fights, biomes, multi-stage | Add final boss on Floor 10 | "Endless floors" — replace with finite Floor 10 win + ascension |
| Pickups, Fluff currency | Add Cotton Threads as second currency | — |
| Dev menu | — | — |
| Run summary screen | Show ascension level on win | — |
| Title screen | Replace with hub scene | — |

---

## Phased build order

We don't ship this in one turn. Suggested order:

### Phase A — Final boss + win state (~1 session)
- Cap floors at 10
- Floor-10 fight uses Mirror Bear or Desert Boss depending on biome cycle, **but with a phase 3** unique to the final fight
- New victory screen between Game Over flow
- Floor 10 boss drops 50 Cotton Threads + 25 Fluff
- Adds a real "I beat it" moment

### Phase B — Character select (~1.5 sessions)
- Build CharacterSelect scene (Title → Character Select → Difficulty → Start)
- Define 2 characters first: **Black Bear** (default) + **Brown Bear** (tank variant, unlocked by first win)
- Per-character data: name, portrait texture, base_max_health, base_speed, base_pizza_damage, starting_special_weapon, starting_special_charges
- Player.gd reads selected character on _ready and applies overrides

### Phase C — Weapon unlock system (~1 session)
- Cotton Threads + Weapon select screen between Character Select and the run
- Promote current 3 weapons to startable
- New scene: pre-run loadout (Character + Weapon + Ascension)

### Phase D — Ascension (~half session)
- Asc 1-5 toggles on the pre-run screen
- Modifier hooks in main.gd + boss.gd
- Per-asc "cleared" flag in MetaSave
- Fluff multiplier per asc

### Phase E — Achievements (~half session)
- AchievementList class + tracker
- Title-screen panel with check marks
- Hook check-ins into existing kill/damage/floor events

### Phase F — Hub + NPC dialogue (~1 session)
- New scene: small den room with bear + 2-3 NPCs
- Replace title screen entry point with hub
- Dialogue file (JSON or .gd dict) keyed by milestone
- Each milestone fires unlocks → next time you enter hub, the NPCs say new lines

### Phase G — New weapons + characters (rolling)
- Whenever you send more plushie photos: process them, define a character, unlock condition, passive
- New weapons (Yarn Ball, Tea Cup, Star Slice) added one at a time as content updates

---

## Cost vs. payoff

| Phase | Effort | Adds | Risk |
|---|---|---|---|
| A | small | win state, beat-the-game feel | low |
| B | medium | replayability via character variety | medium — needs UI work |
| C | small | weapon-build identity | low |
| D | small | end-game grind for completionists | low |
| E | small | discovery hook | low |
| F | medium | atmosphere + sense of place | medium — risks feeling tacked-on |
| G | rolling | content over time | low — just data |

The biggest single payoff is **B (Character Select)** — that's the "next time you play, the game is structurally different" lever. Most "test game vs real game" distinctions live there.

The second biggest is **A (Final boss + win state)** — players need a clear "I did it" moment for the meta-progression to mean anything.

---

## Open questions for you to decide

1. **How many characters at launch?** I'd say 2 to start (Black Bear default + one unlock). Adding a 3rd as plushie photos arrive is trivial.
2. **Do we keep Workshop stat upgrades** alongside character-driven progression? My vote: **drop** the four stat upgrades. They make characters less distinct. Replace Workshop with **Character/Weapon unlock vendor**.
3. **Final boss identity?** Floor-10 final boss should be *different* from the rotating biome bosses. Suggestion: **The Forgotten One** — a hand-stitched amalgam of every other plushie you've fought. Reuses existing chunks/parts via Sprite2D layered up. Fits "final boss" thematically without needing new art.
4. **Hub yes/no?** Atmospheric win but biggest art lift. Could defer to last phase or skip entirely if too ambitious.
5. **Story tone?** From the earlier theme discussion you wanted to dial back from the "bear can't find the kid" angle. The hub NPCs don't have to be heavy — they could just be utility NPCs who occasionally say something offhand. Tone is your call.

---

## Recommendation

**Start with Phase A.** It's the smallest piece with the biggest "yes this matters now" payoff. A real ending unlocks every other phase's meaning. Once Phase A ships, we know whether the rest is worth building.

If you say "go", I scope Phase A in detail and ship it next turn.
