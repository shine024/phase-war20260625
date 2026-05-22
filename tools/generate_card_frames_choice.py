#!/usr/bin/env python3
"""Generate card-frame sets (5:8) — bold + ornate procedural options."""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
CHOICE_ROOT = ROOT / "assets" / "cards" / "frames_choice"
UNIT_SAMPLE = ROOT / "assets" / "card_icons" / "units" / "vis_player_002.png"

W, H = 500, 800
CORNER_R = 48

# Align with game_constants.gd get_rarity_color (RGB 0-255)
RARITIES: dict[str, dict] = {
    "common": {
        "rgb": (191, 191, 191),
        "hi": (245, 245, 250),
        "lo": (70, 74, 82),
        "tier": 0,
    },
    "uncommon": {
        "rgb": (102, 230, 128),
        "hi": (180, 255, 200),
        "lo": (20, 110, 45),
        "tier": 1,
    },
    "rare": {
        "rgb": (102, 166, 255),
        "hi": (190, 225, 255),
        "lo": (20, 60, 160),
        "tier": 2,
    },
    "epic": {
        "rgb": (191, 102, 255),
        "hi": (235, 190, 255),
        "lo": (80, 25, 140),
        "tier": 3,
    },
    "legendary": {
        "rgb": (255, 179, 77),
        "hi": (255, 240, 180),
        "lo": (160, 80, 10),
        "tier": 4,
    },
}


def _rounded_mask(size: tuple[int, int], rect: tuple[int, int, int, int], radius: int) -> Image.Image:
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle(rect, radius=radius, fill=255)
    return m


def border_mask(thickness: int) -> Image.Image:
    outer = _rounded_mask((W, H), (0, 0, W - 1, H - 1), CORNER_R)
    ir = max(CORNER_R - thickness, 4)
    inner = _rounded_mask(
        (W, H),
        (thickness, thickness, W - thickness - 1, H - thickness - 1),
        ir,
    )
    return ImageChops.subtract(outer, inner)


def inner_rim_mask(border_th: int, inset_from_art_edge: int, line_w: int) -> Image.Image:
    """在边框带内侧缘描线（inset 从立绘孔内缘向边框方向量，不进入透明区）。"""
    outer = border_mask(max(border_th - inset_from_art_edge, 4))
    inner = border_mask(max(border_th - inset_from_art_edge - line_w, 2))
    return ImageChops.subtract(outer, inner)


def composite_border_only(base: Image.Image, border_th: int, draw_fn) -> None:
    """装饰只落在边框环内，不进入中央透明立绘区。"""
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw_fn(layer)
    bm = border_mask(border_th)
    _r, _g, _b, a = layer.split()
    layer.putalpha(ImageChops.multiply(a, bm))
    base.alpha_composite(layer)


def tint(mask: Image.Image, rgba: tuple[int, int, int, int]) -> Image.Image:
    layer = Image.new("RGBA", mask.size, rgba)
    return Image.composite(layer, Image.new("RGBA", mask.size, (0, 0, 0, 0)), mask)


def art_hole_mask(border_th: int) -> Image.Image:
    ir = max(CORNER_R - border_th, 4)
    return _rounded_mask(
        (W, H),
        (border_th, border_th, W - border_th - 1, H - border_th - 1),
        ir,
    )


def clip_art_hole(img: Image.Image, border_th: int) -> Image.Image:
    """立绘孔内完全透明（去掉光晕/装饰渗进中央）。"""
    hole = art_hole_mask(border_th)
    _r, _g, _b, a = img.split()
    img.putalpha(ImageChops.multiply(a, ImageChops.invert(hole)))
    return img


def add_glow(base: Image.Image, mask: Image.Image, rgb: tuple[int, int, int], spread: int, alpha: int, *, border_th: int = 0) -> Image.Image:
    if spread <= 0 or alpha <= 0:
        return base
    g = tint(mask, (*rgb, alpha))
    g = g.filter(ImageFilter.GaussianBlur(spread))
    if border_th > 0:
        g = clip_art_hole(g, border_th)
    out = Image.new("RGBA", base.size, (0, 0, 0, 0))
    out.alpha_composite(g)
    out.alpha_composite(base)
    return out


