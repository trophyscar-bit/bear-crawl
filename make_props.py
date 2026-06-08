"""Generate pizza slice + cylinder obstacle PNGs."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).parent / "assets"
OUT.mkdir(exist_ok=True)

# --- pizza slice: triangle pointing in +X (right) so rotation = velocity.angle() works ---
pz = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
d = ImageDraw.Draw(pz)
# triangle slice: tip right, crust at left
tip = (60, 32)
base_a = (8, 8)
base_b = (8, 56)
d.polygon([tip, base_a, base_b], fill=(255, 215, 130))            # cheese
# crust (thick bar at left)
d.polygon([base_a, base_b, (16, 50), (16, 14)], fill=(210, 140, 60))
# crust outline
d.line([base_a, base_b], fill=(140, 80, 30), width=3)
# slice outline
d.line([tip, base_a], fill=(180, 130, 50), width=2)
d.line([tip, base_b], fill=(180, 130, 50), width=2)
# pepperoni dots
for cx, cy in [(28, 30), (38, 22), (38, 42), (46, 32)]:
    d.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=(170, 30, 30))
    d.ellipse([cx - 3, cy - 3, cx + 1, cy + 1], fill=(210, 70, 50))  # highlight
pz.save(OUT / "pizza.png")
print("wrote pizza.png")

# --- cylinder: top-down view of a stone-ish post ---
cy = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
d = ImageDraw.Draw(cy)
# soft shadow
shadow = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
ds = ImageDraw.Draw(shadow)
ds.ellipse([10, 18, 90, 92], fill=(0, 0, 0, 110))
shadow = shadow.filter(ImageFilter.GaussianBlur(3))
cy.alpha_composite(shadow)
# main disc
d.ellipse([4, 4, 88, 84], fill=(130, 130, 140), outline=(60, 60, 75), width=3)
# top highlight crescent
hl = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
dh = ImageDraw.Draw(hl)
dh.ellipse([10, 8, 78, 50], fill=(200, 200, 210, 180))
dh.ellipse([14, 16, 82, 60], fill=(0, 0, 0, 0))
cy.alpha_composite(hl)
cy.save(OUT / "cylinder.png")
print("wrote cylinder.png")
