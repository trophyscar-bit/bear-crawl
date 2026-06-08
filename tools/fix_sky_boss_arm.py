"""
Post-process the sky_boss.png to remove the dangling arm on the left side.
Strategy: find the densest opaque column area (head/body), then only keep
pixels to the right of that column. The thin arm on the left gets cropped
out since it's much less wide than the body.
"""

import os
import numpy as np
from PIL import Image

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ASSETS = os.path.join(PROJECT_ROOT, "assets")
PATH = os.path.join(ASSETS, "sky_boss.png")


def main():
    im = Image.open(PATH).convert("RGBA")
    a = np.array(im.split()[3], dtype=np.uint8)
    # For each column count opaque pixels
    col_density = (a > 128).sum(axis=0)
    # Find the leftmost column where density jumps past 60% of max — this is
    # where the main body begins.
    # Stricter threshold (78% of max) so the arm columns aren't counted as
    # body. The bear's head is the densest area; arms have far fewer opaque
    # pixels per column.
    threshold = col_density.max() * 0.78
    body_start = 0
    for x in range(col_density.shape[0]):
        if col_density[x] >= threshold:
            body_start = x
            break
    # Cut even further into the body to lose the arm-fur fringe entirely
    body_start = max(0, body_start - 4)
    print(f"  body starts at x={body_start}  (image width={a.shape[1]})")
    # Crop to body_start..end
    cropped = im.crop((body_start, 0, im.width, im.height))
    # Re-tight crop to alpha bbox to drop the right side empty pad if any
    bbox = cropped.getchannel("A").getbbox()
    if bbox:
        cropped = cropped.crop(bbox)
    cropped.save(PATH, optimize=True)
    print(f"  wrote {PATH}  ({cropped.size})")


if __name__ == "__main__":
    main()