def draw_corner_ticks(img: Image.Image, th: int, rgb: tuple[int, int, int], arm: int, width: int) -> None:
    d = ImageDraw.Draw(img)
    pad = th + 4
    hi = tuple(min(255, c + 80) for c in rgb)
    for ox, oy, fx, fy in (
        (pad, pad, 1, 1),
        (W - pad, pad, -1, 1),
        (pad, H - pad, 1, -1),
        (W - pad, H - pad, -1, -1),
    ):
        d.line([(ox, oy), (ox + fx * arm, oy)], fill=(*hi, 255), width=width)
        d.line([(ox, oy), (ox, oy + fy * arm)], fill=(*hi, 255), width=width)
        d.line([(ox + fx * 8, oy + fy * 8), (ox + fx * arm, oy + fy * 8)], fill=(*rgb, 200), width=max(1, width - 1))


def draw_neon_segments(img: Image.Image, th: int, rgb: tuple[int, int, int], tier: int) -> None:
    """Set A: horizontal neon dashes on top/bottom inner edge."""
    d = ImageDraw.Draw(img)
    y_top = th + 10
    y_bot = H - th - 12
    seg = 14 + tier * 4
    gap = 8
    col = (*tuple(min(255, c + 60) for c in rgb), 180 + tier * 20)
    x = th + 24
    while x < W - th - 40:
        for y in (y_top, y_bot):
            d.line([(x, y), (x + seg, y)], fill=col, width=2)
        x += seg + gap


