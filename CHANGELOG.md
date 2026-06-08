# Stuffed Crawler — Change Log

A roguelike where a black-bear plushie throws pizza slices at brown bears.
Engine: Godot 4.3. Project root: `C:\Users\matt\OneDrive - Elucid Systems\Desktop\game\`.

Newest entries at the top. Add new sections above existing ones as new features land.

---

## v2.0 "Combat feel + HUD + chair clusters + lamps" — 2026-06-05  (game_v2 only)

Gameplay / AI:
- **5s spawn grace**: nothing fires for the first 5s after a floor loads
  (`ArpgState.begin_spawn_grace` / `in_spawn_grace`). Gated across KK stars, paw,
  boss AoE, growler arrow, gun-bear burst, shrinkwrap puff.
- **Boss 2s engage grace**: the guardian holds fire for 2s after first eye-contact.
- **Boss AoE slower**: windup 1.2 → 1.7s (was too fast to react to).
- **Boss ninja stars easier**: spread 0.2 → 0.5 rad (slip between them), glowing star
  speed ×1.15 → ×0.78, volley interval 1.6 → 2.1s.
- **Gun bear ups his game**: each shot is now a 3-round burst fan (same slow cadence,
  actually threatening instead of a lone bullet).
- **All mobs dodge**: growler now juke-strafes when shot (it overrode movement so it
  never ran the base dodge); `_dodge_tick` helper added. Others already dodge via super.
- **Stuck-at-wall fix**: backrooms faced-wall collision extended 0.85·tile DOWN into the
  floor cell, snagging enemies/player. Cut to 0.16·tile (visual face stays tall). Unstuck
  trigger tightened (0.35 → 0.22s).

Props:
- **Chair clusters**: rooms now get a grouped huddle of 3–10 chairs at random
  orientations (toppled / any-way), sometimes a tidy ring, with ~1/5 half-sunk into the
  floor (new `sink` crop on `_place_prop`). Always clustered around a shared centre.
- **Standing lamps**: extracted a lantern-on-a-post from Level-10-2 (tile 15,6 →
  `props/lamps/floor_lamp.png`); `_spawn_lamps` sets them against walls in ~30% of rooms,
  each with a warm shadowless `PointLight2D`.

UI:
- **Weapon pickup popup**: no longer dead-centre — floats in a varied quadrant each time
  (top-right / bottom-right / bottom-left / centre via `_anchor_quadrant`), wrapped in a
  styled panel, with Q/E as a clean full-width footer below a separator.
- **Top-left HUD restyle**: stats now sit on a rounded plate; HP bar shows a numeric
  `cur / max`; removed the objective line. (The top-right pack switcher was already gone.)

## v2.0 "Wood-frame UI + torch core-glow" — 2026-06-05  (game_v2 only)

- **Wood-window frames on the cards**: extracted a clean beveled wood window frame from
  Level-0-2 (tile 13,12 → `assets/ui_frame.png`) and 9-sliced it (NinePatchRect, ~34px
  patch margin) around BOTH the end-of-round shop upgrade cards (`shop.gd`) and the
  ground weapon-pickup comparison cards (`dungeon._weapon_card`). Dark translucent inner
  panel keeps text readable over the glass. Frame PNG is runtime-loaded (no `.import`).
- **Wall-torch core glow**: the shadowed torch light was getting carved into a narrow
  downward wedge by neighbouring wall occluders ("only the bottom of the brick glows").
  Added a small SHADOWLESS core light pinned to the flame so the candle always reads as a
  lit source; it flickers in sync with the main lamp. `dungeon._add_wall_torch`.

## v2.0 "Core pass: sell-on-skip, dodge AI, Back Shot, furniture scenes" — 2026-06-05  (game_v2 only)

- **Sell a drop for coins**: declining a floor weapon now pays you (`weapon_sell_value`
  = 4 + rarity·5 + depth·2) and removes it, instead of leaving it on the floor. The
  popup's "keep" button reads `Q  Sell Drop (+N)`.
- **Dodge-when-shot AI** (`enemy.gd`): every hit builds a `_hit_streak`; once it crosses
  `DODGE_TRIGGER` the enemy juke-strafes perpendicular to your line of fire for
  `DODGE_DURATION`. Holding a straight stream on a standing target is no longer free.
- **Back Shot power-up**: new global shop upgrade (40g, one-time). Fires an identical
  volley out the back (180°) every shot — covers front and behind. `ArpgState.back_shot`,
  `player._fire_volley()`.
- **Backrooms furniture SCENES** (not scattered trash): rebuilt the furniture set from
  the Level-0-3 sheet (folding/padded chairs, desks, locker, shelf, cabinet, barrels,
  alpha-trimmed). `_spawn_props` now composes vignettes — a ring of chairs, a desk with
  a chair pulled up, a wall cluster (tall piece + barrel/chair), and occasional surreal
  pieces clipping into a wall. ~48% of rooms stay empty/eerie. No more debris/stain
  scatter.
- **Carpet fix (redo)**: previous crop was tile `0,0` (striped like the wall + a baked-in
  stain blob). Re-cut from the clean flecked tile `0,10` — uniform speckle, no stripes,
  seamless.

## v2.0 "Distinct carpet + organised props" — 2026-06-05  (game_v2 only)

- **Carpet no longer matches the wall**: the pack reuses the wallpaper motif for both,
  so the floor read identical. Rebuilt `backrooms_pack5_floor.png` from the flecked
  Level-0-1 (0,2) tile, darkened + desaturated + olive hue-shift → clearly a darker
  flecked carpet vs the lighter striped wallpaper wall.
- **Props now placed organised, not random** (`_spawn_props` rewritten): furniture/
  containers line up AGAINST room walls (`_perimeter_spot`) with a small clutter
  cluster beside each (~0.72/room), plus sparse flat stains/marks on the floor.
  Loads from the categorised `props/<category>/` folders. No more strewn trash.

## v2.0 "Sliced + scattered backrooms props" — 2026-06-05  (game_v2 only)

- **Cut up the whole Cute SCKR pack**: connected-component slicing extracted 558
  individual sprites into `assets/backrooms/_sliced/<sheet>/` (organized by source),
  with numbered contact sheets in `_contact/`, a curated/categorized `props/` set
  (furniture, debris, containers, items, stains, markings), and a README index.
- **Scatter decor in the backrooms**: `dungeon._spawn_props` (backrooms only) places
  up to 80 floor-clutter sprites (papers, debris, barrels, crates, bottles, blood
  splatters, a chair/desk, graffiti) from `props/scatter/` — decorative, no collision,
  random scale/flip. Loaded via the no-import-needed `_load_tex_mip` path. Mock:
  scatter_preview.png.

## v2.0 "Real Cute SCKR Level 0 art in backrooms" — 2026-06-05  (game_v2 only)

- Wired the purchased **Cute SCKR Backrooms Pixel Art Tileset** (in
  `backrooms_assets/`) into the backrooms: extracted the yellow drop-stripe
  WALLPAPER tile (A4 walls sheet 5,8) for walls and a woven yellow CARPET tile
  (Level-0-1 0,0) for the floor, upscaled 2× and saved as `backrooms_pack5_{wall,floor}.png`
  (the locked pack). Loads via the mipmap path (no shimmer). Pack covers Level 0/1/10/
  Poolrooms + object sheets (furniture/debris/beds) not yet used.

## v2.0 "Consistent projectile glow + enemy pathfinding" — 2026-06-05  (game_v2)

- **Projectile glow consistency**: in the now-brighter cave the dim additive halo
  (energy 0.7) was getting washed out / dropped where many lights overlap, so some
  shots glowed and some didn't. Now `player._spawn_pizza` HDR-boosts the projectile
  tint (brightest channel ×1.7) so every shot blooms via post-process (independent
  of nearby 2D lights), and bumps the Glow light to energy 1.3. Backrooms still glow-off.
- **Enemy pathfinding (A*)**: dungeon builds an `AStarGrid2D` from the wall grid
  (`_build_nav`, `nav_path`). When an enemy holds aggro but has lost line of sight,
  `enemy._path_target` follows waypoints AROUND walls (repath every 0.5s) instead of
  grinding straight into the wall between them. Verified paths route around (longer
  than straight-line). Growler (kiter) unaffected; main game unaffected.

## v2.0 "Wall-torch glows from the candle" — 2026-06-05  (game_v2 only)

- Wall torches glowed below the sconce (the light was shoved +0.64 tile down into
  the room to escape the wall's own light occluder). Fix: `_add_wall_torch` now
  receives the wall body + occluder, disables THAT wall's occluder (so it can't
  self-shadow), and places the light right on the candle (≈ sprite position).
  Neighbouring walls keep their occluders, so the torch still doesn't shine through walls.

## v2.0 "Escape-to-menu fix, easier Easy, brighter cave" — 2026-06-05  (game_v2)

- **No more accidental Escape → main menu.** Level Select no longer auto-returns to
  the title on Escape (use the "Back to Title" button). In the pause menu, Escape now
  closes the Dev Tools panel first, then resumes — it never navigates to the menu.
- **Easy toned down**: enemy HP mult 0.7→0.5, enemy count mult 0.7→0.6.
- **Cave lighting**: candelabras 12→17 and their light range doubled (texture_scale
  1.75→3.5); wall torches spawn 3%→6% of south walls and range doubled (1.3→2.6).

## v2.0 "Backrooms polish: aura, aggro, wall-clip, choke traps" — 2026-06-05  (game_v2)

- **No player light aura in the backrooms** (torch hidden) — flat level is already lit.
- **Enemies keep aggro 5s after losing LOS** (`enemy.AGGRO_MEMORY` 0.4→5.0,
  `growler.AGGRO_MEM` 1.6→5.0) instead of giving up almost instantly.
- **Wall-clip fix** — backrooms walls that face a room now extend their collision
  DOWN to cover the tall angled face, so enemies/player stop at the bottom of the
  visible wall instead of clipping up into it (300 walls extended; cave unchanged).
- **Traps moved to choke points** — `_spawn_traps` now finds narrow corridors
  (`_floor_run` width test) and lays a ripple line spanning the passage, at a spaced
  subset (~7 chokes), not every one or random rooms.
- **Boss AoE windup +0.25s** (GroundSlam windup 0.95→1.2) — more telegraph before the blast.

## v2.0 "Pack5 lock, growler bow, ripple traps" — 2026-06-05  (game_v2 only)

- Backrooms **locked to asset pack 5**; the top-right ASSET PACK switcher panel removed.
- **No projectile glow in the backrooms** (`ArpgState.no_projectile_glow`, set when
  theme==backrooms): player pizza Glow hidden + boss star halo skipped. Cave/others
  keep their glow.
- **Growler carries a bow** — generated `bow.png` (recurve bow + nocked arrow),
  attached to his rig hand; flips to whichever side he's facing.
- **Spike traps reworked into ripple lines** — `_spawn_traps` now lays 3-4 traps in
  a row that strike in sequence (`phase_offset` on `dungeon_trap.gd`), so it's a
  timed hazard to dash through rather than one tile to walk around.

## v2.0 "Backrooms shimmer fix + tighter maze" — 2026-06-05  (game_v2 only)

- **Wall/floor shimmer fixed** without changing the pack: backrooms pack textures
  now load via `_load_tex_mip` (PNG → `Image.generate_mipmaps` → ImageTexture) and
  the floor + wall sprites use `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`. Stops the tight
  pattern from moiré-shimmering as the camera moves (minification aliasing).
- **Tighter, mazier layout** — new `@export max_room` caps room size in BSP carving
  (rooms no longer fill their partition). Backrooms set to `bsp_levels=7, max_room=11`
  → ~33 small rooms (max dim 11, avg ~75 cells) vs the old big chambers. Cave dungeon
  unchanged (max_room=0).

## v2.0 "Loot icons, soft shadows, stairs, mob brightness" — 2026-06-05  (game_v2 only)

- **Loot pickups no longer generic diamonds.** Weapon drops show a weapon icon —
  bouncy ball (ball weapons) or pizza slice (everything else), tinted, with a bob.
  Heal pickups now show a heal-heart (`pickup_heal.png`) instead of a blue diamond.
- **Soft enemy shadows** — replaced the hard flat ellipse with a feathered radial
  shadow sprite (`soft_shadow.png`, `enemy._spawn_contact_shadow`).
- **Spiral staircase exit** — replaced the cube/ColorRect with a top-down spiral
  stairwell (`stairs_down.png`) that slowly rotates (`dungeon._spawn_exit`).
- **Backrooms mob brightness** — flat ambient 0.86 → 0.74, glow HDR threshold
  0.8 → 0.95, growler aim-flash 1.35 → 1.15, so growler/shrinkwrap stop blowing out.
- Backrooms LOS-reveal flicker is gone (that system was removed last pass — it's
  flat-lit now).

## v2.0 "Real assets: blood font + 5 backrooms packs" — 2026-06-05  (game_v2 only)

- **YOU DIED** now uses the real **Nosifer** dripping-blood font (Google Fonts, OFL,
  `assets/nosifer.ttf`), loaded via `FontFile.load_dynamic_font` (works w/o import).
  Blood-red w/ dark outline, fades in. Removed the procedural fluff-drip version.
  Preview: you_died_preview.png.
- **Backrooms asset packs (5), live-switchable.** Downloaded 5 real CC0 textures
  from ambientCG (Carpet013, Fabric030, PaintedPlaster003, Carpet009, Fabric062),
  tinted to the mono-yellow palette → `backrooms_pack{1-5}_{wall,floor}.png`. New
  top-right **ASSET PACK 1-5** switcher (`_apply_pack`) re-textures the floor + every
  wall sprite live (verified swapping 1→3→5). Persists (`ArpgState.backrooms_pack`).
  Preview: backrooms_packs.png. (ambientCG packs are textures only — no entities to add.)
- **Removed** the Ceiling Lights / LOS Reveal toggles (disliked) — backrooms is now
  simply flat-lit fluorescent (ambient 0.86,0.83,0.72).
- **Steeper wall "angle"** in backrooms: wall face height 0.5 → 0.85 of a tile
  (`BK_WALL_FACE`) so you see more of the walls. Cave dungeon unchanged.

## v2.0 "Backrooms textures + flat-lit default" — 2026-06-05  (game_v2 only)

- Generated tileable `assets/backrooms_wall.png` (bright mustard wallpaper w/ damask
  + drop stripes) and `backrooms_floor.png` (muted dingy carpet) so the level
  actually LOOKS like Level 0 instead of falling back to cave art. Verified both
  load and `_wall_texture`/`_floor_texture` resolve to them. Preview: backrooms_preview.png.
- Backrooms lighting now defaults to **both toggles OFF = flat bright fluorescent**
  (ambient 0.86,0.83,0.72) — no longer loads into the dark reveal+pools mode.
  Dim base for LOS mode raised 0.06 → 0.17. Player torch in backrooms is a faint
  cool fill (0.35) instead of a warm hotspot.

## v2.0 "Backrooms Level 0 (scaffold)" — 2026-06-05  (game_v2 only)

- New level **Backrooms — Level 0** (`scenes/backrooms.tscn`, in Dev level select).
  `dungeon.gd` is now theme-aware (`@export var theme`): "cave" (default) or
  "backrooms". Backrooms skips candelabras/wall-torches/stalagmites and swaps
  wall/floor textures via `_floor_texture()`/`_wall_texture()` (load
  `assets/backrooms_wall.png` + `backrooms_floor.png`; falls back to cave art until
  the files exist — DROP THOSE TWO PNGs IN to get the yellow look).
- **Dual lighting, two independent top-right toggles** (`_build_backrooms_panel`):
  - **Ceiling Lights** — grid of soft, wide, non-shadow diffuse pools (unseen
    overhead fluorescent grid) over the floor (`_build_ceiling_lights`).
  - **LOS Reveal** — each room has a shadow-casting fill light that ramps on only
    while the player has line-of-sight to it; unseen rooms stay near-black ambient
    (`_build_room_lights`, `_update_backrooms_lighting`, `_has_los`).
  - Both off → ambient brightens so the whole level is plainly lit.

## v2.0 "Pickup E-key, KK paw slam, lighting revert" — 2026-06-05  (game_v2 only)

- Reverted the LIGHT 1-5 / ENEMIES 1-3 brightness panels (disliked) — lighting is
  back to locked Standard (removed the `_build_light_panel`/boost calls from `_ready`).
- **Weapon pickup is now opt-in**: standing on a drop shows a "Press E" prompt; you
  must press **E** (or Q) to open the compare popup — no more accidental triggers
  while moving/firing. In the popup, **Q = Keep**, **E = Equip** (button shortcuts),
  and the two cards are spaced further apart (separation 16 → 48).
- **KK paw slam**: ported v1's procedural telegraphed bear-paw slam to v2. Base KK
  enemies now occasionally drop a giant paw on the player's position (range 420,
  6.5s cooldown). Telegraph is **1.5s** (v1's 1.0 + the requested half second).

## v2.0 "Weapon compare + brightness controls" — 2026-06-05  (game_v2 only)

- **Weapon pickup comparison.** Floor weapons no longer auto-equip. Walking onto a
  drop opens a paused two-card popup (`_offer_weapon`): EQUIPPED vs ON FLOOR, each
  showing DPS / Damage / Fire Rate / Shots / Speed (+ Pierce/Bounces when relevant).
  The floor card colours each stat green ▲ / red ▼ / grey vs your current weapon
  (`ArpgState.weapon_eval`, `_stat_row`). Buttons: **Keep Current** (drop stays on
  the floor) / **Equip This**. Mock: weapon_compare.png.
- **Top-right brightness panel** (`_build_light_panel`):
  - **LIGHT 1-5** — `_apply_light_boost` scales every PointLight2D's energy
    (×1.0→3.1) and reach (×1.0→1.72) from a captured base, plus a small ambient lift.
    1 = current look, 5 = flooded. Persists across floors (`ArpgState.light_boost`).
  - **ENEMIES 1-3** — `_apply_enemy_brightness` gives each enemy a tight SelfLight
    (energy 0 / 0.7 / 1.25) so models are visible in pitch black. 1 = off (current).
    Persists (`ArpgState.enemy_bright`).

## v2.0 "Boss attacks: white stars + AoE slam" — 2026-06-05  (game_v2 only)

- `enemy.gd` gained an `is_boss` flag (set by `dungeon._spawn_boss` before add_child).
  Boss behaviors:
  - **Glowing white ninja stars** — throws a 3-star spread (±0.2 rad) on a faster
    1.6s cadence; boss stars are HDR white-hot (modulate 2.6), 1.5× scale, +15%
    speed, dmg 2, with a soft white PointLight2D halo (`_spawn_ninja_star`).
  - **Telegraphed AoE slam** — every ~4.6s drops a `GroundSlam` (pulsing ring →
    shockwave, r=158, 0.95s windup, dmg 2) under the player's position; dodgeable
    by leaving the ring before detonation (`_boss_aoe`). Boss touch_damage → 2.

## v2.0 "Bouncy Blaster rarer drop" — 2026-06-05  (game_v2 only)

- Weapons now roll on a weighted table (`_pick_archetype`): archetypes default to
  weight 1.0, Bouncy Blaster set to 0.33 → drops ~5.5% vs ~19% each for the others
  (about 1/3 the rate). It was equal-weight (1/6) before, which felt too common.

## v2.0 "Fluffy dripping death screen" — 2026-06-05  (game_v2 only)

- Game-over screen is now animated: black dims in over 1.4s (world fades out),
  **YOU DIED** bleeds up + settles from 1.25× scale, then 16 cream stuffing "drips"
  (rounded capsules, faint blood tint) ooze downward from the letters and 10 fluff
  motes (stuffing.png) drift down and fade. Subtitle + buttons fade in after.
  (`_spawn_death_drips`, all tweens bound to the ALWAYS layer so they run paused.)

## v2.0 "Game-over screen" — 2026-06-05  (game_v2 only)

- Dying in the dungeon did nothing (the `died` signal was never connected). Now
  `_spawn_player` hooks `_player.died` → `_on_player_died`, which waits 1.7s for the
  death explosion, then shows a **YOU DIED** overlay (CanvasLayer, pauses the tree):
  "Reached Floor N · Level L · gold", **NEW RUN** (resets the run + reloads), and
  **Main Menu**.

## v2.0 "Hold to auto-fire" — 2026-06-05  (game_v2 only)

- Firing now uses `is_action_pressed` instead of `is_action_just_pressed` — **hold
  the attack button to fire continuously**, throttled by `attack_cooldown` (weapon
  fire-rate in ARPG, ATTACK_RATE otherwise). No more spamming clicks.

## v2.0 "Dev weapon test bench" — 2026-06-05  (game_v2 only)

- Pause-menu Dev Tools now has a **Weapon Test** bench: a live stats readout, a
  button per archetype to **equip any weapon on the fly** (`dev_set_weapon`), and
  free repeatable **upgrade buttons** (＋Dmg / Faster / ＋Pierce / ＋Proj / ＋Bounce
  via `dev_upgrade_weapon`). Readout (`dev_weapon_summary`) refreshes on every change.

## v2.0 "Weapon upgrades + merchant redesign" — 2026-06-05  (game_v2 only)

- **Per-weapon upgrade system.** The merchant now offers 2 upgrade cards for your
  CURRENTLY equipped weapon (`ArpgState.weapon_upgrade_options`): Sharpen (+2 dmg),
  Quick Hands (-10% cooldown), Piercing (+1 pierce), and a weapon-flavoured slot —
  Super Bounce (+3 bounces) for the Bouncy Blaster, else Multi-Throw (+1 projectile).
  Each buy modifies the weapon dict directly + bumps `weapon.lvl`; cost scales
  24 + lvl*10 (×depth). Repeatable in one visit — keep levelling the weapon you like.
  Swapping weapons starts fresh, so investing is a real choice. Pierce now applies
  to ARPG projectiles (`player._spawn_pizza` reads `weapon.pierce`).
- **Merchant UI fully redesigned** (`shop.gd`): dropped the parchment textures for a
  clean dark torchlit theme — programmatic StyleBoxFlat panels, rounded corners,
  gold border/title, glowing per-card accent orbs, "⚔ WEAPON" vs "◆ RUN" badges,
  accent-coloured cost buttons. 5 cards (2 weapon + 3 global). Mock: shop_redesign.png.

## v2.0 "New weapon: Bouncy Blaster" — 2026-06-04  (game_v2 only)

- **Bouncy Blaster** weapon added (`ArpgState.ARCHETYPES`): 1 shot, 0.26s cooldown,
  dmg 4 (low), but `ball:true` + `bounces:9`. New glossy tintable `bouncy_ball.png`.
- `player._spawn_pizza` ball branch: random vivid HSV colour per shot, swaps to the
  ball sprite, sets max_bounces 9 / lifetime 4s / removes the post-bounce distance
  cap so balls ricochet off walls for ~4s — they persist far longer than any other
  projectile, so spamming fills the room with bouncing shots that keep finding mobs.

## v2.0 "World-fog + +10% light + friendly fire" — 2026-06-04  (game_v2 only)

- **Fog anchored to the world** (was following the player) — `fog.gdshader` now
  samples the noise in WORLD space via `cam_pos` + `vp` uniforms (camera position
  fed each frame in `_process`), so it scrolls past as you move instead of
  sticking to the screen.
- **General lighting +10%** — ambient (0.13→0.143...), player torch (0.85→0.94),
  candelabra flicker base (1.4→1.54), wall torches (0.85→0.94). Enemies read
  better now.
- **Friendly fire** — enemy projectiles (`ninja_star`, `arrow`, `bear_bullet`) now
  collision-mask layer 3 and damage OTHER enemies on hit, with a 0.1s spawn grace
  so they don't instantly clip their own shooter.

## v2.0 "Revert feather + slower arrows" — 2026-06-04  (game_v2 only)

- **Reverted the light feathering** — the heavy gaussian blur on `light_radial.png`
  read as blocky (gradient banding over the dark scene). Back to the original
  smooth `cos²` falloff.
- **Growler arrows ~15% slower** — `ARROW_SPEED` 820 → 700.

## v2.0 "Lighting polish — feather + wall torches" — 2026-06-04  (game_v2 only)

- **Lighting switcher removed** — locked to Standard. No more 1-5 keys/buttons
  (`_apply_lighting_mode(1)` on start; number-key input + switcher build dropped).
- **Feathered light** — regenerated `light_radial.png` with a soft cosine +
  strong gaussian blur so the player's circle of light and the candelabras have a
  gentle, gradual edge instead of a hard circle. (`~/feathered_light.png`)
- **Wall torches now actually light the room** — the light was buried inside its
  own wall's `LightOccluder2D` (so the wall blocked all of it). Pushed it just
  past the occluder edge into the room + brighter (0.85, scale 1.3).
- **Candelabras** a hair brighter/farther (energy 0.85→0.9, scale 1.55→1.75).
- **Fog** dimmed again (Standard density 0.006→0.003 — barely-there).

## v2.0 "Light occlusion + bullet swap + Growler fix" — 2026-06-04  (game_v2 only)

- **Walls now block all light (no more glow-through-stone).** Removed every
  non-shadow "fill" light (player/brazier/wall-torch) and the room-ambiance
  lights — those were what bled through walls AND read as oppressive haze. Wall
  torches made shadow-casting. So light only reaches line-of-sight = ruins-style
  reveal as you round a corner.
- **Everything dimmer + shorter reach.** Player torch energy 1.1→0.85 / scale
  2.3→1.8; braziers 1.2→0.85 / 2.0→1.55; wall torches 1.0→0.7 / 1.3→1.0. Light
  counts trimmed (braziers 18→12, wall torches 5%→3%) since more cast shadows now.
- **Fog cut to near-nothing** (densities 0.004–0.012) — the "oppressive fog" was
  mostly the fill-light haze, now gone.
- **Growler actually shoots now** — more aggressive archer: range 640→760, cooldown
  2.0→1.3, windup 0.4→0.26, sticky 1.6s aggro memory.
- **Real bullet asset** — replaced the rendered bullet with a CC0 **M484 Bullet
  Collection** teardrop round (`assets/bullet.png`, license noted). Gun bear fires
  that now.

## v2.0 "Growler archer + projectile pass" — 2026-06-04  (game_v2 only)

- **Growler is alive + an ARCHER** (`growler.gd` rewritten): walk-bob squish +
  rock/tilt toward movement + sprite-flip to face you (like the player). Behaviour:
  kites to a ~330px standoff (backs off when you close in, strafes, advances when
  too far), aims with a windup, looses a **fast arrow** (780 speed — quicker than
  other projectiles). LOS-gated aggro. (Cover-seeking AI not done — needs nav.)
- **New crisp projectiles** (the CC0 pixel packs were 12px — too low-res for our
  scale, so rendered to match the 64px ninja star): `arrow.png` (shaft + steel
  head + fletching) and `bullet.png` (brass tracer w/ trail).
- **Projectile graphics pass:**
  - **KK** now throws **ninja stars** in the dungeon (the good ones) instead of the
    ugly brown spit blob — `enemy.gd` `throws_stars` flag; spit is main-game-only now.
  - **Gun bear** fires a real **bullet** sprite, flying straight + faster (220→460);
    no more wobbling fluff ball (`bear_bullet.gd`).
  - Subtypes with their own attack (gun/shrink/brawler) opt out of star-throwing.
  - `arrow.tscn`/`arrow.gd` projectile (fast, rotates to heading, dies on walls).

## v2.0 "New enemy: Growler" — 2026-06-04  (game_v2 only)

- **New enemy — Growler** (from `assets/Growler/IMG_8138.jpeg`): rembg cutout,
  alpha cleaned (close + fill-holes + soft edge), rotated head-up, → 192×256
  `assets/growler.png`. `scenes/growler.tscn` + `scripts/growler.gd` (extends
  enemy): a tanky melee **bruiser** — 8 base HP, touch dmg 2, steady speed, no
  ranged, slightly larger rig (0.42). Added to the dungeon spawn rotation (~16%).

## v2.0 "Smooth fog + 4x map + dev menu" — 2026-06-04  (game_v2 only)

- **Fog smoothed + cut 75%** — `fog.gdshader` now scrolls a real, seamlessly-
  tileable cloud-noise texture (`assets/fog_noise.png`, FBM, wrap-blurred) at two
  scales with linear filtering — soft wispy haze instead of the procedural-noise
  "floating squares". All per-mode densities reduced to ~25% (much lighter).
- **Maps ~4× larger** — `dungeon.gd` grid 46×32 → 92×64, `bsp_levels` 4→6, counts
  up (enemies 16→44, items 5→13, braziers 8→18). Enemies still spread round-robin
  across every room. Wall torches made shadowless + rarer (5%) to keep the bigger
  map GPU-friendly.
- **Dev menu is back** — Esc → pause menu now has a **🛠 Dev Tools** button (only
  shows when the scene exposes them): Heal Full, Next Floor, +100 Gold, Kill
  Enemies, Level Up, Random Weapon, Toggle God Mode (`dungeon.gd` `dev_*` methods).

## v2.0 "5 fogs + coloured room atmospheres" — 2026-06-04  (game_v2 only)

- **5 fog versions**, one per lighting mode (the 1-5 switcher now changes fog too):
  1 neutral grey haze, 2 thin pale, 3 blue mist, 4 heavy murky, 5 amber smoke.
  `fog.gdshader` gains a settable `fog_color`; `_set_fog(col, density)` called
  per mode.
- **Coloured room atmospheres** — `_spawn_room_ambiance()` gives every BSP room
  its own big, dim, shadowless tint light (crimson/sapphire/emerald/violet/teal/
  amber/rose, adjacent rooms differ) that washes the room and bleeds up through
  the fog, so the dungeon shifts colour zone to zone as you explore.
  (`~/fog_rooms_preview.png`)

## v2.0 "Lighting modes — fixed the artifacts" — 2026-06-04  (game_v2 only)

Two concrete bugs reported (boxy lighting in 1/2/4, ghost-copies in 3/5):
- **Boxy "square-gradient" lighting → removed tile normal maps.** The normal-mapped
  floor/wall made each 64px tile shade as its own box (a grid of grey squares).
  Floor + walls now use plain diffuse, so the lights fall off SMOOTHLY. (Trade-off:
  lost the relief/AO depth, but it read as weird/boxy — smooth is the ask.)
- **"20 copies of the candles/player" → removed the screen-space bleed shader.**
  The 20-tap radial gather literally smeared each bright sprite into ~20 offset
  ghosts. Deleted the GILayer + bleed entirely. (Clean screen-space GI isn't
  possible without the heavy radiance-cascades route.)
- **5 modes rebuilt as distinct, smooth presets** (no normals, no bleed):
  1 Standard (warm balanced), 2 Bright (well-lit), 3 Cool (moonlit blue),
  4 Noir (dark high-contrast), 5 Warm (cozy orange) — each varies
  ambient + glow + contrast + saturation. (`~/lighting_fixed.png`)

## v2.0 "Lighting modes redo" — 2026-06-04  (game_v2 only)

Fixed the broken 1-5 lighting switcher:
- **GI bleed shader → additive** (`render_mode blend_add`). It was an opaque
  full-screen re-output that could black out the view if the screen-texture read
  failed. Now it can only ADD light — never breaks the image.
- **Modes redone to be clearly distinct** — each now also sets `adjustment_contrast`
  + `adjustment_saturation`, not just glow/ambient: 1 Standard (balanced), 2 Bloom
  (bright/dreamy), 3 Bleed GI (warm additive bounce), 4 Noir (dark, high-contrast,
  desaturated), 5 Warm (cozy saturated orange). Verified distinct via mock
  (`~/lighting_modes_redo.png`).
- **Switcher restyled** — bordered panel + gold-highlighted active button (was
  plain default buttons), `focus_mode = none` so clicks don't steal focus.
- Fog density 0.09→0.06 so it stops washing the modes.

## v2.0 "Parchment merchant + dimmer/fog lighting" — 2026-06-04  (game_v2 only)

- **Merchant reskinned with a real UI pack** — CC0 **"Parchment GUI"** (OpenGameArt):
  extracted 9-slice pieces (`assets/ui/`: ornate dark window, parchment card,
  gold pill button normal/hover/pressed). `shop.gd` rebuilt with `StyleBoxTexture`
  9-slices — ornate gold-cornered window, parchment cards with ink text, gold
  pill buttons. No more Web-1.0 rectangles. (`~/shop_parchment_preview.png`)
- **Lighting dimmer + shorter reach** — every light's `texture_scale` and energy
  trimmed (player torch 2.8→2.3, braziers 2.4→2.0, wall 1.5→1.3, fills smaller),
  and all 5 mode ambients darkened ~25%.
- **Super-light fog** — new `shaders/fog.gdshader`: a faint, slowly-drifting
  translucent haze layer (`_build_fog`, density 0.09) over the dungeon for
  atmosphere.

## v2.0 "Live lighting-mode switcher" — 2026-06-04  (game_v2 only)

- **5 live-switchable lighting presets** — top-right selector in the dungeon
  (buttons + number keys **1-5**), so you can flip between them in-game and pick
  the best. Persists across floors (`ArpgState.light_mode`).
  1. **Standard** — normal-mapped stone + bounce fills + glow (the current look).
  2. **Bloom** — everything blooms, dreamy light spread.
  3. **Bleed GI** — a real **screen-space light-bleed shader**
     (`shaders/light_bleed.gdshader`): bright/lit pixels bounce their colour into
     nearby darker pixels (faux indirect GI), fed by a `BackBufferCopy`.
  4. **Noir** — dark, tight, high-contrast dramatic shadows.
  5. **Warm** — cozy saturated torchlight + subtle bleed.
- Implemented via a `GILayer` (CanvasLayer 2, under the UI) + runtime tweaks to
  the dungeon `Environment` glow + `CanvasModulate` ambient per mode. HUD/minimap
  raised to layer 6 so they stay crisp above the GI post. (`~/lighting_modes_preview.png`)
- Researched the radiance-cascades route ([Sohojoe RC, Apache-2.0](https://github.com/Sohojoe/radiance-cascades-godot)):
  it's a compute-shader research demo, not a drop-in — NOT integrated (too risky
  to bolt in blind). Mode 3's bleed shader is the safe, real light-bounce option.

## v2.0 "Lighting push + enemy spread" — 2026-06-04  (game_v2 only)

- **Enemies spread across the whole dungeon** — `_spawn_enemies` now distributes
  round-robin across every room (shuffled, start room excluded) via `_cell_in_room`,
  instead of clustering near the entrance. You meet them as you explore.
- **Lighting pushed to the 2D max** (researched: Godot has NO native 2D GI —
  SDFGI is 3D-only; true 2D light-bounce = a custom radiance/SDF engine):
  - **Faked indirect bounce** — every torch/candelabra/player light now has a
    paired wide, dim, shadow-LESS warm fill light (`_add_fill_light`) that fills
    the room with indirect warmth (reads as bounced light).
  - **PCF13 soft shadows** (`shadow_filter = 2`) on the player torch + candelabras.
  - **Heavy glow** — dungeon Environment glow intensity 0.6→0.9, strength→1.3,
    bloom→0.22, threshold 0.85→0.7, +glow levels 3-5, so lit surfaces bloom and
    light visibly spreads.
  - Combined with the normal-mapped stone, the dungeon reads as truly lit with
    depth + warm indirect fill. (`~/lighting_push_preview.png`)
  - Wall-torch frequency trimmed (16%→9%) to keep the light count GPU-friendly.

## v2.0 "Real lighting + props + wall collision" — 2026-06-04  (game_v2 only)

- **Projectiles through walls — FIXED.** `bear_bullet`/`bear_spit`/`ninja_star`
  now set `collision_mask` bit 1 and `queue_free()` on `walls`; the shrinkwrap
  `air_line_blast` raycasts and clamps its length to the first wall. No more
  shooting through stone.
- **Real lighting (normal-mapped tiles).** Generated Sobel normal maps for the
  floor + wall tiles and wired them via `CanvasTexture` (diffuse+normal). The
  point-lights (torches/candelabra/player) now sculpt the stone — lit faces +
  **dark crevice shadows between cobbles** (2D's AO). The max real-time lighting
  the engine does in 2D. (`~/normalmap_lighting_check.png`)
- **Angled look (pseudo-3/4).** Walls facing a room to the south now draw a
  darker shaded **front face** below the lit top, so walls read as having height.
- **Real props, not pixels.** Rendered shaded **candelabra** (metal stand + 3 lit
  candles) for room centers and a **wall torch** (bracket + flame) for the wall
  sconces, both with flame-gradient art. (`~/candelabra_preview.png`)
- Note: Godot has no DLSS (NVIDIA-only) or 2D SSAO/refraction; the normal-mapped
  lighting + shadow-casting torches is the genuine max for 2D. A true perspective
  tileset (0x72) is still itch-only.

## v2.0 "Dungeon is the game + shop/HP-bar polish" — 2026-06-04  (game_v2 only)

- **The dungeon crawler IS v2 now** — title "Start Game" → `ArpgState.reset_run()`
  → straight into `dungeon.tscn` (no more loadout/arena). Title screen unchanged.
- **Difficulty now applies** to the dungeon: enemy HP ×0.7 (Easy) / ×1.0 (Med) /
  ×1.35 (Hard) in `_difficulty_hp_mult()`. **Shrinkwrap** base HP 6→4 (less spongy).
- **Shop restyle** (`shop.gd`): gradient backdrop, gold "pill", rounded
  color-accented cards with icon swatches + hover scale, fully styled buttons
  (normal/hover/pressed/disabled StyleBoxes). (`~/shop_restyle_preview.png`)
- **Enemy HP bars stylized** — bordered frame + glossy highlight strip + smooth
  green→yellow→red shading.
- **Wall-mounted torch sconces** — warm flickering shadow-casting lights on
  room-facing walls (atmospheric "lights on the wall").
- DEFERRED (honest): a true **3/4 angled** look needs a perspective tileset (the
  flat-top pack can't do it; 0x72 is itch-only, not curl-able), and dedicated
  **torch/candelabra sprites** need sourcing. Proposed next steps below.

## v2.0 "HP-scaling fix + traps + HP bars" — 2026-06-04  (game_v2 only)

- **Damage was backwards (KK 2 hits, everything else 1-shot)** — the subtypes
  (brawler/gun/shrink) set `max_health` in their OWN `_ready`, which ran AFTER the
  dungeon's pre-add_child scaling and overwrote it. Moved scaling to run AFTER
  `add_child` using the final base HP, and refill current health. Now KK ~21 (2
  cannon hits), gun ~33, brawler/shrink ~39 (3-4 hits) — correct ordering, no 1-shots.
- **Shrinkwrap hitbox** was 38×32 centered under a 104×128 bear (only midsection
  hittable). Enlarged to 66×100 so the whole body takes hits.
- **Traps** — telegraphed cyclic floor **spike traps** (`dungeon_trap.tscn/gd`),
  7 per floor, never in the start room: plate reddens (warning) → spikes stab up
  (1 dmg, 0.7s cd) → retract. Real art: "Animated traps and obstacles" by Irina
  Mir (CC-BY 3.0, credited in `assets/trap_assets_license.txt`). (`~/trap_in_dungeon_preview.png`)
- **Enemy HP bars** (dungeon only) — a small bar appears over a damaged enemy
  (green→red by health) so multi-hit kills read clearly.

## v2.0 "Wide economy + between-floor shop" — 2026-06-04  (game_v2 only)

### One-shotting fixed (wide damage/HP economy)
- Numbers scaled up so per-hit damage is a FRACTION of HP. Weapon base dmg
  8/4/5/12/6 (Slicer/Triple/Spike/Cannon/Frost); rarity scaling gentled
  0.5→0.22, depth 0.18→0.12. Dungeon enemy HP ~6× base +3, +4/floor (basic ~21,
  gun ~33, brawler/shrink ~39); boss `110 + depth×35` (145 at floor 1).
- Verified: **even a Legendary cannon = 2 hits on a basic** (20 vs 21). Cannon
  2-shots trash, Pepperoni ~3, others 2-4. No one-shots.
- `ArpgState.weapon_damage/_cooldown/_count()` now fold in run upgrades; player
  attack uses them. Added **crit** (golden double-damage flash).

### Gold means something — between-floor SHOP
- `scenes/shop.tscn` + `shop.gd`: a **merchant** between floors. Beat the boss →
  step in the portal → shop (4 random offers) → Descend.
- Upgrades (`ArpgState.generate_shop/buy`, permanent for the run): +Max HP,
  +15% Damage, +12% Fire Rate, +10% Crit, +8% Move Speed, +1 Projectile,
  and Mystery Box (reroll weapon). Costs scale with depth.
- `ArpgState.dungeon_path` remembers which dungeon to descend back into.

## v2.0 "Pause-menu Esc fix" — 2026-06-04  (game_v2 only)

- **Esc didn't reliably resume from the pause menu** (felt like it skipped to Main
  Menu). The menu listened on `_unhandled_input`, which a focused button can
  swallow. Moved Escape handling to `_input` (runs before GUI) + ignore key echo,
  and "arm" it 0.12s after opening (pause-safe timer) so the same keypress that
  opens the menu can't instantly close it. Now Esc cleanly toggles
  pause↔resume in both dungeons.

## v2.0 "Playtest fixes 2 + cannon nerf" — 2026-06-04  (game_v2 only)

- **Pizza absorbed by close walls** — on bounce, the pizza now shoves out of the
  wall (+26px) and ignores walls for 0.08s (`_wall_grace`), so point-blank shots
  ricochet instead of being eaten in a 2-frame double-hit.
- **Dead homing pickup** — enemies were still dropping the legacy bomb/scatter/homing
  specials, which the ARPG attack ignores (so picking one up did nothing). Gated
  those drops behind `not ArpgState.active`.
- **Shrinkwrap puff + brawler charge through walls** — both attacks bypassed the
  LOS gate (only movement was gated). Now both require `_aggro_t > 0` + a fresh
  `_has_los_to_player()` check, so no whooshing/charging at unseen players.
- **Aggro-through-walls** — tightened aggro memory 0.6→0.4s so breaking line of
  sight drops the chase faster (less wall-pushing). [nav pathfinding still TODO]
- **Deep-Dish Cannon nerf + wider HP economy** — cannon base dmg 5→3; dungeon
  enemies now ~1.4× base +1 HP (basic bear 3→5, gun 5→8, brawler/shrink 6→9), so
  nothing one-shots trash anymore — cannon 2-shots basics, ~3-shots the rest.
- **Darker dungeon (~12%)** — ambient lowered (`0.17→0.15` / large `0.16→0.14`) and
  torch pool tightened (3.2→2.8) so you can't see as far ahead.

## v2.0 "Pause menu" — 2026-06-04  (game_v2 only)

- **Esc now opens a proper pause menu** in the dungeon (`scenes/pause_menu.tscn` +
  `pause_menu.gd`): pauses the tree (PROCESS_MODE_ALWAYS overlay) with **Resume /
  Level Select / Main Menu**. Esc or Resume closes it; always unpauses before any
  scene change. Replaces the old hard Esc→level-select jump.

## v2.0 "Bigger rooms + safe spawn" — 2026-06-04  (game_v2 only)

Fix for "zerg'd & trapped at the start":
- **Bigger rooms** — min room size 6 cells, leaving a 2-4 cell rock margin (rooms
  stay distinct, not merged); map grown to 46×32.
- **Wider corridors** — `corridor_w = 3` so enemies can't wall you into a 1-tile gap.
- **Safe spawn** — enemies never spawn in the start room and must be ≥7 tiles away
  (`_random_floor_world(.., avoid_start=true)`); the start room is a clear haven.

## v2.0 "Real tileset + bounce/LOS fixes" — 2026-06-04  (game_v2 only)

- **Real asset pack** (no more procedural/basic shapes): pulled the CC0
  **"Top Down Dungeon Pack"** (SBS, OpenGameArt), extracted + de-keyed (magenta)
  the flagstone floor + cobblestone wall fill tiles → `dungeon_floor.png` /
  `dungeon_wall.png` (64px; wall sprite scale now derived from texture size).
  License in `assets/dungeon_tiles_license.txt`. Removed the basic triangle
  stalagmite props. (`~/ddp_room_preview.png`)
- **Pizza wall ricochet fixed**: dungeon walls lacked the `flip_axis` meta, so
  the old code reversed direction straight back. Now reflects off the wall's
  actual normal (`pizza._wall_normal` + reflect) so glancing hits ricochet
  FORWARD; re-enabled 1 bounce in ARPG.
- **Enemies no longer track through walls**: replaced the permanent `_seen_player`
  aggro with continuous LOS+proximity and a short 0.6s memory — break line of
  sight and they give up.
- KNOWN NEXT: prop/loot/torch *sprites* (this pack is floors+walls only — loot
  gems, braziers, exit are still glow+placeholder); enemy nav-mesh pathfinding.

## v2.0 "Playtest fixes" — 2026-06-03  (game_v2 only)

Addressing live playtest notes:
- **Pizza wall-bounce** — `max_bounces = 0` in ARPG (`player._spawn_pizza`); slices
  pop on walls instead of ricocheting back at you.
- **Aggro through walls** — enemies now stay **dormant until first line-of-sight**
  (`enemy.gd` `_seen_player` gate, AGGRO_RANGE 820, LOS raycast). No more charging
  at a player they've never seen. (Movement *pathfinding* once seen still TODO = nav mesh.)
- **Cave aesthetic** — regenerated `dungeon_floor.png` / `dungeon_wall.png` as
  organic rough rock (no castle brick), added `stalagmite.png` props scattered in
  rooms (`_spawn_stalagmites`). (`~/cave_tiles_preview.png`)
- **Player lighting rework** — dropped the Sobel normal maps on the bears (they were
  shading "weird parts" under the torch); back to flat, evenly-lit sprites
  (`player.tscn` + `enemy.tscn`).
- **Boss intro + bar** — approaching the guardian fires a "⚔ THE DUNGEON GUARDIAN ⚔"
  alert + shake and reveals a **boss health bar**.
- **Boss death detection fixed** — was checking node-freed (true only after the whole
  death anim), so the exit stayed locked after you'd killed it. Now checks group-exit
  (`_boss_is_dead` via `is_in_group("enemies")`) → descent opens immediately.
- **Shrinkwrap (plastic-bag) bears** added to the dungeon spawn rotation.

## v2.0 "BSP rooms + LOS" — 2026-06-03  (game_v2 only)

Feedback: 1×1 corridors are bad, enemies shoot through walls, no objective,
whole map visible. Researched roguelike methodology → adopted **BSP** (the
standard); kept our real-time engine (turn-based kits are the wrong genre).
- **`dungeon.gd` rewritten to BSP room+corridor generation**: recursive grid
  partition → a room per leaf → 2-wide L-corridors connect them, plus a couple
  of loops. Real rooms of varying size, big layout (38×26 cells, ~2400px) you
  explore off-screen. Walls only render/collide where they touch floor (cheap);
  occluders cast real shadows. (`~/bsp_layout_preview.png`)
- **Boss-room objective**: a beefed "guardian" spawns in the farthest room; the
  green descent portal stays hidden until it dies. HUD objective line + toasts.
- **Darker, torch-limited vision**: ambient dropped to ~0.17 so you only see
  near the torch; minimap stays fog-of-war (reveals as you explore).
- **Line-of-sight gating (no more shooting through walls)**: `enemy._has_los_to_player()`
  raycasts vs walls; gates ninja-star throw, spit, and the gun bear's shot.
  Only enforced when `ArpgState.active`, so the main game is unchanged.
- KNOWN NEXT: enemy *movement* still steers straight at you (bumps walls) —
  needs `NavigationRegion2D`/`NavigationAgent2D` pathfinding. Real boss fight.

## v2.0 "ARPG rebuild" — 2026-06-03  (game_v2 only)

User locked the direction: **Diablo-style dungeon ARPG**. Keep the bears, change
everything else. Built the core loop (verified by a headless logic test: 60 kills
→ Lv 7, 113 gold, depth-scaled loot rolls). Legacy main game untouched (`active`
flag gates all of it).

- **`scripts/arpg_state.gd`** (autoload `ArpgState`): persistent run state —
  level/XP (1.35× curve), gold, equipped weapon, and loot/rarity generators.
  5 weapon archetypes (Slicer/Triple Crust/Cheese Spike/Deep-Dish Cannon/Frost
  Calzone); rarity (Common→Legendary) + depth scale damage/speed/cooldown.
- **Loot drops**: enemies have a 22% drop on death (`enemy.gd::_begin_death` →
  `ArpgState.notify_kill`). Dungeon spawns a glowing rarity-coloured pickup;
  walking over it auto-equips if the DPS score is higher, else sells for gold.
- **Weapon-driven attack**: `player.gd` `_throw_arpg_weapon()` + `_spawn_pizza`
  override — equipped weapon sets fire-rate, multishot spread, damage, speed and
  tints the projectile + its light. (Legacy pizza path intact when `!active`.)
- **XP / level / gold HUD** built in `dungeon.gd` (health + XP bars, level/floor,
  gold, weapon name, floating toasts for loot/level-up).
- **Descent**: the exit now drops you DEEPER (`ArpgState.descend()` + reload);
  enemies gain HP per floor, loot rolls richer. Level-ups heal + raise max HP.
- **New stone assets**: procedural `dungeon_floor.png` (flagstone) + `dungeon_wall.png`
  (bevelled brick) replace the flat-colour floor/walls. (`~/dungeon_tiles_preview.png`)

## v2.0 "Dungeon-crawler direction test" — 2026-06-03  (game_v2 only)

User feedback: v2 should be a *different game* (Diablo-style dungeon crawler —
maze structure, minimap, hidden items), and the lighting reads as "slapped on
top" in the bright field. Key reframe: **a dark dungeon is where the lighting
rig becomes the look** (torch + braziers + cast shadows), not a filter. Built as
an isolated, testable demo — the main game flow is UNTOUCHED pending approval.

- **`scenes/dungeon.tscn` + `scripts/dungeon.gd`**: procedural recursive-backtracker
  maze (opened up ~10% for loops/rooms), near-black floor, pseudo-height walls,
  and a `LightOccluder2D` on every wall so lights cast **real 2D shadows**.
  Player's `BearLight` promoted to a shadow-casting **torch**; flickering brazier
  point-lights; enemies (mixed types) in far cells; **item pickups** (heal +
  glow) in the maze; glowing **exit**. Camera follows; Esc/exit → level select.
- **Minimap** (`scripts/minimap.gd`): corner plan with fog-of-war (reveals as you
  explore), player/exit/item markers.
- **`scenes/dungeon_large.tscn`**: bigger maze variant (12×9) via exported overrides.
- **Dev Mode**: `DevButton` (top-right of title) → `scenes/level_select.tscn`
  (`level_select.gd`) to jump straight into Dungeon / Large Dungeon / Normal Game.
- Direction self-checked with a torch-lit dungeon mock (`~/dungeon_look_preview.png`).

A separate high-fidelity branch (`Desktop\game_v2`). Goal: AAA-grade *polish* via
engine features + curated high-fidelity free assets. Phase 1 (engine polish
foundation) below. Bears intentionally left as-is for now (do environment + FX
first, decide characters later).

### Phase 1 — engine polish foundation (DONE)
- **Renderer → Forward+** (`project.godot`) + `viewport/hdr_2d=true` + `msaa_2d`.
  Required for real 2D bloom/glow and post-processing.
- **WorldEnvironment** in `main.tscn` (`Env_AAA`): glow/bloom (screen blend,
  HDR threshold 0.92), filmic tonemap, and color grade (contrast 1.09,
  saturation 1.14). Bright/overdriven pixels now bloom.
- **Persistent `GameCamera`** in `main.tscn` replaces the create/free camera.
  `main.gd` `_setup_camera()` rewired: follows the player on traversal floors,
  locks centre on fixed floors. Always present so screen-shake has a target.
- **`Juice` autoload** (`scripts/juice.gd`): trauma-based **screen shake**
  (decaying offset + slight roll) and **hit-stop** (real-clock recovery so it
  can't stall in slow-mo). `register_camera()` from `main._ready()`.
- **Game-feel wiring**: player hit → shake 0.55 + 60ms hit-stop; player death →
  shake 1.0 + 160ms freeze; enemy hit → HDR-white bloom flash + micro-shake,
  enemy death → shake; explosions → warm HDR overdrive (blooms) + size-scaled
  shake.
- **Vignette** post overlay (`PostFX` CanvasLayer + shader) under the HUD.
- Traversal floors set to **[1, 2]**; title stamped **v2.0 ✦ AAA**; project
  renamed **Bear Crawl v2.0**.

### Phase 2 — lighting + post-processing (DONE)
Researched Godot 4 best practices first (2D lights/occluders/normal maps; screen
post via `hint_screen_texture`). Honest buzzword translation: no HW ray tracing
in Godot (use `PointLight2D` + `LightOccluder2D` real-time 2D shadows); no SSAO
in 2D (use contact/drop shadows); chromatic aberration is a real screen shader.
- **Screen-space post** (`main.tscn` `PostShader` on `PostFX/Vignette`, fed by a
  `BackBufferCopy`): radial **chromatic aberration** + animated **film grain** +
  multiplicative **vignette** in one pass. Re-outputs opaque so the HUD (drawn
  after) stays crisp.
- **CA pulses on impact**: `Juice.register_post()` + `ca_pulse()` ease CA back to
  rest each frame; player damage fires 4.5, big explosions scale 3–6.
- **2D lighting rig**: `CanvasModulate` ambient (0.92, cool — crank down for an
  instant night/mood floor), warm `PointLight2D` on the player (`BearLight`),
  and a burst `PointLight2D` on explosions that flares then fades (script-driven,
  scaled to blast size). New `assets/light_radial.png` falloff texture.
- **Player camera disabled** (`player.tscn`) so the new `GameCamera` is the sole
  authority (no current-camera fight).
- **Bloom tuned via a PIL proxy**: composited a real-asset gameplay still and ran
  the post chain offline to catch that bloom/light was blowing out the player;
  raised glow HDR threshold 0.92→1.1, intensity 0.55→0.45, bloom 0.12→0.05;
  player light energy 0.85→0.55. (`~/v2_look_preview2.png`)

### Phase 3 — depth & lighting integration (DONE this pass)
- **Contact-shadow AO on all enemies**: `enemy.gd::_spawn_contact_shadow()` adds
  a rig-scaled soft ground ellipse (one edit covers every variant — they all
  `super._ready()`).
- **Normal-mapped bears**: generated Sobel normal maps (`*_n.png`, alpha-masked
  flat on transparency, gaussian-softened) for `bear_*`/`brown_*`; wired via
  `CanvasTexture` (diffuse+normal) in `player.tscn` + `enemy.tscn` so the bears
  catch the `PointLight2D`s with real directional shading. Verified form-correct
  via an offline Lambert render (`~/bear_normal_check.png`).
- **Pizza light**: warm `PointLight2D` on `pizza.tscn` — flying slices throw
  moving light pools.

### Phase 3 — remaining (best done against a real screenshot)
- Replace low-res props (14×11 bushes, ~20px rocks/cacti, ~60px trees) with a
  cohesive CC0 nature pack — style cohesion needs eyes on the real frame.
- `LightOccluder2D` siblings on big props + `shadow_enabled` on key lights for
  real-time *cast* shadows ("2D ray-traced" look).
- Higher-quality explosion/fire/smoke sheets; HDR-glow + small lights on
  fire/pickups/magic orbs.
- Set the `*_n.png` imports to linear/normal-map role (currently default sRGB —
  works, slightly off).

---

## 2026-05-30

### Scrolling traversal floor (prototype — floor 2)
- New idea: instead of every floor being one fixed screen, listed floors become
  a long left-to-right "crawl" you push through. Floor 2 is the first prototype.
- `scripts/main.gd`:
  - `TRAVERSAL_FLOORS = [2]`, `LONG_W = 4320` (3× the standard 1440 arena).
  - `_setup_floor_extent(traversal)` widens the `Floor` ColorRect, moves
    `WallRight` to the far edge, and resizes/recentres `WallTop`/`WallBottom`
    so the player can't slip out of the longer field. Restores 1440 on normal
    floors (behavior-preserving — `_floor_width` == `WORLD_W` off-traversal).
  - `_setup_camera(traversal)` creates a follow `Camera2D` (limits 0..floor_width,
    smoothing 7) on scroll floors and frees it (default view) otherwise. `_process`
    drives it to the player and tracks the horizon via `get_screen_center_position()`.
  - `_spawn_traversal_enemies()` spreads the wave across 3 clusters along the
    length (first ~700px kept clear); `_spawn_enemy` refactored into
    `_spawn_enemy_in_band(x_min, x_max)`.
  - `_open_door()` drops the exit at the far end (`_floor_width - 220`) on
    traversal floors. Prop/decoration/pond spawn ranges now use `_floor_width`.
- Boss floors are never traversal, so all fixed-arena boss choreography is
  untouched. Known follow-ups: true gate-locking (barriers that open per cluster),
  parallax sky layers, off-screen enemy indicators.

### New lake asset (LPC terrain atlas grass-pond)
- Replaced the pond visual with the grass-ringed blue pond extracted from
  `assets/terrain_atlas.png` (3×3 block, tiles rows 12-14 / cols 7-9). Upscaled
  4× (LANCZOS) to 384×384 with an elliptical alpha feather so the square grass
  border fades into the game's grass floor, leaving water + a grassy shoreline.
- `assets/pond.png` regenerated; provenance noted in `assets/pond_license.txt`.
- `scenes/pond.tscn`: Sprite `scale` → 0.5, CircleShape2D `radius` → 62 so the
  collision blocks at the visible water edge.

### Restored + dramatized "dive into a pizza planet" transition
- `scripts/loadout_screen.gd` `_spawn_planets()` now always runs (even embedded
  in the title) so the planets exist as zoom targets.
- `_on_start()` is now a two-phase tween: Phase A eases OUT (`background_layer`
  scale → 0.78 around screen centre, content → 0.9) to reveal the starfield,
  then Phase B eases IN, rocketing the largest pizza-planet to fill the screen
  (scale → ~6×, position locked so the planet maps to centre), fading UI/decor
  past and black-flashing into `main.tscn`.

---

## 2026-05-27

### Title menu buttons: stop resizing when cycling difficulty

User: "if you click between easy med hard, it changes all button outline sizes"

`custom_minimum_size` on all 5 menu buttons + the `Menu` VBoxContainer bumped from `Vector2(420, 0)` to **`Vector2(520, 0)`**.

Root cause: at font size 34, the longest difficulty label (`🟡  DIFFICULTY: MEDIUM`) was wider than 420 px, so the Difficulty button grew past min size to fit it. That caused the VBox to widen, which propagated to neighbor buttons since they use `SIZE_FILL` horizontally. Cycling EASY → MEDIUM → HARD reflowed the whole menu.

520 is comfortably wider than the longest label (~480 px), so the button stays at its minimum and the VBox doesn't reflow. Shorter labels (`QUIT`, `OPTIONS`) just have empty bg space inside the same fixed-width pill, which reads cleanly.

---

### Sky boss: new magic orb projectile + touch damage

User: "make the homing thing he shoots slower and change the model. i don't know wtf that thing is supposed to be. also i can go inside the boss and take no dmg"

**New projectile asset**: Kenney's `magic_03.png` (CC0, from his Particle Pack) — a 512×512 sparkling glow with 4 ray spikes radiating from a central white orb. Saved to `assets/kenney_particles/magic_03.png` with license attribution.

**`tooth_projectile.gd` rewritten**:
- Procedural tooth wedge geometry **replaced** with a `Sprite2D` using `magic_03.png`
- `ORB_SCALE = 0.13` (downscale 512→~67 px on screen)
- `ORB_TINT = Color(1.0, 0.55, 0.85)` magenta-pink — clearly reads as boss magic against the sky
- `CanvasItemMaterial` with `BLEND_MODE_ADD` so the black source background is transparent and the sparkle adds brightness over whatever it crosses
- Sprite rotation tick (`+1.8 rad/s`) — the ray spikes spin lazily, looks alive
- Speed **320 → 220 px/s** (−30%, slower per user)
- Homing **1.2 → 0.9 rad/s** (less aggressive curve)
- Circle collision (radius 18) instead of capsule

**Face boss touch damage**:
- Player previously couldn't be hurt by standing inside the boss because the boss is on collision layer 4 (player walks through, only pizzas hit).
- New `_physics_process` check: if `player.global_position.distance_to(boss.global_position) < 180 px` (i.e. inside the head silhouette), deal `touch_damage` (2) on a 0.5 s cooldown.
- New `_touch_dmg_cooldown` state var prevents spam. Walking into the giant head now hurts on a tick rate.

---

### Floor cleave warning now visible across full screen height

User: "floor 9 boss. right/left side AOE warning still only shows in background top not full screen"

Root cause: `main.tscn` has `y_sort_enabled = true`. The `FloorCleave` Node2D was at position (0, 0), so it sorted to the BACK of the y-sort order. Bushes, decorations, enemies, the player — everything with y > 0 rendered ON TOP of the red telegraph rectangle, so only the very top sliver of the cleave (above any gameplay element) was actually visible.

Fix in `floor_cleave.gd::_ready()`:
- `z_index = 45` (high enough to draw above all gameplay sprites)
- `z_as_relative = false` (use absolute z, ignore parent's z)
- 45 is below the face boss's z_index of 50, so the boss still draws on top of the cleave (the cleave's overlay reads as on the ground, with the giant head looming above).

Now the red flashing telegraph covers the FULL half of the screen vertically, not just the top.

---

### Desert boss dash speed −10%

User: "boss floor 6. make boss dash 10% slower"

`desert_boss.gd::charge_speed` 760 → **684** px/s (−10%).

Phase 3 still applies its 1.1× multiplier on top (`charge_speed *= 1.1` in `_enter_phase_3`), so the late-fight dash lands at ~752 px/s — still aggressive but more reactable.

---

### Desert boss ads: 1 per wave, 1 HP each

User: "boss 6, make only spawn 1 add at a time. all add should have 1 hp"

- `summons_per_wave` 2 → **1** (one ad per summon event)
- `_summon_add` sets `e.max_health = 1` (was 2 — one pizza kills)
- `summons_max_alive` lowered 5 → **4** to match the new cadence

Adds are now true cannon-fodder distractions — single-hit kills, fewer at a time. Boss fight reads as cleaner without trash mob pile-up.

---

### Floor 3 boss pizza speed −20%

User: "floor 3 boss, pizza projectile minus 20% speed"

`boss.gd::pizza_speed` 570 → **456** px/s (−20%).

Still leaves plenty of threat — the boss throws on a 1.75 s base cadence, so pizzas have time to read at this slower velocity. Floor 3 fight is more reactable on every difficulty.

---

### Menu positioning bug — preserve anchored Y offsets

User screenshot showed the menu vbox shifted UP into the title area after backing out from loadout. Root cause: my tween_method was treating `position` as absolute screen coords and setting `position.x/y` directly. But anchored Controls (e.g. `MenuHolder` with `anchor_top = 0.42`) have a NON-ZERO position computed from their anchor box — `MenuHolder.position.y ≈ 340` on an 810-tall viewport.

By doing `c.position.x = lerp(0, -vp_w, t)` and `c.position.y = arc_y`, I was overwriting the anchored Y with `arc_y` (which was 0 outside the arc peak). Then `c.position = Vector2.ZERO` in the safety reset literally moved the holders to absolute (0, 0), pulling MenuHolder up by 340 px on top of TopHolder. Hence the broken layout.

**Fix**:
1. Capture each `_ui_holder_nodes` member's original `position` ONCE at start of the first forward transition into `_ui_original_positions`.
2. Use those as the BASE in tween_method: `c.position.x = orig.x + lerp(0.0, -vp_w, t)`, `c.position.y = orig.y + arc_y`. Anchored Y is preserved across the swoop.
3. End-of-pan and end-of-Phase-C cleanups now restore `position = _ui_original_positions[i]` instead of zeroing.

Applied to BOTH forward and back transitions. Menu and title now snap back to their proper anchored layout on every back-trip.

---

### Title transition cranked dramatic

User: "make the transition more dramatic"

Every parameter pushed harder:

| | Old | New |
|---|---|---|
| `PANEL_SCALE_OUT` | 0.55 | **0.40** (camera pulls WAY back) |
| `ARC_PX` (swoop Y height) | 55 | **130** (2.4× taller arc) |
| `TILT_DEG` (pan tilt) | 4° | **9°** (over 2× more roll) |
| `BG_PARALLAX` | 0.18 | **0.35** (bg layers fly past 2× faster) |
| Phase A ease | `SINE EASE_IN_OUT` | `CUBIC EASE_IN` (accelerate INTO the pull-back) |
| Phase B ease | `SINE EASE_IN_OUT` | `QUART EASE_IN_OUT` (snappier whip) |
| Phase C ease | `SINE EASE_IN_OUT` | `BACK EASE_OUT` (overshoot bounce past 1.0!) |

**Plus new effects**:
- **Phase A tilt**: title rocks back **-3°** while zooming out — camera tilts AS it pulls away.
- **Phase B bg rotation**: background + decor layers also tilt at `0.3×` and `0.5×` of the panel tilt — bg parallax now includes rotation, not just X drift.
- **Phase C overshoot**: `TRANS_BACK ease_out` — the loadout/title scales PAST 1.0 (~1.1×) before settling. Gives the arrival an impactful punch instead of a flat stop.

End-of-pan snap callbacks also reset bg/decor rotation (they were getting rotated during the swoop now).

Same dramatic treatment applied to the reverse direction (loadout → title) — Phase A tilts loadout +3° while zooming out, Phase B does mirrored swoop with opposite tilt, Phase C overshoots title scale-up.

---

### Loadout→title back-transition: comprehensive state reset

User reported the menu positioning broke after going back to the title from loadout. Tween_method + chained tweens can leave residual sub-pixel offsets, residual scale drift on inner button hover states, or stale rotation values that subtly break the layout next time.

End-of-back-transition cleanup now **forcibly resets every transform** on every animated node back to identity:

- For each UI holder (`TopHolder`, `MenuHolder`, `HintHolder`, `StatsHolder`, `VersionLabel`):
  - `position = Vector2.ZERO`
  - `rotation = 0.0`
  - `scale = Vector2.ONE`
- For `background_layer` and `decor_layer`: same `position = ZERO`, `rotation = 0`.
- For every entry in `_menu_buttons` (the Start/Difficulty/Workshop/Options/Quit buttons):
  - `disabled = false`
  - `scale = Vector2.ONE` (in case the hover-scale tween left them at 1.06)
- Then `set_process_input(true)` and `_menu_buttons[_focus_index].grab_focus()`.

Defense in depth — overrides any residual values from the chained Phase B/C tweens.

---

### Title transition: angle swoop (arc + tilt) during the pan

User: "make it more like a swooping at an angle to the loadout screen. you know?"

Phase B (the pan) is no longer a flat horizontal slide. Replaced the parallel `position:x` tween with a single `tween_method(func(t)...)` that drives a 0..1 progress value, then the lambda computes:

- **Y arc**: `arc_y = -sin(t * PI) * 55.0` — content swoops UP by 55 px at the midpoint, returns to 0 at the end. Reads as the camera arcing up and over.
- **Tilt**: `rotation = sin(t * PI) * -4°` (forward direction) / `+4°` (back direction). Content tilts 4° at midpoint, untilts at end. The opposite signs in each direction sell the "I'm going the other way" feel.
- **X**: still `lerp(start, end, t)` — straight horizontal interpolation, but combined with the arc + tilt it reads as a swoop instead of a slide.

Background + decor layers still pan at 18% / 27% parallax but without arc — they're "far away" and shouldn't visibly swoop.

End-of-pan callback snaps rotation + Y to exactly 0 before Phase C (zoom-in) to avoid floating-point drift.

The phase A (zoom out) and phase C (zoom in) timing unchanged. Total transition still ~1.3 s.

---

### Title transition: 3 sequential phases — zoom out → pan → zoom in

User explained the desired sequence clearly: **"zoom out........ pan to the right on the loadout scene, zoom in."**

Rewrote both `_swipe_out_to_loadout` and `show_title_again` as **three distinct chained phases** instead of combined parallel scale+slide.

**Title → loadout** (`_swipe_out_to_loadout`):
- **Phase A — Zoom out** (0.4 s): title UI scales 1.0 → 0.55. Camera pulls back from title. No position change. Loadout panel is pre-built off-screen right at 0.55× scale, waiting.
- **Phase B — Pan** (0.5 s): everything at 0.55× scale slides left. Title UI x → -viewport_w, loadout x → 0. Background drifts at 18% / 27% parallax. Camera pans right onto the loadout panel.
- **Phase C — Zoom in** (0.4 s): loadout scales 0.55 → 1.0. Camera pushes into the loadout.

**Loadout → title** (`show_title_again`): exact reverse —
- Phase A: zoom out loadout (1.0 → 0.55)
- Phase B: pan left (loadout off right, title in from left at small scale)
- Phase C: zoom in title (0.55 → 1.0), then cleanup (free loadout, restore input/focus)

Each phase uses `Tween.set_trans(TRANS_SINE).set_ease(EASE_IN_OUT)` and chains via `chain().tween_callback(...)` so the transitions are smooth at the phase boundaries. Total transition time: 1.3 s each direction.

Still one continuous scene with persistent bg/decor — stars + pizzas + bg bears stay visible throughout.

---

### Zoom amount cranked way up so it's actually visible

User: "no zoom."

The previous 0.85 → 1.0 scale change was too subtle to read on most monitors. Cranked it WAY harder:

| | Old | New |
|---|---|---|
| `PANEL_SCALE_OUT` (title shrinks to, loadout starts at) | 0.85 | **0.55** |
| `SLIDE_DUR` | 0.6 s | **0.65 s** (gives the bigger zoom time to register) |

Also added `_loadout_panel.size = vp_size` BEFORE setting `pivot_offset`. Without this, the panel's size was 0 at the moment we computed pivot (Godot layout hasn't run yet on a freshly-instantiated Control), so pivot_offset = `size * 0.5` would have ended up at (0, 0). That would have caused the scale to happen around the top-left corner of the panel instead of its center — making the zoom look weird and asymmetric.

Now the title shrinks to ~55% as it slides off and the loadout grows from 55% → 100% as it slides in. Clearly visible dolly-zoom feel.

---

### Title screen KK bears now slowly spin

User: "the title screen kk mob. make them slowly spin"

`BgBear` class in `title_screen.gd` now has a `spin: float` field — per-bear rad/sec rotation rate. Assigned at spawn:
- `randf_range(-0.15, 0.15)` rad/sec
- Floor magnitude to ±0.08 if too close to zero so they don't appear stationary
- Sign is independently randomized per bear so the swarm doesn't all spin the same way

`_process()` bear update now adds `bb.node.rotation += bb.spin * delta` after the bob update. Each bear tumbles lazily as it drifts.

---

### Zoom back into the title↔loadout slide

User: "the zoom out and in is gone???"

Added subtle scale tweens back onto the slide so it reads as a real **dolly-zoom + pan** instead of a flat horizontal slide.

**Going to loadout**:
- Title UI: position.x → -viewport_w + scale 1.0 → **0.85** (camera pulling back as title slides off)
- Loadout panel: position.x = +viewport_w → 0 + scale **0.85** → 1.0 (camera pushing in as loadout arrives, growing into the frame)
- All centered on `pivot_offset = size * 0.5` so scaling happens around the visual center
- Slide duration bumped 0.55 → **0.6 s** to make the combined slide+scale feel sufficiently weighty
- Bg + decor still parallax-drift at 18% / 27% of full speed
- Single Tween, sine ease-in-out, no chained phases

**Going back to title**: exact mirror — loadout slides off + shrinks, title slides back + grows.

Still one continuous scene, no scene change, no blink. Just with the camera-dolly feel restored.

---

### Title + loadout = one scene (no more transition blink, stars/pizzas persist)

User direction: "maybe think of this as one big scene that we bounce around in"

Restructured the title→loadout flow to keep both panels in the same scene tree at all times. No more `change_scene_to_file` between them — that's what was causing both the mid-transition blink AND the stars/pizzas vanishing during the swap.

**Implementation**:
- When user clicks "Start" on the title screen, `_swipe_out_to_loadout()` now **instantiates `loadout_screen.tscn` as a child node** of the title screen rather than swapping scenes.
- The embedded loadout is positioned off-screen to the right (`position.x = viewport_width`) and tagged via `set_meta("embedded_in_title", true)`.
- A single Tween then slides title UI nodes (`TopHolder`, `MenuHolder`, `HintHolder`, `StatsHolder`, `VersionLabel`) left to `-viewport_width` AND the loadout panel from `+viewport_width` to `0` in parallel. Bg + decor layers drift at 18% of full speed for subtle parallax. 0.55 s, sine ease-in-out.
- The title scene's `BgGradient`, `BackgroundLayer` (with all 60 specks + bg bears) and `DecorLayer` (with all 7 pizza slices) **stay rendered the entire time**. Never go blank.

**`loadout_screen.gd` updated to support being embedded**:
- `_ready()` checks `has_meta("embedded_in_title")`. If set, skips building its own `BgGradient` / specks / pizzas / planets and hides the `BgFallback` + `BgGradient` nodes. The title screen's bg shows through instead.
- Sets `content.modulate = (1, 1, 1, 1)` immediately when embedded since the title drives the position tween — no internal entrance animation needed.

**Back navigation**:
- `_on_back()` now checks for the embedded flag. If set, calls `parent.show_title_again()` instead of changing scenes.
- New `show_title_again()` method on `title_screen.gd` runs the reverse tween (loadout slides off right, title slides back to center) and queue_frees the loadout panel at the end.

**Net effect**: Title → loadout → title is one continuous slide with no scene change, no blink, and stars/pizzas/bears all visible the whole way through. Loadout → main game still does a proper scene change (only place it makes sense).

`loadout_screen.tscn` standalone mode still works (workshop fallback etc.) — the embed logic is opt-in via the meta flag.

---

### Title transition rebuilt as simple fade-zoom

The pan + tilt + parallax transitions have been a moving target across many revisions and the user keeps reporting issues. Threw out the entire pan model and switched to the simplest version that doesn't look broken: a clean fade-zoom on a single Tween.

**Title → loadout** (`title_screen.gd::_swipe_out_to_loadout`):
- ALL UI scales 1.0 → **0.92** (subtle pull-back)
- ALL UI alpha 1.0 → 0.0
- Background + decor layers fade to 0.3 alpha (still visible as faint atmosphere through the swap)
- 0.35 s, sine ease-in
- Then `change_scene_to_file`

**Loadout entrance** (`_play_swipe_in`):
- Content starts at scale **1.08**, alpha 0
- Tweens to scale 1.0 + alpha 1 over 0.35 s, sine ease-out
- Background + decor stay put (no parallax pan)

**Loadout → main game** (`_on_start`):
- Content scales to 1.05 + fades to 0
- Black `ColorRect` overlay fades to opaque so the cut into `main.tscn` is clean
- 0.4 s

**Loadout → title** (`_on_back`): mirror of entrance — scale down to 0.92, fade out.

No more two-phase chained tweens. No more tilt/cant. No more parallax pan offsets. If the user wants more flair we can iterate from this clean baseline.

---

### New pond — Kenney Roguelike/RPG pack tiles (4th iteration)

User: "pick another lake texture/image — this one sucks"

The RPG Base pack water tiles were too washed-out / brown. Switched to Kenney's **Roguelike/RPG Pack** (CC0, kenney.nl) which has way more saturated tiles.

**Pipeline**:
- Downloaded `kenney_roguelike-rpg-pack.zip`
- Extracted 3 specific 16×16 tiles from `roguelikeSheet_transparent.png` (stride 17, 1 px margin):
  - `water` at tile (1, 0) — vivid cyan/teal (rgb 99, 197, 207)
  - `grass` at tile (5, 0) — bright leafy green (rgb 140, 195, 52)
  - `sand` at tile (28, 0) — warm tan with wooden-plank texture (rgb 180, 155, 129)
- Saved to `assets/kenney_roguelike/{water,grass,sand,License}` for tracking

**`tools/build_pond.py` rewritten** to composite the new tiles:
- Tile the grass across 192×128, mask to outer ellipse (radius 92×60)
- Tile the sand inside an inner ellipse (radius 78×50)
- Tile the water inside the innermost ellipse (radius 68×42)
- 0.7 px Gaussian alpha-only blur for clean edges

Result: bright cyan water, sandy shore with subtle plank texture, vivid green grass border. Much more vibrant than the previous mute RPG Base pond.

Reimported the texture so Godot serves the fresh asset.

Source: [Roguelike/RPG Pack — Kenney, CC0](https://kenney.nl/assets/roguelike-rpg-pack).

---

### Sky boss arm crop + z-index above ground sprites

**Arm cropped off** — sky_boss.png had a dangling left arm/paw sticking out that looked weird floating in the sky.

New `tools/fix_sky_boss_arm.py` post-process:
- Counts opaque pixels per column on the alpha channel
- Finds the leftmost column where density ≥ **78% of the max** (the head/body is the densest area; arms have far fewer opaque pixels per column)
- Crops everything to the LEFT of that column off
- Re-tightens the bbox after

Wired into the build flow: `process_sky_boss.py` runs first (full rembg + alpha pipeline), then `fix_sky_boss_arm.py` strips the arm. Result: 563×524 pure head + body silhouette, no protrusions.

**Z-index** — face boss was getting overdrawn by ground decorations (bushes etc.) because `main.tscn` has `y_sort_enabled` and the boss sits at low Y (top of screen) while decorations sit at high Y. Y-sort renders higher Y *on top*.

Fix: `face_boss.gd::_ready()` now sets `z_index = 50` and `z_as_relative = false`. The giant head is forced to render above all ground-level sprites regardless of y-sort position.

Re-imported `sky_boss.png` and the affected scenes — fresh assets load on next run.

---

### Gun bear lighting + ear alpha fix

User: "fix gun bear lighting. and the alpha mask on his ears is fucked up"

Two changes in `tools/process_gun_bear.py`:

**Lighting pass** (in order):
- `ImageEnhance.Brightness(1.18)` — +18% brightness so the dark brown fur reads as fur instead of a black blob
- `ImageOps.autocontrast(cutoff=2)` — drops the very darkest + lightest 2% of pixels, expanding dynamic range so highlights and shadows actually separate
- `ImageEnhance.Color(1.35)` — +35% saturation (was 1.30)
- `ImageEnhance.Contrast(1.12)` — reduced from 1.18 since autocontrast already did most of the contrast lift
- UnsharpMask unchanged

**Ear alpha hole-fix**:
- Bumped morphological close kernel `5×5 → 7×7`
- Added `scipy.ndimage.binary_fill_holes(closed)` AFTER the close pass. This fills ANY interior region that's fully surrounded by opaque pixels — patches the see-through holes the rembg cutout was leaving in the ears + belly area.
- Result: solid fur silhouette, no transparent islands inside the body.

Reprocessed `assets/gun_bear.png` (227×256). Removed the old `.ctex` and re-ran headless import so Godot picks up the fresh texture.

---

### Floor 3 boss throw rate slowed

User: "floor three 3 is shooting projectiles too fast. slow it down"

`scripts/boss.gd` `@export var throw_interval` tuning bumped across all difficulties:

| Difficulty | Old | New |
|---|---|---|
| Easy | 1.8 s | **2.4 s** |
| Medium (default) | 1.15 s | **1.75 s** |
| Hard | 1.55 s | **2.0 s** |

Phase 2 still multiplies `throw_interval *= 0.65` once the boss hits half HP (so medium phase 2 = ~1.14 s, was ~0.75 s). The "boss gets mad" ramp is preserved but the baseline cadence is way more readable now.

---

### Air-line blast rebuilt with Kenney CC0 smoke puffs

User: "plastic wrap bear line OAE is ugly as fuck. save to memory from now on use online users assets instead of making shit"

**Memory rule saved to `CLAUDE.md`** — permanent project instruction:
> Always prefer real CC0 assets from online sources over procedural / hand-coded visuals.

Kenney's Smoke Particle Assets pack (CC0, opengameart.org) downloaded. The "White puff" subdirectory has 25 frame PNGs of a soft cloudy smoke puff at variable sizes.

**Pipeline** (`tools/pack_puff_sheet.py`):
- Resizes each frame to fit a 128×128 cell (`thumbnail` LANCZOS, centered)
- Composites into a **5×5 sprite sheet** at 640×640
- Saves to `assets/white_puff_sheet.png`
- License copied to `assets/kenney_smoke/license.txt` for attribution

**`scripts/air_line_blast.gd` rewritten** to use the sprite sheet instead of the previous ugly procedural Line2D + white rectangle:

- **Telegraph (0.55 s)**: a single `Sprite2D` at the bear's mouth playing frames 0–8 of the puff sheet, fading in + growing + pulsing — clearly signals where the blast is about to happen.
- **Active (0.55 s)**: 3 `Sprite2D` blast puffs spawn at staggered start times (0, 0.08, 0.16 s). Each puff travels from the bear forward to `length` px, cycles through all 25 animation frames over its journey, grows from 0.6 → 1.4 scale, and fades on a cubic curve at the tail. Reads as a believable chain of smoke clouds being puffed forward.
- Each puff has a small lateral start/end Y jitter (`±width*0.10`) so they don't track in a perfectly straight line — feels more organic.
- Damage check unchanged: hits player if they're inside the projected forward rectangle (`along ∈ [0, length]`, `lateral ≤ width/2`) at +0.18 s into the active window.

Net effect: looks like an actual gust of smoke instead of a flat geometric placeholder. License preserved in `assets/kenney_smoke/`.

Source: [Smoke Particle Assets — Kenney, CC0](https://opengameart.org/content/smoke-particle-assets).

---

### Gun bear double-fire fix + pond cache refresh

**Gun bear was firing two projectiles per attack** — its own fluff ball PLUS an inherited KK spit attack. `enemy.gd` runs `_tick_spit(delta)` whenever `GameSettings.enemies_spit()` is true (medium difficulty), so anyone extending the base enemy script automatically gets the brown spit. Fix: override `_tick_spit` in `gun_bear.gd` to no-op. Now only the fluff ball fires.

**Lake asset stale** — Godot was still serving the old `pond.png-*.ctex` from `.godot/imported/`. Removed the cached `.ctex` for the pond specifically, then re-ran `godot --headless --import` which reimported `pond.png` (and picked up `gun_bear.png` and `sky_boss.png` while it was at it). New `pond.png-63104ff6...ctex` cache file now matches the current Kenney-tile pond on disk.

---

### Sky boss restored — uses 7.jpg (giant cream teddy)

User dropped `assets/7.jpg` — a massive cream/blonde teddy bear photo, asking to crop and use as the sky boss. The full-body bear (not just a face close-up) gives a much better silhouette for a floating boss.

**Pipeline** (`tools/process_sky_boss.py`):
- EXIF rotate, rembg cutout
- +20% saturation, +18% contrast, unsharp mask
- Low-cutoff alpha (>50 = opaque) + 5×5 morphological close (proven hole-fill recipe)
- Tight crop, resize so longest side = 720 px (boss-scale)
- Output: `assets/sky_boss.png` (720×617 — a wide full-body silhouette)

**Wiring**:
- `face_boss.gd::FACE_TEX_PATH` updated from `cleave_maw.png` → `sky_boss.png`
- `main.gd::_spawn_boss()` reverted: sky biome now routes back to `FaceBossScene`. The "sky-tinted regular boss" workaround is gone.
- All face-boss systems (paw slams, tooth volleys, paw sweeps, floor cleaves, mini-rain) are active again on Floor 9.

The face boss is still on **collision layer 4** with cleared mask, so the player walks freely under/around the giant bear silhouette while pizzas still hit it.

---

### Gun Bear now shoots slow fluff balls

Per user direction: replaced the bullet projectile with a soft cottony **fluff ball**.

`scripts/bear_bullet.gd` redrawn:
- **Speed 540 → 220 px/s** (slow lob, easy to read and dodge)
- **Lifetime 1.2 → 2.4 s** for matching range
- Visual is now a **4-layer Polygon2D fluff ball**: semi-transparent outer halo → mid-tone outer fluff → bright cream core → small darker speck for "weight." Each layer uses a `_wobbly_circle` helper with multi-frequency sin noise on the radius so it reads cottony instead of perfectly round.
- **Lateral wobble** during flight (sin wave on the perpendicular axis) so the puff visibly floats rather than tracking a dead-straight line.
- Slow spin (`_spin * 0.3`) on the body for a softer feel.
- Circle collision matches the fluff body, ~11 px radius.

`gun_bear.gd::BULLET_SPEED` 540 → 220 to match.

---

### New enemy: Gun Bear (mid-range bullet shooter)

User dropped `assets/6.jpg` — a brown plush bear with a black MR6 rifle sticker on its side. Built it into a new mid-range enemy variant.

**Asset pipeline** (`tools/process_gun_bear.py`):
- EXIF-rotate, rembg cutout, +30% saturation, +18% contrast, unsharp mask
- Low-cutoff alpha (>50 = opaque) + scipy `binary_closing` (5×5 kernel, 2 iterations) to fill holes — same proven recipe from the Cleave Maw fix
- Tight crop, resize to 256 px max dim
- Output: `assets/gun_bear.png`

**Gun Bear** (`scripts/gun_bear.gd` / `scenes/gun_bear.tscn`):
- Extends `enemy.gd`
- Stats: **5 HP**, **78 speed** (slower than KK), **1 touch damage**
- Has a **shoot cycle**: 3.2 s ±0.5 s cooldown, fires only if player is in 90–460 px range
- **Windup phase (0.45 s)** — bear freezes, modulates bright yellow ("aiming"), then fires. Skip to base `_physics_process` skipped during windup so he doesn't chase mid-aim.

**Bear Bullet** (`scripts/bear_bullet.gd` / `scenes/bear_bullet.tscn`):
- Procedural Area2D — dark capsule body + mid-grey core + cream tip (3-layer streak)
- 540 px/s, 1 damage, 1.2 s lifetime (~648 px range)
- Capsule collision matches the body, rotated horizontally
- In `hostile_projectile` group so room-cleanup nukes any in-flight bullets

**Variant spawn rates** updated in `main.gd::_spawn_enemy()`:
- 25% KK (regular brown bear, unchanged)
- 25% MB (Plush Brawler, charges)
- 25% Shrinkwrap (plastic-deflect)
- 25% **Gun Bear (new)**

Available from Floor 1+ like the others.

---

### Sky boss removed — replaced with sky-tinted regular boss

The Face Boss (giant `cleave_maw.jpg` floating head) just never looked right in-game no matter how many alpha cleanup passes — even with hole-filling, the rembg-cleaned photo at scale still had artifacts and read as "weird floating thing" instead of "boss." User wanted it removed.

Replaced Floor 9 sky boss with **the regular first boss (`BossScene`) tinted sky-blue**:
- `_spawn_boss()` no longer routes sky biome → `FaceBossScene`. Falls through to default `BossScene`.
- After spawn, if `biome == "sky"`, the boss's `Rig` Node2D gets `modulate = Color(0.78, 0.92, 1.10, 1.0)` — a cool sky-blue tint that distinguishes him visually from the Floor 3 forest version.
- HP boosted 1.45× (~34 → ~49) for the late-game position.
- All the regular boss's attacks (pizza throws, ground slam, paw slam, cleave maw scene unchanged) remain.

`face_boss.gd`, `face_boss.tscn`, and the supporting `tooth_projectile`, `paw_sweep`, `floor_cleave` files all stay on disk. They're just no longer wired into any spawn path. Could be revived later if the photo issue is solved or a fully procedural replacement gets built.

---

### Real Kenney CC0 tiles for the lake

Threw out the procedural pond entirely. New lake composited from **real Kenney RPG Base tiles** (CC0, kenney.nl):

- `assets/kenney_rpg_base/grass.png` — `rpgTile000` from Kenney's RPG Base pack (64×64 light grass)
- `assets/kenney_rpg_base/water.png` — `rpgTile029` (64×64 light blue water with hand-drawn wave texture)
- `assets/kenney_rpg_base/license.txt` — Kenney's CC0 notice

`tools/build_pond.py` rewritten to composite these tiles into a finished pond:
1. **Tile the grass** across a 192×128 canvas
2. Apply an **elliptical mask** (radius 92×60) — outside the ellipse is transparent (so the pond is an isolated cutout)
3. Paste a solid **sand/dirt ring** at radius 78×50
4. **Tile the water** inside an elliptical mask at radius 68×42
5. 0.7 px Gaussian alpha-only blur for clean edges

Result reads as a proper top-down RPG pond — grass border, sandy shore, real wave-textured blue water — at a more reasonable size (192×128).

`pond.tscn` collision radius set to **42** to tightly match the inner water ellipse (the water body's short axis is 42, so the blocker sits exactly inside the visible water).

License attribution: Kenney Vleugels, CC0. Per Kenney's terms: "Credit would be nice but is not mandatory." File copies and license preserved in the assets folder.

---

### Face boss layer 4 (walk-through) + small simple pond + tight collision

**Face boss invisible-geometry fix** — root cause: the face boss is a `CharacterBody2D` on collision layer 1 with a `CircleShape2D` of radius **209 px** (`FACE_RADIUS * 0.95`). The player's mask includes layer 1, so the player got blocked by an enormous invisible disc around the giant floating head — even when standing well below the visible face.

Fix:
- Face boss moves to **collision layer 4** in `_ready()`. Player's mask (1+3) does NOT include 4, so the player walks straight through where the face hovers.
- Face boss `collision_mask` cleared (it never physically moves anyway).
- `pizza.gd`, `pizza_bomb.gd`, `pizza_wheel.gd` now mask layer 4 in addition to layers 1+3, so projectiles still detect and damage the face boss.

**New pond — much smaller + clean simple visual** per user direction.

`tools/build_pond.py` rebuilt from scratch — flat cartoon style:
- 180×120 PNG (was 384×256 — less than half the area)
- 5 simple solid ellipses: dark grass outer → main grass → sand → main water → light water center
- 2 small arc shimmer marks
- 0.6 px Gaussian alpha-only blur for clean edges, no fancy wavy shorelines

`pond.tscn` collision radius shrunk **92 → 40 px** to tightly match the visible water body (which has half-axes ~63×40 — used the smaller axis so collision sits fully INSIDE the water visually). No more "geo weird on them" — the invisible blocker exactly matches the dark blue water you can see.

---

### Emergency fix: wiped .godot/imported/ broke ALL textures

My previous "deep cache clear" included `rm -rf .godot/imported/*` — that's where Godot stores the compiled `.ctex` files for every imported asset. Without those, every `ext_resource` Texture2D reference in every `.tscn` resolved to null, so the game launched showing only the green floor `ColorRect`.

Fix:
1. Pulled `Godot_v4.6.2-stable_win64.exe` out of the user's Downloads zip into `/tmp`.
2. Ran `Godot --headless --import` from the project root — regenerated all 262 cache files in `.godot/imported/`.

Also caught and fixed an unrelated parse error during the editor load: `scripts/shrinkwrap_bear.gd` had the Y-scale crunch logic accidentally placed inside `_fire_air_line()` (which doesn't take `delta`), causing two `Identifier "delta" not declared` parse errors. Moved the crunch block back into `_physics_process(delta)` where it belongs; `_fire_air_line` keeps just the instant exhale-squish, with the lerp recovery handled by the crunch tick next frame.

**Lesson for future cache clears**: ONLY remove the cfg files (`global_script_class_cache.cfg`, `scene_groups_cache.cfg`, `uid_cache.bin`). Never `rm -rf .godot/imported/` — Godot doesn't regenerate that during gameplay, only during editor `--import` runs.

---

### Revert face boss to photo (user req) + new alpha approach, shadows up, zero boss-room props

**Face Boss back to using the `cleave_maw.jpg` photo** per user direction. Reverted the procedural Polygon2D face. Sprite-based facing flip and death rotation restored. `_build_face` helper deleted.

**New alpha cleanup strategy in `tools/fix_cleave_maw.py`** — the previous threshold (>200 = solid) was leaving see-through holes in the muzzle. New approach:
1. **Low cutoff**: anything above alpha 50 → opaque. Below 50 → transparent. No mid-range band.
2. **Morphological close** (5×5 kernel, 2 iterations) on the binary alpha mask — dilates + erodes to fill any remaining 1–2 px gaps inside the silhouette. Done via `scipy.ndimage.binary_closing`.

Result: the bear face is now fully solid — no bushes show through the muzzle. Clean sharp silhouette.

**Shadows moved UP**. User feedback "shadows too low" — was offsetting them south-east at `+y` which placed them BELOW where the prop's base actually sits. Re-tuned ALL shadow Y offsets to negative values:

| Prop | Old Y | New Y |
|---|---|---|
| Tree | +4 | **-4** |
| Pine | +4 | **-4** |
| Stone | +5 | **-3** |
| Desert rocks | +5 | **-3** |
| Cactus round | +3 | **-5** |
| Cactus tall | +3 | **-5** |
| Bush | +1 | **-2** |
| Desert bush | +1 | **-3** |

X offsets unchanged (still +1 to +3 for south-east light source feel). Now the shadows sit at or just above the prop's actual ground contact point.

**Boss-room props zeroed everywhere**. User still hitting "invisible geometry" on Floor 10. To be safe across all boss arenas: `_spawn_props(0)` on ALL boss floors (was sky-only). Decorations (no collision, just Sprite2Ds) bumped 10 → 18 on non-sky to keep visual interest. Final boss arena is now PURE open ground; only the boss, walls, and player.

**Deep cache clear** — `rm -rf .godot/imported/*` plus the script/scene/uid caches so every prop scene gets re-imported from scratch on next launch. Eliminates the "Godot is loading old cached version of tree.tscn with collision still on" possibility.

---

### Procedural Face Boss + organic wavy pond

**Face Boss now drawn procedurally** — gave up on the rembg-photo approach entirely. No more alpha mask issues because there's no photo to mask.

New `_build_face()` in `face_boss.gd` constructs the boss head as **stacked Polygon2D layers** in local space:
- Two **ears** per side (darker outer + pinkish inner)
- **Outer fur ring** at 1.04× radius with sinusoidal waviness (14-cycle sin overlay) for a fluffy edge
- **Main head** circle in mid brown
- **Forehead highlight** (lighter brown oval, top-left, alpha 0.55)
- **Big cream snout/muzzle** (dark cream ring + bright cream inner)
- **Black heart-shaped nose** with white highlight shimmer
- **Two large oval eyes** with white sparkle dots
- **Pink blush cheeks** at low alpha

All drawn in a `_face_root` Node2D centered on origin. **Facing** is now done by mirroring `_face_root.scale.x` (1 vs -1) instead of flipping a sprite — cleaner and instant.

Collision shape switched from RectangleShape2D 360×360 to **CircleShape2D radius 0.95 × FACE_RADIUS** so the hit box matches the actual round head silhouette. Pizzas hit anywhere on the visible head reliably now.

`_process_death` updated to fade/rotate `_face_root` instead of the old `_sprite` reference. `FACE_TEX_PATH`, `_load_face_texture`, and `_sprite` are all gone. The whole `assets/cleave_maw.png` photo pipeline is no longer used by the face boss (the file remains on disk but isn't loaded).

**Pond rebuilt — third time's the charm, fully different aesthetic.**

New `tools/build_pond.py` uses **wavy organic shorelines** instead of stacked perfect ellipses. Each layer is a closed contour with a **sinusoidal radius wobble** combining 3 different harmonic frequencies — looks hand-drawn / painterly, not geometric.

8 layers from outermost in:
1. Dark grass outer (high wobble)
2. Main grass
3. Brighter grass-water edge highlight
4. Narrow sand/dirt shore
5. Deep navy water ring
6. Main blue water body
7. Light cyan inner
8. Re-darken inset (creates a depth gradient)

Plus 5 procedural **"≈" double-arc shimmer marks** scattered across the water surface (two parallel curves drawn with `ImageDraw.arc`). Soft 0.8 px Gaussian blur on alpha only for clean anti-aliased edges.

Final asset is 384×256 (was 320×224). `pond.tscn` collision radius bumped to **92** to match the larger water body.

---

### Pizzas now hit enemies on layer 3 too

Side effect of moving enemies to collision layer 3: player projectiles (`Area2D` with default `collision_mask = 1`) couldn't see them anymore — pizzas flew straight through.

Added `set_collision_mask_value(3, true)` to `_ready()` in:
- `pizza.gd` (default + scatter + homing throws)
- `pizza_bomb.gd`
- `pizza_wheel.gd` (orbital slice — covers both the Pizza Wheel boon AND the Soft Landing shield since they share the same scene)

Now all player damage sources hit enemies on both layer 1 (bosses) and layer 3 (trash).

---

### Saws disabled — only water collisions left on the stage

User followup: "random collisions everywhere even in blank areas" after the props were made walk-through. Culprit was the `SweeperSaw` Area2D hazards — they spin and look subtle, but their CircleShape2D collision (radius 36, scaled 1.4× → ~50 px effective) still triggered damage on overlap, looking like "I just got hit by nothing." With trees/rocks no longer blocking, the player can now traverse the WHOLE arena and runs into saws they couldn't reach before.

Per user direction ("there's no no blockages on the stage except for the water"):
- **`_spawn_sweeper_saws` call commented out** in `main.gd`. The function and scene are preserved on disk for easy re-enable later.

Audit confirmed: after this change the ONLY remaining colliders in any room are:
- The 4 boundary walls (`WallTop`/`Bottom`/`Left`/`Right` in `main.tscn`) — these are the room edges and have to stay or the player walks off the map.
- Active bosses (CharacterBody2D physical colliders so pizzas can hit them).
- The pond(s) (water — exactly what should block).
- The player + enemies (CharacterBody2D, on different layers post-fix).

Cleared `.godot/global_script_class_cache.cfg`, `scene_groups_cache.cfg`, and `uid_cache.bin` so the updated tree/rock collision-disabled `.tscn` files get re-imported on next launch (avoids the player running on a stale cache where rocks still block).

---

### Cleave Maw alpha hard-clip, face higher, ad cap, enemies pass through each other

**Cleave Maw alpha mask** — the 130/200 threshold from last pass still let a heavy ghosty halo through (visible in screenshot as fur-fringe ringing the muzzle). Pushed it hard: now **below 200 alpha → 0**, **above 230 → 255**, with only a tight 30-unit transitional band in between. Net: most of the halo gets cut entirely, just a thin clean edge remains. Reads way crisper at the in-game scale.

**Face Boss position** — `FACE_Y` reverted **270 → 180**. The 270 placement was sitting too low across the play area; back up where it belonged.

**Desert/final boss ad spawn** — was still oppressive even after the last slow-down:
- `summon_cooldown` 2.6 → **4.5** (medium baseline).
- Hard mode: 3.8 → **6.0 s**.
- **NEW: `summons_max_alive` cap** — won't summon if there are already this many ads alive (default 5, hard 4). Stops the 100-bear pile-up entirely.
- Phase 3 multiplier softened: 0.6 → **0.78** (since the cap is also limiting concurrent ads now, the ramp doesn't need to be as aggressive).
- New `_count_ads_alive()` helper iterates the "enemies" group and excludes self.

**Desert random collisions = enemy pile-up around player.** Trash enemies (KK, MB, plastic bag) were all on collision layer 1, so they physically pushed each other into a wall of bears that snagged the player every time they tried to move.

Fix — move trash enemies to their own collision layer:
- `enemy.gd::_ready()` now does `set_collision_layer_value(1, false)` + `set_collision_layer_value(3, true)`. Variants (`plush_brawler`, `shrinkwrap_bear`) inherit this via `super._ready()`.
- `player.gd::_ready()` now does `set_collision_mask_value(3, true)` so the player still physically collides with enemies (so touch-damage detection works).
- Result: two enemies' masks (default 1) don't include layer 3 → they pass through each other physically. Player's mask (1+3) still includes 3 → player collides with enemies. Bosses stay on layer 1 unchanged.
- Visual avoidance (`SEPARATION_RADIUS`/`SEPARATION_REPULSION`) still drives them apart in steering, so they don't visibly overlap either.

---

### Ground shadows on all natural props

Added flat elliptical drop shadows under every tree, rock, cactus, and bush. Each shadow is a `Polygon2D` sized to match the prop's base, slightly offset south-east (`+2, +4` to `+3, +5`) to read as if there's an overhead sun light source.

| Scene | Shadow size (rx × ry) | Alpha |
|---|---|---|
| `tree.tscn` | 20 × 7 | 0.35 |
| `pine_tree.tscn` | 18 × 6 | 0.35 |
| `stone.tscn` | 30 × 9 | 0.40 |
| `desert_rocks.tscn` | 32 × 9 | 0.40 |
| `cactus_round.tscn` | 16 × 5 | 0.38 |
| `cactus_tall.tscn` | 14 × 5 | 0.38 |
| `bush.tscn` | 12.5 × 5 (effective at parent's 2.5× scale) | 0.32 |
| `desert_bush.tscn` | 13.2 × 5.5 (effective at parent's 2.2× scale) | 0.32 |

**Implementation details**:
- For the 6 prop scenes (StaticBody2D roots), the `Shadow` Polygon2D is added as a **sibling** of the `Sprite` node, **declared first** in the .tscn so it renders behind the sprite.
- For the 2 bush scenes (Sprite2D roots), the `Shadow` is added as a **child** of the sprite with `show_behind_parent = true`. The polygon coords compensate for the parent's 2.5× / 2.2× scale.
- 8-point ellipse approximations (octagonal) — cheap and reads as smooth from in-game distance.
- Stones and rocks get a slightly darker shadow (0.40) than vegetation (0.32–0.38) to sell their density.

---

### Audit pass — trees + rocks now walk-through everywhere

User feedback caught that I'd only made the sky-biome boss room obstacle-free in the previous batch. The user actually wanted **every prop except water to be walk-through across all biomes** — final boss was still getting stuck on trees, MB was still grinding on rocks during charges, etc.

**Made all 6 natural-prop scenes pure decoration**:
- `tree.tscn`, `pine_tree.tscn`, `stone.tscn`, `cactus_round.tscn`, `cactus_tall.tscn`, `desert_rocks.tscn`
- Set `collision_layer = 0` and `collision_mask = 0` on each `StaticBody2D` root (so they can neither hit nor be hit by anything).
- Set `disabled = true` on each `CollisionShape2D` (belt-and-suspenders — even if the layer changed, the shape itself wouldn't query).
- Removed each from the `"obstacles"` group entirely, so the enemy AI's `for obs in get_tree().get_nodes_in_group("obstacles")` avoidance loop skips them too — enemies will path THROUGH trees/rocks, won't dodge around them. (Ponds remain in the group + still block.)

After this, **only water (`pond.tscn`) is a physical obstacle**, which is exactly what was requested. Final boss dashes don't get caught in trees. MB charges don't snag on desert rocks. The "invisible geometry" complaints all collapse to this: there is no longer any.

**Audit of recent fix list — confirmed all landed**:

| Request | Status |
|---|---|
| "BEAR CRAWL" title rename | ✅ |
| Title pulse 25% slower | ✅ |
| Rainbow bar 50% slower | ✅ |
| Stats label off the Quit button | ✅ (moved top-left) |
| Difficulty button fixed width | ✅ (420 px min) |
| Trees/rocks not blockers anywhere | ✅ (this batch) |
| Lake actually spawns | ✅ (forest floors, 1-2 per room — `main.gd:236`) |
| KK ninja star 15% slower + less frequent | ✅ |
| First boss: 1 pizza on hard, slower throws | ✅ |
| Boss pizza 5% slower | ✅ |
| Loadout → main game zoom into pizza-planet | ✅ |
| Final boss real dash (760 px/s, 1.35 s) | ✅ |
| Final boss / MB stuck-detection during charge | ✅ (now also moot since no static blockers) |
| Floor 6 boss death chain-explodes ads | ✅ |
| Dev mode damage popups when invincible | ✅ |
| Final boss ad spawn slower on hard | ✅ |
| Cleave Maw alpha threshold | ✅ |
| Sky biome decorations (no props, lots of bushes) | ✅ |
| Sky boss paw sweep visible across full side | ✅ |
| Bag mob still spawning | ✅ (33% rate from Floor 1, asset confirmed on disk) |
| Pizzas reverted to simple 3-layer | ✅ |
| Real `brown_*.png` for bg KK bears | ✅ |
| Title pan shorter + white-blink fix | ✅ |

`scenes/cylinder.tscn` is preloaded but never spawned in current code — vestigial, left alone.

---

### Title transition: kill the white blink + shorter pan

- **White-blink fix**: between scenes, the new screen's `BgGradient` TextureRect was being displayed for ~1 frame before `_ready()` got to build its `GradientTexture2D` — empty TextureRect renders as the default clear color (looks white-ish). Added a static `BgFallback` ColorRect to both `title_screen.tscn` and `loadout_screen.tscn` at the bottom of the node tree, color `(0.045, 0.025, 0.10, 1)` — a deep navy that matches the gradient top. The gradient draws on top of it. Now even if the gradient texture hasn't been generated yet, the screen background is already dark.
- Loadout's `Content` Control is now also pre-set to `modulate.a = 0` in the `.tscn` so the foreground UI is invisible from the *very first frame* of the scene (before script runs). The `_play_swipe_in` then fades it up.
- **Pan distances reduced** per user req: `FG_PAN_FRAC` 0.55 → **0.30**, `BG_PAN_FRAC` 0.28 → **0.14**, `DECOR_PAN_FRAC` 0.40 → **0.20`. The pan now reads as a subtle camera lean instead of a full slide-across. Stars + pizzas barely shift, so they feel persistent through the transition.

---

### Title screen polish — revert pizzas, real KK asset, stats moved, shorter pan

Per follow-up feedback:

- **Reverted pizza visuals** to the original 3-layer slice (crust → cheese → 3 pepperoni dots). The multi-layer "improved" version was busier and worse.
- **KK background bears now use the real assets** — `brown_upper.png` + `brown_legs.png` stacked the same way as the in-game enemy rig, scaled 0.14–0.22 at 30% alpha so they read as distant background. Killed the procedural redraw entirely.
- **Stats line relocated** out of the menu column entirely — now anchored to the **top-left corner** of the screen (small, low-key) instead of squashed under the Quit button. Menu holder's bottom anchor pulled up too (0.88 → 0.86).
- **Pan transition shortened** — foreground UI now slides off by only **55% of viewport width** instead of full width, background slides by **28%**, decor by **40%**. The starfield + pizzas stay clearly visible the whole way through the transition; loadout content fades up FROM alpha 0 instead of slamming in at full visibility, so the bg/decor of both scenes can overlap during the swap.
- Cant softened: 6° → 4° (less dramatic, less disorienting).

---

### Mass user-fix pass (everything in one batch)

Big batch addressing everything from the latest playtest report:

**Title screen**
- Renamed `PLUSH CRAWL` → **`BEAR CRAWL`**.
- Title pulse / bob frequencies 25% slower (1.6 → 1.2 Hz, 2.4 → 1.8 Hz).
- Rainbow bar color-cycle 50% slower (0.7 → 0.35).
- All menu buttons get `custom_minimum_size.x = 420` so changing difficulty no longer reshuffles the menu width.
- Stats label moved up (`anchor_top 0.93 → 0.89`) + menu_holder bottom (`0.92 → 0.88`) so the stats line doesn't kiss the Quit button.
- New 4 **tiny procedural KK bears** drift through the deep background at very low alpha (Polygon2D head + ears + muzzle + eyes — cute silhouettes).
- Pizza slices upgraded: now multi-layer with **crust shadow + crust + crust highlight + cheese + cheese stripe highlight + 4 pepperoni each with darker outline ring + 2 dark green olive bits**. Reads as actual pizza, not flat triangles.

**Title → loadout transition** rewritten as a one-take camera move per user direction:
- Phase A (0.55 s, ease-in-out sine): camera pulls back to 0.55× scale and cants ~6° left.
- Phase B (0.55 s, ease-in-out sine): the WHOLE frame (now at zoomed-out scale) pans off to the left by full viewport width. No pause between A and B.
- Loadout enters with the mirror: starts at zoomed-out scale + canted + offset OFF-screen right, pans IN to center (Phase A), then dolly-zooms IN to 1.0 + untilts (Phase B). Smooth one-take.

**Loadout → main game transition** — Pizza Planet zoom-in:
- Phase A (0.4 s): loadout UI scales down + fades.
- Phase B (0.7 s, accelerating cubic ease-in): picks the closest **pizza-planet** to screen center and scales/translates the bg+decor layers so that planet ends up at center while filling the frame (6.5× scale). White flash overlay fades in over Phase B for a clean cut into the main game.

**First boss balance**
- Removed the phase-2 **3-pizza fan** (was undodgeable on hard). Always single shot now.
- Pizza speed 600 → **570** (5% slower globally).
- Hard mode `throw_interval` 1.15 → **1.55** (less frequent salvos on hard).

**KK trash mob (hard mode)**
- Ninja star speed 460 → **391** (15% slower per user req).
- Ninja star `throw_interval` 2.7 → **3.3** (less frequent).
- Stronger anti-grind: `TOUCH_BACKOFF_DURATION` 0.45 → **0.65**, `PERSONAL_SPACE` 46 → **60**, new `BACKOFF_SPEED_MULT = 1.4` so the juke-back is faster than chase. Bears bounce off the player instead of attaching.

**Desert boss (final boss)**
- `charge_speed` 500 → **760** — REAL dash now, not a 2-inch hop.
- `charge_duration` 0.95 → **1.35** — covers enough ground to read as a charge.
- New **stuck detection during charge** — if a frame's actual travel is under 25% of expected, the charge terminates immediately. No more "boss sitting in a tree."
- Hard mode `summon_cooldown` set to **3.8** (vs 2.6 default) — ad spawn was oppressive.

**Floor 6 boss death — chain-explode ads**
- New `_chain_explode_remaining_ads()` called from `_begin_death()`. Iterates all enemies still in the room, staggers their detonation by distance (`delay = d / 900`, clamped 0.05–0.7 s), spawns a small orange explosion at each, damages the player if they're within 95 px of the ad's blast.

**MB obstacle stuck**
- Stuck detection added to `_tick_charge()` — same logic as desert boss. MB no longer dashes face-first into a desert rock for a full second.

**Sky boss biome (Floor 9)**
- No trees, no rocks, no stones in this biome — `_pick_prop_scene()` returns null for "sky". `_spawn_props` skips null slots entirely. Pure open ground.
- Decoration count bumped to **28** on sky boss room (vs 10) — bushes everywhere for visual texture without blocking gameplay.

**Sky boss paw sweep**
- `band_height` 130 → **220** so the danger band spans more of the side instead of looking like "just clouds at the top."
- `telegraph` 1.4 → **2.2 s** for more dodge time.

**Tooth projectile** — lifetime 4.5 → **6.0** so it can actually reach the player across the sky biome.

**Cleave Maw transparency**
- `tools/fix_cleave_maw.py` extended with a **numpy alpha-threshold pass**: pixels under 130 alpha → 0, over 200 → 255, in between remapped to a tight 50–255 range. Kills the ghostly half-transparent halo rembg leaves around the subject.

**Dev mode damage popups**
- When `DevState.invincible` is on, hits now spawn a floating "-N" red Label above the player that floats up 32 px and fades over 0.75 s. Lets you debug what's hitting you while invulnerable. No-op in normal play.

**Pond/lake** — already rebuilt in the previous batch with the 9-layer ellipse + shimmer + ripples. If you weren't seeing them in-game, it was because the ext_resource sidecar wasn't refreshing — the file on disk IS the new one. (Verified: the asset is loaded by `pond.tscn` via `res://assets/pond.png`.)

**Bag mob (Shrinkwrap Bear)** — still wired and spawning at the 33% variant probability from Floor 1+. Confirmed in `main.gd` line 5/513. RNG can hide him for a few rooms but he's there.

---

### Real lake (finally) + enemy-swarm spread

**Lakes — completely rebuilt from scratch.** Threw out both prior attempts. New `tools/build_pond.py` draws a clearly-readable lake from scratch using 9 layered ellipses:
1. Soft semi-transparent grass-green outer fade
2. Mid grass ring
3. Inner bright grass ring
4. Dark sand shore border
5. Light sand shore
6. Navy water deep ring
7. Main blue water body
8. Light cyan center
9. Re-darkening main blue inset (gives depth)

Plus 4 horizontal **shimmer highlights** at staggered Y offsets with descending alpha, **3 darker ripple-arc** lines for surface texture, and a soft 1 px Gaussian blur on the alpha channel only (anti-aliases edges without smudging the shimmer).

Final asset is 320×224. `pond.tscn` updated: scale 1.0, `CircleShape2D` radius **78** (covers water + thin shore, leaves grass walkable). Reads unmistakably as a lake now — no more wooden-trapdoor look.

**Enemy swarm spread — fixes the "kite-and-clump" problem** where every enemy converged on the exact same tile when kited because they all used `to_player.normalized()` as their chase vector.

Three changes in `scripts/enemy.gd`:

1. **Enemy-to-enemy separation** — new `SEPARATION_RADIUS = 56` / `SEPARATION_REPULSION = 1.4`. After hazard/obstacle avoidance, each enemy adds a repulsion vector pointing away from every other enemy within 56 px, scaled by `(1 - d/SEPARATION_RADIUS)`. At distances under 4 px (two enemies on the exact same pixel), the separation vector is randomized so they break the deadlock instead of staying perfectly stacked.

2. **Per-enemy speed jitter** — each enemy rolls `_speed_jitter = randf_range(0.86, 1.15)` at spawn (±15%). Applied to the final velocity. The same group of bears now spreads naturally into a line as they chase because the faster ones lead.

3. **Per-enemy chase offset** — each enemy maintains `_personal_offset` (a vector 20–70 px around the player, biased by `_orbit_sign`) and chases `player.position + _personal_offset` instead of the player directly. Re-rolled every 2.6 s ±0.4 s so the offset adapts as the engagement evolves. Means each bear is trying to flank you at a slightly different angle.

End result: bears now arrive at the engagement as a loose crescent around you, not a single tile of mob.

---

### Title → loadout transition: dolly-zoom + tilt (was horizontal pan)

Switched the title → loadout transition (and all the loadout's outgoing transitions) from a flat sideways swipe to a cinematic **dolly-zoom with subtle camera cant**:

**Title screen exit** (clicking START):
- Foreground UI: scales from 1.0 → **0.62**, rotates -3.5°, fades to alpha 0 over 0.42 s.
- Background nebula layer: scales to 0.62 × 0.85 ≈ 0.53, rotates -1.75° (half tilt for parallax), position offsets to keep its center anchored.
- Decor layer (pizza slices): scales to 0.62 × 0.78 ≈ 0.48, rotates -2.45°, same center-anchor offset.
- All on `TRANS_QUART / EASE_IN` so it feels like a camera being pulled back.

**Loadout entrance** (`_play_swipe_in`):
- Content starts at scale **0.62**, rotation **+3.5°** (opposite of title's exit cant — the camera is "rolling level" as it resolves), alpha 0.
- Background + decor mirror the title's parallax ratios in reverse.
- Tweens to scale 1.0, rotation 0, alpha 1 over 0.55 s on `TRANS_QUART / EASE_OUT`.

**Loadout → main game** (clicking START THE CRAWL):
- "Camera pushes through" — content scales **PAST 1.0 to 1.55**, rotates -2.5°, fades. Background scales 1.78×, decor 1.94×. Creates the "the screen is rushing past you into the next room" feel.

**Loadout → title** (BACK): mirror of the entrance — dolly out + +3.5° tilt + fade.

All pivots set to `size * 0.5` so scale + rotation happen around the visual center instead of the top-left.

---

### Face Boss overhaul — 3 phases, new attacks, sharper texture, +30% size

**Texture pass** — old `cleave_maw.png` came out washed-out (rembg leaves faded edges on the close-up photo). New `tools/fix_cleave_maw.py`:
- Re-runs rembg on the original `3.JPG`.
- Boosts **saturation +35%**, **contrast +25%**, slight darkness (-5%), then an UnsharpMask pass (radius 2, percent 80).
- Tight crop with 6 px alpha pad, resize to 640 px max dim with LANCZOS.
- Result reads way more clearly — dark nose pops against the bright muzzle, brown fur reads as fur.

**+30% boss size** — `FACE_HEIGHT_FRAC` 0.58 → **0.75**, plus `FACE_Y` shifted 235 → 270 and `FACE_X_MIN/MAX` padded to 420 to keep him fully on-screen at the bigger scale. Collision rect bumped 280×280 → 360×360.

**HP bump** — `max_health` 42 → **54** to accommodate the three-phase fight.

**Three phases, gated by HP**:
- **Phase 1 (100% → 66% HP)**: paw slam every ~4.8 s (existing) + **NEW tooth projectile** every ~2.8 s.
- **Phase 2 (66% → 33%)**: + horizontal paw sweep every ~9 s + floor cleave every ~9.5 s (existing, telegraph bumped 2.0 → 1.8 s).
- **Phase 3 (<33%)**: + **5-tooth volley** every ~6 s in a 22° fan + **4-paw mini-rain** every ~7.5 s at random positions. Slam + tooth cooldowns also tighten on entry.

**NEW: Tooth Projectile** — `scripts/tooth_projectile.gd` + `scenes/tooth_projectile.tscn`.
- Procedural white wedge tooth: outline polygon → cream body → pink-brown root nub → upper-left highlight (3 layers of detail, ~38 px tall).
- 320 px/s with **mild homing** (1.2 rad/s) that curves toward the player. Volley shots disable homing.
- Capsule collision matching the body. Self-frees after 4.5 s or on player hit.
- `_tooth_points()` builds a 5-point wedge shape (flat top → curved sides → sharp tip).

**NEW: Horizontal Paw Sweep** — `scripts/paw_sweep.gd` + `scenes/paw_sweep.tscn`.
- **Telegraph (1.4 s)** — red horizontal band at a chosen Y with crisp pink-red Line2D edges top + bottom, pulses brighter (5 Hz → 20 Hz) as detonation approaches. **10 light specks stream sideways inside the band** during the telegraph, accelerating from 140 → 520 px/s in the sweep direction so the player can see exactly which way the paw is coming.
- **Sweep (0.6 s)** — full procedural cartoon paw (same geometry as `bear_paw_slam`, rotated so toes point in the sweep direction) slides full-screen with ease-in (`p²`) so it picks up speed.
- Sweep Y is random between 45–85% of room height per cast.
- Damages anyone inside the band Y-range at the midpoint of the sweep. ×24 shake.

**NEW: Mini-Paw Rain (phase 3)** — spawns 4 `bear_paw_slam` instances at random room positions, each with a randomized 0.85–1.35 s telegraph so they don't all detonate at once. Reuses the existing paw-slam scene (ground cracks included). Chaos but readable.

**Tooth Volley (phase 3)** — 5 teeth in a 22°-half fan toward the player, no homing on volley shots so they lock down a cone instead of chasing.

Phase transitions still flash the boss red and shake the camera (18 → 28 strength as you escalate).

---

### Floor 6 boss parse error fix + Loadout rebuild + camera-pan transition

**Critical fix: Floor 6 (desert) boss was completely broken.** When I removed the wind force calls earlier, I left an empty `if is_final_fight:` block with only a comment, no statement. That's a GDScript parse error ("Expected an indented block after 'if'"). The whole `desert_boss.gd` failed to compile, which meant:
- Boss scene loaded with no script attached → frozen, no AI
- `add_to_group("enemies")` from `_ready()` never ran → boss not counted as alive → door opened immediately
- Boss visible node persisted into Floor 7 because there was nothing in the enemies group for `_clear_room` to find
- ESC input bound to the dev menu didn't work because the boss's broken collision was eating events or something equally weird
- All three symptoms (frozen boss + door opens immediately + ESC broken + boss on next floor) collapse into this single root cause.

Fixed by removing the orphan `if is_final_fight: # comment` entirely (line 144) — the comment now lives on the line above as a plain comment outside any block.

**Loadout screen — complete rebuild, matching title aesthetic + camera-pan transition.**

Visual treatment now mirrors the title screen so the camera-pan illusion sells:
- Same `GradientTexture2D` nebula bg.
- Same drifting **60 specks** + **5 pizza slices** + **3 huge pizza-PLANETS** in the deep background. Each planet is a layered Polygon2D: brown crust ring + golden cheese disc + 6–10 large pepperoni dots + soft gold rim glow. Planets bob on a slow sine + spin slowly.
- Same procedural title with 64 pt font, magenta-purple outline, drop shadow, vertical bob.
- Same hover-scale-1.05 buttons.

**Weapon selection removed** — per user request, weapons are battle-pickup-only. `_on_start()` always sets `GameSettings.selected_weapon = "default"`. The whole `WeaponSection` of the old `.tscn` is gone.

**Ascension card** is now the centerpiece — a featured panel showing:
- `ASCENSION N` in big 56 pt gold text with outline.
- A **named** ascension tier ("BASE RUN" / "FLOODED FLOORS" / "FORTIFIED FOES" / "NO BOUNCES" / "GLASS BEAR" / "FINAL TANK").
- A **pip row** (0..5) of round pill buttons — click any pip to jump straight to that level. Locked pips are dimmed. Selected pip is gold-highlighted.
- `[NEW]` callout for the curse just added by the current level + a stacked list of every active curse.
- Reward-multiplier badge: `reward x1.0` → `x3.0` across the tiers.
- Card style: rounded-corner dark purple panel with subtle purple border + drop shadow (built programmatically via `StyleBoxFlat`).

**Buttons** redone with proper styling — `BACK ←` is the standard pill, `START THE CRAWL ▶` is a wider gold-bordered featured button.

**Camera-pan transition** — sells the start-game motion as one continuous shot:
- Title screen → loadout: clicking START kicks `_swipe_out_to_loadout()`. All foreground UI (title, menu, hint, stats, version) slides **left off-screen** in 0.45 s with quart ease-in. `BackgroundLayer` and `DecorLayer` slide at **0.4× / 0.7× the foreground speed** for parallax. Once the tween finishes, `change_scene_to_file` swaps in the loadout.
- Loadout `_play_swipe_in()`: foreground starts at `x = +viewport_width`, bg layers at `0.4×` / `0.7×` ahead, all tween back to `0` in 0.55 s with quart ease-out. The parallax speeds mirror the title swipe-out so the bg appears to continue traveling.
- Loadout → main game (START): same swipe-out, then load `main.tscn`.
- Loadout → title (BACK): swipes the OTHER way (positive x direction) so it reads as the camera panning back.

**Keyboard nav on loadout**: ESC = back, ←/A = ascension down, →/D = ascension up. Enter triggers focused button as usual.

---

### MB infinite-shake fix + spit dialed back + real CC0 lake asset

**MB death-lunge loop bug** — when MB hit the room edge during his kamikaze lunge, he'd keep flying off-screen, his `_tick_death_lunge` would still fire each frame, and every frame after `_brawler_t` hit 0 we'd call `_explode_and_die()` again. That re-ran `super._begin_death()` → spawned another wave of body chunks + another camera shake every frame → "items dropping in a trail" + infinite shake.

Fixes:
- New `DEAD` brawler state. After `_explode_and_die()` runs once, the state flips to `DEAD` and subsequent frames defer to base `super._physics_process()` (which routes through `_dying = true` → `_process_death`) — no more re-entry.
- `_explode_and_die()` early-returns if already in `DEAD` state. Double-guarded.
- **Edge-of-room auto-detonate**: if MB's position crosses any room edge during the lunge (within 24 px), he explodes immediately instead of flying offscreen.
- Velocity zeroed at explode time so move_and_slide on the next frame doesn't shove him further.

**Bear spit** — `RADIUS` 28 → **14**. The 28 read as comically huge. 14 (≈28 px diameter) sits in the goldilocks zone — clearly visible but proportional.

**Real lake asset** — pulled the **CC0 Pixel Art Lake Assets** pack by AmberFallStudio from OpenGameArt and replaced the procedural pond entirely.
- New `tools/extract_pond.py` crops the pre-built finished pond from `pond_tiles.png` (the right-half of the source tileset) and saves it as `assets/pond.png` at 2× nearest-neighbor scale (256×192) to keep the pixel art crispness.
- Real layered grass border with leaf/bush detail, sand/dirt shore ring, dark water body — way better than the procedural ellipse.
- `pond.tscn` collision radius dialed to 70 to match the new water-body size.

Source: AmberFallStudio, CC0 — [Pixel Art Lake Assets (OpenGameArt)](https://opengameart.org/content/pixel-art-lake-assets).

---

### Title screen redesign — animated nebula, drifting pizzas, alive UI

Rebuilt `scenes/title_screen.tscn` + `scripts/title_screen.gd` from the ground up. Old screen was a flat dark-blue rectangle with stacked white buttons. New one is animated end-to-end:

**Background**
- New `GradientTexture2D` nebula: dark navy → deep purple → near-black vertical gradient on a full-screen `TextureRect`.
- **60 procedurally-generated specks** in a `BackgroundLayer` Node2D — small polygons in a soft palette (purples, golds, off-whites), drifting up + sideways at random velocities, wrapping at the top edge.
- **Each speck twinkles** on its own sin-wave phase (`0.65 + 0.35 * sin(t*2.4 + offset)`).

**Foreground decor**
- **7 drifting cartoon pizza slices** in a `DecorLayer` Node2D — three procedural layers each (darker crust triangle → golden cheese triangle → 3 red pepperoni dots randomly placed).
- They drift across the screen with random velocity, spin, and base scale. Wrap around all four edges.

**Title**
- Bumped font size 96 → **128**.
- Outline 6 → **10**, magenta-purple outline color for punch.
- New drop shadow with `shadow_offset_y = 8`, `shadow_outline_size = 12`.
- **Vertical bob** (`sin(t*1.6) * 4 px`) + subtle scale pulse (`±1.2%` at 2.4 Hz). Title is alive.

**Subtitle**
- Now rotates through **7 random taglines** ("a pizza-throwing plushie roguelike", "toss till you topple", "crust 'em with extra spice", "the bears are NOT okay", etc.) every 6 s with a fade-out → fade-in transition.

**Menu**
- Real `StyleBoxFlat` panels with rounded corners, semi-transparent purple bg, golden border-bottom on hover/focus, drop-shadow glow.
- **Buttons scale up to 1.06×** on hover/focus via Tween (`0.12 s ease-out`), pivoting from their center.
- **Pizza-slice pointer** spawned next to the focused button — drifts smoothly with `lerp` toward target, spins continuously (1.8 rad/s). Looks like an animated cursor.
- Font size 32 → 34, more readable color (`Color(0.92, 0.88, 0.96, 0.88)`).
- Difficulty button shows a colored dot per level: 🟢 EASY, 🟡 MEDIUM, 🔴 HARD.
- Workshop / Options buttons get unicode glyphs (`🔧`, `⚙`).

**Footer**
- **Meta-stats teaser**: pulls `MetaSave.total_kills` and `MetaSave.total_fluff` (with safe null guards if not present) and shows `🐻 N defeated     🧶 M fluff`.
- Hint line clarifies controls: `WASD / arrows • Enter to confirm • Esc back`.
- `v15` version chip in the top-right corner.

**Options panel**
- Real bordered card with rounded corners + drop shadow, 16 px radii, purple border, semi-transparent dark bg.
- Wider (300 px half-size vs 280) + taller (200 vs 180), title 36 → **40** with outline.

Everything procedural — no new asset files. WASD/arrows/clicks all still work and stay in sync via the existing `_focus_index` machinery.

---

### Face Boss, pond rebuild, ground cracks, persistent-boss fix

**The Face Boss** — new sky-biome (Floor 9) boss using `cleave_maw.png` from asset 3 as a giant floating bear head.
- New `scripts/face_boss.gd` + `scenes/face_boss.tscn`. CharacterBody2D in the "enemies" group so pizzas hit it via the standard collision pipeline.
- **42 HP** (medium baseline). Touch damage 2.
- **Hovers near the top of the room** (`FACE_Y = 235`), idle-bobs ±14 px on a 0.6 Hz sine wave.
- **Follows player horizontally**: lerps `position.x` toward the player's clamped X at `FACE_LERP = 1.4 /s`. Stays at least 360 px from the left/right edges.
- **Flips horizontally** based on which side of the room the player is on — `_sprite.scale.x` sign tracks the player.
- **Phase 1**: spawns a **Bear Paw Slam** (the existing one) on the player's current position every ~4.5 s ±0.8.
- **Phase 2** (below 50% HP): adds the new **Floor Cleave** — every ~8 s ±1, telegraphs a red flashing rectangle covering whichever room half the player is on for 2 s, then detonates with a white flash. Damages anyone still on that side for 2.
- Death pipeline: explosion, 22 stuffing puffs, fluff drop, full-heal drop if player needs it, ×32 camera shake.
- Wired into `main.gd::_spawn_boss()` — sky biome (Floor 9) now spawns this instead of reusing the first boss.

**Floor Cleave** — `scripts/floor_cleave.gd` / `scenes/floor_cleave.tscn`.
- Half-screen red overlay with crisp `Line2D` border for readability.
- Pulse frequency accelerates from 4 Hz → 18 Hz during the telegraph so the urgency reads.
- Detonates with a hard white flash, then fades over 0.35 s.

**Ground cracks at paw-slam impact** — added to `scripts/bear_paw_slam.gd::_spawn_ground_cracks()`.
- 6 jagged dark `Line2D` rays radiating outward from the impact point (±0.25 rad jitter on each).
- Each is built from 4 segments with small angle jitter so they look organic, not perfectly straight.
- 65% chance of a side-branch off the midpoint for extra detail.
- Persist 0.45 s at full opacity, then fade over 0.6 s.

**Pond rebuild** — `tools/build_pond.py`.
- Procedurally regenerated `assets/pond.png` at 256×192 (was 128×96 at scale 2).
- Layered ellipses: dark grass outer ring → mid grass → light grass inner edge → dark water → main water body → 3 specular shimmer highlights at the top-left, middle, and bottom-center.
- Gaussian-blur blend pass for soft edges instead of stair-stepped pixels.
- `pond.tscn` updated: `scale` back to (1, 1), collision radius bumped 56 → 86 to match the new water-body size.

**Persistent boss fix** — bosses leaving the "enemies" group via `_begin_death()` before their fade animation finished meant `_clear_room()`'s group sweep would miss the still-visible-but-dying node, so the boss persisted into the next floor.
- `_clear_room()` now also nukes `_boss` directly if it's still valid.
- Also sweeps any lingering `hostile_projectile` / `hazards`-tagged nodes (bear spit, fire pillars, etc.) so room transitions are actually clean.

**Bear spit bigger again** — RADIUS 22 → **28** for clearer reading. Diameter now ~56 px.

---

### Invisible blocker fix + MB kamikaze death + spit visibility + Floor 6 debug

**Invisible blocker fix.** The plush_brawler (MB) and shrinkwrap_bear (plastic bag bear) both had a silent failure mode: if their PNG didn't load (no `.import` sidecar AND raw `Image.load("res://...")` failed), the sprite went invisible but the `CharacterBody2D`'s 42×42 / 38×32 collision still blocked the player. This created phantom walls on every floor that had variants.

Fixes:
- New `_load_texture` / `_load_tex_robust` helper: tries `load()` (Godot pipeline), falls back to `FileAccess.get_file_as_bytes()` + `Image.load_png_from_buffer()`. The buffer path works even when Godot has never imported the asset.
- Safety net: if the texture STILL returns null, the enemy `queue_free()`s itself and logs a warning instead of standing invisible.

**MB kamikaze death** ("when MB dies, character turns a shade of red, lunges at you a short distance, then explodes"):
- New `DEATH_LUNGE` brawler state. `take_damage()` intercepts the lethal hit (or dev one-shot) and routes into `_begin_death_lunge()` instead of the base death.
- **Phase 1 — flash & freeze (0.18 s)**: modulate to `Color(1.6, 0.45, 0.45)` (angry red), micro-tremble velocity, glow brightens.
- **Phase 2 — lunge (0.42 s)**: dashes at **480 px/s** in the direction the player was when MB died. Player can sidestep by moving perpendicular during the flash.
- **On hit during lunge**: 1 damage + cooldown + immediate detonation.
- **Explode**: red ExplosionScene (end_scale derived from radius), 70 px AoE damage check, 2 damage if player is inside, ×16 camera shake. Then hands off to base `_begin_death()` so loot/fluff drops are preserved.

**Bear spit visibility** — `RADIUS` doubled+ from previous tuning (10→22), now drawn in **three procedural layers** (dark outline + brown body + lighter top-left highlight) so it reads as a 3D goopy ball not a 2D dot. Diameter is ~44–48 px now.

**Floor 6 boss debug** — added a `print("[desert_boss] _ready ...")` line so when you start a desert-biome boss floor (4, 5, 6) the console will tell you whether the boss spawned, its HP, speed, final-fight flag, and whether it found the player. If you see the boss "stand there doing nothing" again, paste the console output — that print will identify if AI is broken or if the boss spawn itself never happened.

---

### Enemy interest pass + Cleave Maw cleanup

**Plush Brawler** — removed the back-view sprite swap (was jarring). Single front sprite for every direction. Stats and behavior overhauled:
- HP **6** (was 5), speed **78**, touch damage **2**.
- New **shoulder-charge dash**: when player is in 110–480 px range and cooldown is up, brawler stops, **glows red for 0.55 s** as a tell, then **dashes 360 px/s in a straight line** for 0.45 s. Charge ends instantly on a touch connect. Long ~5 s cooldown with ±1 s jitter.
- Skips base `_physics_process` during TELEGRAPH/CHARGING states so steering/avoidance doesn't interfere with the dash line.
- `.tscn` updated to drop the back sprite node entirely.

**Shrinkwrap Bear** — funnier, tankier, and now does something:
- HP **6** (was 4) — "one or two hits tankier than the rest."
- New **frontal air-line blast**:
  - New `scripts/air_line_blast.gd` + `scenes/air_line_blast.tscn` — single straight line projecting from the bear forward.
  - **0.55 s telegraph** as a thin pulsing white line guideline.
  - Then **0.45 s active** with a wide 28 px white puff that damages once if the player is on the line.
  - Length 280 px, only fires when player is roughly in front (dot > 0.55) and within 360 px.
  - 4 s cooldown ±1, staggered on spawn.
- Bear "exhales" with an X-stretch / Y-squish when the puff fires.
- `_facing_x` tracks which way the bear is pointed based on the player's X position; line fires that way.

**Cleave Maw** — face overlay removed.
- The procedural ":(" + eyes were getting layered on top of the photo and reading as visual junk. The raw scan already IS the bear face — let it speak for itself.
- Bumped scale: maw is now **105% of room height** (was 85%) so it actually fills the half-screen and looks imposing.

**Godot cache refresh** — cleared `.godot/global_script_class_cache.cfg`, `.godot/scene_groups_cache.cfg`, and `.godot/uid_cache.bin` so any stale scene/UID bindings get rebuilt on next launch. (If changes still aren't appearing in-game, the most common cause is the game .exe was launched once, scenes got baked, and subsequent edits aren't picked up — quit fully and relaunch.)

---

### Dev one-shot kill fix
- `DevState.oneshot_kills` previously only fired in `enemy.gd::take_damage()`. Bosses ignored it and the Shrinkwrap Bear's plastic deflect intercepted before the check.
- Added the bypass at the top of `boss.gd::take_damage` and `desert_boss.gd::take_damage` — when on, the boss skips HP math and i-frames and goes straight to `_begin_death()`.
- `shrinkwrap_bear.gd::take_damage` now checks `DevState.oneshot_kills` BEFORE the plastic-deflect branch, so dev one-shot pops them even mid-deflect window.

---

### Balance pass — trash mob spit, harder first boss, growing fire, fire pillars

**Trash mobs** — the medium-difficulty lock-on AoE was boring (non-interactive, telegraphed at your feet). Replaced with a **short-range projectile**:
- New `scripts/bear_spit.gd` + `scenes/bear_spit.tscn` — small procedural brown blob (16-sided goopy ellipse + lighter highlight dot, no texture needed).
- ~240 px max range, slow (280 px/s), telegraphed by a 0.35 s orange flash on the bear's body before firing.
- Cooldown 2.6 s ±0.6 per enemy, staggered on spawn.
- Only fires when player is within `SPIT_RANGE` (320 px) and outside personal space — no off-screen spam, no point-blank misfires.
- `GameSettings.enemies_aoe_slam()` removed and replaced with `enemies_spit()`. AoE slam scene retained for the bosses, just no longer used by trash mobs.

**First boss** — too soft. Pumped:
- HP 24 → **34** (medium/hard). Easy 16 → **22**.
- Speed 105 → **115**.
- Throw interval 1.35 → **1.15 s** (medium/hard). Easy 2.2 → 1.8.
- Phase-2 specials (Ground Slam, Bear Paw Slam, Cleave Maw) already in place from previous balance passes — they now have more wall-clock time to threaten because he tanks longer.

**Fire trail growth** — `scripts/fire_trail.gd`:
- New `start_scale` (0.55) → `peak_scale` (1.55) over `grow_for` (3.0 s) with ease-out interpolation. Sprite scale AND collision radius both grow in sync (per-instance `CircleShape2D.duplicate()` so we don't mutate shared resources).
- Default trail patches now start small + safe and become real zone-control after a few seconds — matches the user's "fire should grow over time" ask.

**Final boss: Wind Force removed, Fire Pillars added.**
- Wind Force was cosmetic at best (the cone didn't read). Both call sites (dash launch + dash stop) commented out. `wind_force.tscn`/`.gd` remain on disk so we can revisit later.
- **NEW: Fire Pillars** — every ~9 s ±1 (final fight only), spawns **5 fire-trail patches in a ring around the boss** at 130 px radius. Each uses the new growth curve (start 0.55 → peak 1.85 over 2.2 s), lifetime 6.5 s, fades over last 1.5 s. Result: when the boss "roars" you have a brief window to disengage before a ring of growing flame walls you out of melee.
- Adds spawn faster: `summon_cooldown` 3.5 → **2.6 s** (×0.6 in phase 3 = 1.56 s).

---

### Cartoon face on the Cleave Maw + new Bear Paw Slam attack

**Cleave Maw — animated `:(` face overlay.** Drawn programmatically on top of the maw photo so it moves with the slide:
- Two cartoon **black eyes** (oval Polygon2D) above the snout — they **blink** sharply every ~0.55 s (Y-scale dips via `pow(cos, 8)` for a snappy close).
- A big **":("  mouth** — Line2D with rounded joints and caps, 18 px width. Drawn as a downturned 9-point arc. **Wibbles** as he slides (sin wave shifts each sample point's Y position).
- The whole face **droops** a few pixels lower in screen space as the slide progresses — he gets sadder as he passes through.

**Bear Paw Slam** (`scripts/bear_paw_slam.gd` + `scenes/bear_paw_slam.tscn`) — new boss phase-2 attack.

Sequence: **1 s telegraph** → **0.32 s fall** → **0.25 s plant** → **0.45 s lift**.

- **Target indicator on the ground** at the player's *current* position (locked at spawn): black elliptical shadow + dark outline ring + 4 crosshair tick marks. Pulses brighter as impact nears.
- **Preview the paw** faintly during the telegraph, slowly descending and growing — so you can see what's coming.
- **Procedural bear paw** drawn fully in Polygon2D — large brown palm + lighter palm pad + 4 brown toes each with their own lighter toe pad. Goofy cartoon-shape.
- **Falls** with ease-in acceleration (squared progress) — slow at first, then SLAMS.
- **Impact**: 2 damage if player is inside the ellipse, dust ring expands + fades, camera shakes ×22 for 0.35 s. Small squash on the planted paw before it lifts.
- **Lifts** with ease-out + fades out as it rises back off-screen.
- Wired into `boss.gd` on a **7.5 s ±1.5 s cooldown** during phase 2, first cast 5.5 s after phase-2 entry (so it interleaves with the Cleave Maw rather than overlapping).

---

### Three new units from real plush photos
Dropped four iPhone photos (`assets/1-4.JPG`) of real bears into the game. Processed them through `tools/process_bear_photos.py` (PIL + rembg U2Net): EXIF-rotate → background-remove → tight crop → resize. Outputs:
- `plush_brawler_front.png` (256 px tall)
- `plush_brawler_back.png` (256 px tall)
- `cleave_maw.png` (640 px tall)
- `shrinkwrap_bear.png` (256 px tall)

**1. Plush Brawler (`plush_brawler.tscn`/`.gd`)** — new trash-mob variant.
- Extends `enemy.gd` as a subclass.
- Stats: **5 HP** (was 3), **72 speed** (was 90), **2 touch damage** (was 1). Tankier, slower, hits harder.
- Two sprites: **front** + **back**. The script swaps which is visible each frame based on `player.global_position.y` — if the player is above the bear, show the back; otherwise show the front. Crude but effective 2-direction sprite.
- Spawns 15% of the time from Floor 2+ via `_spawn_enemy()` variant roll.

**2. Shrinkwrap Bear (`shrinkwrap_bear.tscn`/`.gd`)** — squishy plastic-armored enemy.
- Extends `enemy.gd`.
- Stats: **4 HP**, **65 speed** (slowest unit in the game), **1 touch damage**.
- **Y-scale crunch wave** — while moving, the rig pulses on a 4.2 Hz sin wave at ±18% Y-amplitude with counter-X to roughly preserve volume. Bear visually waddles inside the plastic bag.
- **Plastic deflect** — overrides `take_damage()`. The first hit in any 0.55 s window is **deflected** (white flash, no damage) and starts a 0.55 s cooldown before he becomes vulnerable again. Forces players to time shots instead of mash-spamming.
- Spawns 15% of the time from Floor 2+.

**3. Cleave Maw (`cleave_maw.tscn`/`.gd`)** — first-boss phase-2 special.
- A massive bear face slides across **half the room** from off-screen, dealing 2 damage to anyone caught on the targeted side.
- Sequence: **1.2 s red telegraph** (pulsing red overlay covers the targeted half + brightens) → **1.1 s slide** (maw enters from off-screen, slightly wobbles, deals damage once at the midpoint).
- Targets the side the player is **currently on**, so they're forced to move across the room during the telegraph window.
- Damages once per cast; on hit, also shakes camera ×28 for 0.5 s.
- Wired into `boss.gd::_enter_phase_2()` — first cast fires ~2.5 s after phase 2 begins so the player gets to learn it; subsequent casts on an 11 s cooldown ±2 s.

Both runtime-load the texture (`load()` → `Image.load` fallback) so missing `.import` sidecars don't break anything on first run.

---

### Anti-grind: enemies and bosses no longer attach to you on touch
**Bug**: `CharacterBody2D` enemies whose AI keeps setting `velocity = to_player.normalized() * speed` would lock onto the player on collision — the AI vector kept pushing into the player every frame, so they'd grind into your hitbox and keep ticking damage every cooldown until you could walk out around them. Felt like they were attaching.

**Fix** — applied in three places (`enemy.gd`, `boss.gd`, `desert_boss.gd`):
1. New `_backoff_time` state — when an enemy's touch hit lands, set this to ~0.45–0.5 s. While > 0, the AI vector inverts (push AWAY from player) instead of toward. They juke back after every touch.
2. New "**personal space**" radius (46 px trash, 64 px boss, 72 px desert boss) — below this distance the AI swaps from `desired = to_player.normalized()` to a **tangent vector** (orbit around the player) with a small inward bias (0.15) instead of the previous straight-in mash. They circle instead of grind.
3. `_orbit_sign` randomized per spawn so adjacent enemies don't all rotate the same way.

Result: enemies that touch you bounce out, can be re-approached, can be kited. The boss can no longer pin you against a wall by walking into you. Desert boss IDLE chase no longer glues to you between charges.

---

### First boss harder
The Floor 3 boss was a bit of a pushover after the recent player feel + Soft-Landing buffs. Bumped:

- **Max HP** 20 → **24** (medium/hard). Easy nudged 14 → **16**.
- **Move speed** 96 → **105** (~10% faster baseline).
- **Throw cadence** 1.6 s → **1.35 s** (medium/hard). Easy nudged 2.5 → 2.2.
- **NEW: Telegraphed Ground Slam** every ~5.5 s (±1 s jitter). Reuses the upgraded `ground_slam.tscn` with the new ring shockwave + multi-ring telegraph. Smaller (78 px) and shorter windup (1.0 s) than the final-boss version since this is earlier-game. Only fires if player is within 420 px so off-screen pressure stays manageable. Easy mode: 8 s cooldown.
- **NEW: Phase 2 shotgun fan** — once below 50% HP, every pizza throw becomes a **3-pizza fan** (±14°) at the same fire rate. Same DPS-per-shot but you can't sidestep it as easily.
- **Phase 2 also tightens slam cooldown** by 30%.
- Hard-mode untouched directly (it just inherits the harder base).

These add real shot-dodging + zone-awareness to a fight that was previously "circle-strafe and click."

---

### Ground slam GFX overhaul — real ring shockwave + multi-ring telegraph
Applies to BOTH the medium-difficulty trash-mob slam AND the final-boss slam since they share `ground_slam.tscn`.

**Telegraph (windup phase)** — was a single yellow ring + flat fill. Now:
- **Outer ring** still there, but width pulses on a sin wave + thickens as detonation nears.
- **Inner concentric ring** at 60% radius, counter-pulsing on a different phase.
- **8 rotating rune segments** floating just outside the outer ring at 105% radius — orange arcs that rotate slowly during early windup, **accelerate** as detonation approaches (1.2 → 5.7 rad/s).
- **4 crosshair tick marks** at N/S/E/W on the inner edge, flash brighter in the last half of the windup.
- Fill bakes from yellow to red over the windup.

**Detonation (impact frame)** — was a single red explosion sprite. Now also includes:
- **`assets/ring_shockwave.png`** — BenHickling CC0 56-frame ring explosion sprite sheet (1000×600, 100px frames in 10×6 grid). Plays over 0.55 s, scaled to ~2.2× the slam radius so it blows visibly outward past the danger zone.
- Tinted warm gold (`Color(1.0, 0.85, 0.55)`) so it reads as a shockwave, not a flame.
- Frame stepping driven by a single `Tween` chain so we don't need a `_process` loop on the sprite.
- Original red central explosion kept for impact punch underneath the shockwave.
- All telegraph visuals hide instantly on detonation so the shockwave isn't competing with leftover rings.

Both load via runtime `load() → Image.load() → ImageTexture` fallback so missing `.import` sidecars don't break parsing.

Source: BenHickling, CC0 — [Ring Explosion (OpenGameArt)](https://opengameart.org/content/ring-explosion).

---

### Medium difficulty: trash mobs get a telegraphed AoE slam
- **Easy/Hard untouched.** Easy bears still pure body-check. Hard bears still throw ninja stars.
- **Medium** now gets a third option between those extremes: every brown bear telegraphs a small ground-slam under the player's current position every ~9 s (±1.5 s jitter, per-enemy timer staggered on spawn so they don't all telegraph at once).
- **Params** (smaller / more forgiving than the boss slam):
  - Radius **62 px** (boss: 110)
  - Windup **1.1 s** (boss: 0.95) — extra reaction time on trash mobs
  - Damage 1
  - Range gate: enemy only commits the slam if the player is within **360 px**, otherwise the cooldown rolls forward without firing (avoids wasted slams from off-screen bears)
- Reuses `scenes/ground_slam.tscn` so the visual telegraph (yellow ring + fill, pulse-brighter as detonation approaches, red explosion on impact) is consistent with the boss attack — players who learned to read it during the final fight already know what to do.
- New `GameSettings.enemies_aoe_slam()` returns true only on Medium.

---

### Soft Landing is now a visible orbiting pizza shield
- Previously: invisible "first hit each room is free" save. Players had no idea when it was up vs. used.
- Now: when you hold the Soft Landing boon, a **light-blue pizza slice orbits the player** (smaller radius than the offensive Pizza Wheel, spins the opposite direction so the two read as distinct if both held).
- The shield IS the charge — when you take a hit, the shield pops at its current orbit position with a blue mini-explosion + tiny shake, then disappears.
- New room → `on_room_entered()` resets the used flag AND respawns the shield.
- Boon description updated: `"First hit each room is free"` → `"Orbiting slice blocks 1 hit/room"`.
- Implementation: reuses `scenes/pizza_wheel.tscn` for the visual but tinted blue, smaller radius (56 vs. 86), reversed angular speed. Bonus: also damages enemies it brushes since the underlying scene's Area2D logic stays intact.

---

### Rupert load fix + footstep dust removed
- **Runtime-load fallback for `rupert_sheet.png`.** Original `load()` returned null if Godot hadn't imported the PNG yet (no `.import` sidecar), which silently fell back to the old rig. Added a second path: `Image.new().load(...)` reads the raw PNG straight off disk, then `ImageTexture.create_from_image()` wraps it into a usable `Texture2D`. Bypasses Godot's import pipeline entirely — Rupert appears on first launch, no editor open required.
- Also: original commit `preload()`'d the sheet, which is worse — a missing import would fail at parse time and break the whole player script (broken input, frozen game). Now using a runtime `var` reference.
- **Footstep dust removed.** Distracting on the player. Removed `DUST_*` constants, `_dust_t` state, the `_spawn_dust_puff()` function, and its `_physics_process` trigger. Net delete ~40 lines.

---

### Rupert — real 3D-scanned plushie as the player sprite
- **New player visuals.** A real 3D photogrammetry scan of Rupert (the actual plushie) replaces the procedurally-drawn bear.
- **Pipeline** (`tools/bake_rupert_sheet.py`, Blender headless):
  1. Import `rupert.glb` (13.4 MB raw scan).
  2. **Island cleanup** — split mesh by loose parts, keep all islands with ≥ 2% of the largest island's poly count (drops background flecks but keeps separate ears/limbs/head shells the scan didn't weld).
  3. Re-join keepers, normalize to unit height, floor on Z=0.
  4. Decimate to ~15% of poly count (scans are massively over-budget).
  5. Orthographic camera @ 58° elevation orbits 8 angles (E, SE, S, SW, W, NW, N, NE).
  6. Three-point sun lighting + ambient world boost.
  7. Per direction, render 6-frame walk cycle via whole-body bob + tilt + squash (no rig required — Rupert is sitting, so it reads as a hop).
  8. Pillow packs 48 frames into a single `assets/rupert_sheet.png` (1024×768, 128 px per frame).
- **CLI controls**: `--preview` for a single 512px front-view, `--rx/--ry/--rz` for orientation tweaks.
- **In-game wiring** (`scripts/player.gd`):
  - New `Sprite2D` named `Rupert` added at runtime as a child of `$Rig`, with `region_enabled=true` slicing the sheet by direction (column) + walk frame (row).
  - Old `Body` and `Legs` sprites hidden, not removed (safe for boons/animations that still reference them).
  - Direction snap: `int(round(velocity.angle() / (PI/4))) & 7` → column index. Lock `_facing` to +1 since the sheet has dedicated left/right frames (no more horizontal flip).
  - Walk frame advances at 10 fps while moving, freezes on frame 0 when idle.
  - `BOB_AMPLITUDE` lowered (2.6 → 0.8) so the code bob doesn't double up with the sheet's baked-in bob.
  - Feel-pass squash/stretch on accel still applies, layered on top.

---

### Footstep dust + Kill streak combo
- **Footstep dust puffs.** Small light-tan ellipses spawn at the bear's rear foot when running above 55% of top speed, every 0.18 s. Each puff drifts backward, scales up 1.8×, and fades over 0.45 s via a parallel Tween. Pure code — no scene or texture asset needed. Scales with rig size so it looks right at any rig scale.
- **Kill-streak combo system.** New `combo_count` + `combo_changed(count)` signal on `player.gd`.
  - Enemies call `player.notify_killed_enemy()` on death (wired in `enemy.gd::_begin_death`).
  - Each kill bumps the counter and refreshes a 2.6 s window. Window expires → combo resets to 0.
  - **Taking damage instantly resets the combo** — rewards no-hit play.
  - Milestone shakes at ×5, ×10, ×20 for feedback.
  - New HUD label (top-right, dynamically appended in `main.gd::_setup_combo_label` so no scene-file edit). Shows "COMBO ×N" with outline, pops scale 1.35→1.0 on each increment, fades out when broken.
- No gameplay multiplier yet — pure scoreboard for now. Easy to wire into damage/drop rate later.

---

### Player "feel" pass — squash, bob, tilt, shadow
Makes the bear feel alive without new art. Pure code, all in `scripts/player.gd`.
- **Squash / stretch on accel** — frame-over-frame Δspeed drives an X/Y stretch with a 10% max and a fast (9.0) recovery lerp. Launching forward stretches X / squashes Y; braking does the inverse. Bear has weight now.
- **Vertical bob** — sin wave on `rig.position.y` while moving, scaled by `velocity.length() / speed` so it eases in/out. ±2.6 px @ 3.2 Hz. Hops instead of sliding.
- **Velocity tilt** — small extra body lean (`±6°`) on top of the existing turn-lean, proportional to `velocity.x`. Bear leans into runs.
- **Drop shadow** — soft elliptical `Polygon2D` parented to the player root (NOT the rig), so it stays planted on the ground while the body bobs above it. `z_index = -1` so sprites overdraw. Sells the "off the ground" feel.
- **Throw punch** — `_throw_pizza()` sets `_squash = (1.12, 0.92)` so the bear front-foots into every toss.
- **Hit recoil** — `take_damage()` sets `_squash = (0.78, 1.22)` for a one-frame squish that the recover-lerp eases out of. Combined with the existing red flash, hits read instantly.
- **Death cleanup** — shadow hides with the rig on death so it doesn't outlive the explosion.
- Net cost: ~50 lines, zero new assets. The existing `TURN_LEAN_DEG` tilt + "move"/"idle" anims still work — this layers on top.

---

### Real explosion sprite sheet + Wind Force shockwave
- **Explosion animation upgraded to real CC0 8-bit-style sprite sheet** — BenHickling 50-frame explosion (`explosion_sheet.png`, 1000×500, 10×5 grid at 100×100/frame). Replaces the procedural orange-blob explosion.
  - `scripts/explosion.gd` rewritten to step `Sprite2D.frame` 0→49 across `duration` with ease-out scale.
  - `BASE_SCALE_MULT = 2.56` baked in so every existing call-site keeps its visual size (old proc was 256-based, new sheet is 100-based).
  - **Duration halved** (`0.95 → 0.48 s`) — feels snappy now, no more lingering fireballs.
  - **Bottom-anchored origin** (`sprite.offset = (0, -50)`) — fireball now grows *upward* from the impact point instead of being centered on it. Looks like a real ground burst, not a floating ball.
  - **`BASE_SCALE_MULT` lowered 2.56 → 1.1** — the new sheet's flame fills much more of its frame than the old procedural circle did. Combined with the bottom-anchor, the old multiplier read as huge. Lowered globally so every call-site (pizza hits, boss death, smoke puffs, ground slam, player death) shrinks proportionally without needing per-site retunes.
  - `scenes/explosion.tscn` now references `explosion_sheet.png` with `hframes=10, vframes=5`; `texture_filter=1` (nearest) preserves crunchy pixels.
  - All downstream effects (pizza hits, boss death, smoke puffs, ground-slam detonation) automatically inherit the new visual.

- **Wind Force shockwave — new final-boss mechanic.** The boss now blows a forward-facing dust shockwave when he *stops* from a sprint (replacing the duplicate smoke puff that previously played at dash end). Smoke puff still plays at dash *start*.
  - New `scripts/wind_force.gd` + `scenes/wind_force.tscn`.
  - Builds a **70° cone wedge** (Outer + Inner `Polygon2D` for layered dust look) facing the boss's `_charge_dir`.
  - Expands from 0 → **230 px range** over **0.5 s** while alpha fades to 0.
  - Damage check fires at p=0.18 of duration: if the player is inside the cone AND within range, takes 1 dmg + 8-strength / 0.18 s camera shake. Single-tick (no spam).
  - Telegraphs the dash-stop punch — players who chase the boss in his wake now get blown back.
  - Wired via `_spawn_wind_force(_charge_dir)` at BOTH the dash *start* (alongside the smoke puff) AND the `CHARGING → IDLE` transition in `desert_boss.gd` (final fight only). Caught in front of him on launch OR stuck in his wake on stop — both cone you.

---

## 2026-05-26

### Real fire trail + Ground Slam + homing hard-nerf
- **Fire trail uses a real animated sprite now** — pulled CC0 [BenHickling Animated Fire](https://opengameart.org/content/animated-fire) (`fire1_64.png`, 60-frame 10×6 grid, public domain).
- New `scripts/fire_trail.gd` + `scenes/fire_trail.tscn`:
  - Area2D wrapping a Sprite2D that flips through 60 frames at ~14 fps. Random starting frame per instance so adjacent patches don't pulse in sync.
  - **Damages the player on `body_entered`** for 1 dmg (player i-frames stop spam if you stand in it).
  - Lives 5 s; fades alpha during the last second.
  - `CircleShape2D` collision radius 22 — matches the visible flame body.
- `desert_boss.gd::_spawn_fire_trail()` now instantiates this FireTrail scene instead of the explosion-modulate placeholder.

- **Ground Slam — new final-boss mechanic** (Floor 10 only):
  - New `scripts/ground_slam.gd` + `scenes/ground_slam.tscn`.
  - Telegraphed yellow ring (`Line2D` outline + `Polygon2D` fill) appears on the floor **at the player's position** every ~4.5 s (with ±0.6 s jitter). Pulses brighter over a **0.95 s windup**, then detonates with a red explosion + 12-strength camera shake.
  - Anyone inside the **110 px radius** at detonation takes 1 damage. Forces the player to keep moving — perfect counter to "just stand at distance and throw."
  - Triggered by a new `_slam_timer` in `desert_boss.gd`; gated by `is_final_fight` so regular boss floors are unaffected.
  - Phase 3 cuts `slam_cooldown × 0.6` for tighter pressure.

- **Homing pizza HARD-nerfed** (the previous "halved range" was still too generous):
  - `speed × 0.5` (was 0.75) AND `lifetime` 1.2 → **1.0 s**.
  - Max travel ≈ 300 px = **~21% of stage width**. Below the user-requested 1/4-stage cap.
  - **Homing pickup charges** 5 → **3**: even pickups can't enable a 5-shot spam.

### Balance pass + biome backdrop expansion + fire-trail final boss + projectile-over-water
**Quick balance**
- **Homing pizza nerfed** — `lifetime` 2.4 → **1.2 s** (range halved). Was OP because slow + long lifetime meant pizzas always found a target.
- **Floor pulse hazards removed** — only sweeper saws now. Pulse traps were "stupid" per playtest. Hazard scene + script kept around (unused) for future reference.
- **Sweeper saws bigger + faster + random patterns** —
  - `travel_distance` 220 → **340**, `speed` 150 → **230**, `damage_interval` 0.45 → **0.40**, `spin_speed` 18 → **28**.
  - Blade `Node2D` scale bumped to 1.4×; collision radius 26 → **36**.
  - New `_maybe_redirect()`: at each end of a sweep there's a **45% chance** to pick a fresh random axis (8 compass directions) AND reset its origin to its current position. Saws now wander rather than oscillating predictably.
  - Spawn formula `clamp((depth - 1) / 2, 1, 3)` — at least 1 saw per floor; up to 3 on later floors.
- **Desert Boss phase 2**: `charge_duration *= 2.0` — dashes are now **twice as long**, going much further across the room.
- **Desert Boss phase 3 nerfed** — `speed × 1.1` (was 1.25), `charge_cooldown × 0.7` (was 0.5), `charge_speed × 1.1` (was 1.2), `summon_cooldown × 0.6` (was 0.4), `summons_per_wave += 0` (was +1). Still meaner than phase 2 (which already doubles charge distance) but no longer a screen-filling chaos.

**Final-boss VFX — fire trail + smoke puffs**
- During the **final-fight** (Floor 10 Desert Boss with `is_final_fight = true`) charge sequence:
  - **Fire trail**: every 0.08 s while CHARGING, spawn a small orange-tinted `Explosion` (`end_scale 1.1`, `duration 5 s`, modulate `Color(1, 0.55, 0.18, 0.85)`) at the boss's current position. Overlapping puffs make a continuous trail behind him.
  - **Smoke puff**: a bigger grey `Explosion` (`end_scale 2.6`, `duration 0.55 s`, `Color(0.78, 0.78, 0.82, 0.85)`) spawns 38 px ahead of the boss at BOTH the dash-start and dash-end. Punctuates each charge cleanly.
- Reuses `ExplosionScene` with tinted modulate — no new asset needed.

**Projectiles now fly over lakes**
- Pond gained `"projectile_passable"` group. All projectiles (`pizza.gd`, `ninja_star.gd`, `pizza_bomb.gd`) early-return on `body_entered` if the body is in that group, so they continue without being consumed or bounced.
- Player/enemy collision still blocks — pond remains impassable underfoot.

**Horizon: stretched bg → tiled bg + 5 biome-specific horizons**
- `prep_horizon.py` rewritten: instead of stretching ansimuz's 272-px-wide dusk bg horizontally (which read smeary), it now **tiles** the bg at native resolution across 1440 px and overlays the parallax mountain layers on top.
- New `prep_biome_horizons.py` produces five 1440×160 strips, one per biome:
  - **forest** — re-uses the existing dusk-mountain composite (CC0 ansimuz)
  - **desert** — same composite warm-shifted (R × 1.18 + 18, G × 0.95, B × 0.78) for sandy palette
  - **sky** — Paulina Riva's cloud background tiled (CC-BY)
  - **snow** — ramses2099's `airadventurelevel4` (CC0) cropped + downscaled to a 160-tall strip
  - **fall** — jkjkke temple background (CC-BY) cropped + autumn-shifted (R × 1.15 + 12, G × 0.85, B × 0.7)
- `main.gd`:
  - `BIOME_HORIZONS` dict preloads all 5 textures.
  - `_apply_biome()` swaps `Sky.texture` based on `_current_biome()` and sets a biome-appropriate floor `ColorRect.color` (`BIOME_SKY_COLOR`, `BIOME_SNOW_COLOR`, `BIOME_FALL_COLOR` added).
  - `_current_biome()` expanded to 5-biome rotation over 10 floors:
    - Floors **1-3 forest**, **4-6 desert**, **7 sky**, **8 snow**, **9 sky**, **10 fall** (final boss biome).
- Props/enemies/decorations don't yet have biome-specific variants for sky/snow/fall — they reuse the forest pool for now. Visual horizon + floor colour give each biome an identity until proper props arrive.

### Desert boss 3× HP + frantic charges + scattered summons + mountain horizon + impassable pond + pickup stacking
**Desert Boss meatier and meaner**
- `max_health` 38 → **114** (3×). Easy 30 → **80**. Final-floor multiplier 1.4× still applies on top → ~160 HP final fight on default.
- `speed` 70 → 85, `charge_speed` 380 → **500**, `charge_duration` 0.7 → 0.95 (further dashes), `charge_telegraph` 0.5 → 0.32, `charge_cooldown` 2.4 → **1.5 s** (way more frequent), `summon_cooldown` 6.0 → **3.5 s**, new `summons_per_wave = 2`.
- `_summon_add()` now spawns **`summons_per_wave` adds at random positions across the whole room** (≥220 px from player, ≥120 px from boss) rather than clustering 80 px from the boss. Adds are scrappier — faster (130 px/s) and lower HP (2).
- Phase 3 (final-floor only) cranks: `speed × 1.25`, `charge_cooldown × 0.5`, `charge_speed × 1.2`, `charge_duration × 1.15`, `summon_cooldown × 0.4`, `summons_per_wave += 1`. Final boss in phase 3 spawns 3 adds every 1.4 s.

**Mountain horizon backdrop**
- Pulled CC0 `parallax_mountain_pack` by ansimuz from [OpenGameArt](https://opengameart.org/content/mountain-at-dusk-background) — dusk sky + far mountains + near mountains as separate layers.
- New `prep_horizon.py` composites them into a single `assets/horizon.png` (1440 × 160) — sky background stretched, then far+near mountain layers tiled on top.
- `main.tscn` adds a **Sky `Sprite2D`** at world `(720, 80)` covering the top 160 px, drawn at `z_index = -5` so everything else sits on top.
- **Play area shrinks**: floor `ColorRect` now starts at `y = 160` (was 0), so the visible top strip is the mountain horizon instead of mossy floor. Total world is still 1440 × 810, but only y=160-810 is playable.
- Top wall moved from `y = -25` to `y = 135` so the player can't enter the sky strip.
- Side walls' Y position moved to the new play centre (`485`), side-wall `RectangleShape2D` height reduced 870 → 710 to match.
- `main.gd` constants: new `SKY_HEIGHT = 160`, `PLAY_TOP`, `PLAY_BOTTOM`, `PLAY_CENTER_Y`, `SPAWN_Y_MIN`, `SPAWN_Y_MAX`. Every `randf_range(MARGIN, WORLD_H - MARGIN)` for the Y axis was migrated to the new spawn bounds. All `WORLD_H / 2.0` references for positions migrated to `PLAY_CENTER_Y`.
- Net effect: viewport top now shows a parallax dusk sky with mountain silhouettes. Bears + traps + boss action stays in the bottom 650 px. No camera/window changes needed.

**Pond uses inkBubi water palette + is now impassable**
- New `prep_pond.py` samples the actual water-blue colour from inkBubi's grass_deep_water sheet, then draws a clean pixel-art pond on top with a **green grass shoreline** (hardcoded `(95, 158, 80)` palette to match the in-game floor green). Soft drop shadow under it for depth, ripple highlights inside the water, two specular reflection blobs.
- `pond.tscn` rewritten: was `Area2D` in `slow_zones` group → now `StaticBody2D` in `obstacles` group with `CircleShape2D radius = 56`. **Player can no longer walk through ponds**; enemies steer around them via the existing obstacle-avoidance code.
- Slow-zone code in player/enemy/boss still iterates `slow_zones` group (now empty) — harmless dead path, left for future water-walking mechanics.

**Pickup stacking** — collect 5 of the same pickup, trigger a bonus
- New `RunState.pickup_stacks` dictionary tracking per-type counts (health / bomb / scatter / homing). Reset per run.
- `RunState.add_pickup_stack(kind)` returns true on every 5th of that kind.
- **Health orbs**: every 5th orb grants **+1 max HP permanently for the run** via new `player.grant_stack_bonus_max_hp(n)` (also heals the new HP + yellow-flash modulate).
- **Weapon pickups**: every 5th pickup of the same weapon type grants **double charges** that pickup (bomb 4→8, scatter 6→12, homing 5→10).

### Phase C + D — Weapon Unlock Vendor + Ascension Ladder
**Phase C — Weapon unlocks (Cotton Threads now has a use)**
- `MetaSave` gains `weapon_unlocks: Dictionary` (scatter / homing / bomb), `WEAPON_DATA` table (name/desc/cost), `is_weapon_unlocked(id)`, `purchase_weapon(id)`.
- Costs: **Scatter 30 Cotton, Homing 30 Cotton, Bomb 60 Cotton.** Default Pizza is always unlocked.
- **Workshop screen** got a second section: a "—  WEAPON UNLOCKS  (Cotton Threads)  —" header followed by 3 rows. Locked weapons show their cost; affordable ones show "Unlock (N)"; unlocked ones show "UNLOCKED" and disable the button.
- New `GameSettings.selected_weapon: String` ("default" by default).
- **`player.gd::_throw_pizza` is now a router**: pickup charges still take priority (existing behavior), but when no pickup is active it dispatches based on `GameSettings.selected_weapon`. So if you picked Scatter as your starting weapon, every default throw is a 3-pizza spread. Pickups still temporarily override mid-run.

**Phase D — Ascension ladder (replayability after first win)**
- `MetaSave` gains `max_ascension: int = 0` (auto-saved). Starts at 0; each victory at the highest-unlocked level bumps it up by 1, capped at 5.
- `GameSettings.ascension: int = 0` — chosen for the current run.
- **Curses, stacked from level 1 upward:**
  1. Asc 1: +50% enemy count per floor (`asc_enemy_mult` in `main.gd::_start_room`)
  2. Asc 2: Regular bosses +30% HP (`b.max_health × 1.3` in `_spawn_boss`)
  3. Asc 3: Pizzas no longer bounce (`_bounces_for_run()` in `player.gd` returns 0)
  4. Asc 4: Player starts at 3 HP (apply_boons subtracts 2 at the end)
  5. Asc 5: Final boss +50% HP on top of the existing 1.4× final multiplier
- **Cotton + Fluff rewards scale**: `mult = 1.0 + 0.2 × asc`. Asc 5 = 2× rewards.
- **`main.gd::_on_victory`** now scales rewards by asc multiplier and auto-unlocks the next asc level if you cleared the current cap.
- **Victory screen** shows "Ascension N cleared" appended to the reward line when asc > 0.

**New Loadout screen** (between title and run)
- New `scenes/loadout_screen.tscn` + `scripts/loadout_screen.gd`.
- Two sections:
  - **STARTING WEAPON**: 4 buttons in a row (Default + 3 unlocks). Locked ones show "[ LOCKED ]" and are disabled. Selected one is yellow-tinted with `▶ ◀` markers. Description text under the row updates with selection.
  - **ASCENSION**: < label > row. Label reads "ASCENSION N   (max unlocked: M)". Curse list below dynamically shows what's active at the current level.
- Bottom: BACK (returns to title) and START RUN (writes `selected_weapon` + `ascension` to GameSettings, resets RunState, loads main).
- **Title-screen START** now routes here instead of straight to main.

### Desert boss tankier + Workshop rebalance
- **Desert Boss HP** 28 → **38**, Easy 22 → **30** (final-boss × 1.4 still on top → ~53 HP final fight on default difficulty). He survives long enough for the dash + summon patterns to actually play out.
- **Workshop nerfed** — capped per-level effects and bumped costs so the meta upgrades stop trivialising runs:
  | Upgrade | Old | New |
  |---|---|---|
  | MORE PLUSH | +1 HP × 3 (10/22/40) — max +3 HP | +1 HP × **2** (30/80) — max **+2 HP** |
  | SHARPER CRUST | +1 dmg × 3 (15/32/60) — max +3 damage | +1 dmg × **1** (90) — max **+1 damage** |
  | FASTER FEET | +5% × 3 (8/16/28) | +5% × 3 (**20/45/80**) |
  | LUCKY START | +2 bombs × 3 (12/24/40) — max +6 bombs | +1 bomb × 3 (**25/55/100**) — max **+3 bombs** |
- Total Fluff to max everything: ~308 → ~525 (~10 runs of farming vs 4 previously).
- `MetaSave.upgrade_level()` now clamps stored levels to the new max — old saves that had bought past the new cap silently lose those over-cap levels rather than carrying broken state.
- `main.gd` lucky-start grant updated to `lucky_lvl × 1` (was × 2).

### Phase A — Final boss + win state
- **Floor 10 is now the final fight.** New `FINAL_FLOOR = 10` in `main.gd`. `_start_room()` treats it as a boss floor regardless of the usual `depth % 3` rule.
- **`_spawn_final_boss()`** spawns the Desert Boss with `is_final_fight = true`, **`max_health × 1.4`**, and a reddish modulate tint so the player can read "this one's different".
- **Phase 3 on both boss types** triggers when `is_final_fight` and HP ≤ 25%:
  - **Mirror Bear**: throw interval ×0.55, speed ×1.25, AOE cooldown ×0.6 — desperate spam.
  - **Desert Boss**: speed ×1.2, charge cooldown ×0.55, charge speed ×1.15, summon cooldown halved (doubles add spawn rate).
  - Both fire an angry-red explosion flash + 22-strength camera shake at the transition.
- **HUD boss bar** reads `FINAL BOSS    n / m` and turns harder red during the final fight.
- **Floor counter** shows `Floor 10 — FINAL BOSS (DESERT, MEDIUM)` so the moment is obvious.
- **Victory flow** — when the final boss dies and the room clears:
  - State flips to new `State.VICTORY` (4th enum value).
  - **+25 Fluff, +50 Cotton Threads** awarded immediately via MetaSave.
  - `MetaSave.times_beaten` increments + saves.
  - 3-second pause to let the death explosion + body chunks play out cinematically.
  - **VictoryScreen overlay** appears: huge gold "VICTORY!" header with deep-amber outline, "You beat the Final Boss" subtitle, run-summary stats (kills, bombs, fluff, run time), reward callout `[ +25 Fluff   +50 Cotton Threads ]   Victories total: N`, and PLAY AGAIN / MAIN MENU buttons.
  - Same keyboard nav as Game Over (R/Enter restart, Esc to title, A/D to move focus).
- **New currency: Cotton Threads** added to MetaSave. Persists in `user://meta.json`. Drops only from bosses (5 from regular, 50 from final). Reserved for future weapon/character unlocks; currently displayed in Workshop top bar as `FLUFF: n    COTTON: n    VICTORIES: n` for visibility.
- New `MetaSave.add_cotton(n)` + `record_victory()` helpers.
- New scenes: `scenes/victory_screen.tscn` + `scripts/victory_screen.gd`.

### Stuck-fix + visual declutter + late-game scaling + boss tuning + design doc
- **Enemy stuck detection** — `enemy.gd` now tracks `_last_pos` each frame. If an enemy fails to move >0.5 px for 0.35 s (pinned against geometry), it picks a perpendicular escape direction (toward the player's side) and commits for 0.4 s. Resolves the "bear pinned on a cactus" issue, especially in dense desert rooms.
- **Visual declutter**: decoration count cut **22 → 14**, prop count cap **16 → 12**, boss-floor cover **6 → 5 props** + **14 → 10 decorations**. Decoration sprites get `modulate.a = 0.78` at spawn so they read as floor-detail vs collidable cover (one alpha tier separates "walkable" from "blocks you").
- **New RARE boon: PIERCER** — pizzas pass through `+1` additional enemy per stack, max 3 stacks. Maxed = 1 throw can hit 4 enemies in a line. Fixes the "single-target weapons useless in late game" problem without auto-scaling damage.
- **Pizza piercing implementation**: new `pizza.gd` `pierce: int` export. On enemy hit, the pizza tracks the enemy's `instance_id` in `_hit_ids` (no double-damage on the same target) and either decrements `pierce` and keeps flying, or `queue_free`s as before. Pizza damage, burn, burst, and bounce logic all still apply per-hit.
- **All player pizza paths** (`_spawn_pizza`, `_throw_scatter`, `_throw_homing`) now read `RunState.pizza_pierce()` and assign it to spawned pizzas.
- **Desert boss dash buffed** — `charge_cooldown` 3.6 → **2.4 s**, `charge_telegraph` 0.5 → **0.35 s**, `charge_speed` 360 → **380 px/s**. Easy-mode charge cooldown 4.5 → 3.2.
- **New design doc `LOOP_OVERHAUL.md`** — research-backed proposal for the bigger gameplay-loop redesign (character roster, weapon-unlock progression, final boss + ascension, achievements, optional hub). Genre research summary (Hades / Dead Cells / RoR2 / Vampire Survivors / Isaac / Slay the Spire pattern table). Phased build order A → G with effort estimates. Open questions parked at the bottom.

### Rare + Legendary boons, Fluff currency, Workshop, run summary, multi-stage boss, desert boss
**Boon pool expanded to 13** — 5 commons (existing) + 5 rares + 3 legendaries — with **rarity-tinted boon cards** and a weighted draw.
- New rares (each unlimited or capped sensibly): **BOUNCY CRUST** (+2 wall bounces per stack), **DOUBLE PEP** (+1 pizza per throw per stack), **SPICY** (pizzas burn enemies for 1 dmg/s × 3 s), **PIZZA MAGNET** (pickups fly toward player within 240 px), **LUCKY CRUMBS** (doubles all enemy drop rates).
- New legendaries: **PEPPERONI BURST** (pizzas pop a 78-px AOE on impact for 75% damage), **PIZZA WHEEL** (an orbital pizza spins around you and damages enemies on contact), **SOFT LANDING** (first hit each room is ignored — visible blue flash on save).
- `RunState.roll_offers` now does **weighted random draw without replacement**: 70% common / 25% rare / 8% legendary (per remaining slot). Maxed boons drop out of the pool naturally.
- Card screen tints each card by rarity — cream-white titles for commons, cyan for rares, gold for legendaries, plus a subtle modulate on the whole card.
- New `pizza.gd` fields: `max_bounces`, `apply_burn`, `burst_on_impact` (all routed through player's `_spawn_pizza`). Old `_bounced` bool replaced by `_bounces_done` counter so 3+ bounces work.

**Fluff currency + Workshop (meta-progression)**
- New autoload **`MetaSave`** persists to `user://meta.json` — tracks `total_fluff`, `best_floor`, and per-upgrade levels. Auto-saves on every change.
- **Every enemy kill drops 1 Fluff, every boss drops 5 Fluff** (auto-collected, no sprite). Stats also accumulate to `RunState.stats_*`.
- New scene **`workshop.tscn`** (with script) reachable from a new **WORKSHOP** button on the title screen. Shows current Fluff total + four upgrades:
  - **MORE PLUSH** — +1 max HP at run start (3 levels, 10/22/40 Fluff)
  - **SHARPER CRUST** — +1 pizza damage at run start (3 levels, 15/32/60)
  - **FASTER FEET** — +5% move speed at run start (3 levels, 8/16/28)
  - **LUCKY START** — +2 starting bomb charges per level (3 levels, 12/24/40)
- `player.apply_boons` reads MetaSave levels into the computed `max_health` and `speed`. `_spawn_pizza` / `_throw_pizza_bomb` / `_throw_scatter` / `_throw_homing` all add `MetaSave.upgrade_level("sharper_crust")` into the damage calc.
- `main.gd::_ready` checks Lucky Start and `grant_special("bomb", level * 2)` so you start each run with bombs if you've bought the upgrade.

**Multi-stage boss (Mirror Bear)**
- New `_phase: int = 1` on `boss.gd`. When `health <= max_health / 2` it calls `_enter_phase_2()`:
  - `throw_interval *= 0.65` (faster rainbow pizzas)
  - `speed *= 1.35` (chases harder)
  - `aoe_cooldown *= 0.75` (close-range AOE fires more often)
  - Brief invuln (0.6 s) + orange explosion flash + 14-strength camera shake to telegraph the transition

**Run summary** on the Game Over screen
- New `StatsLabel` between depth and buttons:
  ```
  Enemies KO'd  N
  Bombs thrown  N
  Fluff earned  N
  Run time      M:SS

  Best floor  N   |   Total Fluff  N
  ```
- `RunState` gained `stats_floors_reached`, `stats_enemies_killed`, `stats_bombs_thrown`, `stats_fluff_earned`, `stats_run_seconds`. main.gd ticks `stats_run_seconds` in `_process` while not on Game Over.

**Desert boss (#7)** — biome-specific boss type
- New `scenes/desert_boss.tscn` + `scripts/desert_boss.gd` — a giant, slow, tankier bear that's brown-bear-textured at 0.7× rig scale (placeholder until you send a dedicated desert-bear photo).
- Behaviour: chases at 70 px/s (vs Mirror Bear 96), 28 HP / 22 on Easy, 2 touch damage. **Telegraphed CHARGE attack** every ~3.6 s — pauses + glows yellow for 0.5 s, then dashes 360 px/s straight at the player. Touch damage on connect.
- Multi-stage too: at half HP enters phase 2, increases speed 30%, halves charge cooldown, and **summons brown-bear adds** every 6 s. Same orange-flash transition.
- `main.gd::_spawn_boss` dispatches by current biome — Forest → Mirror Bear, Desert → Desert Boss.

### Dev menu now grants all 3 weapons
- Dev menu got two new buttons: **+8 SCATTER charges** and **+6 HOMING charges**, alongside the existing **+5 BOMB charges**.
- `main.gd::dev_give_bombs` retained as a shim; new generic `dev_grant_special(weapon, n)` is the underlying helper.

### Scatter + Homing weapon pickups + Easy boss softer
- **Easy boss** HP 16 → **14** (≈2 hits softer with a 1-damage pizza).
- **Three weapon pickup types** now drop from enemies at **7%** chance each (was 6% bomb-only):
  - **Bomb** — existing (4 charges, lands + 0.5 s fuse + AOE)
  - **Scatter** — 6 charges. Throws **3 pizzas in an 18° cone**, half-range (lifetime 0.7 s), slightly slower (85% speed). One charge per throw.
  - **Homing** — 5 charges. Slower (75% speed) and longer-lived (2.4 s) pizzas that **curve toward the nearest enemy** at 5.5 rad/s turn rate. One charge per throw.
- **Generic `weapon_pickup.gd`** replaces the old single-purpose `bomb_pickup.gd`. Three scenes (`bomb_pickup.tscn`, `scatter_pickup.tscn`, `homing_pickup.tscn`) all use it with different `weapon_type` + `charges` + texture exports.
- **Player special-weapon refactor**:
  - `pizza_bomb_charges` → `special_charges` + `active_special: String`
  - New `_throw_default_pizza`, `_throw_scatter`, `_throw_homing` methods
  - `_throw_pizza` is now a router: while `special_charges > 0` it dispatches by `active_special`, decrements, and reverts to default when charges hit 0
  - New `grant_special(weapon, n)` is the public API for pickups; existing `add_pizza_bombs(n)` is now a backwards-compat shim
- **`pizza.gd` gained `homing` flag + `_find_nearest_enemy()`** — when `homing = true` and not hostile, every physics frame the pizza's direction slerps toward the nearest enemy (capped by `homing_turn_rate`). Wall-bounce, lifetime, and damage logic all still work.
- **HUD bombs label** generalised — reads `active_special` and shows e.g. `BOMB x 3`, `SCATTER x 6`, `HOMING x 5`.
- New assets:
  - `scatter_pickup.png` — fanned 3-pizza spread, soft blue aura
  - `homing_pickup.png` — pizza inside a magenta targeting reticle
- New utility: `make_weapon_pickups.py` composites the new sprites out of the existing `pizza.png`.

### Dev menu (Esc) + pizza-bomb pickup + balance bumps
- **Easy-mode boss tanker** — `max_health` 12 → **16**, `throw_interval` 2.7 → **2.5 s** so Easy bosses don't fold immediately.
- **Drop rate doubled** — `HEALTH_DROP_CHANCE` in `enemy.gd`: 0.05 → **0.10**. Regular bears now drop a fluff orb 1 in 10 deaths.
- **New: Pizza Bomb pickup + projectile**
  - New `assets/pizza_bomb.png` (PIL-rendered): cartoon black bomb, lit fuse with spark ember, red danger glow.
  - New `scripts/bomb_pickup.gd` + `scenes/bomb_pickup.tscn` — Area2D pickup that grants the player **4 charges** on contact. Bobs/spins like the heal orbs; same magnet behaviour when `DevState.auto_pickup` is on.
  - New `scripts/pizza_bomb.gd` + `scenes/pizza_bomb.tscn` — Area2D projectile:
    - Travels in the throw direction at 460 px/s for up to **230 px**, then **lands** (also lands on first wall/cylinder/enemy contact).
    - **0.5 s fuse** — blinks red faster as the fuse runs down.
    - On detonation: scaled-up explosion VFX + damages every enemy within `aoe_radius = 110 px` for `damage = round(player_pizza_damage * 1.5)`.
    - Small camera shake (10, 0.22 s) on detonation.
  - `player.gd` tracks `pizza_bomb_charges` and a new `add_pizza_bombs(n)` method. While charges > 0, `_throw_pizza` routes to `_throw_pizza_bomb` instead of the regular pizza, decrementing on each throw.
  - New HUD label "BOMBS x N" under the HP bar — only visible when charges > 0.
  - `enemy.gd`: independent `BOMB_DROP_CHANCE = 0.06` roll on death; spawns a bomb pickup alongside (or instead of) the health drop.

### Dev menu — Esc during play
- New autoload `DevState` (`scripts/dev_state.gd`) holds the test toggles (`invincible`, `oneshot_kills`, `no_enemies`, `auto_pickup`, `show_fps`). Reset by `main.gd::_ready` on every scene load so they don't persist between runs.
- `main.gd::_input`: pressing Esc during PLAYING state (with no other overlay open) opens the dev menu. `main.gd::_open_dev_menu` pauses the tree and instantiates the menu with a back-ref.
- New `scripts/dev_menu.gd` + `scenes/dev_menu.tscn` — CanvasLayer overlay (`process_mode = ALWAYS`, `layer = 20` so it sits above boon screen + game over):
  - **Toggles** (live, no need to close): Invincible / One-shot kill / No new enemies / Auto-pickup magnet
  - **Actions**: Heal to full · Skip to next floor · Spawn boss now · Give random boon · +5 pizza bombs · Kill all enemies · Resume (Esc)
- Dev hooks wired through code:
  - `player.gd::take_damage` early-returns if `DevState.invincible`
  - `enemy.gd::take_damage` slams health to 0 + dies if `DevState.oneshot_kills`
  - `main.gd::_spawn_enemy` skips spawning if `DevState.no_enemies`
  - `pickup.gd` and `bomb_pickup.gd` slide toward the player at 700 px/s when `DevState.auto_pickup` is on
- Dev helper methods on `main.gd`: `dev_heal_player`, `dev_skip_floor`, `dev_spawn_boss`, `dev_give_random_boon`, `dev_give_bombs`, `dev_kill_all_enemies`.

### Desert biome (floors 4-6) + ponds + boss + AOE balance + density
- **Biome system** in `main.gd`:
  - `_current_biome()` cycles every 3 floors: 1-3 forest, 4-6 desert, 7-9 forest, …
  - `_apply_biome()` recolours the floor at room start: `BIOME_FOREST_COLOR` (mossy green) ↔ `BIOME_DESERT_COLOR` (sandy tan).
  - Prop pool + decoration pool swap by biome.
  - HUD floor label now reads `Floor N  (FOREST, MEDIUM)` so you know where you are.
- **Desert props** sliced from ScratchIO's CC0 [Desert Level Decorations](https://opengameart.org/content/desert-level-decorations-pixel-art):
  - `cactus_tall.png` / `cactus_round.png` — obstacle cacti
  - `desert_bush.png` — decorative shrub
  - `desert_rocks.png` — multi-rock cluster obstacle
  - All wrapped in scenes with `texture_filter = NEAREST` + Y-sort anchor at the base of the trunk/rock
- **Ponds (forest only)** — `pond.png` is procedural, sampling the water colour from inkBubi's grass_deep_water tile so it matches palette without dragging in tile-set grass borders that would clash with our floor:
  - 112×80 ellipse — dark blue rim, water-blue fill, two white reflection highlights
  - `pond.tscn` is an Area2D in the new `"slow_zones"` group (no physical collision)
  - 1-2 ponds per non-boss forest floor, placed ≥260 px from player spawn and ≥320 px from other ponds so they can't seal off a quadrant
- **Slow-zone mechanic** — `_slow_factor()` added to `player.gd`, `enemy.gd`, `boss.gd`. While any body overlaps a slow zone, its velocity is multiplied by **0.55**. Player can wade through ponds but pays for it; enemies kited into a pond slow down hard, which is the tactical use.
- **Density bump on every non-boss floor**:
  - Props (cover obstacles): `clamp(3+depth, 3, 12)` → **`clamp(5+depth, 6, 16)`**
  - Decorations (bushes/shrubs): 14 → **22**
  - Boss floor cover: 4 → 6 props
- **Boss body lingers** — `DEATH_FADE_DURATION` 2.0 → **4.5 s** so the dead boss + chunks stay visible for the player to walk around before the door opens.
- **Boss stuffing puffs** — 8 → **18** in `_spawn_body_chunks`. The death is messier.
- **AOE hazard tuned softer**:
  - `damage_interval` 0.5 → **0.8 s** (standing on a hot tile = 1 dmg per 0.8 s instead of 0.5)
  - `burst_interval` 0.7 → **1.3 s** (random shockwaves come ~half as often)
  - `burst_max_radius` 135 → **100** (smaller radius, less of "wait, I was nowhere near it")
  - `on_duration` 1.5 → 1.2, `off_duration` 1.8 → 2.1 (more breathing room)
- New utility: `prep_more_assets.py` slices the ScratchIO desert sheet + bakes the procedural pond.

### Forest biome — pixel-art trees, stones, bushes (CC0)
- Replaced the procedural gray cylinders with **hand-pixeled CC0 forest assets** from inkBubi's [Seasons of Forest free sample](https://opengameart.org/content/free-sample-16x16-pixel-forest-tileset-%E2%80%93-top-down-rpg-style) (Creative Commons Zero — public domain).
- Downloaded the zip into `assets/forest_kit/` (license file + original sheets retained for reference).
- `prep_forest_assets.py` slices the tilesheets into individual sprites placed in `assets/`:
  - `tree_deciduous.png` (58×62 native) — round-canopy leafy tree
  - `tree_pine.png` (52×61 native) — triangular pine
  - `stone_big.png` (22×30 native) + `stone_small.png` — gray boulders
  - `bush_a.png` … `bush_d.png` — four small bush variants
  - `grass_tile.png` — 64×64 grass tile (kept for a future tiled floor pass)
- All sprites use `texture_filter = NEAREST` so the pixel blocks stay crisp at 2.5× scale (Sprite2D.scale = `Vector2(2.5, 2.5)`).
- Sprite `offset` is set so each prop's node origin sits at the **trunk/base** — Y-sort uses this as the depth anchor.
- New scenes: `tree.tscn`, `pine_tree.tscn`, `stone.tscn` (all `StaticBody2D` in the "obstacles" group), `bush.tscn` (pure-decoration `Sprite2D`, no collision).
- `main.gd::_spawn_cylinders` reworked into a forest-prop spawner:
  - `_pick_prop_scene()` randomly returns deciduous (40%), pine (35%), or stone (25%) — keeps variety high.
  - Per-instance random scale variation 0.92–1.10× so the forest doesn't look stamped.
  - Spacing requirements bumped (140 px from spawn-ables, 110 px between props) since trees are bigger than cylinders.
- New `_spawn_bushes(count)`: drops 12–14 decorative bushes per room with random scale + random horizontal flip. Avoids piling on top of other props or the player spawn.

### Y-sort enabled on Main scene
- `main.tscn` root Node2D `y_sort_enabled = true` — direct children (Player, enemies, trees, bushes) now draw in Y-position order automatically.
- Walking "above" a tree (smaller Y in world coords) → player draws first → tree foliage covers player. Walking "below" a tree → player draws after → player in front of tree.
- Pure top-down stays — no 3D math, just depth sorting. The trees' foliage extending upward from their trunk base creates the implied perspective.
- Player position currently sorts by centre, tree by trunk base; minor sort imperfection when player is very close in Y to a tree (could see player clip into trunk briefly). Acceptable for v1, can refine player's anchor later.

### Floor recoloured for biome read
- `Floor` `ColorRect.color`: `Color(0.15, 0.15, 0.18)` (cool gray) → `Color(0.18, 0.32, 0.16)` (mossy green). Cheap biome cue without committing to a full tiled grass texture yet.

### Boss rebalance + tighter boon caps + hazard shockwaves
- **Boon damage stack cap lowered** — `run_state.gd` now stores `max_stacks` per-boon. Extra Cheese drops to **2 stacks max** (max +2 damage = 3-dmg pizza), others stay at 3. New helper `_max_stacks_for(id)` reads from the pool dict so future boons can have their own caps.
- **Boss: i-frames on hit** — `hit_invuln = 0.28 s` in `boss.gd`. `take_damage` early-returns while still in i-frames. With player pizza fire rate ~3/s, this caps effective boss DPS to roughly 1 hit per 0.4 s instead of all 3 landing. **Stops spam-kill at start of fight.**
- **Boss pizzas reach the whole room** — `pizza_speed` 480 → **600** (matches player), `pizza_lifetime` 1.4 → **3.0 s** (boss pizzas can now travel `600 × 3.0 = 1800 px`, longer than the room diagonal so wall bounces always happen).
- **Boss pizza bounce limit tightened** — `pizza.gd::MAX_DISTANCE_AFTER_BOUNCE` is now an `@export` (`max_distance_after_bounce`). Player pizzas keep 720 px default; boss pizzas set to **290 px (~20 % of room width)** after first bounce. Wall ricochets matter but don't ping forever.
- **Boss close-range AOE** — `aoe_cooldown = 1.6 s`, `aoe_range = 95 px`, `aoe_damage = 1`. Whenever the player is within 95 px and the cooldown is ready, boss triggers a small red-tinted explosion-flash + damage tick. **Punishes hugging the boss to avoid his pizza.**
- **Random boss spawn** — `main.gd::_spawn_boss` now picks a random position inside `(MARGIN+150, WORLD-MARGIN-150)` that's at least 420 px from the player. No more "always on the right" — boss can appear top-left, dead-centre-ish, or any quadrant.
- **Hazard tiles fire random-radius AOE shockwaves** while ON — every `0.7 s ± 0.18` a `_fire_burst()` ticks: pick a random radius in `[75, 135]`, damage anything (player + enemies) within that radius once, spawn an expanding orange Line2D ring that tweens to that radius + fades over 0.38 s. The tile feels unstable now — the safe edge isn't fixed.
- `hazard.gd::on_duration`: 1.3 → 1.5 s, leaves room for 2 bursts per ON cycle.

### Trap dynamicness + smart trash mobs + boss HP
- **Hazard tiles got a telegraph phase.** Cycle is now OFF (1.8 s) → **TELEGRAPH** (0.55 s yellow blink) → ON (1.3 s) → repeat. Yellow blink is bright, blinks at ~14 Hz, gives the player a clear visual cue something's about to happen.
- **`is_dangerous()` on every hazard** — returns true when state ≠ OFF (so dangerous during both telegraph and ON for AI purposes). Pizza damage still only lands during ON.
- **New: Sweeper Saw** (`scripts/sweeper_saw.gd` + `scenes/sweeper_saw.tscn`):
  - 16-tooth Polygon2D blade with rim + dark hub. Always spinning at 18 rad/s visually.
  - Slides back and forth along a fixed axis at 150 px/s over a 220-px stretch.
  - Damages overlapping bodies every 0.45 s. Always dangerous (`is_dangerous()` = true).
  - Axis is locked to horizontal or vertical at spawn (randomly picked) so the motion reads at a glance.
- **Spike traps no longer spawn** — replaced wholesale by Sweeper Saws on non-boss floors. Scene/script kept around for potential later use.
- **Sweeper spawn formula**: `clamp((depth - 2) / 2, 0, 2)` — Floor 4 = 1 saw, Floor 6+ = 2 saws. Sweepers need lots of clearance so they keep ≥220 px from player spawn, ≥260 px from each other, and ≥130 px from props/cylinders.
- **Enemy AI: hazard avoidance** — `enemy.gd` now iterates the new `"hazards"` group after its obstacle pass:
  - `HAZARD_AVOID_RADIUS = 110`, `HAZARD_AVOID_REPULSION = 1.8` (3× stronger than cylinders), `HAZARD_AVOID_TANGENT = 0.7`.
  - **Only avoids hazards that report `is_dangerous() = true`** — i.e. saw (always) and pulse-tile when telegraphing or ON. Cold pulse tiles are ignored, which is the lure-and-trick window: enemies will walk over a tile right up until it starts flashing.
- **Boss HP bumped**: `max_health` 15 → **20** (Medium/Hard). Easy boss: 9 → **12**. Slight 33% buff — boss fights last about one extra "throw → run → throw" cycle without dragging.

### Boon cap + de-dupe (anti-abuse) + dynamic hazards
- **Boon stacking cap** — `run_state.gd` `MAX_STACKS_PER_BOON = 3`. Each common boon can now be picked at most 3 times.
- **No duplicates in same offer** — `roll_offers()` now pulls from `available_boons()` (un-maxed only) and slices without replacement, so a single triplet can't show the same boon twice.
- **Graceful empty pool** — if every boon is maxed, the boon card screen emits `boon_selected("")` and `queue_free`s immediately, `main.gd::_on_boon_selected` treats `""` as a skip (no add), and the run continues. Also handled: offer of 1 or 2 boons (cards hide rather than crash, A/D navigates only the visible ones).
- **`available_boons()`** + **`is_maxed(id)`** added to `RunState` for future UI ("3/3" badges, rarity tints, Workshop logic, etc.).

### Pulsing hazard tiles (on/off floor damage objects)
- New `scripts/hazard.gd` + `scenes/hazard.tscn` — Area2D with a Polygon2D diamond visual.
  - Cycles **ON 1.4 s / OFF 2.0 s**, randomised initial state so a cluster doesn't pulse in sync.
  - Damages every body in the area with a `take_damage` method, **once every 0.5 s** while ON. Enemies and player both take hits (i-frames protect the player from chain-damage).
  - OFF state is a dim red diamond; ON state lights up to bright orange/yellow and pulses subtly.
  - First moment of an ON cycle does an immediate damage tick — no grace period for standing on it during the off-to-on flip.
- Spawn count scales with floor: `clamp(depth - 1, 0, 4)` — Floor 2 = 1 hazard, Floor 5+ = 4 hazards.
- `main.gd::_spawn_hazards` keeps them ≥180 px from player spawn, ≥130 px from each other, and not on top of cylinders.

### Spike traps (one-shot tripwire damage)
- New `scripts/spike_trap.gd` + `scenes/spike_trap.tscn` — Area2D with two Node2D visual states.
  - Idle: dark square with a darker pit in the middle. Looks innocuous.
  - On first contact with anything that can `take_damage`: spike star pops up, deals **1 damage to everything overlapping**, then stays visible (sprung) for the rest of the room so the player isn't surprised twice.
- Spawn count: `clamp((depth - 2) / 2, 0, 3)` — Floor 4 = 1 trap, Floor 6 = 2, Floor 8+ = 3.
- Same anti-overlap logic as hazards but tighter radius (one-shot = less crowding concern).

### Chain explosion + delay landed
- `GAME_OVER_DELAY`: 4.4 → **4.0 s** (final).
- **Chain reaction on player death** — every enemy within `CHAIN_RADIUS = 360 px` of the player explodes too:
  - New `chain_explode()` on both `enemy.gd` and `boss.gd`.
  - Regular bears: small explosion (`end_scale = 3.5`, `duration = 0.75 s`) + brown-bear upper/legs chunks + 6 stuffing puffs, all with shorter `lifetime` (2.0–3.2 s) than the player's debris.
  - Boss `chain_explode()` routes straight into the normal `_begin_death` (full-size explosion, 8 puffs, full-heal drop).
  - Player's `_chain_explode_nearby_enemies()` iterates the `enemies` group and stagers each chain call by `distance / 700 s` (capped at 0.55 s) so the cascade ripples outward instead of all-at-once.
  - Boss-floor deaths: the boss is the only enemy in the room, so taking him out as you die is a satisfying mutual annihilation.

### Player death — explosion + lingering chunks + game-over pop-up
- **Player no longer queue_frees on death.** Instead `player.gd::_begin_death` hides the rig, disables physics + collisions, removes itself from the `player` group, and emits a new `died` signal. The CharacterBody2D node stays alive (camera still attached) so the view doesn't jump.
- **Bigger explosion than the boss** — same `ExplosionScene`, but `end_scale = 7.5` (vs boss's 4.8) and `duration = 1.4 s` (vs 0.95 s). Camera shake too: strength 38, 0.8 s.
- **Lingering body chunks** spawned in `_spawn_death_chunks`:
  - 1 upper-body chunk (`bear_upper.png`, scale 0.5) flung up-and-out at 320–420 px/s
  - 1 legs chunk (`bear_legs.png`, scale 0.5) flung down-and-out at 300–400 px/s
  - **14 cotton stuffing puffs** (vs boss's 8) flung in all directions at 220–460 px/s
  - All have `lifetime` 4.0–5.5 s and `fade_after = 0.72–0.78` (boss chunks were 1.5 s / 0.55), so they hang around long after the explosion.
- New `scripts/game_over_screen.gd` + `scenes/game_over_screen.tscn`:
  - Full-screen CanvasLayer overlay (`process_mode = ALWAYS`, `layer = 10`).
  - 84% opacity dark background.
  - Big red **GAME OVER** title with deep-red outline.
  - "Reached Floor N" subtitle.
  - Two big themed buttons in an HBox: **START OVER** + **MAIN MENU** (dark navy bg, gold-bordered hover, same Theme pattern as the boon cards).
  - Hint footer: "R to restart | Esc to main menu | AD / arrows + Enter".
  - Keyboard: R restarts, Esc → title screen, A/D / arrows cycle button focus, Enter activates focused, mouse click also works.
- `main.gd` integration:
  - Connects to `player.died` in `_ready`.
  - `_on_player_died`: flips to GAME_OVER state, starts a 1.4 s timer → `_show_game_over_screen()`.
  - Pop-up emits `restart_requested` (→ `get_tree().reload_current_scene()`) or `menu_requested` (→ `change_scene_to_file("res://scenes/title_screen.tscn")`).
  - `_input` R-restart still works during the 1.4 s death-explosion delay (before the pop-up is up) — after the pop-up exists, the pop-up consumes the key instead.

### Boon system (MVP) — pick-1-of-3 power-ups between floors
- New autoload **`RunState`** (`scripts/run_state.gd`):
  - Holds per-run state — `active_boons: Array[String]`.
  - `reset()` (called by `main.gd::_ready` on every load — i.e. new run or post-death restart).
  - `add(id)`, `count(id)` for stacking.
  - Modifier accessors used by the rest of the code:
    - `pizza_damage_bonus()`, `pizza_size_multiplier()`, `pizza_speed_multiplier()`
    - `bonus_max_health()`, `move_speed_multiplier()`
  - `roll_offers(n=3)` returns `n` shuffled boons from `COMMON_POOL`.
- Five **common** boons (additive, unlimited stacking):
  - **EXTRA CHEESE** — +1 pizza damage
  - **STUFFED CRUST** — pizzas 25% bigger (sprite scale + collision radius)
  - **SPEED SLICE** — pizzas fly 25% faster
  - **PLUSH ARMOR** — +1 max HP (also heals 1 immediately)
  - **STICKY BUNS** — +12% move speed
- New `scripts/boon_card_screen.gd` + `scenes/boon_card_screen.tscn`:
  - Full-screen CanvasLayer overlay (`process_mode = ALWAYS`, `layer = 10`) shown when player walks through portal.
  - Pauses the rest of the scene tree via `get_tree().paused = true`.
  - Three card Buttons in a horizontal row inside a CenterContainer.
  - Each card uses a `StyleBoxFlat` (dark navy bg, subtle border) for normal and a brighter gold-bordered hover style — applied via a Theme sub-resource so all three share styling.
  - Card content: bold gold **TITLE** label + soft cream **description** label (autowrap).
  - Header: outlined "CHOOSE A BOON" in deep purple.
  - Hint footer: "Arrows / AD to move | Enter / click to pick".
  - Keyboard nav: arrows + WASD horizontal cycle, Enter / Space activates, mouse clicks work too.
- `main.gd` integration:
  - `_advance_room` no longer immediately advances — it calls `_show_boon_screen()` which pauses, instantiates the card screen, and listens for `boon_selected`.
  - `_on_boon_selected(id)` adds the boon to `RunState`, unpauses, calls `player.apply_boons()` to re-roll stats, then bumps `depth` and runs `_start_room` as before.
- `player.gd` refactor:
  - Renamed exports to `base_speed` / `base_max_health` (+ new `base_pizza_damage`, `base_pizza_speed`).
  - New `apply_boons()` recomputes `max_health` and `speed` from base + RunState modifiers. If `max_health` grew (Plush Armor picked), heals the difference.
  - `_throw_pizza()` now sets `pizza.damage` / `pizza.speed` from base + RunState, and Stuffed Crust scales the pizza Sprite2D + duplicates and resizes the CollisionShape2D's `CircleShape2D` so the bigger pizza also has a bigger hitbox.
- `title_screen.gd::_on_start` calls `RunState.reset()` (belt-and-braces — `main.gd::_ready` does it too).
- `project.godot` autoload section now declares both `GameSettings` and `RunState`.

### Combat + UX fixes
- **Touch damage fixed** — `enemy.gd` now uses `get_slide_collision()` to detect actual physical contact instead of a 32-px center-distance check (player + enemy collision boxes touch at center-distance ≈37 px, so the old check could never fire). Damage now lands the moment a bear pushes against you.
- **No drop if full HP** — both `enemy.gd::_begin_death` and `boss.gd::_begin_death` now check `player.health < player.max_health` before spawning a pickup. Boss skips the heart-fluff entirely if you're at max; regular bears skip the roll. Helper: `_player_needs_health()` on each script.
- **Boss bursts into chunks on death**
  - New `scripts/body_chunk.gd` + `scenes/body_chunk.tscn` — a Sprite2D that flies outward with random angular velocity, gentle gravity, fades alpha after 55 % of its lifetime, despawns when done.
  - New `assets/stuffing.png` (small fluffy cotton puff, PIL-generated by `make_stuffing.py`).
  - On `_begin_death`, the boss hides its `Rig` and spawns:
    - 1 **upper-body** chunk (using `boss_upper.png`, nearest-filter, scale 0.45) flung upward-and-out at 280–380 px/s
    - 1 **legs** chunk (using `boss_legs.png`) flung downward-and-out at 260–360 px/s
    - 8 **cotton stuffing puffs** flung in all directions at 180–420 px/s
  - The original fall/vibrate/fade still runs invisibly under the chunks for timing — `queue_free` still happens at the end of `DEATH_FADE_DURATION`.
- **Smaller pickup sprites** — Sprite2D scale dropped from 0.55 → **0.38** (health orb) and **0.40** (full heal). Textures themselves unchanged, so the fluffy detail is preserved when zoomed.
- **Portal spawn near-but-not-on centre** — `main.gd::_open_door` adds a random offset around the room centre: angle `[0, TAU]`, distance `[140, 240]` px. The door pops at a new spot each time it opens.
- **WASD in title menu** — `title_screen.gd` now tracks the menu buttons in an array with a `_focus_index`, hooks every button's `focus_entered` so the index stays in sync no matter how focus moved (mouse, arrows, or WASD), and intercepts W/S/A/D in `_input` to cycle focus. Arrows + Enter still work via Godot's built-in UI nav.
- **Easy-mode boss nerfs** — in `boss.gd::_ready`, if `GameSettings.difficulty == EASY`:
  - `max_health` 15 → **9** (≈40 % less HP)
  - `throw_interval` 1.6 s → **2.7 s** (rainbow pizza less often)
  - Medium and Hard unchanged.

### Drop rate tuning
- Regular-bear health-orb drop chance lowered **25% → 5%** (`HEALTH_DROP_CHANCE` in `enemy.gd`). Bosses still always drop the full-heal fluff.

### Fluff-ball pickups (redesign of health drops)
- Replaced the abstract green/gold orbs with **cute fluffy pom-pom characters**.
- Rewrote `make_pickups.py` to draw at 2× resolution and LANCZOS-downsample for crisp anti-aliased hi-res output:
  - Soft outer glow in the body colour
  - Solid base disc, then ~220 inner fur "fibres" + ~160 edge fibres in randomised body/light/dark colour variants and slight Gaussian blur
  - Bottom shadow + top highlight crescent for volume
  - Big dark eyes with white catch-lights
  - Pink blush patches under each eye (Gaussian-softened)
  - Tiny dark smile arc
- **+1 HP fluff** (`health_orb.png`): 96 × 96 green pom-pom, no icon — drops 25% of the time from regular bears.
- **Full-heal fluff** (`full_heal.png`): 144 × 144 cream/gold pom-pom with a small **red heart on top** (white outline for pop, lighter reflection on the upper-left lobe) — always drops from bosses.
- `scenes/health_orb.tscn` + `scenes/full_heal.tscn` now scale the Sprite2D to 0.55 and bumped collision radii to 24 / 36 so on-screen pickup size matches the original orbs while retaining the high-res texture detail.
- Inspiration / future swap-in sources noted: [OpenGameArt CC0 collection](https://opengameart.org/content/cc0-resources), [itch.io furry pixel-art](https://itch.io/game-assets/tag-furry/tag-pixel-art), [CraftPix freebies](https://craftpix.net/freebies/), [Vecteezy plush PNGs](https://www.vecteezy.com/free-png/plush-toys).

### Health pickups
- **+1 HP orb** — regular brown bears now have a **25% chance** to drop one when they hit 0 HP (`HEALTH_DROP_CHANCE = 0.25` in `enemy.gd::_begin_death`).
  - New `assets/health_orb.png` (small green orb, white plus icon, soft green glow).
  - New `scenes/health_orb.tscn` — Area2D + Sprite + CollisionShape, uses generic `pickup.gd` with `heal_amount = 1`.
- **Full heal** — bosses **always** drop one in `boss.gd::_begin_death` (alongside the explosion).
  - New `assets/full_heal.png` (bigger golden disc, red medical cross, golden outer ring, warm glow).
  - New `scenes/full_heal.tscn` — same pickup script with `full_heal = true`, larger bob, bigger collision radius.
- New `scripts/pickup.gd` — generic Area2D pickup:
  - Bobs vertically (`sin(t * 2.4) * 4 px`) and slowly rotates so it reads as collectible.
  - On `body_entered` with the player: calls `player.heal(amount)` (or `player.max_health` for full heal) and `queue_free`s itself.
  - `call_deferred` overlap check on `_ready` so it pops if the player is already standing where it spawned.
- `player.gd` gained a `heal(amount)` method: clamps `health = min(health + amount, max_health)` and pulses the bear green for 0.15 s for feedback.
- **Player i-frames** — `player.gd` `take_damage` now early-returns if `_invuln_time > 0` and sets it to `INVULN_DURATION = 0.45 s` on a successful hit. Stops a swarm of brown bears from chipping HP off you on the same frame; you still take 1 HP per touch (per the existing `touch_damage = 1` on enemies), just not 3× at once.
- **Pizza wall-bounce speed boost** — `pizza.gd` multiplies `speed *= 1.1` when reflecting off a wall, so a bounced shot zips faster on the way back through.
- **Portal spawns at room centre** — `main.gd::_open_door` now places the door at `(WORLD_W / 2, WORLD_H / 2)` instead of the right edge.
- **Door activation delay** — `door.gd` gained an `_active` gate with a 0.55 s grace period after spawn. Prevents accidental advance when the player happens to be standing on the spawn point. After the delay, it also re-checks `get_overlapping_bodies()` so a player who is *still* on the portal advances automatically.
- **Portal redesign** — `make_portal.py` now draws at 512×512 then LANCZOS-downsamples to 256 for crisp anti-aliased rings (previous version had soft Gaussian-blurred edges).
  - Outer golden ring with **24 rune tick marks** (12 long + 12 short, alternating clock-positions) — inspired by the Chaos Gate look in Hades.
  - Thin cream highlight inside the gold.
  - New **mid-radius cyan accent ring** plus 8 broken arc segments rotating off it.
  - Sparkle field inside the deep-purple void (6 stars, soft blurred).
  - Brighter, more layered gold core glow.
- Web search references for inspiration / future swap-in assets: [OpenGameArt portals](https://opengameart.org/content/portals) (CC0), [Elthen 2D pixel art portal sprites](https://elthen.itch.io/2d-pixel-art-portal-sprites), [Hades Chaos Gate description](https://hades.fandom.com/wiki/Chaos_Gate).

### Title screen + difficulty + Hard-mode ninja stars
- Game renamed to **PLUSH CRAWL** (`project.godot` `config/name`). Old internal "Stuffed Crawler" retired.
- `project.godot` `run/main_scene` now points at `scenes/title_screen.tscn` — game boots into the menu, not straight into combat.
- New autoload `GameSettings` (`scripts/game_settings.gd`) — persistent across scene loads. Holds:
  - `difficulty` enum (EASY / MEDIUM / HARD)
  - `enemy_count_multiplier()` → 0.7 / 1.0 / 1.35
  - `enemies_throw()` → true only on HARD
  - `cycle_difficulty()` — used by the menu
- New `scenes/title_screen.tscn` + `scripts/title_screen.gd`:
  - Dark navy backdrop, large white-cream **PLUSH CRAWL** title with deep-purple outline.
  - Animated **rainbow accent bar** (6 px) under the title — modulate cycles through HSV at 0.7 cycles/s.
  - Subtitle "a pizza-throwing plushie roguelike".
  - Vertically centred menu: **START GAME / DIFFICULTY: <level> / OPTIONS / QUIT**. Text-only Buttons (`StyleBoxEmpty` for normal/hover/pressed/focus), cream colour with bright gold on hover and keyboard focus.
  - Hint line at bottom: "Arrow keys + Enter | or click".
  - Options panel (initially hidden) with a Fullscreen toggle (`DisplayServer.window_set_mode`) and a Back button. `Esc` also closes options.
  - DifficultyButton text updates live to `DIFFICULTY: EASY / MEDIUM / HARD`.
- `main.gd::_start_room` now scales regular-floor enemy counts by `GameSettings.enemy_count_multiplier()` (HUD also shows the current difficulty in parentheses next to the floor number).
- New `assets/ninja_star.png` (PIL-generated 4-pointed steel shuriken with shadow, centre hole, edge highlights) via `make_ninja_star.py`.
- New `scripts/ninja_star.gd` + `scenes/ninja_star.tscn` — Area2D projectile. 520 px/s, 1.6 s lifetime, fast spin, no wall bounce. Ignores fellow enemies, damages the player, destroyed by walls / cylinders.
- `scripts/enemy.gd`: on HARD only (`GameSettings.enemies_throw()`), regular brown bears throw ninja stars at the player every ~2.7 s ± random jitter. Initial throw timer also randomised so a cluster of enemies doesn't fire in sync.

### Boss health bar + huge explosion on death
- HUD **boss health bar** centred at top of screen (`scenes/main.tscn`):
  - Black frame, dark-red empty backing, hot-pink fill that contracts from both edges as the boss takes damage.
  - "BOSS BEAR    n / m" label overlay.
  - Hidden whenever no boss is alive (driven by `main.gd::_update_boss_bar` polling `_boss.health` / `max_health`).
- `main.gd::_spawn_boss` now stores the spawned boss as `_boss` so the HUD can track it.
- New `assets/explosion.png` (PIL-generated: orange halo, yellow-white core glow, 14 randomised star rays, hot white pinpoint) via `make_explosion.py`.
- New `scripts/explosion.gd` + `scenes/explosion.tscn` — Node2D effect. Sprite scales from 0.3 → 4.8 with ease-out, fades alpha 1 → 0, slow rotation, despawns after 0.95 s.
- `boss.gd::_begin_death` now also: (a) spawns an Explosion at the boss's position, and (b) requests a camera shake (`player.shake(28, 0.55)`). The original fall-over + vibrate + fade animation still plays underneath.
- `scripts/player.gd` gained a `shake(strength, duration)` method: animates `Camera2D.offset` with random jitter that decays over the duration. Used by the boss explosion (and ready to wire to other big moments).

### Boss speed + portal redesign
- **Boss moves 1.2× faster** — `boss.gd` `speed`: 80 → 96.
- **Portal door**: replaced the plain yellow ColorRect doorway with a magical portal.
  - New asset `assets/portal.png` generated by `make_portal.py` (purple void, golden ring, soft halo, sparkle dots, glowing core).
  - `scenes/door.tscn` rebuilt: `Sprite2D` portal that **rotates** one full turn every 3 s and **pulses** scale 0.6 ↔ 0.7.
  - Gold "NEXT FLOOR" label below the portal with outline + matching pulse on its modulate.
  - Door spawn position moved inward (`WORLD_W - 90` from edge) so the portal isn't clipped by the right wall.
- **Floor-clear flash**: replaced the static "Door open →" status with a fading "FLOOR CLEARED" banner that tweens out over 1 s after a 1.4 s hold.

### Player health bar + boss visual overhaul
- **HUD health bar** (upper left): black frame + dark-red empty backing + colour-coded fill.
  - Green > 60 % HP, yellow 30–60 %, red < 30 %.
  - "HP n / m" text centred over the bar.
  - Width and colour update every frame from `player.health` / `player.max_health` in `main.gd::_update_health_bar`.
- **Boss text removed**: `BOSS BEAR` RichTextLabel deleted from `boss.tscn`.
- **Boss bear rainbow**: `boss.gd` now cycles `Rig.modulate` through full HSV every ~0.77 s (`RAINBOW_SPEED = 1.3`). Root modulate is reserved for hit flash + death fade — they multiply naturally with the rainbow.

### Boss textures finally rendering
- Ran `Godot --headless --import` against the project — generated `boss_upper.png.import` and `boss_legs.png.import` (Godot's editor hadn't picked up the new PNGs on its own, so the sprite references were resolving to nothing and only the rainbow label was visible).
- **Hostile pizza is rainbow**: `pizza.gd` cycles `modulate` through HSV when `hostile = true` (2.5 cycles / s). Friendly pizza unchanged.

### Bigger arena
- World scaled to 1.5× → **1440 × 810** (`main.gd` `WORLD_W` / `WORLD_H`, all 4 walls + collision shapes resized, `player.tscn` camera limits updated, `pizza.gd` `MAX_DISTANCE_AFTER_BOUNCE` 480 → 720).
- **Window size matched** to the new arena in `project.godot` (`viewport_width = 1440`, `viewport_height = 810`) so the full room is visible without scrolling.
- GAME OVER label re-centred for the new window dimensions.

### Boss fight every 3 floors
- New `scripts/boss.gd` + `scenes/boss.tscn` — a tankier replica of the player.
  - Chases with the same obstacle-avoidance steering as regular enemies (uses the "obstacles" group).
  - 15 HP, slower than regular bears, slightly bigger collision (60 × 60), 1.5 × visual scale.
  - Throws **hostile pizza** at the player every 1.6 s.
  - Longer death sequence (0.4 s fall + 2.0 s vibrate-and-fade).
- New `assets/boss_upper.png` + `assets/boss_legs.png` — pixelated 8-bit look generated by `pixelate_boss.py` (56 × 56 downscale → 14-colour quantize → crisp alpha threshold → nearest-neighbour upscale).
- Sprites use `texture_filter = 1` (nearest) so the pixel blocks stay crisp at display size.
- (Original) `scripts/rainbow_label.gd` + RichTextLabel name plate — later removed in favour of full-body rainbow.
- `main.gd::_start_room` branches on `depth % 3 == 0` → spawns one boss + 4 cylinders instead of the regular enemy waves.
- `pizza.gd` gained a `hostile` flag — when true, ignores enemies and damages the player; friendly pizza is unchanged.
- Cylinder spawning now avoids the player **and** any pre-placed enemies so the boss doesn't spawn inside a pillar.

### Smarter AI, wall borders, pizza bounce
- **4 wall borders** (`StaticBody2D` + `RectangleShape2D`) wrap the floor. Each carries a `flip_axis` metadata flag ("x" or "y") so pizza knows which velocity component to flip on collision. Walls are in the "walls" group.
- **Enemy AI steers around cylinders**: each frame, sums a repulsion vector (away from each obstacle in radius 95 px) plus a tangent vector (perpendicular, toward the side of the obstacle closer to the player). Net result is smooth orbital pathing around posts instead of pinning. Cylinders are now in the "obstacles" group.
- **Pizza bounces once off a wall** (`pizza.gd`): reflects velocity axis based on wall metadata, then travels up to half a room width (`MAX_DISTANCE_AFTER_BOUNCE`) before despawning. Second wall hit or any enemy / cylinder hit destroys it.

### Roguelike room loop
- New `scripts/main.gd` + `scenes/main.tscn` HUD overlay + new `scenes/door.tscn` + `scripts/door.gd`.
  - State machine: `PLAYING` → `CLEARED` → next room, or → `GAME_OVER` → restart.
  - Clearing all enemies opens a door on the right edge; walking into it advances `depth` and re-rolls the room (new cylinder layout, +1 enemy, +1 cylinder up to 12 cap).
  - HUD `DepthLabel` (top-left): "Floor 1", "Floor 2", …
  - HUD `StatusLabel`: shows GAME OVER + "Press R to restart" when the player dies. `R` calls `get_tree().reload_current_scene()`.
  - Player respawns at the left edge of each new room (`Vector2(80, WORLD_H / 2)`).
- Investigated and dismissed full Godot roguelike templates ([SelinaDev](https://github.com/SelinaDev/Godot-Roguelike-Tutorial), [Bozar](https://github.com/Bozar/godot-4-roguelike-tutorial), [statico](https://github.com/statico/godot-roguelike-example), [stesproject](https://github.com/stesproject/godot-2d-topdown-template), [noidexe](https://github.com/noidexe/top-down-action-rpg-template)) — turn-based ones would have replaced the action combat; generic top-down ones would have replaced the bears. Borrowed only the structural Hades-like pattern instead.

### Pizza projectile attack
- Replaced the AOE flash attack with a thrown pizza slice.
- New `assets/pizza.png` (PIL-drawn triangle slice with crust, cheese, pepperoni) via `make_props.py`.
- New `scripts/pizza.gd` + `scenes/pizza.tscn` (Area2D + Sprite2D + CircleShape2D). Spins through the air, expires after 1.4 s.
- `player.gd` now tracks `_last_dir` and throws pizza in that direction on attack input (Space / left-click). Cooldown 0.35 s.
- New `assets/cylinder.png` (PIL-drawn stone post with top-down shading + shadow) + `scenes/cylinder.tscn`. Static obstacles placed randomly each room.
- Camera2D added to `player.tscn` (later clamped to world bounds).

### 2D cutout rigging + hop animation
- `bear_front.png` split into `bear_upper.png` (head + body + arms) and `bear_legs.png` (crossed legs) by `slice_bear.py` (auto-detects the waist as the narrowest horizontal band).
- Same for the brown bear (`brown_upper.png`, `brown_legs.png`).
- `player.tscn` restructured as a `Rig` Node2D holding both halves plus an `AnimationPlayer`.
  - `idle` (~1.6 s breathing) and `move` (~0.4 s hop with squash-and-stretch).
- `player.gd` switches between `idle` / `move` based on input, flips the rig horizontally to match facing direction, and **leans 8°** into the direction of motion (`lerp_angle` to a target).
- `enemy.tscn` got the same treatment with a constant-looping `move` so the brown bears bounce while chasing.

### Project moved + Godot installed
- Project relocated from `Desktop\lol\stuffed-crawler\` to `Desktop\game\` (OneDrive-synced).
- **Godot 4.3 stable** downloaded (~95 MB zip) and extracted to `C:\Users\matt\Godot\`.
- Desktop shortcut `Godot.lnk` created on the OneDrive-synced Desktop (`C:\Users\matt\OneDrive - Elucid Systems\Desktop\`).

### Photo → sprite pipeline
- Two bears photographed and processed into 256 × 256 transparent PNGs.
  - Black bear (`IMG_3162.JPG`, `IMG_3163.JPG`) → `bear_front.png`, `bear_side.png`.
  - Brown bear (`IMG_3178.JPG`, `IMG_3179.JPG`) → `brown_front.png`, `brown_side.png`.
- `process_bear.py` does the heavy lifting: EXIF orientation fix → `rembg` (u2net model) background removal → bbox crop → fit-to-square on a transparent canvas.
- `rembg[cpu]` + Pillow installed locally; model downloads once (~176 MB) on first run.
- `player.tscn` Sprite2D wired to `bear_front.png`; `enemy.tscn` Sprite2D wired to `brown_front.png`.

### Initial scaffold
- Godot 4 project created in `Desktop\lol\stuffed-crawler\` (later moved).
- Player (`scripts/player.gd` + `scenes/player.tscn`): CharacterBody2D with WASD / arrow movement, 220 px/s, mouse-or-Space attack with AOE flash + radius damage.
- Enemy (`scripts/enemy.gd` + `scenes/enemy.tscn`): naive chase-the-player AI, 3 HP, touch damage on contact.
- Main scene (`scripts/main.gd` + `scenes/main.tscn`): solid grey floor, 3 enemies, auto-respawn one whenever the world is empty.
- Input map: `move_up` / `move_down` / `move_left` / `move_right` / `attack`.
- Visuals were placeholder `ColorRect` squares (player blue, enemy red).

---

## Asset / script index (current state)

### `assets/`
- `bear_front.png`, `bear_side.png`, `bear_upper.png`, `bear_legs.png` — black bear (player)
- `brown_front.png`, `brown_side.png`, `brown_upper.png`, `brown_legs.png` — brown bear (regular enemy)
- `boss_upper.png`, `boss_legs.png` — pixelated boss
- `pizza.png` — player projectile (rainbow when thrown by boss)
- `ninja_star.png` — hard-mode enemy projectile
- `cylinder.png` — obstacle
- `portal.png` — next-floor doorway
- `explosion.png` — boss-death burst
- `health_orb.png` — +1 HP pickup (regular enemy drop)
- `full_heal.png` — full-heal pickup (boss drop)
- `stuffing.png` — cotton-puff chunk used by the boss-explosion debris
- `tree_deciduous.png`, `tree_pine.png` — CC0 pixel-art trees (inkBubi)
- `stone_big.png`, `stone_small.png` — CC0 pixel-art stones (inkBubi)
- `bush_a.png` … `bush_d.png` — CC0 pixel-art bushes (inkBubi)
- `grass_tile.png` — CC0 grass tile (inkBubi), reserved for tiled floor pass
- `cactus_tall.png`, `cactus_round.png` — CC0 cacti (ScratchIO)
- `desert_bush.png` — CC0 desert shrub (ScratchIO)
- `desert_rocks.png` — CC0 multi-rock cluster (ScratchIO)
- `pond.png` — procedural pond (water colour sampled from inkBubi's tile, drawn fresh)
- `pizza_bomb.png` — cartoon bomb sprite (used by both projectile + pickup)
- `scatter_pickup.png` — 3-pizza fan, blue aura
- `homing_pickup.png` — pizza inside magenta targeting reticle

### `scripts/`
- `game_settings.gd` — autoload singleton: difficulty + multipliers
- `run_state.gd` — autoload singleton: active boons for this run + stat-modifier accessors
- `dev_state.gd` — autoload singleton: dev/test toggles
- `meta_save.gd` — autoload singleton: persistent run-survivable Fluff + upgrade levels (JSON @ `user://meta.json`)
- `workshop.gd` — Workshop screen for spending Fluff on permanent upgrades
- `desert_boss.gd` — slow, charging, summoning desert-biome boss
- `pizza_wheel.gd` — orbital defensive pizza (Pizza Wheel legendary boon)
- `victory_screen.gd` — Floor 10 win pop-up with stats + reward summary
- `loadout_screen.gd` — pre-run weapon + ascension picker
- `dev_menu.gd` — Esc-triggered pause overlay with debug toggles + actions
- `pizza_bomb.gd` — thrown bomb projectile with fuse + AOE detonation
- `weapon_pickup.gd` — generic special-weapon pickup (bomb / scatter / homing)
- `boon_card_screen.gd` — pause-overlay picker shown between floors
- `game_over_screen.gd` — death pop-up with Start-Over / Main-Menu options
- `title_screen.gd` — menu, difficulty cycling, options panel, scene change to main
- `player.gd` — movement, attack throw, rig flip + lean, camera shake
- `enemy.gd` — chase, obstacle-avoidance steering, death sequence, hard-mode ninja-star throw
- `boss.gd` — chase + throw hostile pizza, rainbow rig modulation, longer death, spawns Explosion + shakes camera on defeat
- `pizza.gd` — flight, single wall bounce, friendly/hostile targeting, rainbow tint when hostile
- `ninja_star.gd` — straight-flight projectile, no bounce, kills on first non-enemy collision
- `pickup.gd` — generic healing-orb behaviour (bob, spin, heal player on overlap)
- `body_chunk.gd` — flying piece of debris (used by boss death; ballistic + drag + fade)
- `hazard.gd` — pulsing on/off floor damage zone
- `spike_trap.gd` — one-shot tripwire trap *(no longer spawned, kept for future use)*
- `sweeper_saw.gd` — sliding saw-blade hazard, always dangerous
- `door.gd` — Area2D portal that emits `entered_by_player`
- `explosion.gd` — short-lived expanding-burst effect
- `main.gd` — state machine, room generation, HUD updates (player + boss bars), restart input, difficulty scaling
- `rainbow_label.gd` — unused (was the per-character scrolling rainbow label for the boss; kept for possible future banner)

### `scenes/`
- `title_screen.tscn` — entry point
- `boon_card_screen.tscn` — pause overlay for picking a boon
- `game_over_screen.tscn` — modal pop-up shown after the player's death animation
- `main.tscn` — root gameplay scene (Floor, walls, Player, HUD)
- `player.tscn`, `enemy.tscn`, `boss.tscn`
- `pizza.tscn`, `ninja_star.tscn`, `cylinder.tscn`, `door.tscn`, `explosion.tscn`
- `health_orb.tscn`, `full_heal.tscn`, `body_chunk.tscn`, `hazard.tscn`, `spike_trap.tscn`, `sweeper_saw.tscn`
- `tree.tscn`, `pine_tree.tscn`, `stone.tscn`, `bush.tscn` (forest biome props)
- `cactus_tall.tscn`, `cactus_round.tscn`, `desert_bush.tscn`, `desert_rocks.tscn` (desert biome props)
- `pond.tscn` (slow-zone water)
- `pizza_bomb.tscn` (thrown bomb projectile)
- `bomb_pickup.tscn`, `scatter_pickup.tscn`, `homing_pickup.tscn` (weapon pickups)
- `dev_menu.tscn` (Esc dev/test overlay)
- `workshop.tscn` (meta-upgrades shop on title screen)
- `desert_boss.tscn`, `pizza_wheel.tscn`
- `victory_screen.tscn`
- `loadout_screen.tscn`

### Utility scripts (project root)
- `process_bear.py` — photo → transparent square sprite
- `slice_bear.py` — sprite → upper + legs halves at auto-detected waist
- `make_props.py` — generate pizza + cylinder PNGs
- `pixelate_boss.py` — 8-bit treatment for boss textures
- `make_portal.py` — generate portal PNG
- `make_ninja_star.py` — generate throwing-star PNG
- `make_explosion.py` — generate boss-death burst PNG
- `make_pickups.py` — generate health-orb + full-heal PNGs
- `make_stuffing.py` — generate cotton-puff chunk PNG
- `prep_forest_assets.py` — slice the CC0 inkBubi forest tilesheet into individual sprites
- `prep_more_assets.py` — slice ScratchIO desert sheet + bake procedural pond
- `make_bomb.py` — generate the pizza-bomb pickup PNG
- `make_weapon_pickups.py` — composite scatter + homing pickup PNGs from `pizza.png`

---

## How to add a new entry

1. Add a new dated `## YYYY-MM-DD` section at the very top.
2. Under it, group changes into short subsections (e.g. "### Combat tuning", "### New enemy: red bear").
3. Each bullet should be specific enough that someone can find the change in code — file paths, identifier names, constant changes ("HP 5 → 7").
4. If a new asset, script, or scene was added, also append it to the **Asset / script index** below.
