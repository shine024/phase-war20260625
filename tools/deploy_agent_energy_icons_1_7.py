#!/usr/bin/env python3
"""Key white background from Agent-generated energy PNGs and deploy to card icon paths."""
from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
AGENT_ASSETS = Path(
    r"C:\Users\jianchang.tan\.cursor\projects\f-godot-fair-duet-create-phase-war\assets"
)
OUT_SIZE = 512

JOBS: list[tuple[str, str]] = [
    ("energy_start_1.png", "energy_start_1"),
    ("energy_start_2.png", "energy_start_2"),
    ("energy_start_3.png", "energy_start_3"),
    ("energy_start_4.png", "energy_start_4"),
    ("energy_start_5.png", "energy_start_5"),
    ("energy_start_6.png", "energy_start_6"),
    ("energy_start_7.png", "energy_start_7"),
]


def whitescreen_to_rgba(img: Image.Image) -> Image.Image:
    rgb = img.convert("RGB")
    try:
        import numpy as np

        arr = np.array(rgb, dtype=np.int16)
        r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
        brightness = (r + g + b) / 3.0
        neutral = 255 - np.maximum(np.abs(r - g), np.maximum(np.abs(g - b), np.abs(r - b)))
        white_score = np.clip((brightness - 210) + (neutral - 180) * 0.5, 0, 255)
        alpha = (255 - np.clip(white_score * 3, 0, 255)).astype(np.uint8)
        fringe = (white_score > 20) & (alpha > 0) & (alpha < 255)
        alpha[fringe] = np.minimum(alpha[fringe], np.clip(255 - (white_score[fringe] - 20) * 8, 0, 255))
        out = np.dstack(
            [
                arr[:, :, 0].astype(np.uint8),
                arr[:, :, 1].astype(np.uint8),
                arr[:, :, 2].astype(np.uint8),
                alpha,
            ]
        )
        return Image.fromarray(out, "RGBA")
    except ImportError:
        px = rgb.load()
        w, h = rgb.size
        out = Image.new("RGBA", (w, h))
        opx = out.load()
        for y in range(h):
            for x in range(w):
                r, g, b = px[x, y]
                bright = (r + g + b) / 3
                neutral = 255 - max(abs(r - g), abs(g - b), abs(r - b))
                score = max(0, (bright - 210) + (neutral - 180) * 0.5)
                if score > 60:
                    a = 0
                elif score > 30:
                    a = int(255 - (score - 30) * 8)
                else:
                    a = 255
                opx[x, y] = (r, g, b, max(0, min(255, a)))
        return out


def fit_square(img: Image.Image, size: int) -> Image.Image:
    img = img.convert("RGBA")
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    w, h = img.size
    scale = min(size / w, size / h) * 0.88
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(img, ((size - nw) // 2, (size - nh) // 2), img)
    return canvas


def main() -> None:
    icons_dir = ROOT / "assets" / "card_icons"
    archive = icons_dir / "_agent_source"
    archive.mkdir(parents=True, exist_ok=True)

    for src_name, card_id in JOBS:
        src = AGENT_ASSETS / src_name
        if not src.is_file():
            raise SystemExit(f"Missing Agent output: {src}")
        keyed = fit_square(whitescreen_to_rgba(Image.open(src)), OUT_SIZE)
        shutil.copy2(src, archive / src_name)
        dest = icons_dir / f"{card_id}.png"
        keyed.save(dest, optimize=True)
        print(f"  {dest.relative_to(ROOT)} ({dest.stat().st_size // 1024} KB)")
        print(f"[OK] {card_id} <- {src_name}")


if __name__ == "__main__":
    main()
