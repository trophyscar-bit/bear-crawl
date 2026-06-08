# Plush Crawl — Roadmap

A living plan. Newer phases at the bottom — current focus pinned at the top of the "Active" section.

---

## Where we are today (2026-05-26)

**Shipped:**
- Title screen + difficulty + fullscreen + WASD nav
- Movement, pizza projectile w/ single wall bounce + 10% speed-up
- Brown-bear enemies w/ steering-based obstacle avoidance + (hard-only) ninja-star throwing
- Mirror-bear bosses every 3 floors w/ rainbow body + rainbow pizzas + 2-phase-ish difficulty curve
- Wall borders, cylinder cover, randomly-placed portal-near-centre
- HP bar (player) + top-center boss bar
- Health pickups (cute green fluff +1 HP, golden heart fluff full heal — boss drop)
- I-frames so swarms can't burst-kill you
- Boons: 5 commons, 1-of-3 picker between every floor
- Player death = big explosion + lingering body chunks + chain explosion of nearby enemies + game-over pop-up
- `RunState` + `GameSettings` autoloads as the live-game state holders

**Genre we're targeting:** Hades-flavoured 2D top-down action roguelite. Permadeath, procedural rooms, run-based boon stacking, eventual meta-progression. Closer to Hades / Enter the Gungeon than to traditional Nethack-style turn-based roguelikes.

---

## Genre research — what other games do

| Game | Per-run system | Meta system | Combat depth | Why it matters for us |
|---|---|---|---|---|
| **Hades** | Boons from 9 gods, duo boons, weapon aspects, Charon shops, Pact of Punishment "heat" | 5 separate currencies, Mirror of Night skill tree, weapon unlocks, dialogue/story arcs | Dash w/ i-frames, special attack, cast, multiple weapons, hangover combos | Gold standard. We're already shaped like a stripped-down Hades. |
| **Dead Cells** | Mutations, scrolls, weapons w/ affixes, biome forks | Permanent cell unlocks add items to the run pool ("unlock-don't-power") | 2 weapons + 2 skills, parry, dodge-roll, slow-mo | Item-pool unlocks > raw stat upgrades. Worth borrowing. |
| **Binding of Isaac** | Item pickups stack additively/multiplicatively, room layouts, item synergies | Unlocks add new items + characters to the run pool | Ranged tear-shooting, room-based combat | Synergies and discovery are the loop. |
| **Slay the Spire** | Card draft choices each step, relics, potions | Permanent ascension levels, new starting decks unlock | Turn-based | Choice-density per step is what hooks. Each room = a meaningful pick. |
| **Risk of Rain 2** | Items stack indefinitely, item rarities, lunar items (curses) | New characters + items unlock | Real-time, dodge-by-position | Aggressive item stacking + scaling difficulty timer is potent. |
| **Vampire Survivors** | Per-run weapon evolutions, passive items | Permanent stat tiers, character unlocks | Auto-attack | Evolutions (combine 2 items → 1 powerful one) are a cheap pattern with high reward. |
| **Enter the Gungeon** | Active items, passive items, gun unlocks | Hegemony Credits buy new items into the pool | Dodge-roll, table-flipping, blank | "Meta-progression doesn't increase power" stance is a valid alternate philosophy. |

**Top patterns to steal, ranked by reward-per-effort for our game:**

1. **Rarity-weighted boon pool** (Common / Rare / Legendary) — almost free, huge variety boost.
2. **Persistent currency + Workshop** — universal "another run" hook.
3. **Boon synergies** (Hades duos / Isaac items) — 2 specific boons combine into a stronger effect. Cheap content with deep play impact.
4. **Dodge-roll w/ i-frames** — combat skill ceiling, well-understood pattern.
5. **Item-pool unlocks via meta-currency** — alternative to stat upgrades that ages well.
6. **Heat / ascension** — voluntary difficulty for replayability.
7. **Status effects** (burn / slow / freeze) — multiplies boon variety.
8. **Multiple enemy archetypes** — currently only one (brown bear). Three would feel like a whole other game.
9. **Room type variety** (treasure / shop / fountain) — breaks up the combat rhythm.

---

## Phased plan

Each phase is 1–2 short sessions of work. Phases can swap order if something feels more important to play with.

### Phase 1 — Boon depth (rares + legendaries + rarity UI) ⏳ NEXT
**Why:** We've proven the picker mechanic works. Adding rares + legendaries multiplies variety with very little new code.

