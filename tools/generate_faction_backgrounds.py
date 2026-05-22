#!/usr/bin/env python3
"""Generate 5:8 faction card backgrounds for Phase War."""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "cards" / "backgrounds"

W, H = 500, 800

FACTIONS: dict[str, dict] = {
    "neutral": {
        "name": "中立",
        "base": (18, 24, 36),
        "accent": (90, 110, 140),
        "glow": (60, 90, 120),
        "pattern": "hex",
    },
    "iron_wall_corp": {
        "name": "钢壁防务",
        "base": (22, 28, 42),
        "accent": (120, 140, 165),
        "glow": (80, 110, 150),
        "pattern": "plates",
    },
    "nova_arms": {
        "name": "新星兵工",
        "base": (28, 18, 16),
        "accent": (220, 90, 45),
        "glow": (255, 140, 60),
        "pattern": "strike",
    },
    "aether_dynamics": {
        "name": "以太动力",
        "base": (12, 28, 34),
        "accent": (40, 200, 190),
        "glow": (80, 255, 220),
        "pattern": "turbine",
    },
    "quantum_logistics": {
        "name": "量子后勤",
        "base": (20, 16, 32),
        "accent": (140, 80, 200),
        "glow": (100, 220, 255),
        "pattern": "crates",
    },
    "helix_recon": {
        "name": "螺旋侦察",
        "base": (14, 26, 20),
        "accent": (90, 220, 130),
        "glow": (120, 255, 160),
        "pattern": "spiral",
    },
    "void_research": {
        "name": "虚空相位",
        "base": (14, 10, 24),
        "accent": (160, 70, 220),
        "glow": (220, 120, 255),
        "pattern": "void_rift",
    },
    "frontier_union": {
        "name": "边境联合",
        "base": (30, 24, 18),
        "accent": (190, 130, 70),
        "glow": (220, 170, 90),
        "pattern": "patch",
    },
}


