"""Slice a transparent bear PNG into upper-body and legs layers for 2D cutout rigging."""
from pathlib import Path
from PIL import Image
import numpy as np

import sys
HERE = Path(__file__).parent
NAME = sys.argv[1] if len(sys.argv) > 1 else "bear"
IN_PATH = HERE / "assets" / f"{NAME}_front.png"
OUT_DIR = HERE / "assets"

# Cut roughly at the waistline. Find the row in the middle 40% with the
# narrowest band of non-transparent pixels — that's our waist.
img = Image.open(IN_PATH).convert("RGBA")
alpha = np.array(img.split()[-1])
h, w = alpha.shape
top, bot = int(h * 0.45), int(h * 0.75)
band_widths = []
for y in range(top, bot):
    cols = np.where(alpha[y] > 20)[0]
    band_widths.append(cols.size if cols.size else 1e9)
cut_y = top + int(np.argmin(band_widths))
overlap = 12  # px overlap so the seam is hidden

# Upper layer: top of image down to cut_y + overlap, rest transparent (kept on same canvas size).
upper = Image.new("RGBA", img.size, (0, 0, 0, 0))
upper.paste(img.crop((0, 0, w, cut_y + overlap)), (0, 0))

# Lower layer: cut_y - overlap to bottom, kept on same canvas size so positions match.
lower = Image.new("RGBA", img.size, (0, 0, 0, 0))
lower_slice = img.crop((0, cut_y - overlap, w, h))
lower.paste(lower_slice, (0, cut_y - overlap))

upper.save(OUT_DIR / f"{NAME}_upper.png")
lower.save(OUT_DIR / f"{NAME}_legs.png")
print(f"cut at y={cut_y} of {h}; wrote {NAME}_upper.png and {NAME}_legs.png")
