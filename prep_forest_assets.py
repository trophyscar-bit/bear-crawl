"""Slice the CC0 'Seasons of Forest' tileset (by inkBubi) into individual sprite PNGs.

Source: https://opengameart.org/content/free-sample-16x16-pixel-forest-tileset-%E2%80%93-top-down-rpg-style
License: CC0
"""
from pathlib import Path
from PIL import Image

SRC = Path(__file__).parent / "assets" / "forest_kit" / "texture only" / "Forest Tileset - Free"
OUT = Path(__file__).parent / "assets"

def crop_and_save(img, box, name):
    cropped = img.crop(box)
    # Trim transparent border to a tight crop, keeps positioning predictable
    bbox = cropped.getbbox()
    if bbox is not None:
        cropped = cropped.crop(bbox)
    cropped.save(OUT / name)
    print(f"wrote {name} ({cropped.size})")

# --- Trees: 64x128 sheet, two trees stacked ---
trees = Image.open(SRC / "trees.png").convert("RGBA")
crop_and_save(trees, (0, 0, 64, 64), "tree_deciduous.png")
crop_and_save(trees, (0, 64, 64, 128), "tree_pine.png")

# --- Stones: 48x32 sheet, two stones side by side ---
stones = Image.open(SRC / "stones.png").convert("RGBA")
crop_and_save(stones, (0, 0, 30, 32), "stone_big.png")
crop_and_save(stones, (30, 0, 48, 32), "stone_small.png")

# --- Bushes: 32x32 sheet, four bushes in 2x2 grid (16x16 each cell) ---
bushes = Image.open(SRC / "bushes.png").convert("RGBA")
crop_and_save(bushes, (0, 0, 16, 16), "bush_a.png")
crop_and_save(bushes, (16, 0, 32, 16), "bush_b.png")
crop_and_save(bushes, (0, 16, 16, 32), "bush_c.png")
crop_and_save(bushes, (16, 16, 32, 32), "bush_d.png")

# --- Grass: copy 64x64 tile as-is for tiling background ---
grass = Image.open(SRC / "grass.png").convert("RGBA")
grass.save(OUT / "grass_tile.png")
print(f"wrote grass_tile.png ({grass.size})")
