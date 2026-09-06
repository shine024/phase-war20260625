#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""黑门底图部署（含台面高度校准）。

把 docs/黑门底图生成/ 的档位图校准后部署到 assets/backgrounds/bg_endless_gate_t{0,1,2}.png。

原理：战场代码以"图底=视口底(648)"锚定背景 → 台面顶屏幕落点 screen_y = 648 - d_pb，
其中 d_pb = 台面顶距图底距离。只有底部操作能移动台面：
  - d_pb < 276（台面偏低，单位悬空）：底部补虚空（台面升高到 372）
  - d_pb > 276（台面偏高）：底部裁切（台面下降到 372；切的是碎块/虚空区）
台面探测：先高斯模糊（抹掉星点/星云絮团/细裂缝），再找首个"连续 20 行亮度>75"的行。

用法：python deploy_endless_gate_tiers.py <src0> <src1> <src2>
"""
import sys, os
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "backgrounds")
TARGET_W = 1280
TARGET_D_PB = 276    # 台面顶→图底距离 → 台面顶 screen 372（行1脚位 384 上方 12px）
FACE_MIN, FACE_MAX = 356, 398
NEED_X = [80, 140, 180, 310, 480, 520, 800, 840, 975, 1120, 1150, 1190]
REF_X = [310, 520, 840, 1120]
EDGE_X = (80, 1190)


def _gray_blur(im):
    return im.convert("L").filter(ImageFilter.GaussianBlur(6))


def rock_top(gb, W, H, x):
    px = gb.load()
    for y0 in range(int(H * 0.30), H - 30):
        if all(px[x, y0 + k] > 75 for k in range(0, 20, 2)):
            return y0
    return None


def measure(im):
    gb = _gray_blur(im)
    return gb, {x: rock_top(gb, im.size[0], im.size[1], x) for x in REF_X}


def calibrate(im):
    im = im.convert("RGB")
    if im.size[0] != TARGET_W:
        im = im.resize((TARGET_W, round(im.size[1] * TARGET_W / im.size[0])), Image.LANCZOS)
    W, H = im.size
    _, tops = measure(im)
    tops = [t for t in tops.values() if t is not None]
    if not tops:
        return im, None, "无台面读数"
    import statistics
    d_pb = int(H - statistics.median(tops))
    diff = TARGET_D_PB - d_pb
    if diff > 0:  # 台面偏低 → 底部补虚空，抬升台面
        strip = im.crop((0, H - 4, W, H)).resize((W, diff)).transpose(Image.FLIP_TOP_BOTTOM)
        canvas = Image.new("RGB", (W, H + diff))
        canvas.paste(im, (0, 0))
        canvas.paste(strip, (0, H))
        return canvas, d_pb, f"底部补虚空 {diff}px（台面抬升 {diff}px）"
    if diff < 0:  # 台面偏高 → 底部裁切，台面下降
        cut = min(-diff, H // 6)
        return im.crop((0, 0, W, H - cut)), d_pb, f"底部裁切 {cut}px（台面下降 {-diff}px）"
    return im, d_pb, "无需校准"


def verify(im, tag):
    W, H = im.size
    gb = _gray_blur(im)
    tops = {}
    for x in NEED_X:
        t = rock_top(gb, W, H, min(x, W - 1))
        tops[x] = None if t is None else t - (H - 648)
    bad = {x: v for x, v in tops.items()
           if v is None or not (FACE_MIN <= v <= FACE_MAX)}
    interior_bad = {x: v for x, v in bad.items() if x not in EDGE_X}
    print(f"  [{tag}] 台面顶(screen):", {x: (v if v is not None else -1) for x, v in sorted(tops.items())})
    print(f"  [{'t?'[0:0] or ''}{tag}] 出界列: {dict(sorted(bad.items())) or '无 ✓'}"
          + ("" if not interior_bad else f"  ⚠ 含槽位列: {dict(sorted(interior_bad.items()))}"))
    return not interior_bad


def main():
    srcs = sys.argv[1:4]
    if not srcs:
        print(__doc__)
        sys.exit(2)
    all_ok = True
    for tier, src in enumerate(srcs):
        p = os.path.join(ROOT, src)
        im = Image.open(p)
        cal, d_pb, msg = calibrate(im)
        out = os.path.join(OUT_DIR, "bg_endless_gate_t%d.png" % tier)
        cal.save(out, optimize=True)
        print(f"t{tier} <- {os.path.basename(src)}  (原 d_pb={d_pb}, {msg}) -> {out}  {cal.size}")
        all_ok &= verify(cal, "t%d" % tier)
    print("全部槽位列校准通过" if all_ok else "⚠ 存在槽位列未通过，需人工复查")


if __name__ == "__main__":
    main()
