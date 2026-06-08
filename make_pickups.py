"""Generate cute fluff-ball pickup PNGs.

Renders at 2x then LANCZOS-downsamples for crisp hi-res look:
  - health_orb.png — small green fuzzy pom with eyes + smile (+1 HP)
  - full_heal.png  — larger cream/gold fluff with a red heart on top (full heal)
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import math, random

OUT = Path(__file__).parent / "assets"
OUT.mkdir(exist_ok=True)


def _draw_heart(d: ImageDraw.ImageDraw, cx: float, cy: float, size: float, color: tuple) -> None:
    r = size / 2.0
    # two top lobes
    d.ellipse([cx - r * 2, cy - r, cx, cy + r], fill=color)
    d.ellipse([cx, cy - r, cx + r * 2, cy + r], fill=color)
    # bottom triangle
    d.polygon(
        [(cx - r * 2 + 1, cy + r * 0.2), (cx + r * 2 - 1, cy + r * 0.2), (cx, cy + r * 2.2)],
        fill=color,
    )


def fluff(final_size: int,
          body_color: tuple,
          dark_color: tuple,
          light_color: tuple,
          eye_size_ratio: float = 0.11,
          with_heart: bool = False) -> Image.Image:
    HIRES = final_size * 2
    cx = HIRES // 2
    cy = HIRES // 2
    radius = int(HIRES * 0.36)

    img = Image.new("RGBA", (HIRES, HIRES), (0, 0, 0, 0))

    # soft outer glow
    glow = Image.new("RGBA", (HIRES, HIRES), (0, 0, 0, 0))
    glow_col = (*body_color[:3], 130)
    ImageDraw.Draw(glow).ellipse(
        [cx - radius - 14, cy - radius - 14, cx + radius + 14, cy + radius + 14],
        fill=glow_col,
    )
    glow = glow.filter(ImageFilter.GaussianBlur(14))
    img.alpha_composite(glow)

    # base body disc
    ImageDraw.Draw(img).ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=body_color)

    # fur fiber texture — many small bumps inside / on the edge
    random.seed(7)
    fibers = Image.new("RGBA", (HIRES, HIRES), (0, 0, 0, 0))
    df = ImageDraw.Draw(fibers)
    # inner fibers (slightly varied body color)
    for _ in range(220):
        a = random.uniform(0, math.pi * 2)
        r = random.uniform(0, radius - 4)
        bx = cx + math.cos(a) * r
        by = cy + math.sin(a) * r
        bsize = random.uniform(4, 9)
        roll = random.random()
        if roll < 0.45:
            col = light_color
        elif roll < 0.85:
            col = body_color
        else:
            col = dark_color
        df.ellipse([bx - bsize, by - bsize, bx + bsize, by + bsize], fill=col)
    # edge fluffies (just outside the radius)
    for _ in range(160):
        a = random.uniform(0, math.pi * 2)
        r = radius + random.uniform(-8, 18)
        bx = cx + math.cos(a) * r
        by = cy + math.sin(a) * r
        bsize = random.uniform(5, 10)
        roll = random.random()
        col = light_color if roll < 0.5 else body_color
        df.ellipse([bx - bsize, by - bsize, bx + bsize, by + bsize], fill=col)
    fibers = fibers.filter(ImageFilter.GaussianBlur(1.4))
    img.alpha_composite(fibers)

    # soft bottom shadow inside the body
    shadow = Image.new("RGBA", (HIRES, HIRES), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse(
        [cx - radius * 0.75, cy + radius * 0.25, cx + radius * 0.75, cy + radius * 0.95],
        fill=(*dark_color[:3], 110),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    img.alpha_composite(shadow)

    # top highlight (lighter crescent)
    hi = Image.new("RGBA", (HIRES, HIRES), (0, 0, 0, 0))
    ImageDraw.Draw(hi).ellipse(
        [cx - radius * 0.6, cy - radius * 0.95, cx + radius * 0.4, cy - radius * 0.15],
        fill=(*light_color[:3], 160),
    )
    hi = hi.filter(ImageFilter.GaussianBlur(10))
    img.alpha_composite(hi)

    # face — eyes, blush, smile
    eye_size = max(8, int(HIRES * eye_size_ratio))
    eye_r = eye_size // 2
    eye_y = cy - int(radius * 0.10)
    eye_dx = int(radius * 0.38)

    d = ImageDraw.Draw(img)
    # eye whites (slight)? skip — solid dark eyes read clearer at small size
    # left eye
    d.ellipse([cx - eye_dx - eye_r, eye_y - eye_r, cx - eye_dx + eye_r, eye_y + eye_r], fill=(20, 22, 30))
    # right eye
    d.ellipse([cx + eye_dx - eye_r, eye_y - eye_r, cx + eye_dx + eye_r, eye_y + eye_r], fill=(20, 22, 30))
    # white reflection on each eye (upper-right)
    hl_r = max(2, eye_r // 3)
    d.ellipse(
        [cx - eye_dx + eye_r - hl_r * 2 - 1, eye_y - eye_r + 2, cx - eye_dx + eye_r - 1, eye_y - eye_r + 2 + hl_r * 2],
        fill=(255, 255, 255),
    )
    d.ellipse(
        [cx + eye_dx + eye_r - hl_r * 2 - 1, eye_y - eye_r + 2, cx + eye_dx + eye_r - 1, eye_y - eye_r + 2 + hl_r * 2],
        fill=(255, 255, 255),
    )

    # pink cheek blush under each eye
    cheek = Image.new("RGBA", (HIRES, HIRES), (0, 0, 0, 0))
    blush_r = int(radius * 0.13)
    cheek_y = eye_y + int(radius * 0.28)
    ImageDraw.Draw(cheek).ellipse(
        [cx - eye_dx - blush_r, cheek_y - blush_r // 2, cx - eye_dx + blush_r, cheek_y + blush_r // 2],
        fill=(255, 150, 165, 150),
    )
    ImageDraw.Draw(cheek).ellipse(
        [cx + eye_dx - blush_r, cheek_y - blush_r // 2, cx + eye_dx + blush_r, cheek_y + blush_r // 2],
        fill=(255, 150, 165, 150),
    )
    cheek = cheek.filter(ImageFilter.GaussianBlur(3))
    img.alpha_composite(cheek)

    # tiny smile
    smile_w = int(radius * 0.32)
    smile_y = eye_y + int(radius * 0.38)
    d.arc(
        [cx - smile_w, smile_y - smile_w // 2, cx + smile_w, smile_y + smile_w // 2],
        start=15, end=165,
        fill=(20, 22, 30),
        width=max(3, HIRES // 70),
    )

    # optional red heart sitting on top
    if with_heart:
        heart_cy = cy - radius - int(HIRES * 0.04)
        heart_sz = int(HIRES * 0.08)
        # subtle white outline by drawing slightly bigger black-shadow first
        _draw_heart(d, cx, heart_cy + 2, heart_sz + 1, (255, 255, 255, 220))
        _draw_heart(d, cx, heart_cy, heart_sz, (225, 65, 78))
        # bright reflection on the heart
        d.ellipse(
            [cx - heart_sz * 0.6, heart_cy - heart_sz * 0.4, cx - heart_sz * 0.1, heart_cy],
            fill=(255, 200, 210, 210),
        )

    # downsample with LANCZOS for clean anti-aliasing
    return img.resize((final_size, final_size), Image.LANCZOS)


# +1 HP — small green fuzzy
green_body = (95, 220, 110)
green_dark = (35, 130, 55)
green_light = (200, 250, 205)
fluff_small = fluff(96, green_body, green_dark, green_light, eye_size_ratio=0.11)
fluff_small.save(OUT / "health_orb.png")
print("wrote health_orb.png")

# Full heal — larger cream/gold fluff with red heart on top
gold_body = (255, 220, 130)
gold_dark = (180, 125, 55)
gold_light = (255, 250, 215)
fluff_big = fluff(144, gold_body, gold_dark, gold_light, eye_size_ratio=0.11, with_heart=True)
fluff_big.save(OUT / "full_heal.png")
print("wrote full_heal.png")
