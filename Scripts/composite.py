# /// script
# dependencies = ["numpy", "pillow"]
# ///
"""Puts App Store screenshots on the purple gradient used for the portfolio and social posts.

    uv run Scripts/composite.py <out-dir> <screenshot.png>...

Each screenshot becomes <out-dir>/pergram-<name>.jpg at 2400×1350, where a leading
"01-" style order prefix is dropped from <name>.
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 2400, 1350
PHONE_H = 1161
TOP = 94
RADIUS = 59
SHADOW_OPACITY = 0.32
SHADOW_BLUR = 40
SHADOW_DY = 20
GRAIN = 1.6
# Per-channel cubic in (u, v), matching the portfolio's existing project images.
GRADIENT = [
    [175.4, 37.7, 20.1, -88.2, -234.0, -109.0, 40.5, 91.8, 141.5, 22.9],
    [168.8, 28.7, 14.7, -75.5, -170.0, -79.0, 33.0, 68.6, 100.2, 13.9],
    [220.0, 36.2, 22.5, -89.2, -187.8, -93.2, 38.3, 77.6, 109.4, 19.2],
]


def background():
    v, u = np.mgrid[0:H, 0:W] / [[[H - 1]], [[W - 1]]]
    basis = np.stack([np.ones_like(u), u, v, u * v, u**2, v**2, u**2 * v, u * v**2, u**3, v**3], -1)
    rgb = basis @ np.array(GRADIENT).T
    return rgb + np.random.default_rng(0).normal(0, GRAIN, (H, W, 1))


def composite(src, dst):
    shot = Image.open(src).convert("RGB")
    width = round(shot.width * PHONE_H / shot.height)
    shot = shot.resize((width, PHONE_H), Image.LANCZOS)
    left = (W - width) // 2

    mask = Image.new("L", (width, PHONE_H), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width - 1, PHONE_H - 1), RADIUS, fill=255)

    shadow = Image.new("L", (W, H), 0)
    shadow.paste(mask, (left, TOP + SHADOW_DY))
    shadow = np.asarray(shadow.filter(ImageFilter.GaussianBlur(SHADOW_BLUR)), float) / 255

    rgb = background() * (1 - SHADOW_OPACITY * shadow)[..., None]
    canvas = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8))
    canvas.paste(shot, (left, TOP), mask)
    canvas.save(dst, quality=92)


if __name__ == "__main__":
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for src in map(Path, sys.argv[2:]):
        name = src.stem.split("-", 1)[-1] if src.stem[:2].isdigit() else src.stem
        composite(src, out / f"pergram-{name}.jpg")
