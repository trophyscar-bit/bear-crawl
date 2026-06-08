"""Generate a big explosion burst PNG for boss death."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import math, random

OUT = Path(__file__).parent / "assets"
OUT.mkdir(exist_ok=True)
SIZE = 256
CX = CY = SIZE // 2

img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

# Outer orange halo
for r in range(120, 60, -1):
    t = (120 - r) / 60.0
    alpha = int(80 * (t ** 1.6))
    color = (255, int(140 + 90 * t), int(40 + 60 * t), alpha)
    ImageDraw.Draw(img).ellipse([CX - r, CY - r, CX + r, CY + r], outline=color, width=1)

# Bright yellow-white core glow
core = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ImageDraw.Draw(core).ellipse([CX - 70, CY - 70, CX + 70, CY + 70], fill=(255, 220, 130, 200))
ImageDraw.Draw(core).ellipse([CX - 40, CY - 40, CX + 40, CY + 40], fill=(255, 245, 200, 240))
core = core.filter(ImageFilter.GaussianBlur(5))
img.alpha_composite(core)

# Star rays
rays = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
dr = ImageDraw.Draw(rays)
random.seed(42)
for i in range(14):
    angle = i * (math.pi * 2 / 14) + random.uniform(-0.18, 0.18)
    length = random.uniform(90, 130)
    width = random.uniform(3, 7)
    x2 = CX + math.cos(angle) * length
    y2 = CY + math.sin(angle) * length
    dr.line([(CX, CY), (x2, y2)], fill=(255, 230, 160, 220), width=int(width))
rays = rays.filter(ImageFilter.GaussianBlur(2))
img.alpha_composite(rays)

# Hot white pinpoint
ImageDraw.Draw(img).ellipse([CX - 22, CY - 22, CX + 22, CY + 22], fill=(255, 255, 240, 255))

img.save(OUT / "explosion.png")
print("wrote explosion.png")
