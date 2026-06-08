"""Composite the inkBubi parallax mountain pack (CC0, by ansimuz) into a
single horizon strip sized 1440x160 — the top-of-screen sky band."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).parent
SRC = ROOT / "assets" / "parallax" / "parallax_mountain_pack" / "layers"
OUT = ROOT / "assets"

W = 1440
H = 160

bg = Image.open(SRC / "parallax-mountain-bg.png").convert("RGBA")
far = Image.open(SRC / "parallax-mountain-montain-far.png").convert("RGBA")
mountains = Image.open(SRC / "parallax-mountain-mountains.png").convert("RGBA")

# Tile the sky background horizontally (stretching it 5x looked smeary).
sky = Image.new("RGBA", (W, H), (0, 0, 0, 0))
for x in range(0, W, bg.width):
	sky.paste(bg, (x, 0))

# Tile the far mountains horizontally (preserve their pixel art)
far_tiled = Image.new("RGBA", (W, H), (0, 0, 0, 0))
for x in range(0, W, far.width):
    far_tiled.paste(far, (x, 0), far)

# Tile the front mountains
near_tiled = Image.new("RGBA", (W, H), (0, 0, 0, 0))
for x in range(0, W, mountains.width):
    near_tiled.paste(mountains, (x, 0), mountains)

# Composite
out = sky.copy()
out.alpha_composite(far_tiled)
out.alpha_composite(near_tiled)
out.save(OUT / "horizon.png")
print(f"wrote horizon.png ({out.size})")
