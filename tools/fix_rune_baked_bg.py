# -*- coding: utf-8 -*-
"""符文图标烤底修复（v10.5）

问题：3 张符文 PNG 带烘焙死的深色方形底（非透明）：
  - assets/runes/common/rune_energy_03.png
  - assets/runes/common/rune_mobility_01.png
  - assets/runes/epic/rune_attack_06.png
其余 95 张为"圆形石体外透明"。游戏内 resource_slot_item 会按稀有度 modulate 图标，
烤底被染色后显形为深色方块（与改造图标同源缺陷）。

方案：径向方差检测圆盘边界 → 圆形羽化遮罩抠出石体 → 缩放到 995×995（与 91 张主流尺寸一致）。
不重生成：保留原画，保证与其余 95 张彩绘宝石风格 100% 一致。

用法：python tools/fix_rune_baked_bg.py            # 修复全部 3 张
      python tools/fix_rune_baked_bg.py --dry      # 只检测不写盘
"""
import math
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TARGETS = [
    "assets/runes/common/rune_energy_03.png",
    "assets/runes/common/rune_mobility_01.png",
    "assets/runes/epic/rune_attack_06.png",
]
OUT_SIZE = (995, 995)  # 与主流 91 张一致

VAR_THRESHOLD = 500.0  # 环带方差低于此值视为纯背景
FEATHER_PX = 6         # 遮罩羽化宽度（抗锯齿边）


def detect_disc_radius(im: Image.Image) -> int:
    """从中心向外的环带方差剖面：最后一个方差超阈值的环带半径即圆盘边界。"""
    rgb = im.convert("RGB")
    w, h = rgb.size
    cx, cy = w / 2.0, h / 2.0
    px = rgb.load()
    last_content_r = 0
    r = 8
    # 全程扫描取全局最后的内容半径：圆盘内部可能有安静环带（深色斜面），
    # 不能见到低方差带就提前停（attack_06 曾因此截到 r=292 丢失外环）。
    while r < int(min(cx, cy)) - 4:
        vals = []
        for ang in range(0, 360, 10):
            x = int(cx + r * math.cos(math.radians(ang)))
            y = int(cy + r * math.sin(math.radians(ang)))
            vals.append(sum(px[x, y]) / 3.0)
        avg = sum(vals) / len(vals)
        var = sum((v - avg) ** 2 for v in vals) / len(vals)
        if var > VAR_THRESHOLD:
            last_content_r = r
        r += 4
    return last_content_r


def circular_cutout(im: Image.Image, radius: int) -> Image.Image:
    w, h = im.size
    cx, cy = w / 2.0, h / 2.0
    mask = Image.new("L", (w, h), 0)
    mpx = mask.load()
    # 环带边缘用超采样抗锯齿：先在大 mask 上画硬圆再 FEATHER_PX 高斯羽化
    import PIL.ImageDraw as IDraw
    import PIL.ImageFilter as IFilter
    d = IDraw.Draw(mask)
    d.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=255)
    mask = mask.filter(IFilter.GaussianBlur(FEATHER_PX / 2.0))
    out = im.convert("RGBA")
    out.putalpha(mask)
    return out


def main() -> None:
    dry = "--dry" in sys.argv
    for rel in TARGETS:
        path = ROOT / rel
        im = Image.open(path)
        r = detect_disc_radius(im)
        w, h = im.size
        margin = r + FEATHER_PX
        cx, cy = w / 2.0, h / 2.0
        box = (int(cx - margin), int(cy - margin), int(cx + margin), int(cy + margin))
        cut = circular_cutout(im.crop(box), margin)
        final = cut.resize(OUT_SIZE, Image.LANCZOS)
        # 校验：四角全透明
        px = final.load()
        corners = [px[2, 2][3], px[OUT_SIZE[0] - 3, 2][3], px[2, OUT_SIZE[1] - 3][3], px[OUT_SIZE[0] - 3, OUT_SIZE[1] - 3][3]]
        ok = all(c < 10 for c in corners)
        print(f"{rel}: disc_r={r}/{int(min(w, h) / 2)} -> {OUT_SIZE[0]}x{OUT_SIZE[1]} corners_a={corners} {'OK' if ok else 'FAIL'}")
        if not dry and ok:
            final.save(path)
            print(f"  saved {path}")
    if dry:
        print("(dry run, nothing written)")


if __name__ == "__main__":
    main()
