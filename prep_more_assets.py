"""Slice additional CC0 asset packs into individual sprite PNGs.

- Desert decorations from ScratchIO (CC0): cacti + desert bush + rocks
- Pond chunks extracted from inkBubi's grass_deep_water tilesheet (CC0)
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).parent
OUT = ROOT / "assets"


def crop_and_save(img, box, name):
    cropped = img.crop(box)
    bbox = cropped.getbbox()
    if bbox is not None:
        cropped = cropped.crop(bbox)
    cropped.save(OUT / name)
    print(f"wrote {name} ({cropped.size})")


# --- Desert pack: scratchio_desert.png (336x80) ---
# Layout (from x-range analysis):
#   (7, 80)    dead leafless tree
#   (92, 144)  green desert tree
#   (157, 181) tall cactus
#   (193, 208) round / barrel cactus
#   (213, 255) desert bush / shrub
#   (256, 336) rocks (two-three of them in a row)
desert = Image.open(OUT / "scratchio_desert.png").convert("RGBA")
crop_and_save(desert, (7,   0,  80, 80), "desert_tree_dead.png")
crop_and_save(desert, (92,  0, 144, 80), "desert_tree_green.png")
crop_and_save(desert, (157, 0, 181, 80), "cactus_tall.png")
crop_and_save(desert, (193, 0, 208, 80), "cactus_round.png")
crop_and_save(desert, (213, 0, 255, 80), "desert_bush.png")
crop_and_save(desert, (256, 0, 336, 80), "desert_rocks.png")  # multi-rock — could be split further

# --- Pond — procedural so it blends with whatever floor colour the biome uses ---
# Samples water blue from inkBubi's sheet so the colour matches their palette,
# but draws our own clean oval pond with a hard pixel-art edge.
def make_pond():
    from PIL import ImageDraw
    water = Image.open(ROOT / "assets" / "forest_kit" / "texture only" / "Forest Tileset - Free" / "grass_deep_water.png").convert("RGBA")
    # sample a known pure-water pixel — middle column tends to be solid water
    water_rgb = water.getpixel((136, 96))[:3]
    water_dark = tuple(max(c - 50, 0) for c in water_rgb)
    water_light = tuple(min(c + 70, 255) for c in water_rgb)

    W, H = 112, 80
    pond = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(pond)
    cx, cy = W // 2, H // 2

    # dark muddy outline
    d.ellipse([1, 1, W - 2, H - 2], fill=water_dark + (255,))
    # main water body
    d.ellipse([4, 4, W - 5, H - 5], fill=water_rgb + (255,))
    # subtle highlight strip on upper-left
    d.ellipse([14, 10, W // 2 + 8, H // 2 - 2], fill=water_light + (180,))
    # bright reflection pinpoint
    d.ellipse([22, 16, 36, 22], fill=(255, 255, 255, 200))
    # a second smaller reflection lower-right
    d.ellipse([W - 38, H - 30, W - 22, H - 24], fill=(255, 255, 255, 110))

    pond.save(OUT / "pond.png")
    print(f"wrote pond.png ({pond.size}) — water rgb sampled = {water_rgb}")

make_pond()
