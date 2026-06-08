"""
Crops the finished pond design out of the CC0 pond_tiles.png tileset
(AmberFallStudio, OpenGameArt) and saves it as assets/pond.png at a usable
in-game size. Replaces the previous procedurally drawn pond.
"""

import os
from PIL import Image

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ASSETS = os.path.join(PROJECT_ROOT, "assets")
SRC = os.path.join(ASSETS, "pond_tiles.png")
OUT = os.path.join(ASSETS, "pond.png")

# Coordinates of the finished green-border pond in the 256x256 source.
# Determined by eye from the tileset layout: top-left of the pond at (96, 96),
# size ~128x96.
CROP_X = 96
CROP_Y = 96
CROP_W = 128
CROP_H = 96

# Target render size in-game — bump 2x so the pond reads at a reasonable
# scale relative to the player (~30 px tall).
SCALE = 2


def main():
    im = Image.open(SRC).convert("RGBA")
    crop = im.crop((CROP_X, CROP_Y, CROP_X + CROP_W, CROP_Y + CROP_H))
    # Tight crop alpha just in case (the tileset edges are opaque so this is a no-op safety)
    bbox = crop.getchannel("A").getbbox()
    if bbox:
        crop = crop.crop(bbox)
    if SCALE != 1:
        crop = crop.resize(
            (crop.width * SCALE, crop.height * SCALE),
            Image.NEAREST,  # keep crisp pixel-art edges
        )
    crop.save(OUT, optimize=True)
    print(f"Wrote {OUT}  ({crop.width}x{crop.height})")


if __name__ == "__main__":
    main()
