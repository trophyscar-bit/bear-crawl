"""
Re-process 3.JPG into a cleaner cleave_maw.png. Original pass used rembg
straight, which left the face looking washed out and ghosty. This version:

  1. Reads the original 3.JPG (kept on disk after the first pass).
  2. Applies EXIF rotation.
  3. Runs rembg for background removal.
  4. Boosts saturation +35%, contrast +25%, then a light unsharp mask.
  5. Crops tight to the alpha bbox + a small pad.
  6. Resizes to max dim 640 px.
"""

import os
import io
from PIL import Image, ImageOps, ImageEnhance, ImageFilter

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ASSETS = os.path.join(PROJECT_ROOT, "assets")
SRC = os.path.join(ASSETS, "3.JPG")
OUT = os.path.join(ASSETS, "cleave_maw.png")

TARGET_MAX = 640


def main():
    if not os.path.isfile(SRC):
        raise SystemExit(f"Missing source: {SRC}")
    from rembg import remove
    im = Image.open(SRC)
    im = ImageOps.exif_transpose(im).convert("RGB")
    print(f"  loaded {im.size}, running rembg…")
    no_bg = remove(im)
    if not isinstance(no_bg, Image.Image):
        no_bg = Image.open(io.BytesIO(no_bg))
    no_bg = no_bg.convert("RGBA")
    # Saturation boost
    r, g, b, a = no_bg.split()
    rgb = Image.merge("RGB", (r, g, b))
    rgb = ImageEnhance.Color(rgb).enhance(1.35)       # saturation +35%
    rgb = ImageEnhance.Contrast(rgb).enhance(1.25)    # contrast +25%
    rgb = ImageEnhance.Brightness(rgb).enhance(0.95)  # darken a hair, was too pale
    rgb = rgb.filter(ImageFilter.UnsharpMask(radius=2.0, percent=80, threshold=4))
    r2, g2, b2 = rgb.split()
    # Alpha cleanup — new strategy: anything above a low cutoff (50) is
    # treated as fully opaque. Avoids both the ghosty halo (everything below
    # 50 is killed) AND the holes in the middle (everything else gets locked
    # to 255 so the muzzle never goes see-through). Then morphological close
    # to fill any remaining 1-2 px gaps inside the subject.
    import numpy as np
    from scipy import ndimage
    a_np = np.array(a, dtype=np.uint8)
    binary = (a_np > 50).astype(np.uint8) * 255
    # Morphological close — dilate then erode with a 3x3 kernel to fill
    # small holes inside the silhouette.
    struct = np.ones((5, 5), dtype=bool)
    filled = ndimage.binary_closing(binary > 0, structure=struct, iterations=2)
    a_clean = (filled.astype(np.uint8)) * 255
    from PIL import Image as _Image
    a = _Image.fromarray(a_clean, mode="L")
    out = Image.merge("RGBA", (r2, g2, b2, a))
    # Tight crop
    bbox = out.getchannel("A").getbbox()
    if bbox:
        pad = 6
        x0, y0, x1, y1 = bbox
        x0 = max(0, x0 - pad); y0 = max(0, y0 - pad)
        x1 = min(out.width, x1 + pad); y1 = min(out.height, y1 + pad)
        out = out.crop((x0, y0, x1, y1))
    # Resize to target max dim
    w, h = out.size
    scale = TARGET_MAX / float(max(w, h))
    out = out.resize((max(1, int(round(w * scale))), max(1, int(round(h * scale)))), Image.LANCZOS)
    out.save(OUT, optimize=True)
    print(f"  wrote {OUT}  ({out.size})")


if __name__ == "__main__":
    main()
