"""Generate scatter + homing pickup sprites by compositing the existing pizza.png."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).parent
OUT = ROOT / "assets"
pizza = Image.open(OUT / "pizza.png").convert("RGBA")  # 64x64


def paste_rot(canvas, src, angle_deg, dx, dy, scale=1.0):
    s = src.copy()
    if scale != 1.0:
        s = s.resize((int(s.width * scale), int(s.height * scale)), Image.LANCZOS)
    s = s.rotate(angle_deg, resample=Image.BICUBIC, expand=True)
    cx, cy = canvas.width // 2, canvas.height // 2
    canvas.alpha_composite(s, (cx + dx - s.width // 2, cy + dy - s.height // 2))


# --- Scatter pickup: 3 pizza slices fanning out from a central slice ---
W, H = 96, 80
scatter = Image.new("RGBA", (W, H), (0, 0, 0, 0))
# faint blue aura
aura = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ImageDraw.Draw(aura).ellipse([4, 8, W - 5, H - 5], fill=(80, 180, 230, 80))
from PIL import ImageFilter
aura = aura.filter(ImageFilter.GaussianBlur(6))
scatter.alpha_composite(aura)
# back slices flanking
paste_rot(scatter, pizza, -32, -22, -2, 0.55)
paste_rot(scatter, pizza,  32,  22, -2, 0.55)
# central larger slice
paste_rot(scatter, pizza, 0, 0, 6, 0.85)
scatter.save(OUT / "scatter_pickup.png")
print(f"wrote scatter_pickup.png ({scatter.size})")


# --- Homing pickup: pizza inside a purple targeting reticle ---
W, H = 96, 96
homing = Image.new("RGBA", (W, H), (0, 0, 0, 0))
# faint purple aura
aura = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ImageDraw.Draw(aura).ellipse([4, 4, W - 5, H - 5], fill=(200, 90, 230, 110))
aura = aura.filter(ImageFilter.GaussianBlur(8))
homing.alpha_composite(aura)
# centred pizza, slightly small to leave room for the reticle
paste_rot(homing, pizza, 0, 0, 0, 0.72)
# reticle on top
d = ImageDraw.Draw(homing)
cx, cy = W // 2, H // 2
d.ellipse([cx - 38, cy - 38, cx + 38, cy + 38], outline=(210, 90, 240, 255), width=3)
d.ellipse([cx - 26, cy - 26, cx + 26, cy + 26], outline=(180, 80, 220, 200), width=2)
for ax, ay, bx, by in [(-42, 0, -28, 0), (28, 0, 42, 0), (0, -42, 0, -28), (0, 28, 0, 42)]:
    d.line([(cx + ax, cy + ay), (cx + bx, cy + by)], fill=(210, 90, 240, 255), width=3)
d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=(255, 220, 255, 255))
homing.save(OUT / "homing_pickup.png")
print(f"wrote homing_pickup.png ({homing.size})")
