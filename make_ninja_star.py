"""Generate a 4-pointed throwing-star PNG for hard-mode enemy projectiles."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import math

OUT = Path(__file__).parent / "assets"
OUT.mkdir(exist_ok=True)
SIZE = 64
CX = CY = SIZE / 2

img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
outer = 28.0
inner = 7.5

points = []
for i in range(8):
    angle = -math.pi / 2 + i * math.pi / 4
    r = outer if i % 2 == 0 else inner
    points.append((CX + r * math.cos(angle), CY + r * math.sin(angle)))

# drop shadow
shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ImageDraw.Draw(shadow).polygon([(p[0] + 2, p[1] + 2) for p in points], fill=(0, 0, 0, 130))
shadow = shadow.filter(ImageFilter.GaussianBlur(2))
img.alpha_composite(shadow)

# star body
d = ImageDraw.Draw(img)
d.polygon(points, fill=(150, 158, 170), outline=(35, 38, 48), width=2)

# centre hole
d.ellipse([CX - 5, CY - 5, CX + 5, CY + 5], fill=(20, 22, 28))

# blade highlights (lighter edge along top-left side)
hi = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
dh = ImageDraw.Draw(hi)
for i in range(0, 8, 2):
    p1 = points[i]
    p2 = points[(i + 1) % 8]
    dh.line([p1, p2], fill=(225, 230, 240, 200), width=1)
hi = hi.filter(ImageFilter.GaussianBlur(0.6))
img.alpha_composite(hi)

img.save(OUT / "ninja_star.png")
print("wrote ninja_star.png")
