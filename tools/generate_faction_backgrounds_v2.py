#!/usr/bin/env python3
"""Generate high-contrast faction card backgrounds (5:8) — preview set."""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "cards" / "backgrounds_choice" / "set_distinct_v2"
OLD_DIR = ROOT / "assets" / "cards" / "backgrounds"
UNIT_SAMPLE = ROOT / "assets" / "card_icons" / "units" / "vis_player_002.png"
FRAME_SAMPLE = ROOT / "assets" / "cards" / "frames" / "epic.png"

W, H = 500, 800


def _lift(c: tuple[int, int, int], n: int = 34) -> tuple[int, int, int]:
    return tuple(min(255, v + n) for v in c)


# base = mid-tone backdrop; accent/hi/glow = faction read at card scale
FACTIONS: dict[str, dict] = {
    "neutral": {
        "name": "中立",
        "base": _lift((42, 52, 72)),
        "accent": _lift((110, 130, 165), 18),
        "hi": (210, 225, 245),
        "glow": _lift((90, 120, 170), 22),
        "side": _lift((55, 70, 95)),
        "emblem": "hex",
    },
    "iron_wall_corp": {
        "name": "钢壁防务",
        "base": _lift((48, 54, 68)),
        "accent": _lift((150, 165, 190), 16),
        "hi": (235, 240, 250),
        "glow": _lift((120, 145, 185), 20),
        "side": _lift((70, 78, 95)),
        "emblem": "shield",
    },
    "nova_arms": {
        "name": "新星兵工",
        "base": _lift((58, 28, 22)),
        "accent": (255, 130, 60),
        "hi": (255, 210, 120),
        "glow": (255, 170, 80),
        "side": _lift((120, 45, 25)),
        "emblem": "flame",
    },
    "aether_dynamics": {
        "name": "以太动力",
        "base": _lift((18, 48, 58)),
        "accent": (55, 230, 210),
        "hi": (170, 255, 245),
        "glow": (90, 245, 225),
        "side": _lift((20, 90, 100)),
        "emblem": "turbine",
    },
    "quantum_logistics": {
        "name": "量子后勤",
        "base": _lift((34, 24, 58)),
        "accent": _lift((150, 90, 220), 20),
        "hi": (150, 235, 255),
        "glow": (200, 140, 255),
        "side": _lift((55, 35, 95)),
        "emblem": "network",
    },
    "helix_recon": {
        "name": "螺旋侦察",
        "base": _lift((18, 46, 32)),
        "accent": (90, 245, 150),
        "hi": (190, 255, 210),
        "glow": (130, 255, 170),
        "side": _lift((25, 85, 50)),
        "emblem": "helix",
    },
    "void_research": {
        "name": "虚空相位",
        "base": _lift((32, 18, 52)),
        "accent": _lift((170, 70, 240), 18),
        "hi": (250, 175, 255),
        "glow": (220, 120, 255),
        "side": _lift((55, 25, 85)),
        "emblem": "void_eye",
    },
    "frontier_union": {
        "name": "边境联合",
        "base": _lift((52, 40, 26)),
        "accent": (230, 170, 85),
        "hi": (255, 235, 160),
        "glow": (255, 200, 110),
        "side": _lift((95, 70, 35)),
        "emblem": "star_banner",
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


def rich_gradient(size: tuple[int, int], spec: dict) -> Image.Image:
    w, h = size
    img = Image.new("RGB", (w, h))
    px = img.load()
    base, accent, hi, side = spec["base"], spec["accent"], spec["hi"], spec["side"]
    for y in range(h):
        ty = y / max(h - 1, 1)
        for x in range(w):
            tx = x / max(w - 1, 1)
            # vertical lift + diagonal warmth
            t = max(0.0, min(1.0, 0.45 * (1.0 - ty) + 0.30 * tx + 0.25 * (1.0 - abs(tx - 0.5) * 2.0)))
            c = _lerp_rgb(base, accent, t * 0.88)
            # side color wash (left/right faction tint)
            edge = min(tx, 1.0 - tx) * 2.0
            if edge < 0.22:
                side_t = (0.22 - edge) / 0.22
                c = _lerp_rgb(c, side, side_t * 0.35)
            # top highlight band
            if ty < 0.16:
                c = _lerp_rgb(c, hi, (0.16 - ty) / 0.16 * 0.38)
            # center lift for art readability
            cx_dist = abs(tx - 0.5) * 2.0
            cy_dist = abs(ty - 0.40) * 2.2
            center_t = max(0.0, 1.0 - max(cx_dist, cy_dist))
            if center_t > 0:
                c = _lerp_rgb(c, hi, center_t * 0.12)
            px[x, y] = c
    return img


def soft_vignette(img: Image.Image, strength: float = 0.10) -> Image.Image:
    w, h = img.size
    out = img.convert("RGBA")
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse((-80, -60, w + 80, h + 60), fill=(0, 0, 0, int(255 * strength)))
    layer = layer.filter(ImageFilter.GaussianBlur(50))
    return Image.alpha_composite(out, layer).convert("RGB")


def center_glow(img: Image.Image, glow: tuple[int, int, int], alpha: int = 105) -> Image.Image:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = W // 2, int(H * 0.40)
    d.ellipse((cx - 200, cy - 160, cx + 200, cy + 160), fill=(*glow, alpha))
    layer = layer.filter(ImageFilter.GaussianBlur(36))
    out = img.convert("RGBA")
    out.alpha_composite(layer)
    return out.convert("RGB")


def draw_emblem(d: ImageDraw.ImageDraw, kind: str, accent: tuple[int, int, int], hi: tuple[int, int, int]) -> None:
    cx, cy = W // 2, int(H * 0.40)
    fill_a, line_a = 48, 105

    if kind == "hex":
        for row in range(-1, 4):
            for col in range(-1, 5):
                hx = cx + (col - 2) * 52 + (26 if row % 2 else 0)
                hy = cy + (row - 1) * 46
                pts = [(hx + 22 * math.cos(math.pi / 3 * i - math.pi / 6),
                        hy + 22 * math.sin(math.pi / 3 * i - math.pi / 6)) for i in range(6)]
                d.polygon(pts, outline=(*hi, line_a), fill=(*accent, fill_a))

    elif kind == "shield":
        d.polygon(
            [(cx, cy - 95), (cx + 72, cy - 28), (cx + 52, cy + 78), (cx, cy + 118), (cx - 52, cy + 78), (cx - 72, cy - 28)],
            outline=(*hi, line_a + 20),
            fill=(*accent, fill_a + 10),
        )
        for y in (cy - 50, cy - 20, cy + 10, cy + 40):
            d.line([(cx - 48, y), (cx + 48, y)], fill=(*hi, 55), width=2)

    elif kind == "flame":
        d.polygon(
            [(cx, cy - 100), (cx + 35, cy - 20), (cx + 55, cy + 40), (cx, cy + 90), (cx - 55, cy + 40), (cx - 35, cy - 20)],
            fill=(*accent, fill_a + 25),
            outline=(*hi, line_a),
        )
        d.line([(cx - 120, cy + 60), (W + 40, cy - 180)], fill=(*accent, 45), width=4)
        d.line([(cx - 80, cy + 100), (W, cy - 120)], fill=(*hi, 35), width=3)

    elif kind == "turbine":
        for r in (110, 82, 54, 28):
            d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(*hi, line_a - 20), width=3)
        for i in range(5):
            ang = i * 2 * math.pi / 5 - math.pi / 2
            x2 = cx + 118 * math.cos(ang)
            y2 = cy + 118 * math.sin(ang)
            d.line([(cx, cy), (x2, y2)], fill=(*accent, 70), width=4)
        d.ellipse((cx - 14, cy - 14, cx + 14, cy + 14), fill=(*hi, 120))

    elif kind == "network":
        box = (cx - 38, cy - 28, cx + 38, cy + 28)
        d.rectangle(box, outline=(*hi, line_a), fill=(*accent, fill_a), width=3)
        for ox, oy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
            x0 = cx + ox * 38
            y0 = cy + oy * 28
            x1 = cx + ox * 130
            y1 = cy + oy * 90
            d.line([(x0, y0), (x1, y1)], fill=(*hi, 60), width=2)
            d.ellipse((x1 - 5, y1 - 5, x1 + 5, y1 + 5), fill=(*accent, 100))

    elif kind == "helix":
        pts_l, pts_r = [], []
        for t in range(0, 360, 6):
            rad = math.radians(t)
            r = 18 + t * 0.28
            pts_l.append((cx - 16 + r * math.cos(rad), cy - 80 + t * 0.55 + r * math.sin(rad) * 0.3))
            pts_r.append((cx + 16 + r * math.cos(rad + math.pi), cy - 80 + t * 0.55 + r * math.sin(rad + math.pi) * 0.3))
        d.line(pts_l, fill=(*hi, 80), width=3)
        d.line(pts_r, fill=(*accent, 80), width=3)
        for rr in (70, 100, 130):
            d.arc((cx - rr, cy - rr, cx + rr, cy + rr), 200, 340, fill=(*hi, 50), width=2)

    elif kind == "void_eye":
        d.ellipse((cx - 55, cy - 38, cx + 55, cy + 38), fill=(48, 32, 72, 130), outline=(*hi, line_a + 10), width=3)
        d.ellipse((cx - 18, cy - 12, cx + 18, cy + 12), fill=(*hi, 160))
        for i in range(8):
            ang = i * math.pi / 4
            d.line([(cx + 60 * math.cos(ang), cy + 40 * math.sin(ang)),
                    (cx + 150 * math.cos(ang + 0.15), cy + 110 * math.sin(ang + 0.15))],
                   fill=(*accent, 55), width=2)

    elif kind == "star_banner":
        star = []
        for i in range(10):
            ang = -math.pi / 2 + i * math.pi / 5
            r = 70 if i % 2 == 0 else 32
            star.append((cx + r * math.cos(ang), cy - 20 + r * math.sin(ang)))
        d.polygon(star, fill=(*accent, fill_a + 15), outline=(*hi, line_a))
        d.polygon([(cx - 55, cy + 40), (cx + 55, cy + 40), (cx + 42, cy + 78), (cx - 42, cy + 78)],
                  fill=(*accent, fill_a), outline=(*hi, 70))


def draw_texture(d: ImageDraw.ImageDraw, kind: str, accent: tuple[int, int, int], hi: tuple[int, int, int]) -> None:
    if kind == "hex":
        step = 22
        for row in range(-2, H // step + 3):
            for col in range(-2, W // step + 3):
                cx = col * step + (step // 2 if row % 2 else 0)
                cy = row * int(step * 0.86)
                pts = [(cx + 9 * math.cos(math.pi / 3 * i), cy + 9 * math.sin(math.pi / 3 * i)) for i in range(6)]
                d.polygon(pts, outline=(*accent, 22))
    elif kind == "shield":
        y = 50
        while y < H - 40:
            d.line([(16, y), (W - 16, y)], fill=(*hi, 40), width=2)
            d.line([(24, y + 7), (W - 32, y + 7)], fill=(*accent, 25), width=1)
            y += 20
    elif kind == "flame":
        for i in range(9):
            x0 = -60 + i * 58
            d.line([(x0, H + 10), (x0 + 160, -20)], fill=(*accent, 35), width=3)
    elif kind == "turbine":
        for i in range(12):
            ang = i * math.pi / 6
            x1 = W // 2 + 160 * math.cos(ang)
            y1 = int(H * 0.4) + 160 * math.sin(ang)
            d.line([(W // 2, int(H * 0.4)), (x1, y1)], fill=(*accent, 18), width=1)
    elif kind == "network":
        for row in range(5):
            for col in range(4):
                x = 40 + col * 108 + (row % 2) * 24
                y = 70 + row * 92
                d.rectangle((x, y, x + 64, y + 44), outline=(*accent, 40), fill=(*accent, 16))
    elif kind == "helix":
        cx, cy = W // 2, int(H * 0.42)
        for turn in range(0, 480, 10):
            t = turn / 480.0
            ang = turn * 0.05
            r = 16 + t * 165
            x = cx + r * math.cos(ang)
            y = cy + r * math.sin(ang)
            d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=(*hi, int(35 + 70 * t)))
    elif kind == "void_eye":
        for i in range(14):
            ang = i * math.pi / 7
            x1 = W // 2 + 50 * math.cos(ang)
            y1 = int(H * 0.4) + 35 * math.sin(ang)
            x2 = W // 2 + 170 * math.cos(ang + 0.12)
            y2 = int(H * 0.4) + 120 * math.sin(ang + 0.12)
            d.line([(x1, y1), (x2, y2)], fill=(*accent, 30), width=1)
    elif kind == "star_banner":
        polys = [
            [(36, 130), (130, 95), (110, 210)],
            [(190, 85), (310, 115), (270, 230)],
            [(70, 310), (170, 270), (150, 430)],
            [(250, 350), (390, 310), (350, 520)],
        ]
        for pts in polys:
            d.polygon(pts, fill=(*accent, 22), outline=(*hi, 40))


def build_background(spec: dict) -> Image.Image:
    img = rich_gradient((W, H), spec)

    tex = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_texture(ImageDraw.Draw(tex), spec["emblem"], spec["accent"], spec["hi"])
    img = Image.alpha_composite(img.convert("RGBA"), tex).convert("RGB")

    emblem = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_emblem(ImageDraw.Draw(emblem), spec["emblem"], spec["accent"], spec["hi"])
    img = Image.alpha_composite(img.convert("RGBA"), emblem).convert("RGB")

    img = center_glow(img, spec["glow"], 105)
    img = soft_vignette(img, 0.10)

    d = ImageDraw.Draw(img)
    bar = _lerp_rgb(spec["base"], spec["hi"], 0.22)
    hi = spec["hi"]
    d.rectangle((0, 0, W - 1, 34), fill=bar)
    d.rectangle((0, 0, W - 1, 5), fill=hi)
    d.rectangle((0, H - 40, W - 1, H - 1), fill=bar)
    d.rectangle((0, H - 5, W - 1, H - 1), fill=hi)
    return img


def preview_sheet(images: dict[str, Image.Image], title: str) -> Image.Image:
    pad = 14
    cols = 4
    rows = (len(images) + cols - 1) // cols
    cell_w, cell_h = W + pad, H + pad + 22
    sheet = Image.new("RGB", (cols * cell_w + pad, rows * cell_h + pad + 28), (12, 14, 20))
    d = ImageDraw.Draw(sheet)
    d.text((pad, 6), title, fill=(130, 200, 255))
    for i, (fid, img) in enumerate(images.items()):
        c, r = i % cols, i // cols
        ox = pad + c * cell_w
        oy = pad + 26 + r * cell_h
        sheet.paste(img, (ox, oy))
        d.text((ox + 4, oy + H + 4), FACTIONS[fid]["name"], fill=(220, 225, 235))
    return sheet


def mockup_cards(frames: dict[str, Image.Image]) -> Image.Image:
    pad = 12
    cols = 4
    rows = 2
    sheet = Image.new("RGBA", (cols * (W + pad) + pad, rows * (H + pad) + pad), (14, 18, 28, 255))
    unit = None
    frame = None
    if UNIT_SAMPLE.is_file():
        unit = Image.open(UNIT_SAMPLE).convert("RGBA")
        unit.thumbnail((340, 340), Image.Resampling.LANCZOS)
    if FRAME_SAMPLE.is_file():
        frame = Image.open(FRAME_SAMPLE).convert("RGBA")
    keys = list(frames.keys())
    for i, fid in enumerate(keys):
        c, r = i % cols, i // cols
        card = Image.new("RGBA", (W, H), (0, 0, 0, 255))
        card.paste(frames[fid].convert("RGBA"), (0, 0))
        if unit:
            card.alpha_composite(unit, ((W - unit.width) // 2, int(H * 0.18)))
        if frame:
            card.alpha_composite(frame, (0, 0))
        sheet.alpha_composite(card, (pad + c * (W + pad), pad + r * (H + pad)))
    return sheet


def compare_old_new(new_imgs: dict[str, Image.Image]) -> Image.Image:
    pad = 14
    gap = 10
    row_h = H + pad * 2 + 30
    sheet = Image.new("RGB", (W * 2 + pad * 3 + gap, row_h * len(new_imgs) + pad), (10, 12, 18))
    d = ImageDraw.Draw(sheet)
    for i, fid in enumerate(new_imgs.keys()):
        y = pad + i * row_h
        label = FACTIONS[fid]["name"]
        d.text((pad, y), label, fill=(200, 210, 225))
        old_path = OLD_DIR / ("bg_neutral.png" if fid == "neutral" else f"bg_{fid}.png")
        if old_path.is_file():
            old = Image.open(old_path).convert("RGB")
            sheet.paste(old, (pad, y + 22))
            d.text((pad + 4, y + 22 + H + 4), "旧版", fill=(140, 150, 165))
        sheet.paste(new_imgs[fid], (pad + W + gap, y + 22))
        d.text((pad + W + gap + 4, y + 22 + H + 4), "新版 v2", fill=(120, 220, 140))
    return sheet


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

    prev = preview_sheet(built, "Set v2 — 高区分势力底图（提亮版）")
    prev.save(OUT_DIR.parent / "_preview_factions_v2.png")
    print(f"Wrote {OUT_DIR.parent / '_preview_factions_v2.png'}")

    mock = mockup_cards(built)
    mock.save(OUT_DIR.parent / "_mockup_factions_v2.png")
    print(f"Wrote {OUT_DIR.parent / '_mockup_factions_v2.png'}")

    cmp = compare_old_new(built)
    cmp.save(OUT_DIR.parent / "_compare_factions_old_vs_v2.png")
    print(f"Wrote {OUT_DIR.parent / '_compare_factions_old_vs_v2.png'}")


if __name__ == "__main__":
    main()
