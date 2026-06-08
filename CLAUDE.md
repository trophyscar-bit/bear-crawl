# Bear Crawl — Project Memory

## Asset rule (PERMANENT)

**Always prefer real CC0 assets from online sources over procedural / hand-coded visuals.** When the user asks for any new visual (enemy projectile, attack effect, prop, pickup, UI element, particle, etc.), the default path is:

1. Search **kenney.nl**, **opengameart.org** (CC0 / CC0 1.0 filter), or **itch.io** (CC0 only) for a matching asset.
2. Download the pack/tile, copy the source into `assets/<descriptive_name>/` along with the license file.
3. Wire it into the relevant scene/script.
4. Only fall back to procedural `Polygon2D` / `Line2D` drawing if:
   - User explicitly requests procedural ("draw it from scratch", "make it cartoon," etc.), OR
   - A reasonable CC0 asset genuinely doesn't exist after a real search, OR
   - The visual is trivial UI chrome (pips, borders, etc.) that doesn't benefit from sourced art.

Existing examples of correct sourced-asset use:
- `assets/fire1_64.png` — BenHickling animated fire (CC0, OpenGameArt)
- `assets/explosion_sheet.png` — BenHickling explosion (CC0, OpenGameArt)
- `assets/ring_shockwave.png` — BenHickling ring explosion (CC0, OpenGameArt)
- `assets/pond.png` — composited from Kenney RPG Base tiles (CC0, kenney.nl)
- `assets/kenney_rpg_base/` — source tiles + license

Procedural attempts that we ended up replacing (lesson learned):
- Old pond.png — multiple procedural rewrites the user hated → finally fixed with Kenney tiles
- air_line_blast.gd ("plastic wrap line AoE") — procedural Line2D + Polygon2D, ugly. Needs CC0 replacement.

When in doubt: **search online first, code procedurally last.**

---

## Project conventions

- Engine: **Godot 4.3+** (currently using 4.6 binary for headless ops)
- Project root: `C:\Users\matt\OneDrive - Elucid Systems\Desktop\game\`
- Main script: `scripts/main.gd`
- Player: `scripts/player.gd` / `scenes/player.tscn`
- All enemies extend `scripts/enemy.gd`
- Bosses: `scripts/boss.gd` (Floor 3), `scripts/face_boss.gd` (Floor 9 sky), `scripts/desert_boss.gd` (Floor 6 + Floor 10 final)

### Collision layers (CRITICAL — anything that fights must respect this)
- **Layer 1**: walls, ponds, player, regular bosses (boss.gd, desert_boss.gd)
- **Layer 3**: trash enemies (KK / MB / Shrinkwrap / Gun Bear) — they pass through each other physically
- **Layer 4**: Face Boss (Floor 9) — player walks UNDER it, only pizzas hit
- **Player mask**: 1 + 3 (collides with walls/ponds, bosses, and enemies)
- **Pizza/projectile masks**: 1 + 3 + 4 (hits everything damageable)

### Asset processing pipeline (for user photos like 3.JPG, 6.jpg, 7.jpg)
Use the proven recipe in `tools/process_*.py`:
1. EXIF transpose
2. rembg cutout
3. ImageEnhance saturation +20–35%, contrast +18–25%
4. UnsharpMask radius 2, percent 70–80
5. **Hole-filling alpha**: threshold `>50`, then `scipy.ndimage.binary_closing` with 5×5 kernel, 2 iterations
6. Tight crop with 6–8 px pad, LANCZOS resize to 256–720 px max dim
7. Save as PNG

### Godot import cache
- **NEVER** `rm -rf .godot/imported/*` — it nukes all baked textures and the game launches with nothing visible.
- Safe: remove only the `.cfg` files (`global_script_class_cache.cfg`, `scene_groups_cache.cfg`, `uid_cache.bin`).
- For single-asset refresh: `rm .godot/imported/<asset>.png-*.ctex` then run `Godot --headless --import`.
- Godot 4.6 binary is at `/tmp/godot_extract/Godot_v4.6.2-stable_win64.exe` (extracted from the user's Downloads zip).

### CHANGELOG
- Maintained at `CHANGELOG.md`, newest entries at the top.
- Every batch of changes gets a heading + bullet list of what shipped.

### Level-building workflow (REQUIRED — user mandate)
When building ANY level/biome, do NOT eyeball it. Every time:
1. **Reference first** — research ~10 reference shots/descriptions of the real thing
   (web search the layout, e.g. "top-down warehouse layout", "spaceship hangar floor plan").
2. **Analyse** — write down what works, what doesn't, what's doable vs not with our assets.
3. **Map to assets** — list which assets we ALREADY have that correspond to the reference
   (check assets/fx/biome, assets/backrooms/props, assets/kenney_pack, etc.).
4. **Build to the reference** — organised/cohesive layout (rows, aisles, bays — not random
   scatter). Real places are orderly; random prop spam reads as "AI who's never seen one."
