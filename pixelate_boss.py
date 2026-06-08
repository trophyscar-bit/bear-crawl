"""Pixelate the black-bear sprites into boss_upper.png + boss_legs.png for an 8-bit feel."""
from pathlib import Path
from PIL import Image

HERE = Path(__file__).parent / "assets"

def pixelate(src_name: str, dst_name: str, downscale_size: int = 56, palette_colors: int = 14) -> None:
    src = Image.open(HERE / src_name).convert("RGBA")
    w, h = src.size
    # smooth downscale to capture the silhouette
    small = src.resize((downscale_size, downscale_size), Image.BILINEAR)
    # quantize the RGB to a small palette (8-bit feel)
    rgb_only = small.convert("RGB").quantize(colors=palette_colors, dither=Image.NONE).convert("RGB")
    # threshold the alpha so edges are crisp instead of feathered
    alpha = small.split()[-1].point(lambda a: 255 if a > 110 else 0)
    rgba = rgb_only.convert("RGBA")
    rgba.putalpha(alpha)
    # nearest-neighbor upscale = visible pixel blocks
    out = rgba.resize((w, h), Image.NEAREST)
    out.save(HERE / dst_name)
    print(f"wrote {dst_name}")

if __name__ == "__main__":
    pixelate("bear_upper.png", "boss_upper.png")
    pixelate("bear_legs.png", "boss_legs.png")
