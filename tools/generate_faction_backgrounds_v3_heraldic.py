#!/usr/bin/env python3
"""Heraldic / banner-style faction card backgrounds (5:8) — preview set."""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "cards" / "backgrounds_choice" / "set_heraldic_v3"
V2_DIR = ROOT / "assets" / "cards" / "backgrounds_choice" / "set_distinct_v2"
UNIT_SAMPLE = ROOT / "assets" / "card_icons" / "units" / "vis_player_002.png"
FRAME_SAMPLE = ROOT / "assets" / "cards" / "frames" / "epic.png"

W, H = 500, 800


def _lift(c: tuple[int, int, int], n: int = 34) -> tuple[int, int, int]:
    return tuple(min(255, v + n) for v in c)


def _lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def _lerp_rgb(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (
        int(_lerp(c1[0], c2[0], t)),
        int(_lerp(c1[1], c2[1], t)),
        int(_lerp(c1[2], c2[2], t)),
    )


FACTIONS: dict[str, dict] = {
    "neutral": {
        "name": "中立",
        "field": _lift((42, 52, 72)),
        "field2": _lift((55, 70, 95)),
        "metal": (190, 200, 215),
        "accent": _lift((110, 130, 165), 18),
        "hi": (220, 230, 245),
        "glow": _lift((90, 120, 170), 22),
        "charge": "hex_mesh",
        "division": "plain",
        "banner": "NEUTRAL",
    },
    "iron_wall_corp": {
        "name": "钢壁防务",
        "field": _lift((48, 54, 68)),
        "field2": (120, 135, 155),
        "metal": (215, 220, 230),
        "accent": _lift((150, 165, 190), 16),
        "hi": (245, 248, 255),
        "glow": _lift((120, 145, 185), 20),
        "charge": "steel_cross",
        "division": "fess",
        "banner": "IRON WALL",
    },
    "nova_arms": {
        "name": "新星兵工",
        "field": _lift((58, 28, 22)),
        "field2": (140, 45, 30),
        "metal": (255, 200, 120),
        "accent": (255, 130, 60),
        "hi": (255, 210, 120),
        "glow": (255, 170, 80),
        "charge": "flame_saltire",
        "division": "chief",
        "banner": "NOVA ARMS",
    },
    "aether_dynamics": {
        "name": "以太动力",
        "field": _lift((18, 48, 58)),
        "field2": (30, 100, 110),
        "metal": (170, 255, 240),
        "accent": (55, 230, 210),
        "hi": (190, 255, 245),
        "glow": (90, 245, 225),
        "charge": "turbine_rose",
        "division": "round",
        "banner": "AETHER",
    },
    "quantum_logistics": {
        "name": "量子后勤",
        "field": _lift((34, 24, 58)),
        "field2": (70, 45, 110),
        "metal": (180, 150, 255),
        "accent": _lift((150, 90, 220), 20),
        "hi": (160, 235, 255),
        "glow": (200, 140, 255),
        "charge": "chevron_crates",
        "division": "quarterly",
        "banner": "QUANTUM",
    },
    "helix_recon": {
        "name": "螺旋侦察",
        "field": _lift((18, 46, 32)),
        "field2": (35, 95, 55),
        "metal": (190, 255, 200),
        "accent": (90, 245, 150),
        "hi": (210, 255, 220),
        "glow": (130, 255, 170),
        "charge": "helix_bend",
        "division": "bend",
        "banner": "HELIX",
    },
    "void_research": {
        "name": "虚空相位",
        "field": _lift((32, 18, 52)),
        "field2": (55, 30, 85),
        "metal": (230, 170, 255),
        "accent": _lift((170, 70, 240), 18),
        "hi": (250, 190, 255),
        "glow": (220, 120, 255),
        "charge": "void_eye",
        "division": "saltire",
        "banner": "VOID",
    },
    "frontier_union": {
        "name": "边境联合",
        "field": _lift((52, 40, 26)),
        "field2": (95, 75, 40),
        "metal": (255, 220, 130),
        "accent": (230, 170, 85),
        "hi": (255, 240, 170),
        "glow": (255, 200, 110),
        "charge": "union_star",
        "division": "canton",
        "banner": "FRONTIER",
    },
}


def field_gradient(spec: dict) -> Image.Image:
    img = Image.new("RGB", (W, H))
    px = img.load()
    f1, f2, hi = spec["field"], spec["field2"], spec["hi"]
    for y in range(H):
        ty = y / max(H - 1, 1)
        for x in range(W):
            tx = x / max(W - 1, 1)
            t = 0.5 * (1.0 - ty) + 0.3 * tx + 0.2 * (1.0 - abs(tx - 0.5) * 2.0)
            t = max(0.0, min(1.0, t))
            c = _lerp_rgb(f1, f2, t * 0.75)
            if ty < 0.14:
                c = _lerp_rgb(c, hi, (0.14 - ty) / 0.14 * 0.25)
            px[x, y] = c
    return img


def draw_diaper(d: ImageDraw.ImageDraw, c1: tuple[int, int, int], c2: tuple[int, int, int]) -> None:
    step = 28
    for row in range(-1, H // step + 2):
        for col in range(-1, W // step + 2):
            x = col * step + (step // 2 if row % 2 else 0)
            y = row * step
            d.polygon(
                [(x, y), (x + step // 2, y + step // 2), (x, y + step), (x - step // 2, y + step // 2)],
                outline=(*c1, 28),
                fill=(*c2, 12),
            )


def heater_shield(cx: int, cy: int, hw: int, hh: int) -> list[tuple[float, float]]:
    w, h = hw, hh
    return [
        (cx, cy - h),
        (cx + w * 0.72, cy - h * 0.55),
        (cx + w * 0.82, cy - h * 0.05),
        (cx + w * 0.62, cy + h * 0.55),
        (cx + w * 0.28, cy + h * 0.92),
        (cx, cy + h),
        (cx - w * 0.28, cy + h * 0.92),
        (cx - w * 0.62, cy + h * 0.55),
        (cx - w * 0.82, cy - h * 0.05),
        (cx - w * 0.72, cy - h * 0.55),
    ]


def round_shield(cx: int, cy: int, r: int) -> list[tuple[float, float]]:
    pts = []
    for i in range(32):
        ang = -math.pi / 2 + i * 2 * math.pi / 32
        rr = r if i < 24 else r * 0.92
        pts.append((cx + rr * math.cos(ang), cy + rr * math.sin(ang) * 1.15))
    return pts


def draw_shield_body(d: ImageDraw.ImageDraw, pts, spec: dict) -> None:
    f1, f2, metal, hi = spec["field"], spec["field2"], spec["metal"], spec["hi"]
    div = spec["division"]
    d.polygon(pts, fill=(*f1, 235), outline=(*metal, 255), width=4)

    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    x0, x1 = min(xs), max(xs)
    y0, y1 = min(ys), max(ys)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2

    if div == "fess":
        d.polygon(
            [(x0, y0), (x1, y0), (x1, cy - 8), (x0, cy - 8)],
            fill=(*f2, 200),
        )
        d.line([(x0 + 8, cy), (x1 - 8, cy)], fill=(*metal, 220), width=3)
    elif div == "chief":
        d.polygon([(x0, y0), (x1, y0), (x1, cy - 30), (x0, cy - 30)], fill=(*spec["accent"], 210))
    elif div == "quarterly":
        d.polygon([(x0, y0), (cx, y0), (cx, cy), (x0, cy)], fill=(*f2, 190))
        d.polygon([(cx, cy), (x1, cy), (x1, y1), (cx, y1)], fill=(*spec["accent"], 160))
        d.line([(cx, y0), (cx, y1)], fill=(*metal, 200), width=2)
        d.line([(x0, cy), (x1, cy)], fill=(*metal, 200), width=2)
    elif div == "bend":
        d.polygon([(x0, y0), (x1, y0), (x1, y0 + 60), (x0 + 80, y1), (x0, y1)], fill=(*f2, 170))
        d.line([(x0 + 20, y1 - 20), (x1 - 20, y0 + 20)], fill=(*metal, 200), width=4)
    elif div == "saltire":
        d.line([(x0 + 15, y0 + 15), (x1 - 15, y1 - 15)], fill=(*spec["accent"], 180), width=5)
        d.line([(x1 - 15, y0 + 15), (x0 + 15, y1 - 15)], fill=(*spec["accent"], 180), width=5)
    elif div == "canton":
        d.polygon([(x0, y0), (x0 + 110, y0), (x0 + 110, y0 + 110), (x0, y0 + 110)], fill=(*spec["accent"], 200))
        d.polygon([(x1 - 110, y0), (x1, y0), (x1, y0 + 110), (x1 - 110, y0 + 110)], fill=(*f2, 180))

    # inner fimbriation
    inset = [(cx + (p[0] - cx) * 0.88, cy + (p[1] - cy) * 0.88) for p in pts]
    d.polygon(inset, outline=(*hi, 120), width=2)


def draw_charge(d: ImageDraw.ImageDraw, kind: str, cx: int, cy: int, spec: dict) -> None:
    acc, hi, metal = spec["accent"], spec["hi"], spec["metal"]

    if kind == "hex_mesh":
        for row in range(-1, 3):
            for col in range(-1, 4):
                hx = cx + (col - 1) * 38 + (19 if row % 2 else 0)
                hy = cy + (row - 1) * 34
                pts = [(hx + 14 * math.cos(math.pi / 3 * i - math.pi / 6),
                        hy + 14 * math.sin(math.pi / 3 * i - math.pi / 6)) for i in range(6)]
                d.polygon(pts, outline=(*hi, 140), fill=(*acc, 50))

    elif kind == "steel_cross":
        d.rectangle((cx - 12, cy - 55, cx + 12, cy + 55), fill=(*metal, 230))
        d.rectangle((cx - 55, cy - 12, cx + 55, cy + 12), fill=(*metal, 230))
        for y in range(cy - 40, cy + 45, 14):
            d.line([(cx - 48, y), (cx + 48, y)], fill=(*acc, 60), width=1)

    elif kind == "flame_saltire":
        d.polygon(
            [(cx, cy - 70), (cx + 28, cy - 10), (cx + 40, cy + 50), (cx, cy + 75),
             (cx - 40, cy + 50), (cx - 28, cy - 10)],
            fill=(*acc, 220), outline=(*hi, 255),
        )
        d.line([(cx - 60, cy + 40), (cx + 70, cy - 60)], fill=(*hi, 180), width=4)

    elif kind == "turbine_rose":
        for r in (58, 42, 26):
            d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(*metal, 220), width=2)
        for i in range(5):
            ang = i * 2 * math.pi / 5 - math.pi / 2
            d.line([(cx, cy), (cx + 62 * math.cos(ang), cy + 62 * math.sin(ang))], fill=(*acc, 200), width=3)
        d.ellipse((cx - 10, cy - 10, cx + 10, cy + 10), fill=(*hi, 240))

    elif kind == "chevron_crates":
        d.polygon([(cx - 70, cy + 20), (cx, cy - 50), (cx + 70, cy + 20)], fill=(*acc, 200), outline=(*hi, 255))
        for ox, oy in ((-45, 25), (15, 25)):
            d.rectangle((cx + ox, cy + oy, cx + ox + 36, cy + oy + 26), outline=(*hi, 200), fill=(*metal, 80), width=2)

    elif kind == "helix_bend":
        pts_l, pts_r = [], []
        for t in range(0, 280, 8):
            rad = math.radians(t)
            r = 12 + t * 0.18
            pts_l.append((cx - 10 + r * math.cos(rad), cy - 50 + t * 0.35))
            pts_r.append((cx + 10 + r * math.cos(rad + math.pi), cy - 50 + t * 0.35))
        d.line(pts_l, fill=(*hi, 220), width=4)
        d.line(pts_r, fill=(*acc, 220), width=4)

    elif kind == "void_eye":
        d.ellipse((cx - 48, cy - 32, cx + 48, cy + 32), fill=(50, 30, 80, 200), outline=(*hi, 255), width=3)
        d.ellipse((cx - 16, cy - 10, cx + 16, cy + 10), fill=(*hi, 240))
        for i in range(6):
            ang = i * math.pi / 3
            d.line([(cx + 52 * math.cos(ang), cy + 34 * math.sin(ang)),
                    (cx + 95 * math.cos(ang), cy + 70 * math.sin(ang))], fill=(*acc, 120), width=2)

    elif kind == "union_star":
        star = []
        for i in range(10):
            ang = -math.pi / 2 + i * math.pi / 5
            r = 58 if i % 2 == 0 else 26
            star.append((cx + r * math.cos(ang), cy - 10 + r * math.sin(ang)))
        d.polygon(star, fill=(*acc, 230), outline=(*hi, 255), width=2)
        d.polygon([(cx - 50, cy + 45), (cx + 50, cy + 45), (cx + 38, cy + 72), (cx - 38, cy + 72)],
                  fill=(*spec["field2"], 200), outline=(*metal, 200))


def draw_laurel(d: ImageDraw.ImageDraw, cx: int, cy: int, r: int, color: tuple[int, int, int]) -> None:
    for side in (-1, 1):
        for i in range(14):
            ang = math.radians(210 + i * 8 * side)
            lx = cx + side * r * math.cos(ang)
            ly = cy + r * 0.55 * math.sin(ang)
            d.ellipse((lx - 7, ly - 4, lx + 7, ly + 4), fill=(*color, 160), outline=(*color, 220))


def draw_top_banner(d: ImageDraw.ImageDraw, spec: dict, text: str) -> None:
    y0, y1 = 8, 52
    acc, hi, metal = spec["accent"], spec["hi"], spec["metal"]
    d.polygon([(24, y0), (W - 24, y0), (W - 36, y1), (36, y1)], fill=(*acc, 230), outline=(*metal, 255))
    d.polygon([(36, y1), (W - 36, y1), (W - 48, y1 + 18), (48, y1 + 18)], fill=(*spec["field2"], 220), outline=(*metal, 200))
    d.line([(48, y0 + 8), (W - 48, y0 + 8)], fill=(*hi, 180), width=2)
    tw = len(text) * 7
    d.text((W // 2 - tw, y0 + 14), text, fill=(*hi, 255))


def draw_bottom_ribbon(d: ImageDraw.ImageDraw, spec: dict) -> None:
    y0 = H - 58
    acc, hi, metal = spec["accent"], spec["hi"], spec["metal"]
    d.polygon([(60, y0), (W - 60, y0), (W - 44, y0 + 28), (44, y0 + 28)], fill=(*spec["field2"], 220), outline=(*metal, 255))
    d.polygon([(44, y0 + 28), (W - 44, y0 + 28), (W - 56, y0 + 44), (W // 2 + 8, y0 + 44),
               (W // 2, y0 + 54), (W // 2 - 8, y0 + 44), (56, y0 + 44)], fill=(*acc, 210), outline=(*metal, 200))


def draw_side_flags(d: ImageDraw.ImageDraw, spec: dict) -> None:
    acc, hi = spec["accent"], spec["hi"]
    for sx, dx in ((8, 1), (W - 38, -1)):
        d.polygon([(sx, 120), (sx + 30 * dx, 128), (sx + 30 * dx, 220), (sx, 212)], fill=(*acc, 200), outline=(*hi, 220))
        d.line([(sx + 15 * dx, 118), (sx + 15 * dx, 240)], fill=(*hi, 180), width=2)


def build_background(spec: dict) -> Image.Image:
    img = field_gradient(spec).convert("RGBA")
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    draw_diaper(d, spec["metal"], spec["field2"])
    draw_side_flags(d, spec)
    draw_top_banner(d, spec, spec["banner"])
    draw_bottom_ribbon(d, spec)

    cx, cy = W // 2, int(H * 0.44)
    if spec["division"] == "round":
        pts = round_shield(cx, cy, 155)
    else:
        pts = heater_shield(cx, cy, 165, 195)

    draw_shield_body(d, pts, spec)
    draw_charge(d, spec["charge"], cx, cy, spec)
    draw_laurel(d, cx, cy + 10, 175, spec["accent"])

    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((cx - 190, cy - 170, cx + 190, cy + 170), fill=(*spec["glow"], 90))
    glow = glow.filter(ImageFilter.GaussianBlur(40))
    out = Image.alpha_composite(glow, img)
    out = Image.alpha_composite(out, layer)

    # light vignette
    vig = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    vd = ImageDraw.Draw(vig)
    vd.ellipse((-60, -40, W + 60, H + 40), fill=(0, 0, 0, 28))
    vig = vig.filter(ImageFilter.GaussianBlur(45))
    out = Image.alpha_composite(out, vig)
    return out.convert("RGB")


def preview_sheet(images: dict[str, Image.Image], title: str) -> Image.Image:
    pad = 14
    cols = 4
    rows = (len(images) + cols - 1) // cols
    cell_w, cell_h = W + pad, H + pad + 22
    sheet = Image.new("RGB", (cols * cell_w + pad, rows * cell_h + pad + 28), (12, 14, 20))
    d = ImageDraw.Draw(sheet)
    d.text((pad, 6), title, fill=(255, 210, 130))
    for i, (fid, img) in enumerate(images.items()):
        c, r = i % cols, i // cols
        ox = pad + c * cell_w
        oy = pad + 26 + r * cell_h
        sheet.paste(img, (ox, oy))
        d.text((ox + 4, oy + H + 4), FACTIONS[fid]["name"], fill=(220, 225, 235))
    return sheet


def mockup_cards(frames: dict[str, Image.Image]) -> Image.Image:
    pad = 12
    cols, rows = 4, 2
    sheet = Image.new("RGBA", (cols * (W + pad) + pad, rows * (H + pad) + pad), (14, 18, 28, 255))
    unit = frame = None
    if UNIT_SAMPLE.is_file():
        unit = Image.open(UNIT_SAMPLE).convert("RGBA")
        unit.thumbnail((340, 340), Image.Resampling.LANCZOS)
    if FRAME_SAMPLE.is_file():
        frame = Image.open(FRAME_SAMPLE).convert("RGBA")
    for i, fid in enumerate(frames.keys()):
        c, r = i % cols, i // cols
        card = Image.new("RGBA", (W, H), (0, 0, 0, 255))
        card.paste(frames[fid].convert("RGBA"), (0, 0))
        if unit:
            card.alpha_composite(unit, ((W - unit.width) // 2, int(H * 0.18)))
        if frame:
            card.alpha_composite(frame, (0, 0))
        sheet.alpha_composite(card, (pad + c * (W + pad), pad + r * (H + pad)))
    return sheet


def compare_v2_v3(v2: dict[str, Image.Image], v3: dict[str, Image.Image]) -> Image.Image:
    pad, gap = 14, 10
    row_h = H + pad * 2 + 30
    sheet = Image.new("RGB", (W * 2 + pad * 3 + gap, row_h * len(v3) + pad), (10, 12, 18))
    d = ImageDraw.Draw(sheet)
    for i, fid in enumerate(v3.keys()):
        y = pad + i * row_h
        d.text((pad, y), FACTIONS[fid]["name"], fill=(200, 210, 225))
        if fid in v2:
            sheet.paste(v2[fid], (pad, y + 22))
            d.text((pad + 4, y + 22 + H + 4), "v2 几何", fill=(140, 180, 255))
        sheet.paste(v3[fid], (pad + W + gap, y + 22))
        d.text((pad + W + gap + 4, y + 22 + H + 4), "v3 纹章", fill=(255, 200, 120))
    return sheet


def load_v2() -> dict[str, Image.Image]:
    out: dict[str, Image.Image] = {}
    for fid in FACTIONS:
        name = "bg_neutral.png" if fid == "neutral" else f"bg_{fid}.png"
        p = V2_DIR / name
        if p.is_file():
            out[fid] = Image.open(p).convert("RGB")
    return out


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    built: dict[str, Image.Image] = {}
    for fid, spec in FACTIONS.items():
        img = build_background(spec)
        name = "bg_neutral.png" if fid == "neutral" else f"bg_{fid}.png"
        path = OUT_DIR / name
        img.save(path, optimize=True)
        built[fid] = img
        print(f"Wrote {path.relative_to(ROOT)} ({path.stat().st_size // 1024} KB)")

    root = OUT_DIR.parent
    preview_sheet(built, "Set v3 — 欧式纹章 / 旗帜底图").save(root / "_preview_factions_v3_heraldic.png")
    mockup_cards(built).save(root / "_mockup_factions_v3_heraldic.png")
    v2 = load_v2()
    if v2:
        compare_v2_v3(v2, built).save(root / "_compare_factions_v2_vs_v3.png")
    print(f"Wrote previews under {root}")


if __name__ == "__main__":
    main()
