"""
Process 6.jpg → assets/gun_bear.png — EXIF rotate, rembg, low-cutoff alpha
threshold + morphological close to fill holes, tight crop, resize.

Uses the same hole-filling alpha strategy as fix_cleave_maw.py — works
reliably on plush textures.
"""

import os
import io
import numpy as np
from PIL import Image, ImageOps, ImageEnhance, ImageFilter
from scipy import ndimage

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ASSETS = os.path.join(PROJECT_ROOT, "assets")
SRC = os.path.join(ASSETS, "6.jpg")
OUT = os.path.join(ASSETS, "gun_bear.png")

TARGET_MAX = 256


def main():
    from rembg import remove
    im = Image.open(SRC)
    im = ImageOps.exif_transpose(im).convert("RGB")
    print(f"  loaded {im.size}")
    no_bg = remove(im)
    if not isinstance(no_bg, Image.Image):
        no_bg = Image.open(io.BytesIO(no_bg))
    no_bg = no_bg.convert("RGBA")

    # Lighting fix — the photo came out a bit dark on the dark brown fur.
    # Brighten + auto-contrast clip (drops the very darkest / very lightest
    # pixels to expand the visible dynamic range), then punch saturation.
    r, g, b, a = no_bg.split()
    rgb = Image.merge("RGB", (r, g, b))
    rgb = ImageEnhance.Brightness(rgb).enhance(1.18)        # +18% brightness
    rgb = ImageOps.autocontrast(rgb, cutoff=2)               # tighter dynamic range
    rgb = ImageEnhance.Color(rgb).enhance(1.35)              # +35% saturation (was 30)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.12)           # contrast a hair lighter (was 1.18 — autocontrast already did most of it)
    rgb = rgb.filter(ImageFilter.UnsharpMask(radius=2.0, percent=70, threshold=4))
    r2, g2, b2 = rgb.split()

    # Hole-fill alpha — stronger pass: low cutoff, then BOTH morphological
    # close AND binary_fill_holes. The ears specifically had rembg holes
    # poking through the bear's belly fur — fill_holes patches anything
    # fully surrounded by opaque pixels.
    a_np = np.array(a, dtype=np.uint8)
    binary = (a_np > 50)
    # First close any 1-2 px gaps in the silhouette edge
    closed = ndimage.binary_closing(binary, structure=np.ones((7, 7), dtype=bool), iterations=2)
    # Then fill ANY interior hole (the ears + body holes)
    filled = ndimage.binary_fill_holes(closed)
    a_clean = (filled.astype(np.uint8)) * 255
    a = Image.fromarray(a_clean, mode="L")
    out = Image.merge("RGBA", (r2, g2, b2, a))

    # Tight crop
    bbox = out.getchannel("A").getbbox()
    if bbox:
        pad = 6
        x0, y0, x1, y1 = bbox
        x0 = max(0, x0 - pad); y0 = max(0, y0 - pad)
        x1 = min(out.width, x1 + pad); y1 = min(out.height, y1 + pad)
        out = out.crop((x0, y0, x1, y1))

    # Resize so longest side = TARGET_MAX
    w, h = out.size
    scale = TARGET_MAX / float(max(w, h))
    out = out.resize(
        (max(1, int(round(w * scale))), max(1, int(round(h * scale)))),
        Image.LANCZOS,
    )

    out.save(OUT, optimize=True)
    print(f"  wrote {OUT}  ({out.size})")


if __name__ == "__main__":
    main()
