"""Generate a magical portal PNG for the next-floor doorway.

Draws at 2x then downsamples with LANCZOS for crisp anti-aliased rings.
Layered look inspired by Hades Chaos Gates: outer rune ring + middle rotation ring + glowing core.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import math

OUT = Path(__file__).parent / "assets"
OUT.mkdir(exist_ok=True)
HIRES = 512
FINAL = 256
CX = HIRES // 2
CY = HIRES // 2

img = Image.new("RGBA", (HIRES, HIRES), (0, 0, 0, 0))

# Soft purple outer halo (the only place we keep heavy blur)
halo = Image.new("RGBA", (HIRES, HIRES), (0, 0, 0, 0))
for r in range(245, 180, -2):
    t = (245 - r) / 65.0
    alpha = int(120 * (t ** 1.4))
    ImageDraw.Draw(halo).ellipse(
        [CX - r, CY - r, CX + r, CY + r],
        outline=(155, 110, 235, alpha),
        width=3,
    )
halo = halo.filter(ImageFilter.GaussianBlur(10))
img.alpha_composite(halo)

# Outer golden ring with rune tick marks
ring_outer = Image.new("RGBA", (HIRES, HIRES), (0, 0, 0, 0))
d_outer = ImageDraw.Draw(ring_outer)
d_outer.ellipse(
    [CX - 184, CY - 184, CX + 184, CY + 184],
    outline=(245, 205, 95, 255),
    width=10,
)
# 12 long ticks at clock positions + 12 short ticks between
for i in range(24):
    angle = math.pi * 2 * i / 24 - math.pi / 2
    cos_a = math.cos(angle)
    sin_a = math.sin(angle)
    is_major = (i % 2 == 0)
    inner_r = 195
    outer_r = 215 if is_major else 207
    width = 6 if is_major else 3
    x1 = CX + cos_a * inner_r
    y1 = CY + sin_a * inner_r
    x2 = CX + cos_a * outer_r
    y2 = CY + sin_a * outer_r
    d_outer.line([(x1, y1), (x2, y2)], fill=(245, 205, 95, 255), width=width)
img.alpha_composite(ring_outer)

# Thin inner highlight just inside the gold (crisp cream line)
ring_hl = Image.new("RGBA", (HIRES, HIRES), (0, 0, 0, 0))
ImageDraw.Draw(ring_hl).ellipse(
    [CX - 170, CY - 170, CX + 170, CY + 170],
    outline=(255, 246, 215, 255),
    width=4,
)
img.alpha_composite(ring_hl)

# Deep purple void filling the interior
void = Image.new("RGBA", (HIRES, HIRES), (0, 0, 0, 0))
dv = ImageDraw.Draw(void)
for r in range(165, 0, -1):
    t = (165 - r) / 165.0
    color = (
        int(14 + 70 * (1 - t)),
        int(7 + 32 * (1 - t)),
        int(50 + 95 * (1 - t)),
        255,
    )
    dv.ellipse([CX - r, CY - r, CX + r, CY + r], fill=color)
img.alpha_composite(void)

# Mid ring — thin cyan accent halfway between core and outer
mid = Image.new("RGBA", (HIRES, HIRES), (0, 0, 0, 0))
ImageDraw.Draw(mid).ellipse(
    [CX - 100, CY - 100, CX + 100, CY + 100],
    outline=(125, 220, 255, 220),
    width=4,
)
img.alpha_composite(mid)

# Eight short arc segments on the mid ring (broken-ring decoration)
arcs = Image.new("RGBA", (HIRES, HIRES), (0, 0, 0, 0))
dr = ImageDraw.Draw(arcs)
for i in range(8):
    start_deg = i * 45 + 6
    end_deg = i * 45 + 39
    dr.arc(
        [CX - 130, CY - 130, CX + 130, CY + 130],
        start=start_deg,
        end=end_deg,
        fill=(255, 240, 200, 220),
        width=4,
    )
img.alpha_composite(arcs)

# Sparkle stars inside the void
spots = Image.new("RGBA", (HIRES, HIRES), (0, 0, 0, 0))
ds = ImageDraw.Draw(spots)
for angle_deg, dist, sz in [
    (12, 132, 6),
    (78, 70, 4),
    (155, 115, 6),
    (218, 80, 4),
    (282, 132, 5),
    (340, 56, 4),
]:
    a = math.radians(angle_deg)
    sx = CX + math.cos(a) * dist
    sy = CY + math.sin(a) * dist
    ds.ellipse([sx - sz, sy - sz, sx + sz, sy + sz], fill=(255, 250, 220, 255))
spots = spots.filter(ImageFilter.GaussianBlur(1.5))
img.alpha_composite(spots)

# Core glow (gold, mid-blur)
core_glow = Image.new("RGBA", (HIRES, HIRES), (0, 0, 0, 0))
ImageDraw.Draw(core_glow).ellipse(
    [CX - 64, CY - 64, CX + 64, CY + 64],
    fill=(255, 220, 130, 230),
)
core_glow = core_glow.filter(ImageFilter.GaussianBlur(10))
img.alpha_composite(core_glow)

# Hard cream centre + brighter pinpoint
ImageDraw.Draw(img).ellipse([CX - 24, CY - 24, CX + 24, CY + 24], fill=(255, 252, 230, 255))
ImageDraw.Draw(img).ellipse([CX - 12, CY - 12, CX + 12, CY + 12], fill=(255, 255, 255, 255))

# Downsample with LANCZOS for clean anti-aliased final
final = img.resize((FINAL, FINAL), Image.LANCZOS)
final.save(OUT / "portal.png")
print(f"wrote portal.png ({FINAL}x{FINAL} downsampled from {HIRES}x{HIRES})")
