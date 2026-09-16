#!/usr/bin/env python3
"""B6c（2026-09-15）：基地车剖面白边收缩（用户手工抠图版仍有白边）。
规则：紧贴透明区（4 邻域）的不透明/半透明近白像素（min rgb ≥ 235）→ alpha=0，
迭代 2 轮。只动边界环，不碰内部内容白（灯管/纸条/床单——它们不贴透明边）。
用法：--apply 落盘；默认 dry-run 出前后对比图。
"""
import os
import sys
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BAK = os.path.join(ROOT, "_art_backup")
PREVIEW = os.path.join(ROOT, "_anim_review", "b6_previews")
THRESH = 235
PASSES = 2


def defringe(path, apply):
    im = Image.open(path).convert("RGBA")
    a = np.array(im).astype(np.int16)
    al = a[..., 3]
    before_white = None
    removed_total = 0
    for it in range(PASSES):
        trans = al < 10
        opaque = al > 0
        bd = opaque & (np.roll(trans, 1, 0) | np.roll(trans, -1, 0) |
                       np.roll(trans, 1, 1) | np.roll(trans, -1, 1))
        whiteish = np.minimum(np.minimum(a[..., 0], a[..., 1]), a[..., 2]) >= THRESH
        kill = bd & whiteish
        if it == 0:
            before_white = int((opaque & whiteish & bd).sum()) + int(((al > 10) & (al <= 200) & whiteish & bd).sum())
        if not kill.any():
            break
        removed_total += int(kill.sum())
        al[kill] = 0
    a[..., 3] = al
    out = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
    name = os.path.basename(path)
    if apply:
        out.save(path)
    # 对比图：处理前 vs 处理后（深底）
    w, h = im.size
    scale = min(1.0, 560 / w)
    vis = Image.new("RGB", (int(w * scale) * 2 + 12, int(h * scale)), (40, 44, 52))
    for i, src in enumerate([im, out]):
        crop = src.resize((int(w * scale), int(h * scale)), Image.LANCZOS)
        bg = Image.new("RGBA", crop.size, (40, 44, 52, 255))
        bg.alpha_composite(crop)
        vis.paste(bg.convert("RGB"), (i * (int(w * scale) + 12), 0))
    os.makedirs(PREVIEW, exist_ok=True)
    vis.save(os.path.join(PREVIEW, ("applied_" if apply else "dry_") + name))
    print("%s: 白边移除 %d px%s" % (name, removed_total, "（已落盘）" if apply else "（dry）"))


if __name__ == "__main__":
    apply = "--apply" in sys.argv
    for n in range(1, 6):
        defringe(os.path.join(ROOT, "assets", "ui", "truck_base", "truck_cut%d.png" % n), apply)
