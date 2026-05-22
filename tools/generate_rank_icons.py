#!/usr/bin/env python3
"""生成 Phase War 军衔图标 PNG（128×128，透明底）。运行：python tools/generate_rank_icons.py"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "ui" / "ranks"
SIZE = 128
PAD = 14

# rank_id, 中文名, tier 0-4 (与 CardGridRankStrip 配色层级一致)
RANKS = [
    ("private", "列兵", 0),
    ("corporal", "下士", 0),
    ("sergeant", "中士", 0),
    ("second_lieutenant", "少尉", 1),
    ("first_lieutenant", "中尉", 1),
    ("captain", "上尉", 1),
    ("major", "少校", 2),
    ("lieutenant_colonel", "中校", 2),
    ("colonel", "上校", 2),
    ("brigadier", "少将", 3),
    ("major_general", "中将", 3),
    ("general", "上将", 3),
    ("marshal", "元帅", 4),
]

TIER_METAL = [
    (42, 46, 52),      # 士
    (48, 58, 72),      # 尉
    (58, 52, 36),      # 校
    (72, 48, 32),      # 将
    (88, 72, 28),      # 元帅
]
TIER_GOLD = [
    (168, 172, 178),
    (186, 198, 214),
    (220, 188, 88),
    (238, 178, 72),
    (255, 228, 120),
]


def _plate(draw: ImageDraw.ImageDraw, tier: int) -> None:
    metal = TIER_METAL[tier]
    gold = TIER_GOLD[tier]
    cx, cy = SIZE // 2, SIZE // 2
    r = SIZE // 2 - PAD
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(*metal, 255))
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(*gold, 255), width=3)
    draw.ellipse((cx - r + 6, cy - r + 6, cx - r + 18, cy - r + 18), fill=(*[min(255, c + 40) for c in gold], 90))


def _chevrons(draw: ImageDraw.ImageDraw, count: int, tier: int) -> None:
    gold = TIER_GOLD[tier]
    cx = SIZE // 2
    base_y = SIZE // 2 + 8
    w, h = 36, 14
    gap = 6
    for i in range(count):
        y = base_y - i * (h + gap)
        pts = [
            (cx - w // 2, y + h),
            (cx, y),
            (cx + w // 2, y + h),
        ]
        draw.polygon(pts, fill=(*gold, 255))
        draw.polygon(pts, outline=(20, 22, 26, 200))


def _bars(draw: ImageDraw.ImageDraw, count: int, tier: int) -> None:
    gold = TIER_GOLD[tier]
    cx = SIZE // 2
    bar_w, bar_h = 44, 8
    gap = 5
    total_h = count * bar_h + (count - 1) * gap
    y0 = SIZE // 2 - total_h // 2 + 4
    for i in range(count):
        y = y0 + i * (bar_h + gap)
        draw.rounded_rectangle(
            (cx - bar_w // 2, y, cx + bar_w // 2, y + bar_h),
            radius=2,
            fill=(*gold, 255),
            outline=(24, 28, 34, 220),
        )


def _stars(draw: ImageDraw.ImageDraw, count: int, tier: int, large: bool = False) -> None:
    gold = TIER_GOLD[tier]
    cx, cy = SIZE // 2, SIZE // 2 + (2 if large else 6)
    outer = 22 if large else 16
    inner = 9 if large else 6
    spacing = 30 if large else 22
    xs = [cx] if count == 1 else [cx - spacing * (count - 1) / 2 + i * spacing for i in range(count)]
    for x in xs:
        _star(draw, x, cy, outer, inner, gold)


def _star(draw: ImageDraw.ImageDraw, cx: float, cy: float, outer: float, inner: float, color) -> None:
    pts = []
    for i in range(10):
        ang = math.pi / 2 + i * math.pi / 5
        r = outer if i % 2 == 0 else inner
        pts.append((cx + math.cos(ang) * r, cy - math.sin(ang) * r))
    draw.polygon(pts, fill=(*color, 255), outline=(30, 26, 18, 200))


def _marshal_emblem(draw: ImageDraw.ImageDraw) -> None:
    gold = TIER_GOLD[4]
    cx, cy = SIZE // 2, SIZE // 2
    # 简化元帅标识：稻穗环 + 中心大星
    draw.ellipse((cx - 38, cy - 38, cx + 38, cy + 38), outline=(*gold, 255), width=4)
    _star(draw, cx, cy - 2, 26, 11, gold)
    for i in range(6):
        ang = i * math.pi / 3 - math.pi / 2
        sx = cx + math.cos(ang) * 30
        sy = cy + math.sin(ang) * 30
        _star(draw, sx, sy, 7, 3, gold)


def draw_rank(rank_id: str, tier: int) -> Image.Image:
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    _plate(draw, tier)
    if rank_id == "private":
        _star(draw, SIZE // 2, SIZE // 2 + 4, 10, 4, TIER_GOLD[tier])
    elif rank_id in ("corporal", "sergeant"):
        _chevrons(draw, 1 if rank_id == "corporal" else 2, tier)
    elif rank_id in ("second_lieutenant", "first_lieutenant", "captain"):
        n = {"second_lieutenant": 1, "first_lieutenant": 2, "captain": 3}[rank_id]
        _bars(draw, n, tier)
    elif rank_id in ("major", "lieutenant_colonel", "colonel"):
        n = {"major": 1, "lieutenant_colonel": 2, "colonel": 3}[rank_id]
        _stars(draw, n, tier, False)
    elif rank_id in ("brigadier", "major_general", "general"):
        n = {"brigadier": 1, "major_general": 2, "general": 3}[rank_id]
        _stars(draw, n, tier, True)
    elif rank_id == "marshal":
        _marshal_emblem(draw)
    return img


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for rank_id, _name, tier in RANKS:
        path = OUT_DIR / f"rank_{rank_id}.png"
        draw_rank(rank_id, tier).save(path)
        print("wrote", path)
    print(f"Done: {len(RANKS)} icons -> {OUT_DIR}")


if __name__ == "__main__":
    main()