def draw_bold_gems(img: Image.Image, th: int, rgb: tuple[int, int, int], tier: int) -> None:
    d = ImageDraw.Draw(img)
    sz = 14 + tier * 5
    pad = th + 8
    hi = tuple(min(255, c + 100) for c in rgb)
    for cx, cy in (
        (pad + sz // 2, pad + sz // 2),
        (W - pad - sz // 2, pad + sz // 2),
        (pad + sz // 2, H - pad - sz // 2),
        (W - pad - sz // 2, H - pad - sz // 2),
    ):
        d.ellipse((cx - sz // 2, cy - sz // 2, cx + sz // 2, cy + sz // 2), fill=(*rgb, 240), outline=(*hi, 255), width=2)
        d.ellipse((cx - 3, cy - 3, cx + 3, cy + 3), fill=(255, 255, 255, 220))


def draw_crown_bar(img: Image.Image, th: int, rgb: tuple[int, int, int]) -> None:
    d = ImageDraw.Draw(img)
    cx, y = W // 2, th + 2
    hi = tuple(min(255, c + 90) for c in rgb)
    pts = [
        (cx - 40, y + 20),
        (cx - 24, y + 4),
        (cx - 8, y + 18),
        (cx, y),
        (cx + 8, y + 18),
        (cx + 24, y + 4),
        (cx + 40, y + 20),
    ]
    d.polygon(pts, fill=(*rgb, 230), outline=(*hi, 255))
    d.rectangle((cx - 38, y + 18, cx + 38, y + 26), fill=(*rgb, 200))


def _lerp_rgb(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def _metallic_gradient(size: tuple[int, int], lo: tuple[int, int, int], mid: tuple[int, int, int], hi: tuple[int, int, int]) -> Image.Image:
    w, h = size
    img = Image.new("RGB", (w, h))
    px = img.load()
    wm, hm = max(w - 1, 1), max(h - 1, 1)
    for y in range(h):
        ty = y / hm
        for x in range(w):
            tx = x / wm
            t = max(0.0, min(1.0, 0.42 * tx + 0.38 * (1.0 - ty) + 0.2 * ty))
            px[x, y] = _lerp_rgb(lo, mid, t * 2.0) if t < 0.5 else _lerp_rgb(mid, hi, (t - 0.5) * 2.0)
    return img


def gradient_border_layer(mask: Image.Image, lo: tuple[int, int, int], mid: tuple[int, int, int], hi: tuple[int, int, int]) -> Image.Image:
    grad = _metallic_gradient(mask.size, lo, mid, hi).convert("RGBA")
    grad.putalpha(mask)
    return grad


def draw_circuit_traces(img: Image.Image, th: int, rgb: tuple[int, int, int], tier: int) -> None:
    d = ImageDraw.Draw(img)
    pad = th + 6
    col = (*tuple(min(255, int(c * 1.05)) for c in rgb), 80 + tier * 30)
    hi = (*tuple(min(255, c + 50) for c in rgb), 140 + tier * 25)
    for side_x in (pad + 2, W - pad - 6):
        for seg in range(4 + tier * 2):
            y0 = pad + 36 + seg * int((H - pad * 2 - 72) / (5 + tier))
            y1 = y0 + 14 + tier * 2
            d.line([(side_x, y0), (side_x, y1)], fill=col, width=1)
            d.line([(side_x + 2, y0 + 3), (side_x + 12, y0 + 3)], fill=hi, width=1)
    for y_line in (pad + 10, H - pad - 12):
        x = pad + 24
        while x < W - pad - 36:
            ln = 10 + tier * 4
            d.line([(x, y_line), (x + ln, y_line)], fill=col, width=1)
            d.ellipse((x + ln - 2, y_line - 2, x + ln + 2, y_line + 2), fill=hi)
            x += 16 + tier * 3


def draw_hex_lattice_sides(img: Image.Image, th: int, rgb: tuple[int, int, int], tier: int) -> None:
    """六边形纹仅画在左右边框竖条内，不进入立绘区。"""
    d = ImageDraw.Draw(img)
    for col_x in (th // 2 + 2, W - th // 2 - 2):
        y = th + 20
        while y < H - th - 30:
            for dy in (0, 14):
                hy = y + dy
                pts = []
                for i in range(6):
                    ang = math.pi / 3 * i - math.pi / 6
                    pts.append((col_x + 6 * math.cos(ang), hy + 6 * math.sin(ang)))
                d.polygon(pts, outline=(*rgb, 100 + tier * 20), fill=(*rgb, 25 + tier * 10))
            y += 22 + tier * 2


def draw_corner_brackets(img: Image.Image, th: int, rgb: tuple[int, int, int], tier: int) -> None:
    d = ImageDraw.Draw(img)
    pad = th + 2
    arm = 26 + tier * 10
    lw = 2 + tier // 2
    hi = tuple(min(255, c + 80) for c in rgb)
    for ox, oy, fx, fy in ((pad, pad, 1, 1), (W - pad, pad, -1, 1), (pad, H - pad, 1, -1), (W - pad, H - pad, -1, -1)):
        d.line([(ox, oy), (ox + fx * arm, oy)], fill=(*hi, 240), width=lw)
        d.line([(ox, oy), (ox, oy + fy * arm)], fill=(*hi, 240), width=lw)
        if tier >= 1:
            d.polygon(
                [
                    (ox + fx * (arm - 6), oy + fy * 4),
                    (ox + fx * (arm + 4), oy),
                    (ox + fx * (arm - 6), oy - fy * 4),
                ],
                fill=(*rgb, 200),
            )


def draw_wing_filigree(img: Image.Image, th: int, rgb: tuple[int, int, int]) -> None:
    d = ImageDraw.Draw(img)
    pad = th + 4
    wing = 48
    hi = tuple(min(255, c + 90) for c in rgb)
    gold = (255, 225, 140)

    def wing_one(ox: int, oy: int, fx: int, fy: int) -> None:
        pts = [
            (ox, oy),
            (ox + fx * wing, oy + fy * 8),
            (ox + fx * (wing - 10), oy + fy * 24),
            (ox + fx * (wing - 22), oy + fy * 34),
            (ox + fx * 12, oy + fy * 20),
            (ox + fx * 4, oy + fy * 10),
        ]
        d.polygon(pts, fill=(*rgb, 200), outline=(*hi, 255))
        d.line([(ox + fx * 6, oy + fy * 6), (ox + fx * (wing - 8), oy + fy * 12)], fill=(*gold, 210), width=2)

    wing_one(pad, pad, 1, 1)
    wing_one(W - pad, pad, -1, 1)
    wing_one(pad, H - pad, 1, -1)
    wing_one(W - pad, H - pad, -1, -1)


def draw_border_rosettes(img: Image.Image, th: int, rgb: tuple[int, int, int], tier: int) -> None:
    """Mid-edge circular rosettes."""
    d = ImageDraw.Draw(img)
    hi = tuple(min(255, c + 70) for c in rgb)
    r = 5 + tier
    for cx, cy in (
        (W // 2, th + 14),
        (W // 2, H - th - 14),
        (th + 14, H // 2),
        (W - th - 14, H // 2),
    ):
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(*rgb, 220), outline=(*hi, 255), width=2)
        for k in range(6):
            ang = math.pi / 3 * k
            d.line(
                [(cx + math.cos(ang) * (r + 2), cy + math.sin(ang) * (r + 2)),
                 (cx + math.cos(ang) * (r + 6), cy + math.sin(ang) * (r + 6))],
                fill=(*hi, 180),
                width=1,
            )


def draw_sparkles(img: Image.Image, th: int, tier: int, seed: int) -> None:
    d = ImageDraw.Draw(img)
    mask = border_mask(th)
    data = mask.getdata()
    w = mask.size[0]
    pts = [(i % w, i // w) for i, v in enumerate(data) if v > 0]
    if not pts:
        return
    rng = random.Random(seed)
    n = 10 + tier * 12
    for _ in range(min(n, len(pts))):
        x, y = pts[rng.randrange(len(pts))]
        r = rng.randint(1, 3)
        a = rng.randint(120, 240)
        col = (255, 240, 180, a) if tier >= 4 else (210, 235, 255, a)
        d.ellipse((x - r, y - r, x + r, y + r), fill=col)
        if r >= 2:
            d.line([(x - r * 2, y), (x + r * 2, y)], fill=(*col[:3], a // 2), width=1)
            d.line([(x, y - r * 2), (x, y + r * 2)], fill=(*col[:3], a // 2), width=1)


def draw_triple_rim(img: Image.Image, th: int, rgb: tuple[int, int, int], hi: tuple[int, int, int]) -> None:
    # 仅一条内沿高光（贴在立绘孔边缘的边框内侧，不伸进透明区）
    m = inner_rim_mask(th, 2, 2)
    img.alpha_composite(tint(m, (*hi, 160)))


def build_set_c_luxe(rarity: str, spec: dict) -> Image.Image:
    """Set C — 华丽典藏：金属渐变 + 相位电路 + 六边形带 + 角翼/顶冠/星屑。"""
    rgb, hi, lo = spec["rgb"], spec["hi"], spec["lo"]
    tier = spec["tier"]
    th = 24 + tier * 5  # 24..44 px

    mask = border_mask(th)
    frame = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # 四层外晕（裁掉渗入立绘孔的部分）
    frame = add_glow(frame, mask, lo, spread=20 + tier * 6, alpha=100 + tier * 18, border_th=th)
    frame = add_glow(frame, mask, rgb, spread=14 + tier * 4, alpha=95 + tier * 22, border_th=th)
    frame = add_glow(frame, mask, hi, spread=8, alpha=55 + tier * 12, border_th=th)
    if tier >= 3:
        frame = add_glow(frame, mask, (255, 220, 140), spread=5, alpha=35 + tier * 8, border_th=th)

    outer = border_mask(th + 10)
    frame.alpha_composite(tint(ImageChops.subtract(outer, mask), (*tuple(max(0, c - 90) for c in lo), 210)))

    # 金属渐变主框 + 内层亮环
    mid_mask = border_mask(max(th - 6, 10))
    outer_ring = ImageChops.subtract(mask, mid_mask)
    frame.alpha_composite(gradient_border_layer(outer_ring, lo, rgb, hi))

    composite_border_only(frame, th, lambda lyr: draw_corner_brackets(lyr, th, rgb, tier))
    composite_border_only(frame, th, lambda lyr: draw_corner_ticks(lyr, th, hi, arm=min(22 + tier * 6, th - 4), width=2 + tier // 2))

    if tier >= 0:
        composite_border_only(frame, th, lambda lyr: draw_circuit_traces(lyr, th, rgb, tier))
        composite_border_only(frame, th, lambda lyr: draw_border_rosettes(lyr, th, rgb, tier))
    if tier >= 1:
        composite_border_only(frame, th, lambda lyr: draw_bold_gems(lyr, th, rgb, max(0, tier - 1)))
        composite_border_only(frame, th, lambda lyr: draw_neon_segments(lyr, th, rgb, tier))
    if tier >= 2:
        composite_border_only(frame, th, lambda lyr: draw_hex_lattice_sides(lyr, th, rgb, tier))
        composite_border_only(frame, th, lambda lyr: draw_bold_gems(lyr, th, rgb, tier))
    if tier >= 3:
        composite_border_only(frame, th, lambda lyr: draw_wing_filigree(lyr, th, rgb))
    if tier >= 4:
        composite_border_only(frame, th, lambda lyr: draw_crown_bar(lyr, th, rgb))
        yb = H - th - 20
        composite_border_only(frame, th, lambda lyr: ImageDraw.Draw(lyr).rectangle(
            (th + 24, yb, W - th - 24, yb + 10), fill=(*rgb, 200), outline=(*hi, 255)
        ))
        frame = add_glow(frame, mask, (255, 200, 80), spread=8, alpha=50, border_th=th)

    draw_sparkles(frame, th, tier, seed=hash(rarity) * 997 + tier)
    return clip_art_hole(frame, th)


def build_set_a_neon(rarity: str, spec: dict) -> Image.Image:
    """Set A — 霓虹粗框：厚边 + 强外发光 + 高对比内白线，小格也醒目。"""
    rgb, hi, lo = spec["rgb"], spec["hi"], spec["lo"]
    tier = spec["tier"]
    th = 18 + tier * 3

    mask = border_mask(th)
    frame = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    frame = add_glow(frame, mask, rgb, spread=14 + tier * 4, alpha=70 + tier * 18)
    frame = add_glow(frame, mask, hi, spread=8 + tier * 2, alpha=45 + tier * 12)
    outer_shell = border_mask(th + 6)
    frame.alpha_composite(tint(ImageChops.subtract(outer_shell, mask), (0, 0, 0, 160)))
    frame.alpha_composite(tint(mask, (*rgb, 255)))
    frame.alpha_composite(tint(inner_rim_mask(th, 4, 3), (*hi, 220)))
    frame.alpha_composite(tint(inner_rim_mask(th, 8, 2), (255, 255, 255, 120 + tier * 25)))
    draw_corner_ticks(frame, th, hi, arm=28 + tier * 6, width=3 + tier // 2)
    draw_neon_segments(frame, th, rgb, tier)
    if tier >= 3:
        draw_bold_gems(frame, th, rgb, tier)
    if tier >= 4:
        draw_crown_bar(frame, th, rgb)
        frame = add_glow(frame, mask, (255, 220, 120), spread=6, alpha=40)
    return frame


def build_set_b_heavy(rarity: str, spec: dict) -> Image.Image:
    """Set B — 重装镶边：更厚双层色带 + 角饰 + 强饱和渐变，偏 TCG 收藏感。"""
    rgb, hi, lo = spec["rgb"], spec["hi"], spec["lo"]
    tier = spec["tier"]
    th = 22 + tier * 4  # 22..38 px

    mask = border_mask(th)
    frame = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # 三层外晕
    frame = add_glow(frame, mask, lo, spread=18 + tier * 5, alpha=90 + tier * 15)
    frame = add_glow(frame, mask, rgb, spread=12 + tier * 3, alpha=85 + tier * 20)
    frame = add_glow(frame, mask, hi, spread=6, alpha=50 + tier * 10)

    # 外黑金/深 rim
    outer = border_mask(th + 8)
    outer_only = ImageChops.subtract(outer, mask)
    frame.alpha_composite(tint(outer_only, (*tuple(max(0, c - 100) for c in lo), 200)))

    # 渐变模拟：外 lo → 内 hi（分两段 composite）
    mid_mask = border_mask(max(th - 4, 8))
    inner_core = ImageChops.subtract(mask, mid_mask)
    mid_ring = ImageChops.subtract(mid_mask, border_mask(max(th - 10, 6)))
    frame.alpha_composite(tint(inner_core, (*rgb, 255)))
    frame.alpha_composite(tint(mid_ring, (*tuple(int((a + b) // 2) for a, b in zip(rgb, hi)), 255)))

    # 双内沿
    for inset, col, alpha in ((5, hi, 200), (12, (255, 255, 255), 100 + tier * 20)):
        rim = inner_rim_mask(th, inset, 2 + tier // 2)
        frame.alpha_composite(tint(rim, (*col[:3], alpha)))

    draw_corner_ticks(frame, th, hi, arm=36 + tier * 8, width=4 + tier // 2)

    # 稀有+：角宝石 + 顶冠
    if tier >= 2:
        draw_bold_gems(frame, th, rgb, tier - 1)
    if tier >= 3:
        # 侧边竖条装饰
        d = ImageDraw.Draw(frame)
        for sx in (th + 6, W - th - 10):
            for k in range(6 + tier):
                y0 = th + 50 + k * int((H - th * 2 - 100) / 7)
                d.rectangle((sx, y0, sx + 3, y0 + 10 + tier), fill=(*hi, 160))
    if tier >= 4:
        draw_crown_bar(frame, th, rgb)
        # 底部对称饰带
        d = ImageDraw.Draw(frame)
        yb = H - th - 18
        d.rectangle((th + 30, yb, W - th - 30, yb + 8), fill=(*rgb, 180), outline=(*hi, 255))

    return frame


def save_set(name: str, builder, out_dir: Path) -> dict[str, Image.Image]:
    out_dir.mkdir(parents=True, exist_ok=True)
    built: dict[str, Image.Image] = {}
    for rarity, spec in RARITIES.items():
        img = builder(rarity, spec)
        path = out_dir / f"{rarity}.png"
        img.save(path, optimize=True)
        built[rarity] = img
        print(f"  {path.relative_to(ROOT)} ({path.stat().st_size // 1024} KB)")
    return built


def preview_sheet(frames: dict[str, Image.Image], title: str, bg=(14, 18, 28, 255)) -> Image.Image:
    cols = len(frames)
    pad = 20
    label_h = 40
    cell_w = W + pad * 2
    cell_h = H + pad * 2 + label_h
    sheet = Image.new("RGBA", (cols * cell_w, cell_h + 50), bg)
    d = ImageDraw.Draw(sheet)
    d.text((pad, 8), title, fill=(120, 200, 255, 255))
    for i, (name, img) in enumerate(frames.items()):
        ox = i * cell_w + pad
        oy = pad + 42
        sheet.alpha_composite(img, (ox, oy))
        d.text((ox + 6, oy + H + 8), name, fill=(230, 235, 245, 255))
    return sheet


def mockup_with_unit(frames: dict[str, Image.Image], unit_path: Path) -> Image.Image:
    cols = len(frames)
    pad = 16
    bg = (18, 24, 38, 255)
    sheet = Image.new("RGBA", (cols * (W + pad) + pad, H + pad * 2), bg)
    unit = None
    if unit_path.is_file():
        unit = Image.open(unit_path).convert("RGBA")
        unit.thumbnail((340, 340), Image.Resampling.LANCZOS)
    for i, (r, frame) in enumerate(frames.items()):
        card = Image.new("RGBA", (W, H), (10, 14, 22, 255))
        if unit:
            card.alpha_composite(unit, ((W - unit.width) // 2, int(H * 0.20)))
        card.alpha_composite(frame, (0, 0))
        sheet.alpha_composite(card, (pad + i * (W + pad), pad))
    return sheet


def compare_ab(a: dict[str, Image.Image], b: dict[str, Image.Image]) -> Image.Image:
    """Each rarity: Set A | Set B side by side."""
    pad = 16
    gap = 12
    row_h = H + pad * 2 + 36
    sheet = Image.new("RGBA", (W * 2 + pad * 3 + gap, row_h * len(RARITIES) + pad), (12, 16, 26, 255))
    d = ImageDraw.Draw(sheet)
    for i, rarity in enumerate(RARITIES.keys()):
        y = pad + i * row_h
        d.text((pad, y - 2), rarity, fill=(200, 210, 230, 255))
        sheet.alpha_composite(a[rarity], (pad, y + 28))
        d.text((pad + 4, y + 28 + H + 4), "A 霓虹粗框", fill=(100, 180, 255, 255))
        xb = pad + W + gap
        sheet.alpha_composite(b[rarity], (xb, y + 28))
        d.text((xb + 4, y + 28 + H + 4), "B 重装镶边", fill=(255, 180, 100, 255))
    return sheet


def compare_bc(b: dict[str, Image.Image], c: dict[str, Image.Image]) -> Image.Image:
    pad = 16
    gap = 12
    row_h = H + pad * 2 + 36
    sheet = Image.new("RGBA", (W * 2 + pad * 3 + gap, row_h * len(RARITIES) + pad), (12, 16, 26, 255))
    d = ImageDraw.Draw(sheet)
    for i, rarity in enumerate(RARITIES.keys()):
        y = pad + i * row_h
        d.text((pad, y - 2), rarity, fill=(200, 210, 230, 255))
        sheet.alpha_composite(b[rarity], (pad, y + 28))
        d.text((pad + 4, y + 28 + H + 4), "B 重装镶边", fill=(255, 180, 100, 255))
        xb = pad + W + gap
        sheet.alpha_composite(c[rarity], (xb, y + 28))
        d.text((xb + 4, y + 28 + H + 4), "C 华丽典藏 ★推荐", fill=(180, 255, 160, 255))
    return sheet


def main() -> None:
    CHOICE_ROOT.mkdir(parents=True, exist_ok=True)
    dir_a = CHOICE_ROOT / "set_a_neon"
    dir_b = CHOICE_ROOT / "set_b_heavy"
    dir_c = CHOICE_ROOT / "set_c_luxe"

    print("=== Set A: Neon Bold ===")
    frames_a = save_set("a", build_set_a_neon, dir_a)
    print("=== Set B: Heavy Ornate ===")
    frames_b = save_set("b", build_set_b_heavy, dir_b)
    print("=== Set C: Luxe Baroque (华丽) ===")
    frames_c = save_set("c", build_set_c_luxe, dir_c)

    preview_a = preview_sheet(frames_a, "Set A — Neon Bold")
    preview_b = preview_sheet(frames_b, "Set B — Heavy Ornate")
    preview_c = preview_sheet(frames_c, "Set C — Luxe Baroque (metal + circuit + wings + sparkles)")
    preview_a.save(CHOICE_ROOT / "_preview_set_a_neon.png")
    preview_b.save(CHOICE_ROOT / "_preview_set_b_heavy.png")
    preview_c.save(CHOICE_ROOT / "_preview_set_c_luxe.png")
    print(f"Wrote {CHOICE_ROOT / '_preview_set_c_luxe.png'}")

    mock_c = mockup_with_unit(frames_c, UNIT_SAMPLE)
    mock_c.save(CHOICE_ROOT / "_mockup_set_c_luxe.png")
    print(f"Wrote {CHOICE_ROOT / '_mockup_set_c_luxe.png'}")

    cmp_bc = compare_bc(frames_b, frames_c)
    cmp_bc.save(CHOICE_ROOT / "_compare_b_vs_c.png")
    print(f"Wrote {CHOICE_ROOT / '_compare_b_vs_c.png'}")

    cmp_ab = compare_ab(frames_a, frames_b)
    cmp_ab.save(CHOICE_ROOT / "_compare_a_vs_b.png")

    readme = CHOICE_ROOT / "README.md"
    readme.write_text(
        """# 卡框候选（程序化生成）

| 目录 | 风格 | 特点 |
|------|------|------|
| `set_a_neon/` | A 霓虹粗框 | 小格最醒目 |
| `set_b_heavy/` | B 重装镶边 | 双层色带 + 角饰 |
| **`set_c_luxe/`** | **C 华丽典藏 ★** | 金属渐变 + 相位电路 + 六边形带 + 角翼/顶冠/星屑 |

## 预览

- **`_mockup_set_c_luxe.png`** — C 套叠单位（推荐先看）
- **`_compare_b_vs_c.png`** — B 与 C 同稀有度对照
- `_preview_set_c_luxe.png` — C 五稀有度纯框

## 重新生成

```powershell
python tools/generate_card_frames_choice.py
```

## 部署到游戏

```powershell
Copy-Item assets\\cards\\frames_choice\\set_c_luxe\\*.png assets\\cards\\frames\\ -Force
```

然后在 Godot 中对 `assets/cards/frames/` Reimport。
""",
        encoding="utf-8",
    )
    print(f"Wrote {readme}")


if __name__ == "__main__":
    main()
