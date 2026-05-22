#!/usr/bin/env python3
"""Generate ornate 5:8 card rarity frames (transparent center) for Phase War."""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "cards" / "frames_v2"

W, H = 500, 800
CORNER_R = 50

RARITIES: dict[str, dict] = {
    "common": {
        "rgb": (191, 191, 191),
        "rgb_hi": (230, 230, 235),
        "rgb_lo": (110, 115, 125),
        "border": 12,
        "glow": 4,
        "tier": 0,
    },
    "uncommon": {
        "rgb": (102, 230, 128),
        "rgb_hi": (160, 255, 190),
        "rgb_lo": (30, 120, 60),
        "border": 14,
        "glow": 10,
        "tier": 1,
    },
    "rare": {
        "rgb": (102, 166, 255),
        "rgb_hi": (180, 220, 255),
        "rgb_lo": (25, 70, 160),
        "border": 16,
        "glow": 12,
        "tier": 2,
    },
    "epic": {
        "rgb": (191, 102, 255),
        "rgb_hi": (240, 180, 255),
        "rgb_lo": (90, 30, 150),
        "border": 18,
        "glow": 14,
        "tier": 3,
    },
    "legendary": {
        "rgb": (255, 179, 77),
        "rgb_hi": (255, 240, 180),
        "rgb_lo": (180, 90, 20),
        "border": 22,
        "glow": 18,
        "tier": 4,
    },
}


def _rounded_mask(size: tuple[int, int], rect: tuple[int, int, int, int], radius: int) -> Image.Image:
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle(rect, radius=radius, fill=255)
    return m


def border_mask(width: int, height: int, radius: int, thickness: int) -> Image.Image:
    outer = _rounded_mask((width, height), (0, 0, width - 1, height - 1), radius)
    ir = max(radius - thickness, 4)
    inner = _rounded_mask(
        (width, height),
        (thickness, thickness, width - thickness - 1, height - thickness - 1),
        ir,
    )
    return ImageChops.subtract(outer, inner)


def inner_edge_mask(thickness: int, inset: int, line_w: int = 2) -> Image.Image:
    outer = border_mask(W, H, CORNER_R, thickness + inset)
    inner = border_mask(W, H, CORNER_R, thickness + inset + line_w)
    return ImageChops.subtract(outer, inner)


