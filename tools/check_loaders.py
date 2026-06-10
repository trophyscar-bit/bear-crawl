#!/usr/bin/env python3
"""
Export-safety audit for asset loaders.

Exported Godot builds pack PNGs as .ctex and DROP the raw .png — so any loader
that reads a res:// asset via FileAccess (raw bytes) or scans a directory and
filters on ".png" returns NOTHING in the shipped game, even though it works fine
in the editor. That's invisible until a player runs the build.

This flags every loader function that decodes a PNG (load_png_from_buffer) or scans
a directory (DirAccess) WITHOUT a load()/ResourceLoader fallback. Run it before any
release:  python tools/check_loaders.py   (exit code 1 if anything is unsafe)

The export-safe pattern:
  - single file:  ResourceLoader.exists(path) -> load(path), then FileAccess fallback
  - directory:    DirAccess.get_files(); strip ".import"/".remap"; dedupe; load(clean)
"""
import re, glob, os, sys

def funcs(src):
    out, cur, body = [], None, []
    for line in src.splitlines():
        m = re.match(r'^func\s+(\w+)', line)
        if m:
            if cur:
                out.append((cur, '\n'.join(body)))
            cur, body = m.group(1), [line]
        elif cur is not None:
            body.append(line)
    if cur:
        out.append((cur, '\n'.join(body)))
    return out

def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    bad = []
    for f in sorted(glob.glob(os.path.join(root, 'scripts', '*.gd'))):
        src = open(f, encoding='utf-8').read()
        for name, body in funcs(src):
            touches_assets = ('load_png_from_buffer' in body) or ('DirAccess' in body)
            if not touches_assets:
                continue
            if 'user://' in body and 'res://' not in body:
                continue  # save-file IO, not asset loading
            robust = (
                'ResourceLoader' in body
                or re.search(r'=\s*load\(', body)
                # handles the export-only ".import"/".remap" directory listing:
                or '.import' in body or '.remap' in body
                # or delegates the actual load to a known export-safe helper:
                or re.search(r'_load_tex_mip|_load_tex_opt|_ui_tex|_stuffing_load|'
                             r'_dir_pngs|_load_png|_load_tex|_load_tex_robust|'
                             r'_runtime_png|_robust_png|_decal_tex|_load_sheet', body)
            )
            if not robust:
                bad.append(f"{os.path.basename(f)}::{name}()")
    if bad:
        print("UNSAFE asset loaders (will break in exported builds):")
        for b in bad:
            print("  ", b)
        sys.exit(1)
    print("OK - all asset loaders are export-safe.")

if __name__ == '__main__':
    main()
