#!/usr/bin/env python3
"""Key #00FF00 green from Agent-generated PNGs and deploy to card icon paths."""
from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
AGENT_ASSETS = Path(
    r"C:\Users\jianchang.tan\.cursor\projects\f-godot-fair-duet-create-phase-war\assets"
)
OUT_SIZE = 512

JOBS: list[tuple[str, str, str, str]] = [
    ("vis_player_001_scout_car.png", "vis_player_001", "foe_platform_ww1_light", "captured_foe_platform_ww1_light"),
    ("vis_player_002_mark5_tank.png", "vis_player_002", "foe_platform_ww1_medium", "captured_foe_platform_ww1_medium"),
    ("vis_player_003_coastal_gun.png", "vis_player_003", "foe_platform_ww1_fort", "captured_foe_platform_ww1_fort"),
    ("vis_player_004_balloon.png", "vis_player_004", "foe_platform_ww1_radar", "captured_foe_platform_ww1_radar"),
    ("vis_player_005_ambulance.png", "vis_player_005", "foe_platform_ww1_medic", "captured_foe_platform_ww1_medic"),
]


def greenscreen_to_rgba(img: Image.Image) -> Image.Image:
    rgb = img.convert("RGB")
    try:
        import numpy as np

        arr = np.array(rgb, dtype=np.int16)
        r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
        green_dom = g - np.maximum(r, b)
        spill = np.clip((green_dom - 24) * 6, 0, 255).astype(np.uint8)
        alpha = (255 - spill).astype(np.uint8)
        # soften green fringe on edges
        fringe = (green_dom > 8) & (alpha > 0) & (alpha < 255)
        alpha[fringe] = np.minimum(alpha[fringe], np.clip(255 - (green_dom[fringe] - 8) * 12, 0, 255))
        out = np.dstack([arr[:, :, 0].astype(np.uint8), arr[:, :, 1].astype(np.uint8), arr[:, :, 2].astype(np.uint8), alpha])
        return Image.fromarray(out, "RGBA")
    except ImportError:
        px = rgb.load()
        w, h = rgb.size
        out = Image.new("RGBA", (w, h))
        opx = out.load()
        for y in range(h):
            for x in range(w):
                r, g, b = px[x, y]
                dom = g - max(r, b)
                if dom > 40:
                    a = 0
                elif dom > 20:
                    a = int(255 - (dom - 20) * 12)
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
    units_dir = ROOT / "assets" / "card_icons" / "units"
    icons_dir = ROOT / "assets" / "card_icons"
    archive = ROOT / "assets" / "card_icons" / "_agent_source"
    archive.mkdir(parents=True, exist_ok=True)
    units_dir.mkdir(parents=True, exist_ok=True)

    for src_name, visual_id, archetype_id, captured_id in JOBS:
        src = AGENT_ASSETS / src_name
        if not src.is_file():
            raise SystemExit(f"Missing Agent output: {src}")
        keyed = fit_square(greenscreen_to_rgba(Image.open(src)), OUT_SIZE)
        shutil.copy2(src, archive / src_name)
        for dest in (
            units_dir / f"{visual_id}.png",
            icons_dir / f"{archetype_id}.png",
            icons_dir / f"{captured_id}.png",
        ):
            keyed.save(dest, optimize=True)
            print(f"  {dest.relative_to(ROOT)} ({dest.stat().st_size // 1024} KB)")
        print(f"[OK] {visual_id} <- {src_name}")


if __name__ == "__main__":
    main()