def tint_layer(mask: Image.Image, rgba: tuple[int, int, int, int]) -> Image.Image:
    layer = Image.new("RGBA", mask.size, rgba)
    return Image.composite(layer, Image.new("RGBA", mask.size, (0, 0, 0, 0)), mask)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def lerp_rgb(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (
        int(lerp(c1[0], c2[0], t)),
        int(lerp(c1[1], c2[1], t)),
        int(lerp(c1[2], c2[2], t)),
    )


def _metallic_gradient_rgb(size: tuple[int, int], lo: tuple[int, int, int], mid: tuple[int, int, int], hi: tuple[int, int, int]) -> Image.Image:
    """Full-canvas metallic gradient; composite with border mask afterward."""
    try:
        import numpy as np

        w, h = size
        xs = np.linspace(0.0, 1.0, w, dtype=np.float32)
        ys = np.linspace(0.0, 1.0, h, dtype=np.float32)
        xg, yg = np.meshgrid(xs, ys)
        t = np.clip(0.45 * xg + 0.35 * (1.0 - yg) + 0.2 * yg, 0.0, 1.0)
        lo_a = np.array(lo, dtype=np.float32)
        mid_a = np.array(mid, dtype=np.float32)
        hi_a = np.array(hi, dtype=np.float32)
        low = t < 0.5
        t2 = np.where(low, t * 2.0, (t - 0.5) * 2.0)
        c_lo = lo_a + (mid_a - lo_a) * t2[:, :, np.newaxis]
        c_hi = mid_a + (hi_a - mid_a) * t2[:, :, np.newaxis]
        rgb = np.where(low[:, :, np.newaxis], c_lo, c_hi).astype(np.uint8)
        return Image.fromarray(rgb, mode="RGB")
    except ImportError:
        w, h = size
        img = Image.new("RGB", (w, h))
        px = img.load()
        wm, hm = max(w - 1, 1), max(h - 1, 1)
        for y in range(h):
            ty = y / hm
            for x in range(w):
                tx = x / wm
                t = max(0.0, min(1.0, 0.45 * tx + 0.35 * (1.0 - ty) + 0.2 * ty))
                px[x, y] = lerp_rgb(lo, mid, t * 2.0) if t < 0.5 else lerp_rgb(mid, hi, (t - 0.5) * 2.0)
        return img


def gradient_border_layer(mask: Image.Image, lo: tuple[int, int, int], mid: tuple[int, int, int], hi: tuple[int, int, int]) -> Image.Image:
    grad = _metallic_gradient_rgb(mask.size, lo, mid, hi).convert("RGBA")
    grad.putalpha(mask)
    return grad


def add_glow(base: Image.Image, mask: Image.Image, rgb: tuple[int, int, int], spread: int, alpha: int) -> Image.Image:
    if spread <= 0:
        return base
    g = tint_layer(mask, (*rgb, alpha))
    g = g.filter(ImageFilter.GaussianBlur(spread))
    out = Image.new("RGBA", base.size, (0, 0, 0, 0))
    out.alpha_composite(g)
    out.alpha_composite(base)
    return out


def draw_circuit_traces(img: Image.Image, thickness: int, rgb: tuple[int, int, int], tier: int) -> None:
    d = ImageDraw.Draw(img)
    pad = thickness + 8
    col = (*tuple(min(255, int(c * 1.1)) for c in rgb), 70 + tier * 25)
    hi = (*tuple(min(255, c + 40) for c in rgb), 120 + tier * 20)
    # vertical side channels
    for side_x in (pad + 4, W - pad - 8):
        for seg in range(5 + tier * 2):
            y0 = pad + 40 + seg * int((H - pad * 2 - 80) / (6 + tier))
            y1 = y0 + 12 + tier * 2
            d.line([(side_x, y0), (side_x, y1)], fill=col, width=1)
            d.line([(side_x + 3, y0 + 4), (side_x + 10, y0 + 4)], fill=hi, width=1)
    # top/bottom micro traces
    for y_line in (pad + 12, H - pad - 14):
        x = pad + 30
        while x < W - pad - 40:
            ln = 8 + tier * 3
            d.line([(x, y_line), (x + ln, y_line)], fill=col, width=1)
            d.ellipse((x + ln - 2, y_line - 2, x + ln + 2, y_line + 2), fill=hi)
            x += 18 + tier * 4


def draw_hex_lattice_band(img: Image.Image, thickness: int, rgb: tuple[int, int, int]) -> None:
    d = ImageDraw.Draw(img)
    cy = H // 2
    x = thickness + 20
    while x < W - thickness - 35:
        for row, dy in enumerate((-22, 0, 22)):
            hx = x + (11 if row == 1 else 0)
            hy = cy + dy
            pts = []
            for i in range(6):
                ang = math.pi / 3 * i - math.pi / 6
                pts.append((hx + 9 * math.cos(ang), hy + 9 * math.sin(ang)))
            fill_a = 45 if row == 1 else 25
            d.polygon(pts, outline=(*rgb, 110), fill=(*rgb, fill_a))
        x += 28


def draw_corner_brackets(img: Image.Image, thickness: int, rgb: tuple[int, int, int], tier: int) -> None:
    d = ImageDraw.Draw(img)
    pad = thickness + 2
    arm = 22 + tier * 8
    thick = 2 + tier // 2
    hi = tuple(min(255, c + 70) for c in rgb)
    lo = tuple(max(0, c - 40) for c in rgb)
    corners = [
        (pad, pad, 1, 1),
        (W - pad, pad, -1, 1),
        (pad, H - pad, 1, -1),
        (W - pad, H - pad, -1, -1),
    ]
    for ox, oy, fx, fy in corners:
        d.line([(ox, oy), (ox + fx * arm, oy)], fill=(*hi, 220), width=thick)
        d.line([(ox, oy), (ox, oy + fy * arm)], fill=(*hi, 220), width=thick)
        d.line([(ox + fx * 6, oy + fy * 6), (ox + fx * arm, oy + fy * 6)], fill=(*rgb, 160), width=1)
        if tier >= 2:
            d.polygon(
                [
                    (ox + fx * (arm - 4), oy + fy * 4),
                    (ox + fx * (arm + 2), oy),
                    (ox + fx * (arm - 4), oy - fy * 4),
                ],
                fill=(*rgb, 180),
            )


def draw_corner_gem(img: Image.Image, cx: int, cy: int, rgb: tuple[int, int, int], size: int) -> None:
    d = ImageDraw.Draw(img)
    hi = tuple(min(255, c + 90) for c in rgb)
    sh = tuple(max(0, c - 50) for c in rgb)
    half = size // 2
    pts = [(cx, cy - half), (cx + half, cy), (cx, cy + half), (cx - half, cy)]
    d.polygon(pts, fill=(*rgb, 230), outline=(*hi, 255))
    d.polygon(
        [(cx - 2, cy - half + 3), (cx + half - 4, cy - 2), (cx, cy)],
        fill=(*hi, 140),
    )
    d.ellipse((cx - 3, cy - 3, cx + 3, cy + 3), fill=(255, 255, 255, 200))
    d.line([(cx - half, cy + half - 2), (cx + half - 2, cy + half)], fill=(*sh, 180), width=1)


def draw_corner_gems(img: Image.Image, thickness: int, rgb: tuple[int, int, int], tier: int) -> None:
    pad = thickness + 10
    sz = 16 + tier * 4
    for cx, cy in (
        (pad + sz // 2, pad + sz // 2),
        (W - pad - sz // 2, pad + sz // 2),
        (pad + sz // 2, H - pad - sz // 2),
        (W - pad - sz // 2, H - pad - sz // 2),
    ):
        draw_corner_gem(img, cx, cy, rgb, sz)


def draw_wing_filigree(img: Image.Image, thickness: int, rgb: tuple[int, int, int]) -> None:
    d = ImageDraw.Draw(img)
    pad = thickness + 6
    wing = 42
    hi = tuple(min(255, c + 100) for c in rgb)
    accent = (255, 230, 160)

    def draw_one_wing(ox: int, oy: int, fx: int, fy: int) -> None:
        pts = [
            (ox, oy),
            (ox + fx * wing, oy + fy * 6),
            (ox + fx * (wing - 8), oy + fy * 22),
            (ox + fx * (wing - 18), oy + fy * 32),
            (ox + fx * 14, oy + fy * 18),
            (ox + fx * 6, oy + fy * 10),
        ]
        d.polygon(pts, fill=(*rgb, 190), outline=(*hi, 255))
        d.line(
            [(ox + fx * 8, oy + fy * 8), (ox + fx * (wing - 10), oy + fy * 14)],
            fill=(*accent, 200),
            width=2,
        )

    draw_one_wing(pad, pad, 1, 1)
    draw_one_wing(W - pad, pad, -1, 1)
    draw_one_wing(pad, H - pad, 1, -1)
    draw_one_wing(W - pad, H - pad, -1, -1)


def draw_crown_crest(img: Image.Image, thickness: int, rgb: tuple[int, int, int]) -> None:
    d = ImageDraw.Draw(img)
    cx = W // 2
    y = thickness + 4
    hi = tuple(min(255, c + 90) for c in rgb)
    pts = [
        (cx - 36, y + 18),
        (cx - 22, y + 4),
        (cx - 10, y + 16),
        (cx, y),
        (cx + 10, y + 16),
        (cx + 22, y + 4),
        (cx + 36, y + 18),
        (cx + 28, y + 26),
        (cx - 28, y + 26),
    ]
    d.polygon(pts, fill=(*rgb, 210), outline=(*hi, 255))
    for gx in (cx - 18, cx, cx + 18):
        draw_corner_gem(img, gx, y + 10, hi, 10)


def _border_pixel_samples(mask: Image.Image, count: int, seed: int) -> list[tuple[int, int]]:
    rng = random.Random(seed)
    data = mask.getdata()
    w, h = mask.size
    pts: list[tuple[int, int]] = []
    for i, v in enumerate(data):
        if v > 0:
            pts.append((i % w, i // w))
    if not pts:
        return []
    return [pts[rng.randrange(len(pts))] for _ in range(min(count, len(pts)))]


def draw_sparkles(img: Image.Image, thickness: int, tier: int, seed: int = 42) -> None:
    d = ImageDraw.Draw(img)
    mask = border_mask(W, H, CORNER_R, thickness)
    n = 12 + tier * 10
    for x, y in _border_pixel_samples(mask, n, seed):
        rng = random.Random(seed + x * 17 + y)
        r = rng.randint(1, 3)
        a = rng.randint(100, 220)
        col = (255, 245, 200, a) if tier >= 4 else (220, 240, 255, a)
        d.ellipse((x - r, y - r, x + r, y + r), fill=col)
        if r >= 2:
            d.line([(x - r * 2, y), (x + r * 2, y)], fill=(*col[:3], a // 2), width=1)
            d.line([(x, y - r * 2), (x, y + r * 2)], fill=(*col[:3], a // 2), width=1)


def draw_inner_glow_line(img: Image.Image, thickness: int, rgb: tuple[int, int, int], alpha: int) -> None:
    m = inner_edge_mask(thickness, 3, 2)
    glow = tint_layer(m, (*rgb, alpha))
    glow = glow.filter(ImageFilter.GaussianBlur(2))
    img.alpha_composite(glow)
    img.alpha_composite(tint_layer(m, (*tuple(min(255, c + 50) for c in rgb), min(255, alpha + 60))))


def draw_triple_rim(img: Image.Image, thickness: int, rgb: tuple[int, int, int]) -> None:
    for inset, alpha, w in ((6, 50, 1), (12, 90, 2), (18, 130, 2)):
        m = inner_edge_mask(thickness, inset, w)
        img.alpha_composite(tint_layer(m, (*rgb, alpha)))


def build_frame(rarity: str, spec: dict) -> Image.Image:
    rgb = spec["rgb"]
    hi = spec["rgb_hi"]
    lo = spec["rgb_lo"]
    thickness = spec["border"]
    tier = spec["tier"]
    mask = border_mask(W, H, CORNER_R, thickness)

    # outer aura
    frame = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    frame = add_glow(frame, mask, rgb, spec["glow"] + 4, 35 + tier * 12)
    frame = add_glow(frame, mask, hi, max(4, spec["glow"] // 2), 25 + tier * 8)

    # main metallic gradient border
    frame.alpha_composite(gradient_border_layer(mask, lo, rgb, hi))

    # dark outer rim (depth)
    outer_rim = border_mask(W, H, CORNER_R, thickness + 4)
    outer_only = ImageChops.subtract(outer_rim, mask)
    frame.alpha_composite(tint_layer(outer_only, (*tuple(max(0, c - 80) for c in lo), 180)))

    draw_corner_brackets(frame, thickness, rgb, tier)

    if tier >= 1:
        draw_circuit_traces(frame, thickness, rgb, tier)
        draw_inner_glow_line(frame, thickness, rgb, 60 + tier * 25)

    if tier >= 2:
        draw_triple_rim(frame, thickness, rgb)
        draw_hex_lattice_band(frame, thickness, rgb)

    if tier >= 3:
        draw_corner_gems(frame, thickness, rgb, tier)
        m2 = inner_edge_mask(thickness, 8, 1)
        frame.alpha_composite(tint_layer(m2, (*hi, 100)))

    if tier >= 4:
        draw_wing_filigree(frame, thickness, rgb)
        draw_crown_crest(frame, thickness, rgb)
        draw_sparkles(frame, thickness, tier)
        # second inner gold rim
        draw_inner_glow_line(frame, thickness, (255, 220, 140), 100)

    draw_sparkles(frame, thickness, tier, seed=hash(rarity) % 10000)

    return frame


def make_preview_sheet(frames: dict[str, Image.Image]) -> Image.Image:
    cols = len(frames)
    pad = 24
    label_h = 36
    cell_w, cell_h = W + pad * 2, H + pad * 2 + label_h
    sheet = Image.new("RGBA", (cols * cell_w, cell_h), (12, 16, 26, 255))
    d = ImageDraw.Draw(sheet)
    for i, (name, img) in enumerate(frames.items()):
        ox = i * cell_w + pad
        oy = pad
        sheet.alpha_composite(img, (ox, oy))
        d.text((ox + 4, oy + H + 10), name, fill=(220, 230, 245, 255))
    return sheet


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    built: dict[str, Image.Image] = {}
    for rarity, spec in RARITIES.items():
        img = build_frame(rarity, spec)
        path = OUT_DIR / f"frame_{rarity}.png"
        img.save(path, optimize=True)
        built[rarity] = img
        print(f"Wrote {path} ({path.stat().st_size // 1024} KB)")

    preview = make_preview_sheet(built)
    preview_path = OUT_DIR / "_preview_all_rarities.png"
    preview.save(preview_path)
    print(f"Wrote {preview_path}")


if __name__ == "__main__":
    main()
