"""
Pack Kenney's 25 White Puff PNGs into a single uniform sprite sheet.
Output: assets/white_puff_sheet.png (5x5 grid of 128x128 frames = 640x640)

Source frames are variable-size (~350-420 px). We resize each to fit a
128x128 cell while preserving aspect ratio, centered.

Also copies the license to assets/kenney_smoke/ for attribution.
"""

import os
from PIL import Image

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ASSETS = os.path.join(PROJECT_ROOT, "assets")
OUT_SHEET = os.path.join(ASSETS, "white_puff_sheet.png")
SRC_DIR = os.path.join(PROJECT_ROOT, "tools", "_puff_src")
LICENSE_SRC = "/tmp/smoke/license.txt"
LICENSE_DEST_DIR = os.path.join(ASSETS, "kenney_smoke")

FRAME = 128
COLS = 5
ROWS = 5
N_FRAMES = 25


def main():
    os.makedirs(LICENSE_DEST_DIR, exist_ok=True)
    if os.path.exists(LICENSE_SRC):
        with open(LICENSE_SRC, "r") as f:
            data = f.read()
        with open(os.path.join(LICENSE_DEST_DIR, "license.txt"), "w") as f:
            f.write(data)

    sheet = Image.new("RGBA", (FRAME * COLS, FRAME * ROWS), (0, 0, 0, 0))
    for i in range(N_FRAMES):
        p = os.path.join(SRC_DIR, f"whitePuff{i:02d}.png")
        if not os.path.isfile(p):
            print(f"  missing {p}")
            continue
        im = Image.open(p).convert("RGBA")
        # Resize to fit FRAME, preserving aspect ratio
        im.thumbnail((FRAME, FRAME), Image.LANCZOS)
        # Center in FRAMExFRAME cell
        cell = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        cx = (FRAME - im.width) // 2
        cy = (FRAME - im.height) // 2
        cell.paste(im, (cx, cy), im)
        col = i % COLS
        row = i // COLS
        sheet.paste(cell, (col * FRAME, row * FRAME))
    sheet.save(OUT_SHEET, optimize=True)
    print(f"Wrote {OUT_SHEET}  ({sheet.size})  {N_FRAMES} frames, {COLS}x{ROWS} grid, {FRAME}px each")


if __name__ == "__main__":
    main()
