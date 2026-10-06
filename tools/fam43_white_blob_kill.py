# -*- coding: utf-8 -*-
"""staged _512 卡亚阈值白块定点清除（2026-10-06 dive_bomber 白云案立档）。

病：模型在白底卡上画亮度 226-237 的灰白云雾——低于 flood_white_to_alpha(238) 阈值
逃逸，实色不透明故封闭口袋补刀（pockets_transparent 只看 α<16）也不触。
判真伪：近白连通域 ≥ --min-px 视为病块定点清除（本机深色涂装无白漆前提）；
机身白漆单位（浅灰白涂装）勿用本工具，会误杀。

用法:
  python tools/fam43_white_blob_kill.py <key> [--min-px 200]   # 清除+报告
  python tools/fam43_white_blob_kill.py <key> --check          # 只查不清
"""
import argparse
import os
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGE = os.path.join(ROOT, ".godot", "unit_review", "fam43_cards_redo")


def white_mask(a):
    return (a[..., 0] > 225) & (a[..., 1] > 225) & (a[..., 2] > 225) & (a[..., 3] > 60)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("key")
    ap.add_argument("--min-px", type=int, default=200)
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    p = os.path.join(STAGE, "%s_512.png" % args.key)
    a = np.asarray(Image.open(p).convert("RGBA")).copy()
    w = white_mask(a)
    lab, n = ndi.label(w)
    comps = []
    for i, sl in enumerate(ndi.find_objects(lab)):
        m = lab[sl] == i + 1
        if m.sum() >= args.min_px:
            comps.append((int(m.sum()), sl))
    print("[%s] 近白不透明总 px=%d，≥%dpx 病块 %d 个：%s"
          % (args.key, int(w.sum()), args.min_px, len(comps),
             [(c, (sl[1].start, sl[0].start, sl[1].stop - sl[1].start, sl[0].stop - sl[0].start))
              for c, sl in comps[:6]]))
    if args.check or not comps:
        return
    kill = np.zeros_like(w)
    for _c, sl in comps:
        kill[sl] |= lab[sl] == -1  # placeholder 不会命中
    # 重新按标签精确取块（上面 find_objects 的 sl 内可能混小块）
    kill = np.isin(lab, [i + 1 for i, sl in enumerate(ndi.find_objects(lab))
                         if (lab[sl] == i + 1).sum() >= args.min_px])
    a[..., 3][kill] = 0
    ring = kill.copy()
    for _ in range(2):  # 边缘咬蚀 2 圈（fam43_cards_stage.pockets_transparent 同款）
        grow = ndi.binary_dilation(ring) & ~ring & (a[..., 3] > 0)
        a[..., 3] = np.where(grow, np.maximum(a[..., 3] - 120, 0), a[..., 3])
        ring = grow
    Image.fromarray(a).save(p)
    b = np.asarray(Image.open(p).convert("RGBA")).astype(int)
    print("  清除 %d px → 残留近白 %d px（零星高光属正常）" % (int(kill.sum()), int(white_mask(b).sum())))


if __name__ == "__main__":
    main()