- Add **5 rares**: Bouncy Crust, Double Pep, Spicy (burn DoT), Pizza Magnet, Lucky Crumbs.
- Add **3 legendaries**: Pepperoni Burst (AOE on impact), Pizza Wheel (orbital defensive slice), Soft Landing (1 free hit per room).
- Rarity-weighted draw in `RunState.roll_offers` — common 65 / rare 25 / legendary 10, with depth scaling toward rares.
- **Visual rarity tint** on boon cards: common cream-white, rare cyan, legendary gold-with-glow.
- Small **"active boons" HUD strip** (bottom-left) showing icons of what you've picked so far.

**Done when:** A 10-floor run can roll a meaningfully different build from another 10-floor run.

---

### Phase 2 — Combat depth (dodge + status effects)
**Why:** Boons get more interesting when they can apply status effects. Dodge gives the player a survival tool.

- **Dodge-roll** on Shift/Space — short burst in last-move direction, 0.25 s of i-frames, ~0.7 s cooldown. (Re-uses existing `_invuln_time`.)
- **Status effect system** on enemies — small `Status` resource with `apply(target)` and ticker:
  - **Burn**: 1 dmg/sec for 3 s (Spicy boon, future pepperoni)
  - **Slow**: -40% speed for 2 s (future "Sticky Sauce" boon)
- Status visual: small icon floats above enemy.
- Pizza-on-hit applies any boon-derived statuses to the target.

**Done when:** Spicy makes pizzas leave a burning enemy behind that you can watch die.

---

### Phase 3 — Meta-progression (Fluff currency + Workshop)
**Why:** The "one more run" hook. Each death feels like progress.

