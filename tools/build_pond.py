"""
Builds the pond using REAL Kenney CC0 Roguelike/RPG Pack tiles (grass +
sand + water). Vibrant teal water with a sandy shore and bright grass border.

Source tiles (CC0, kenney.nl Roguelike/RPG Pack):
  assets/kenney_roguelike/grass.png   (16x16 bright green)
  assets/kenney_roguelike/sand.png    (16x16 tan/cream shore)
  assets/kenney_roguelike/water.png   (16x16 cyan/teal water)

Output: assets/pond.png  (192 x 128)
"""

import os
from PIL import Image, ImageDraw, ImageFilter

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ASSETS = os.path.join(PROJECT_ROOT, "assets")
KENNEY = os.path.join(ASSETS, "kenney_roguelike")
OUT = os.path.join(ASSETS, "pond.png")

W, H = 192, 128


def tile(im_tile, w, h):
    """Tile a small image to fill (w, h)."""
    out = Image.new("RGBA", (w, h))
    tw, th = im_tile.size
    for y in range(0, h, th):
        for x in range(0, w, tw):
            out.paste(im_tile, (x, y))
    return out


def make_mask(w, h, rx, ry):
    """Solid white ellipse on transparent."""
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    cx, cy = w // 2, h // 2
    d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=255)
    return m


def main():
    grass = Image.open(os.path.join(KENNEY, "grass.png")).convert("RGBA")
    sand = Image.open(os.path.join(KENNEY, "sand.png")).convert("RGBA")
    water = Image.open(os.path.join(KENNEY, "water.png")).convert("RGBA")

    cx, cy = W // 2, H // 2
    # 1) Outer grass disc (everything outside is transparent)
    grass_tiled = tile(grass, W, H)
    grass_mask = make_mask(W, H, 92, 60)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.paste(grass_tiled, (0, 0), grass_mask)

    # 2) Sand shore ring (using the tile texture, not a flat color)
    sand_tiled = tile(sand, W, H)
    sand_mask = make_mask(W, H, 78, 50)
    out.paste(sand_tiled, (0, 0), sand_mask)

    # 3) Water disc
    water_tiled = tile(water, W, H)
    water_mask = make_mask(W, H, 68, 42)
    out.paste(water_tiled, (0, 0), water_mask)

    # Soft alpha-only blur for clean edges
    rgb = out.convert("RGB")
    a = out.split()[3].filter(ImageFilter.GaussianBlur(radius=0.7))
    final = Image.merge("RGBA", (*rgb.split(), a))

    final.save(OUT, optimize=True)
    print(f"Wrote {OUT}  ({W}x{H})")


if __name__ == "__main__":
    main()
