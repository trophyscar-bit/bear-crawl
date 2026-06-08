"""
Crop, EXIF-rotate, background-remove, and resize the dropped bear photos
(1-4.JPG) into clean transparent PNGs ready to drop into the game.

Sources expected:  assets/1.JPG ... assets/4.JPG
Outputs written:   assets/plush_brawler_front.png
                   assets/plush_brawler_back.png
                   assets/cleave_maw.png
                   assets/shrinkwrap_bear.png
                   plus 256x256-tall in-game-sized variants alongside
"""

import os
from PIL import Image, ImageOps
from rembg import remove

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ASSETS_DIR   = os.path.join(PROJECT_ROOT, "assets")

# (source_filename, output_basename, target_max_dimension)
SOURCES = [
    ("1.JPG", "plush_brawler_front", 256),
    ("2.JPG", "plush_brawler_back",  256),
    ("3.JPG", "cleave_maw",          640),  # large — fills part of the screen
    ("4.JPG", "shrinkwrap_bear",     256),
]


def tight_crop(im: Image.Image) -> Image.Image:
    """Crop to the bounding box of non-transparent pixels. Adds a 4 px pad."""
    if im.mode != "RGBA":
        im = im.convert("RGBA")
    bbox = im.getchannel("A").getbbox()
    if bbox is None:
        return im
    pad = 4
    x0, y0, x1, y1 = bbox
    x0 = max(0, x0 - pad)
    y0 = max(0, y0 - pad)
    x1 = min(im.width,  x1 + pad)
    y1 = min(im.height, y1 + pad)
    return im.crop((x0, y0, x1, y1))


def resize_max(im: Image.Image, max_dim: int) -> Image.Image:
    """Scale so the longer side equals max_dim, preserving aspect."""
    w, h = im.size
    scale = max_dim / float(max(w, h))
    new_w = max(1, int(round(w * scale)))
    new_h = max(1, int(round(h * scale)))
    return im.resize((new_w, new_h), Image.LANCZOS)


def process_one(src_name: str, out_basename: str, target_max: int) -> None:
    src_path = os.path.join(ASSETS_DIR, src_name)
    print(f"\n[process] {src_name} -> {out_basename}.png")
    im = Image.open(src_path)
    # Apply EXIF rotation so the image stands upright before processing.
    im = ImageOps.exif_transpose(im)
    # rembg expects RGB
    im_rgb = im.convert("RGB")
    print(f"  - rembg on {im_rgb.size}...")
    # rembg returns an RGBA Image (or bytes — depends on version). It
    # accepts a PIL Image and returns a PIL Image in modern releases.
    no_bg = remove(im_rgb)
    if not isinstance(no_bg, Image.Image):
        # older API: returns bytes
        import io
        no_bg = Image.open(io.BytesIO(no_bg))
    no_bg = no_bg.convert("RGBA")
    cropped = tight_crop(no_bg)
    print(f"  - cropped to {cropped.size}")
    resized = resize_max(cropped, target_max)
    print(f"  - resized to {resized.size}")
    out_path = os.path.join(ASSETS_DIR, f"{out_basename}.png")
    resized.save(out_path, optimize=True)
    print(f"  - wrote {out_path}")


if __name__ == "__main__":
    for src, name, dim in SOURCES:
        process_one(src, name, dim)
    print("\n[process] done.")
