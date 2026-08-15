# -*- coding: utf-8 -*-
"""符文图标小圆盘归一（v10.6）

问题：5 张 1024 批次的符文 PNG 圆盘只占画布 ~82%（其余 93 张贴边 100%），
在相位仪槽位/背包瓷砖里比同排符文小一圈：
  - assets/runes/common/rune_attack_03.png
  - assets/runes/common/rune_defense_01.png
  - assets/runes/epic/rune_attack_07.png
  - assets/runes/rare/rune_defense_05.png
  - assets/runes/rare/rune_mobility_03.png

方案：按 alpha 包围盒裁剪 → 放大到圆盘直径 ~98% 贴边（与主流 93 张一致，
留 1% 抗锯齿边）→ 统一 995×995。

用法：python tools/fix_rune_small_discs.py          # 执行
      python tools/fix_rune_small_discs.py --dry    # 只检测
"""
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TARGETS = [
    "assets/runes/common/rune_attack_03.png",
    "assets/runes/common/rune_defense_01.png",
    "assets/runes/epic/rune_attack_07.png",
    "assets/runes/rare/rune_defense_05.png",
    "assets/runes/rare/rune_mobility_03.png",
]
OUT_SIZE = (995, 995)
TARGET_FILL = 0.98  # 圆盘直径占画布比例（主流贴边 1.0，留 2% 安全边）


def main() -> None:
    dry = "--dry" in sys.argv
    for rel in TARGETS:
        path = ROOT / rel
        im = Image.open(path).convert("RGBA")
        bbox = im.split()[3].getbbox()
        if bbox is None:
            print(f"{rel}: 无内容，跳过")
            continue
        x0, y0, x1, y1 = bbox
        bw, bh = x1 - x0, y1 - y0
        side = max(bw, bh)
        # 以 bbox 中心为基准取正方形裁剪窗（扩到 side，含安全余量 2%）
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
        m = int(side * 0.51)
        box = (max(0, cx - m), max(0, cy - m), min(im.width, cx + m), min(im.height, cy + m))
        cut = im.crop(box)
        # 圆盘当前占裁剪窗比例 → 放大到 TARGET_FILL：直接把裁剪窗缩放到
        # OUT_SIZE * (裁剪窗直径 / 目标直径)。bbox 即圆盘直径（约），故缩放比 = 1/TARGET_FILL 的窗放大。
        scale_to = (int(OUT_SIZE[0] / TARGET_FILL), int(OUT_SIZE[1] / TARGET_FILL))
        big = cut.resize(scale_to, Image.LANCZOS)
        # 居中裁回 OUT_SIZE
        ox = (big.width - OUT_SIZE[0]) // 2
        oy = (big.height - OUT_SIZE[1]) // 2
        final = big.crop((ox, oy, ox + OUT_SIZE[0], oy + OUT_SIZE[1]))
        # 校验：四角透明 + 圆盘占比达标
        px = final.load()
        w, h = final.size
        corners = [px[2, 2][3], px[w - 3, 2][3], px[2, h - 3][3], px[w - 3, h - 3][3]]
        opaque = sum(final.split()[3].histogram()[200:])
        dia = (opaque / (w * h) / 0.7854) ** 0.5
        ok = all(c < 10 for c in corners) and dia > 0.9
        print(f"{rel}: bbox={side}px dia_before≈{side / max(im.width, im.height):.2f} -> dia_after≈{dia:.2f} corners_a={corners} {'OK' if ok else 'FAIL'}")
        if not dry and ok:
            final.save(path)
            print(f"  saved {path}")
    if dry:
        print("(dry run, nothing written)")


if __name__ == "__main__":
    main()
