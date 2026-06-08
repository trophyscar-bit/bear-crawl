"""Build a 1440x160 horizon strip per biome and save into assets/.

Sources (all integrated locally — see CHANGELOG for credits):
  - forest: ansimuz parallax mountain (already in repo) — re-used existing horizon.png
  - desert: ansimuz parallax tinted warm/sandy
  - sky:    PauR cloud background, tiled (CC-BY)
  - snow:   ramses2099 air-adventure level 4 (CC0), cropped to 160 strip
  - fall:   ansimuz parallax tinted orange + jkjkke temple background (CC-BY)
"""
from pathlib import Path
from PIL import Image, ImageEnhance, ImageOps

ROOT = Path(__file__).parent
PARALLAX = ROOT / "assets" / "parallax"
OUT = ROOT / "assets"

W, H = 1440, 160


def tile_horizontal(img: Image.Image, w: int, h: int) -> Image.Image:
	if img.height != h:
		ratio = h / img.height
		img = img.resize((max(1, int(img.width * ratio)), h), Image.LANCZOS)
	canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	for x in range(0, w, img.width):
		canvas.paste(img, (x, 0))
	return canvas


def crop_strip(img: Image.Image, w: int, h: int, y_start: int = 0) -> Image.Image:
	"""Take a horizontal strip from a wide image. If image is wider than w it's
	cropped; otherwise it's stretched to width."""
	if img.height > y_start + h:
		strip = img.crop((0, y_start, img.width, y_start + h))
	else:
		strip = img
	if strip.width != w:
		strip = strip.resize((w, h), Image.LANCZOS)
	if strip.height != h:
		strip = strip.resize((w, h), Image.LANCZOS)
	return strip.convert("RGBA")


# Forest — re-use the existing dusk-mountain composite (CC0 ansimuz)
forest = Image.open(OUT / "horizon.png").convert("RGBA")
forest.save(OUT / "horizon_forest.png")

# Desert — same dusk mountain layers but warm/sandy tint
desert = forest.copy()
# Warm shift: boost reds, knock greens, knock blues
r, g, b, a = desert.split()
r = r.point(lambda v: min(255, int(v * 1.18 + 18)))
g = g.point(lambda v: int(v * 0.95))
b = b.point(lambda v: int(v * 0.78))
desert = Image.merge("RGBA", (r, g, b, a))
desert.save(OUT / "horizon_desert.png")
print("wrote horizon_forest + horizon_desert")

# Sky — PauR clouds tiled across width
sky_src = Image.open(PARALLAX / "sky.png").convert("RGBA")
sky_strip = tile_horizontal(sky_src, W, H)
sky_strip.save(OUT / "horizon_sky.png")
print("wrote horizon_sky.png")

# Snow — ramses2099 air-adventure level 4 cropped to top horizon strip
snow_src = Image.open(PARALLAX / "snow_pack" / "airadventurelevel4.png").convert("RGBA")
# Take top 480 px (sky + stars + far hills), then squeeze to 160 H, 1440 W
snow_strip = snow_src.crop((0, 0, snow_src.width, 720))
snow_strip = snow_strip.resize((W, H), Image.LANCZOS)
snow_strip.save(OUT / "horizon_snow.png")
print("wrote horizon_snow.png")

# Fall — jkjkke temple background (640x320, CC-BY), top strip warm-toned
fall_src = Image.open(PARALLAX / "temple_forest.jpg").convert("RGBA")
fall_strip = fall_src.crop((0, 0, fall_src.width, 200))
fall_strip = fall_strip.resize((W, H), Image.LANCZOS)
# Push toward autumn oranges
r, g, b, a = fall_strip.split()
r = r.point(lambda v: min(255, int(v * 1.15 + 12)))
g = g.point(lambda v: int(v * 0.85))
b = b.point(lambda v: int(v * 0.7))
fall_strip = Image.merge("RGBA", (r, g, b, a))
fall_strip.save(OUT / "horizon_fall.png")
print("wrote horizon_fall.png")
