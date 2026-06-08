# Backrooms assets (Cute SCKR pack, sliced & categorized)

Source: **Backrooms Pixel Art Tileset by Cute SCKR** (purchased), raw sheets in
"game_v2/backrooms_assets/". 558 sprites auto-cut via connected-component slicing.

## Layout
- "_sliced/<Sheet>/" — every sprite cut from each source sheet, organized by source:
  - Level01 / Level02 / Level03 — Level 0 props (furniture, debris, doors, graffiti
    alphabet, blood stains, water bottles, beds, barrels, crates).
  - Level11 / level12 — Level 1 tiles + props.
  - Level101 / Level102 / Level103 / 5 — Level 10 (suburbia: trees, houses, figures).
  - pool_core1 / pool_core2 — Poolrooms tiles + props.
  - AutotileA4walls2 / AutotileA4walls3 — wall autotiles (used for wall textures).
- "_contact/<Sheet>.png" — numbered contact sheets to browse each folder.
- "props/<category>/" — curated, categorized props: furniture, debris, containers,
  items, stains, markings.
- "props/scatter/" — floor-clutter set the backrooms scatters at runtime
  (dungeon._spawn_props).

## Wall/floor textures currently wired (Level 0)
- assets/backrooms_pack5_wall.png  = yellow drop-stripe wallpaper (A4 walls 5,8)
- assets/backrooms_pack5_floor.png = flecked tan backrooms carpet (Level-0-1 tile 0,10) — uniform speckle, no stripes, distinct from the striped wallpaper wall

## Not yet wired (available for future floors/decor)
- Level 1, Level 10, Poolrooms tiles → could become deeper descent floors.
- Doors/windows, beds, graffiti alphabet (wall text), the Level 10 suburbia set.
