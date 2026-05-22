#!/usr/bin/env python3
"""Stack sample unit + frame for visual preview."""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
FRAMES = ROOT / "assets" / "cards" / "frames_v2"
OUT = FRAMES / "_mockup_stacked.png"
# fallback unit art
UNIT = ROOT / "assets" / "card_icons" / "elite_cold_t72.png"
BG = (26, 32, 48, 255)


def main() -> None:
    rarities = ["common", "uncommon", "rare", "epic", "legendary"]
    pad = 20
    cols = len(rarities)
    w, h = 500, 800
    sheet = Image.new("RGBA", (cols * (w + pad) + pad, h + pad * 2), BG)
    unit = None
    if UNIT.is_file():
        unit = Image.open(UNIT).convert("RGBA")
        unit = unit.resize((360, 360), Image.Resampling.LANCZOS)

    for i, r in enumerate(rarities):
        frame_path = FRAMES / f"frame_{r}.png"
        if not frame_path.is_file():
            continue
        frame = Image.open(frame_path).convert("RGBA")
        card = Image.new("RGBA", (w, h), (12, 18, 28, 255))
        if unit:
            ux = (w - unit.width) // 2
            uy = int(h * 0.22)
            card.alpha_composite(unit, (ux, uy))
        card.alpha_composite(frame, (0, 0))
        ox = pad + i * (w + pad)
        sheet.alpha_composite(card, (ox, pad))

    sheet.save(OUT)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
