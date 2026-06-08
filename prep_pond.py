"""Build a pond with a hard pixel-art shoreline.

inkBubi's tileset has water as the dominant terrain (with grass islands), so
its transition tiles don't make a clean pond. Instead we draw our own pond in
pixel-art style using the SAMPLED water + grass colours from the sheet, with
a chunky grass shore ring so the pond visually reads as impassable terrain.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).parent
SHEET = ROOT / "assets" / "forest_kit" / "texture only" / "Forest Tileset - Free" / "grass_deep_water.png"
OUT = ROOT / "assets"

sheet = Image.open(SHEET).convert("RGBA")
# Sample water blue from a pure-water tile location
water = sheet.getpixel((96 + 8, 16 + 8))[:3]
water_dark = tuple(max(c - 30, 0) for c in water)
water_light = tuple(min(c + 50, 255) for c in water)
# Hardcode grass green to match the in-game floor mossy palette
grass = (95, 158, 80)
grass_dark = (55, 110, 50)
grass_edge = (75, 130, 65)

W, H = 112, 84
img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

# Drop shadow under the pond (gives it some "depth in the ground")
shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ImageDraw.Draw(shadow).ellipse([4, 8, W - 5, H - 1], fill=(0, 0, 0, 90))
shadow = shadow.filter(ImageFilter.GaussianBlur(4))
img.alpha_composite(shadow)

d = ImageDraw.Draw(img)

# Outer shoreline — chunky grass ring (this is what "stops" the player visually)
d.ellipse([0, 4, W - 1, H - 1], fill=grass)
d.ellipse([2, 6, W - 3, H - 3], fill=grass_edge)
d.ellipse([5, 8, W - 6, H - 5], fill=grass_dark)

# Water body
d.ellipse([8, 10, W - 9, H - 8], fill=water_dark)
d.ellipse([10, 12, W - 11, H - 10], fill=water)

# Water highlights — couple of horizontal ripple lines
for i in range(3):
    y = 22 + i * 8
    x0 = 18 + (i % 2) * 6
    x1 = W - 24 - (i % 2) * 4
    d.line([(x0, y), (x1, y)], fill=water_light + (200,), width=1)

# Big white reflection blob top-left
hi = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ImageDraw.Draw(hi).ellipse([20, 18, 44, 26], fill=(255, 255, 255, 210))
img.alpha_composite(hi)
# Small reflection bottom-right
ImageDraw.Draw(img).ellipse([W - 32, H - 24, W - 22, H - 20], fill=(255, 255, 255, 130))

img.save(OUT / "pond.png")
print(f"wrote pond.png ({img.size})  water={water}  grass={grass}")
