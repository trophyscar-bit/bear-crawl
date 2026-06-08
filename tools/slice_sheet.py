#!/usr/bin/env python3
"""
slice_sheet.py — cut a sprite sheet into individual PNGs.

Two modes:
  --grid W H     Fixed-cell tilesheets (e.g. 48x48 RPG-Maker sheets). Cuts an even
                 grid, trims each cell to its alpha bounding box, skips empty cells.
  --auto         Irregular sheets (scattered icons/props of mixed sizes). Uses
                 connected-component labeling on the alpha channel to find each
                 sprite's bounding box automatically.

Always writes a labeled contact sheet (<out>/_contact.png) so you can eyeball the
indices and rename/categorize afterward.

Examples:
  python slice_sheet.py GUISprite.png --out out/gui --auto --min-size 8
  python slice_sheet.py Level-0-3.png --out out/l03 --grid 48 48 --prefix L03
  python slice_sheet.py weapons.png   --out out/weapons --grid 32 32 --trim

Requires: pillow, numpy, scipy (scipy only for --auto).
"""
import argparse, os, sys
from PIL import Image, ImageDraw

def _alpha_mask(im, thresh):
    import numpy as np
    return np.array(im)[:, :, 3] > thresh

def _trim(im):
    bb = im.getbbox()
    return im.crop(bb) if bb else im

def grid_cut(im, cw, ch, trim):
    W, H = im.size
    out = []
    for gy in range(H // ch):
        for gx in range(W // cw):
            cell = im.crop((gx * cw, gy * ch, gx * cw + cw, gy * ch + ch))
            if cell.getbbox() is None:
                continue  # empty cell
            out.append((f"{gx}_{gy}", _trim(cell) if trim else cell))
    return out

def auto_cut(im, thresh, min_size):
    import numpy as np
    from scipy import ndimage
    mask = _alpha_mask(im, thresh)
    lbl, n = ndimage.label(mask)
    out = []
    for i, sl in enumerate(ndimage.find_objects(lbl)):
        if sl is None:
            continue
        y0, y1 = sl[0].start, sl[0].stop
        x0, x1 = sl[1].start, sl[1].stop
        if (x1 - x0) < min_size or (y1 - y0) < min_size:
            continue
        out.append((str(len(out)), im.crop((x0, y0, x1, y1))))
    return out

def contact_sheet(sprites, path, zoom=3, cols=8):
    if not sprites:
        return
    cw = max(s.size[0] for _, s in sprites)
    ch = max(s.size[1] for _, s in sprites)
    rows = (len(sprites) + cols - 1) // cols
    pad = 18
    cell_w = cw * zoom + pad
    cell_h = ch * zoom + pad
    img = Image.new("RGBA", (cols * cell_w + 10, rows * cell_h + 10), (35, 35, 45, 255))
    d = ImageDraw.Draw(img)
    for i, (name, s) in enumerate(sprites):
        c, r = i % cols, i // cols
        x, y = 8 + c * cell_w, 8 + r * cell_h
        s2 = s.resize((s.size[0] * zoom, s.size[1] * zoom), Image.NEAREST)
        img.alpha_composite(s2, (x + (cw * zoom - s2.size[0]) // 2, y + 12))
        d.text((x, y), f"{i}:{name} {s.size[0]}x{s.size[1]}", fill=(0, 255, 255))
    img.convert("RGB").save(path)

def main():
    ap = argparse.ArgumentParser(description="Slice a sprite sheet into PNGs.")
    ap.add_argument("sheet")
    ap.add_argument("--out", required=True)
    ap.add_argument("--grid", nargs=2, type=int, metavar=("W", "H"))
    ap.add_argument("--auto", action="store_true")
    ap.add_argument("--prefix", default="s")
    ap.add_argument("--min-size", type=int, default=6)
    ap.add_argument("--alpha-thresh", type=int, default=20)
    ap.add_argument("--trim", action="store_true", help="grid mode: trim cells to alpha bbox")
    args = ap.parse_args()

    im = Image.open(args.sheet).convert("RGBA")
    os.makedirs(args.out, exist_ok=True)
    if args.grid:
        sprites = grid_cut(im, args.grid[0], args.grid[1], args.trim)
    elif args.auto:
        sprites = auto_cut(im, args.alpha_thresh, args.min_size)
    else:
        print("Pick a mode: --grid W H  or  --auto", file=sys.stderr)
        sys.exit(2)

    for name, s in sprites:
        s.save(os.path.join(args.out, f"{args.prefix}_{name}.png"))
    contact_sheet(sprites, os.path.join(args.out, "_contact.png"))
    print(f"wrote {len(sprites)} sprites to {args.out}  (+ _contact.png)")

if __name__ == "__main__":
    main()
