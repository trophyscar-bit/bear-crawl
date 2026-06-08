"""Background-remove the bear photos, auto-rotate, crop to content, resize square."""
from pathlib import Path
from PIL import Image, ImageOps
from rembg import remove, new_session

SRC = [
    Path(r"C:\Users\matt\OneDrive - Elucid Systems\Pictures\PhotoSync\nothing_\Recents\2023\IMG_3178.JPG"),
    Path(r"C:\Users\matt\OneDrive - Elucid Systems\Pictures\PhotoSync\nothing_\Recents\2023\IMG_3179.JPG"),
]
OUT = Path(__file__).parent / "assets"
OUT.mkdir(exist_ok=True)
NAMES = ["brown_front.png", "brown_side.png"]
SIZE = 256

session = new_session("u2net")

for src, name in zip(SRC, NAMES):
    print(f"Processing {src.name}...")
    img = Image.open(src)
    # respect EXIF orientation (phone photos rotated landscape often need this)
    img = ImageOps.exif_transpose(img)
    cut = remove(img, session=session)
    # crop to non-transparent bbox
    bbox = cut.getbbox()
    if bbox:
        cut = cut.crop(bbox)
    # fit on transparent square canvas
    cut.thumbnail((SIZE, SIZE), Image.LANCZOS)
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    canvas.paste(cut, ((SIZE - cut.width) // 2, (SIZE - cut.height) // 2), cut)
    out_path = OUT / name
    canvas.save(out_path)
    print(f"  -> {out_path}")

print("Done.")