def _lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def _lerp_rgb(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (
        int(_lerp(c1[0], c2[0], t)),
        int(_lerp(c1[1], c2[1], t)),
        int(_lerp(c1[2], c2[2], t)),
    )


def base_gradient(size: tuple[int, int], base: tuple[int, int, int], accent: tuple[int, int, int]) -> Image.Image:
    try:
        import numpy as np

        w, h = size
        ys = np.linspace(0.0, 1.0, h, dtype=np.float32)
        xs = np.linspace(0.0, 1.0, w, dtype=np.float32)
        xg, yg = np.meshgrid(xs, ys)
        t = np.clip(0.55 * (1.0 - yg) + 0.25 * xg + 0.2 * (1.0 - xg), 0, 1)
        b = np.array(base, dtype=np.float32)
        a = np.array(accent, dtype=np.float32)
        rgb = (b + (a - b) * t[:, :, np.newaxis] * 0.35).astype(np.uint8)
        return Image.fromarray(rgb, mode="RGB")
    except ImportError:
        w, h = size
        img = Image.new("RGB", (w, h))
        px = img.load()
        for y in range(h):
            ty = y / max(h - 1, 1)
            for x in range(w):
                tx = x / max(w - 1, 1)
                t = max(0.0, min(1.0, 0.55 * (1.0 - ty) + 0.25 * tx + 0.2 * (1.0 - tx)))
                px[x, y] = _lerp_rgb(base, accent, t * 0.35)
        return img


def vignette(img: Image.Image, strength: float = 0.55) -> Image.Image:
    try:
        import numpy as np

        w, h = img.size
        ys = np.linspace(-1.0, 1.0, h, dtype=np.float32)
        xs = np.linspace(-1.0, 1.0, w, dtype=np.float32)
        xg, yg = np.meshgrid(xs, ys)
        d = np.sqrt(xg * xg + yg * yg * 1.15)
        v = np.clip((d - 0.25) / 0.95, 0, 1) * strength
        arr = np.array(img.convert("RGB"), dtype=np.float32)
        arr *= 1.0 - v[:, :, np.newaxis]
        return Image.fromarray(arr.astype(np.uint8), mode="RGB")
    except ImportError:
        return img


def center_glow(img: Image.Image, glow: tuple[int, int, int], alpha: int = 45) -> Image.Image:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = W // 2, int(H * 0.42)
    d.ellipse((cx - 180, cy - 140, cx + 180, cy + 140), fill=(*glow, alpha))
    layer = layer.filter(ImageFilter.GaussianBlur(28))
    out = img.convert("RGBA")
    out.alpha_composite(layer)
    return out.convert("RGB")


def draw_hex_pattern(d: ImageDraw.ImageDraw, accent: tuple[int, int, int], alpha: int) -> None:
    step = 26
    for row in range(-2, H // step + 3):
        for col in range(-2, W // step + 3):
            cx = col * step + (step // 2 if row % 2 else 0)
            cy = row * int(step * 0.86)
            pts = []
            for i in range(6):
                ang = math.pi / 3 * i
                pts.append((cx + 11 * math.cos(ang), cy + 11 * math.sin(ang)))
            d.polygon(pts, outline=(*accent, alpha))


def draw_plates(d: ImageDraw.ImageDraw, accent: tuple[int, int, int]) -> None:
    y = 40
    while y < H - 30:
        d.line([(20, y), (W - 20, y)], fill=(*accent, 35), width=2)
        d.line([(30, y + 8), (W - 40, y + 8)], fill=(*tuple(max(0, c - 30) for c in accent), 22), width=1)
        y += 22
    # shield watermark
    cx, cy = W // 2, int(H * 0.38)
    d.polygon(
        [(cx, cy - 70), (cx + 55, cy - 20), (cx + 40, cy + 60), (cx, cy + 90), (cx - 40, cy + 60), (cx - 55, cy - 20)],
        outline=(*accent, 50),
        fill=(*accent, 18),
    )


def draw_strike(d: ImageDraw.ImageDraw, accent: tuple[int, int, int], glow: tuple[int, int, int]) -> None:
    for i in range(7):
        x0 = -40 + i * 70
        d.line([(x0, H + 20), (x0 + 180, -30)], fill=(*accent, 28), width=3)
    d.polygon([(W - 30, 50), (W - 10, 90), (W - 80, 120)], fill=(*glow, 40))


def draw_turbine(d: ImageDraw.ImageDraw, accent: tuple[int, int, int], glow: tuple[int, int, int]) -> None:
    cx, cy = W // 2, int(H * 0.4)
    for r in (120, 90, 60, 35):
        d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(*accent, 40), width=2)
    for i in range(8):
        ang = i * math.pi / 4
        x2 = cx + 130 * math.cos(ang)
        y2 = cy + 130 * math.sin(ang)
        d.line([(cx, cy), (x2, y2)], fill=(*glow, 35), width=2)


def draw_crates(d: ImageDraw.ImageDraw, accent: tuple[int, int, int]) -> None:
    for row in range(5):
        for col in range(4):
            x = 50 + col * 105 + (row % 2) * 20
            y = 80 + row * 95
            d.rectangle((x, y, x + 70, y + 50), outline=(*accent, 45), fill=(*accent, 20))
            d.line([(x + 8, y + 12), (x + 62, y + 12)], fill=(*accent, 30), width=1)


def draw_spiral(d: ImageDraw.ImageDraw, accent: tuple[int, int, int], glow: tuple[int, int, int]) -> None:
    cx, cy = W // 2, int(H * 0.42)
    for turn in range(0, 520, 8):
        t = turn / 520.0
        ang = turn * 0.045
        r = 20 + t * 150
        x = cx + r * math.cos(ang)
        y = cy + r * math.sin(ang)
        d.ellipse((x - 3, y - 3, x + 3, y + 3), fill=(*glow, int(30 + 80 * t)))
    d.ellipse((cx - 25, cy - 25, cx + 25, cy + 25), outline=(*accent, 80), width=2)


def draw_void_rift(d: ImageDraw.ImageDraw, accent: tuple[int, int, int], glow: tuple[int, int, int]) -> None:
    cx, cy = W // 2, int(H * 0.4)
    d.ellipse((cx - 45, cy - 30, cx + 45, cy + 30), fill=(8, 4, 16, 200), outline=(*glow, 120))
    d.ellipse((cx - 12, cy - 8, cx + 12, cy + 8), fill=(*glow, 180))
    for i in range(10):
        ang = i * math.pi / 5
        x1 = cx + 60 * math.cos(ang)
        y1 = cy + 40 * math.sin(ang)
        x2 = cx + 140 * math.cos(ang + 0.2)
        y2 = cy + 100 * math.sin(ang + 0.2)
        d.line([(x1, y1), (x2, y2)], fill=(*accent, 40), width=1)


def draw_patch(d: ImageDraw.ImageDraw, accent: tuple[int, int, int], glow: tuple[int, int, int]) -> None:
    polys = [
        [(40, 120), (140, 90), (120, 200)],
        [(200, 80), (320, 110), (280, 220)],
        [(80, 300), (180, 260), (160, 420)],
        [(260, 340), (400, 300), (360, 500)],
    ]
    for pts in polys:
        d.polygon(pts, fill=(*accent, 25), outline=(*glow, 45))
    d.line([(0, 60), (W, 100)], fill=(*glow, 30), width=4)


def apply_pattern(img: Image.Image, spec: dict) -> Image.Image:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    pat = spec["pattern"]
    accent = spec["accent"]
    glow = spec["glow"]
    if pat == "hex":
        draw_hex_pattern(d, accent, 28)
    elif pat == "plates":
        draw_plates(d, accent)
    elif pat == "strike":
        draw_strike(d, accent, glow)
    elif pat == "turbine":
        draw_turbine(d, accent, glow)
    elif pat == "crates":
        draw_crates(d, accent)
    elif pat == "spiral":
        draw_spiral(d, accent, glow)
    elif pat == "void_rift":
        draw_void_rift(d, accent, glow)
    elif pat == "patch":
        draw_patch(d, accent, glow)
    out = img.convert("RGBA")
    out.alpha_composite(layer)
    return out.convert("RGB")


def build_background(faction_id: str, spec: dict) -> Image.Image:
    img = base_gradient((W, H), spec["base"], spec["accent"])
    img = apply_pattern(img, spec)
    img = center_glow(img, spec["glow"], 38)
    img = vignette(img, 0.5)
    # top/bottom safe bars for UI text
    d = ImageDraw.Draw(img)
    bar = tuple(max(0, c - 12) for c in spec["base"])
    d.rectangle((0, 0, W - 1, 36), fill=bar)
    d.rectangle((0, H - 42, W - 1, H - 1), fill=bar)
    return img


def preview_sheet(images: dict[str, Image.Image]) -> Image.Image:
    pad = 16
    cols = 4
    rows = (len(images) + cols - 1) // cols
    cell_w, cell_h = W + pad, H + pad + 20
    sheet = Image.new("RGB", (cols * cell_w + pad, rows * cell_h + pad), (10, 12, 18))
    d = ImageDraw.Draw(sheet)
    for i, (fid, img) in enumerate(images.items()):
        c = i % cols
        r = i // cols
        ox = pad + c * cell_w
        oy = pad + r * cell_h
        sheet.paste(img, (ox, oy))
        label = FACTIONS.get(fid, {}).get("name", fid)
        d.text((ox + 6, oy + H + 4), label, fill=(210, 220, 235))
    return sheet


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    built: dict[str, Image.Image] = {}
    for fid, spec in FACTIONS.items():
        img = build_background(fid, spec)
        name = "bg_neutral.png" if fid == "neutral" else f"bg_{fid}.png"
        path = OUT_DIR / name
        img.save(path, optimize=True)
        built[fid] = img
        print(f"Wrote {path} ({path.stat().st_size // 1024} KB)")
    prev = preview_sheet(built)
    prev_path = OUT_DIR / "_preview_all_factions.png"
    prev.save(prev_path)
    print(f"Wrote {prev_path}")


if __name__ == "__main__":
    main()
