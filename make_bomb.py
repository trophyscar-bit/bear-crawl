"""Generate the pizza-bomb pickup sprite — cartoon bomb with a lit fuse."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).parent / "assets"
OUT.mkdir(exist_ok=True)
SIZE = 80
CX = CY = SIZE // 2

img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

# danger glow
glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse([CX - 30, CY - 22, CX + 30, CY + 32], fill=(230, 80, 60, 140))
glow = glow.filter(ImageFilter.GaussianBlur(7))
img.alpha_composite(glow)

d = ImageDraw.Draw(img)
# main body — round black bomb sitting on the ground
d.ellipse([CX - 22, CY - 16, CX + 22, CY + 26], fill=(28, 26, 28))
# slightly lighter rim
d.ellipse([CX - 22, CY - 16, CX + 22, CY + 26], outline=(60, 58, 62), width=2)
# top highlight crescent
hi = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ImageDraw.Draw(hi).ellipse([CX - 14, CY - 12, CX - 4, CY - 2], fill=(140, 140, 145, 220))
hi = hi.filter(ImageFilter.GaussianBlur(2))
img.alpha_composite(hi)
# bright catch-light pinpoint
d.ellipse([CX - 13, CY - 11, CX - 8, CY - 6], fill=(220, 220, 225))

# fuse — small curved/straight twig sticking up from the top
d.rectangle([CX - 2, CY - 30, CX + 2, CY - 16], fill=(110, 80, 40))
d.rectangle([CX - 3, CY - 17, CX + 3, CY - 14], fill=(70, 50, 25))

# spark ember at the top of the fuse
ember = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ImageDraw.Draw(ember).ellipse([CX - 7, CY - 38, CX + 7, CY - 28], fill=(255, 200, 50, 200))
ember = ember.filter(ImageFilter.GaussianBlur(2))
img.alpha_composite(ember)
d.ellipse([CX - 4, CY - 36, CX + 4, CY - 30], fill=(255, 220, 100))
d.ellipse([CX - 2, CY - 34, CX + 2, CY - 31], fill=(255, 250, 220))

img.save(OUT / "pizza_bomb.png")
print(f"wrote pizza_bomb.png ({img.size})")
