"""
Process 7.jpg → assets/sky_boss.png — for the Sky Boss (Floor 9).
Same proven hole-fill recipe as gun_bear / cleave_maw.
"""

import os
import io
import numpy as np
from PIL import Image, ImageOps, ImageEnhance, ImageFilter
from scipy import ndimage

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ASSETS = os.path.join(PROJECT_ROOT, "assets")
SRC = os.path.join(ASSETS, "7.jpg")
OUT = os.path.join(ASSETS, "sky_boss.png")

TARGET_MAX = 720    # bigger for boss scale


def main():
    from rembg import remove
    im = Image.open(SRC)
    im = ImageOps.exif_transpose(im).convert("RGB")
    print(f"  loaded {im.size}")
    no_bg = remove(im)
    if not isinstance(no_bg, Image.Image):
        no_bg = Image.open(io.BytesIO(no_bg))
    no_bg = no_bg.convert("RGBA")

    # Punch saturation slightly + contrast for in-game pop
    r, g, b, a = no_bg.split()
    rgb = Image.merge("RGB", (r, g, b))
    rgb = ImageEnhance.Color(rgb).enhance(1.20)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.18)
    rgb = rgb.filter(ImageFilter.UnsharpMask(radius=2.0, percent=70, threshold=4))
    r2, g2, b2 = rgb.split()

    # Hole-fill alpha: low cutoff + morphological close
    a_np = np.array(a, dtype=np.uint8)
    binary = (a_np > 50)
    closed = ndimage.binary_closing(binary, structure=np.ones((5, 5), dtype=bool), iterations=2)
    a_clean = (closed.astype(np.uint8)) * 255
    a = Image.fromarray(a_clean, mode="L")
    out = Image.merge("RGBA", (r2, g2, b2, a))

    # Tight crop
    bbox = out.getchannel("A").getbbox()
    if bbox:
        pad = 8
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