- New autoload `MetaSave` writes a small JSON to `user://meta.json` (Godot's app data folder — survives reloads):
  - Total fluff earned
  - Best floor reached
  - Permanent upgrade levels
- Enemies drop **1 Fluff** on death; bosses drop **5 Fluff**.
- HUD: small fluff counter top-right.
- **Workshop** button on title screen → new scene `workshop.tscn`:
  - 4 upgrades, 3 levels each, costs ramp up:
    - **More Plush** — +1 starting HP (max 3)
    - **Sharper Crust** — +1 starting pizza dmg (max 3)
    - **Faster Feet** — +5% starting move speed (max 3)
    - **Wise Bear** — Reveal boon rarity at a glance (1 level)
  - Workshop applies via `GameSettings` modifiers read by `player.gd::apply_boons`.

**Done when:** Dying still feels rewarding because you bring Fluff home.

---

### Phase 4 — Enemy variety (3 new archetypes)
**Why:** "Same brown bear forever" is the weakest part of the game right now.

- **Runner bear**: smaller, ~30% faster, lower HP — flanks aggressively.
- **Tank bear**: bigger, slow, +3 HP, hits twice as hard.
- **Shooter bear**: stays at range, throws ninja stars at all difficulties (we already have the projectile).
- Spawn weighting by floor depth: floors 1-2 brown only, 3-5 add runners, 6+ add tanks + shooters.
- Each gets a slight tint or accessory to distinguish (recolour the brown_upper/brown_legs textures programmatically — cheap until graphics pass).

**Done when:** A Floor 5 room feels like a different fight from Floor 1.

---

### Phase 5 — Room type variety (treasure / shop / fountain)
**Why:** Combat-only rooms get repetitive. Hades-style variety = better pacing.

- After clearing a floor, the portal sometimes leads to a non-combat room:
  - **Treasure room**: 1 guaranteed boon, no enemies. Rarer odds.
  - **Shop**: NPC bear sells 3 boons for in-run "Crust Coins" (a separate currency that drops from enemies).
  - **Fountain**: heal to full, light enemies (2 brown bears).
- Door visual signals next room type (different inner-glow colour or icon).
- Floor counter shows next room type if you've chosen the door.

**Done when:** A run feels like a journey, not a treadmill.

---

### Phase 6 — Boss variety + multi-stage fights
**Why:** Boss every 3 floors is structurally good but it's always the same fight.

- 3 distinct bosses:
  - **Mirror Bear** (current) — rainbow pizza pattern
  - **Giant Bear** — slow, charges in straight lines, summons brown adds
  - **Cotton Cloud** — floats around, drops ninja-star rain in waves
- Multi-stage: at 50% HP each boss transitions to a more aggressive moveset (faster, denser pattern, etc.).
- Floor 9 = current; Floor 12 = next boss type; Floor 15 = third boss; cycle from there with stat scaling.

**Done when:** Beating Floor 12 boss feels different from beating Floor 9.

---

### Phase 7 — Audio (music + SFX)
**Why:** Audio is the single highest perceived-quality lift per hour of work.

- **Music**: 1 title track, 1 combat track, 1 boss track. (CC0 from [OpenGameArt](https://opengameart.org/) or commissioned royalty-free.)
- **SFX**: pizza throw, wall bounce, enemy hit, enemy explode, pickup chime, portal hum, hurt grunt, death boom, menu blip.
- **Audio bus** + master volume slider in Options.
- All SFX assignable via constants in a single `audio.gd` so swap-outs are 1 line.

**Done when:** Playing with sound on is noticeably better than playing with it off.

---

### Phase 8 — Polish, stats, and "feel"
**Why:** Roguelites live or die on feel — the small frictionless touches.

- **Run summary screen** between game-over and main menu: floors reached, enemies killed, bosses killed, fluff earned, run time.
- **Stats panel** on title screen: lifetime totals (kills, bosses, deaths, best floor, time played, fluff lifetime).
- **Achievements** — small popups, ~10 of them ("First boss kill", "Floor 10 reached", "Bouncy pizza KO", etc.).
- **Tutorial hints** — first-run only, single-line overlays during early floors: "WASD to move", "Space/click to throw pizza", "Walk into portal to advance".
- **Particle polish**: spark trail on pizza, footstep puffs, pickup sparkles.
- **Screen shake refinement** — context-aware strength (small on hit, medium on explosion, big on boss death).
- **Pause menu** with Resume / Options / Quit-to-title.

**Done when:** A new player picks up the game and can play for an hour without confusion or dead air.

---

### Phase 9 — Graphics overhaul
**Why:** Save it for last — every other phase changes which sprites exist. Doing art first guarantees rework.

The whole project right now is **procedural PIL output** + photographed bears. That's fine for prototyping but gives the game an inconsistent visual register. Two paths once mechanics are locked:

**Path A — Hand-painted / commissioned art.** Pay an illustrator or use commercial CC0 packs for:
- Floor / wall / cylinder tiles
- Bear sprites (player + 3-4 enemy variants + 3 bosses) — 4-8 frame walk cycles
- Pizza, ninja star, pickup icons
- Portal animation (8-frame sprite sheet)
- Particle textures (explosion smoke, sparks, glow)
- UI frames + buttons + bar fills

**Path B — Stylized procedural retake.** Lean into the "stuffed-animal photographed at home" charm: re-shoot all bears in matching lighting against a consistent backdrop, build a custom rim-light shader in Godot to add a single coherent lighting model, replace cylinder + portal art with photographed-prop equivalents (a wooden block, a glowing toy phone, etc.). Keeps the soul of the prototype.

**My recommendation:** **Path B first**, escalating to Path A if the photographs can't keep up with the gameplay's polish. Path B preserves what makes this game odd (it IS your toys), and the lighting shader is a one-time investment that fixes the whole catalogue.

A graphics-pass checklist worth running through regardless:
- Replace every PIL-generated PNG with a final asset (pizza, cylinder, portal, explosion, ninja star, fluff orbs, stuffing, body chunks).
- Add **animated walk cycles** for bears (currently they hop, which is charming but limited).
- Tighten **HUD fonts** — install a proper font in `assets/fonts/` and theme everything to use it.
- Tighten **boon card styling** — currently functional but plain.
- Tileset the floor instead of a flat ColorRect.
- Apply a CRT / paper-grain post-process for visual unification.

**Done when:** Screenshots are share-worthy without explanation.

---

## How we'll work the roadmap

- **One phase at a time.** Don't half-finish two phases — finish one and play with it.
- **Each phase ends with a play session.** Notes from playing feed into the next phase.
- **CHANGELOG.md tracks what shipped; ROADMAP.md tracks what's next.** When a phase lands, copy a short summary into CHANGELOG and check it off here.
- **Cut ruthlessly.** Anything in a phase that doesn't survive the play session gets dropped or moved.

---

## Open questions

- **Win condition?** Is there a "final floor" the game can be beaten on (Floor 20 ultimate boss?), or open-ended-scaling-forever?
- **Save mid-run?** Hades doesn't; roguelikes vary. I'd say no — keeps runs tight.
- **Mouse aim?** Currently throw direction is "last input direction." Mouse aim would change feel substantially — pro: more control, con: harder on keyboard-only.
- **Multiple player characters?** Different starting bears with different base stats / starting boons. Big content lift but a great hook for replay variety.

---

## What's next concretely

Phase 1 (rare + legendary boons + rarity UI) is the cheapest big-impact step from here. I can scaffold it in one session. **Ready when you are.**
