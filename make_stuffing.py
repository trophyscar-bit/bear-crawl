"""Generate a small cotton-stuffing puff PNG for boss-death debris."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import math, random

OUT = Path(__file__).parent / "assets"
OUT.mkdir(exist_ok=True)
SIZE = 48
CX = CY = SIZE // 2

img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

# soft outer glow
glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse([CX - 18, CY - 18, CX + 18, CY + 18], fill=(255, 252, 240, 200))
glow = glow.filter(ImageFilter.GaussianBlur(3))
img.alpha_composite(glow)

# base puff
ImageDraw.Draw(img).ellipse([CX - 14, CY - 14, CX + 14, CY + 14], fill=(255, 250, 235))

# random fluffy fibres
random.seed(13)
for _ in range(70):
    a = random.uniform(0, math.pi * 2)
    r = random.uniform(0, 18)
    bx = CX + math.cos(a) * r
    by = CY + math.sin(a) * r
    bsize = random.uniform(2, 5)
    col = random.choice([
        (255, 250, 235),
        (245, 235, 215),
        (255, 255, 250),
    ])
    ImageDraw.Draw(img).ellipse([bx - bsize, by - bsize, bx + bsize, by + bsize], fill=col)

img.save(OUT / "stuffing.png")
print("wrote stuffing.png")
