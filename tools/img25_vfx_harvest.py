# -*- coding: utf-8 -*-
"""img25 火光贴图收割：从生图终版雪碧图抠火光/焰心 → 独立 RGBA 贴图库，供 codeanim 后续复用。

来源 = 用户拍板采纳 route1（生图胜过程序焰）的单位终版 img25_approved/<key>_attack_sheet_832.png。
方法：对开火格 c2..c6 与待机格 c1 差分，取"暖色/白热 & 高亮"最大连通域为焰心，
连体烟/机身不入选；紧 bbox+8px 裁切，保留原像素与透明底。
产物 .godot/unit_review/img25_vfx/：
    <key>_c<i>.png   火光贴图（RGBA，透明底）
    _index.json      元数据（来源格/bbox/质心/面积/主色，muzzle 相对格坐标）
    _contact.png     全库目检拼图
codeanim 复用口径（后续批次接线）：compose_frame 焰段以
    Image.paste(flash_tex, muzzle-质心, flash_tex) 替代 draw_flash，
    质心 = 贴图内焰心，对齐 cfg["muzzle"] 即"贴枪口"。

用法： python -X utf8 tools/img25_vfx_harvest.py [--keys k1,k2]
"""
import colorsys
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from img25_route_apply import load_decisions

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, ".godot", "unit_review", "img25_approved")
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_vfx")
CELL = 832
PAD = 8


def warm_flash_mask(cell, idle):
    """暖色/白热且比待机格显著变亮的像素（火光核心，排除灰烟与机身）。"""
    a = cell[..., :3].astype(int)
    b = idle[..., :3].astype(int)
    bright = a.mean(axis=2)
    delta = np.abs(a - b).mean(axis=2)
    mx = a.max(axis=2).clip(1)
    mn = a.min(axis=2)
    sat = (mx - mn) / mx
    white = (bright > 200) & (sat < 0.25)
    warm = (a[..., 0] > a[..., 2] + 30) & (bright > 120)
    m = (white | warm) & (delta > 40) & (cell[..., 3] > 60)
    return m.astype(np.uint8)


def largest_blob(m):
    import cv2
    n, lab, stats, cent = cv2.connectedComponentsWithStats(m)
    if n <= 1:
        return None
    best = 1 + int(np.argmax(stats[1:, 4]))
    x, y, w, h, area = stats[best]
    if area < 120:
        return None
    return (x, y, w, h), cent[best], area


def harvest(key):
    p = os.path.join(APP, "%s_attack_sheet_832.png" % key)
    if not os.path.exists(p):
        return []
    im = np.asarray(Image.open(p).convert("RGBA"))
    idle = im[:CELL, :CELL]
    found = []
    for i in range(1, 6):
        r, c = divmod(i, 3)
        cell = im[r * CELL:(r + 1) * CELL, c * CELL:(c + 1) * CELL]
        m = warm_flash_mask(cell, idle)
        blob = largest_blob(m)
        if blob is None:
            continue
        (x, y, w, h), cent, area = blob
        x0, y0 = max(0, x - PAD), max(0, y - PAD)
        x1, y1 = min(CELL, x + w + PAD), min(CELL, y + h + PAD)
        crop = Image.fromarray(cell[y0:y1, x0:x1])
        out_p = os.path.join(OUT, "%s_c%d.png" % (key, i + 1))
        crop.save(out_p)
        px = cell[y:y + h, x:x + w]
        op = px[px[..., 3] > 100][:, :3] / 255.0
        if len(op):
            hh, ss, vv = [np.mean(v) for v in zip(*[colorsys.rgb_to_hsv(*q) for q in op[::17]])]
            dom = tuple(int(v * 255) for v in colorsys.hsv_to_rgb(hh, ss, vv))
        else:
            dom = (0, 0, 0)
        found.append(dict(key=key, cell=i + 1, png="%s_c%d.png" % (key, i + 1),
                          bbox=[int(x0), int(y0), int(x1 - x0), int(y1 - y0)],
                          centroid_in_tex=[round(float(cent[0] - x0), 1),
                                           round(float(cent[1] - y0), 1)],
                          area=int(area), dominant_rgb=list(dom)))
    return found


def main():
    os.makedirs(OUT, exist_ok=True)
    dec = load_decisions()
    keys = [k for k, v in dec.items() if v.get("sel") == "route1"]
    if "--keys" in sys.argv:
        sub = sys.argv[sys.argv.index("--keys") + 1].split(",")
        keys = [k for k in keys if k in sub]
    meta = []
    for k in keys:
        r = harvest(k)
        meta += r
        print("[%s] %d 个火光格: %s" % (k, len(r), [e["cell"] for e in r]) if r else "[%s] 未检出" % k)
    json.dump(meta, open(os.path.join(OUT, "_index.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    # 目检拼图
    from PIL import ImageDraw
    cols = 6
    rows = (len(meta) + cols - 1) // cols
    S = 208
    canvas = Image.new("RGB", (cols * (S + 6) + 6, rows * (S + 24) + 6), (40, 40, 44))
    d = ImageDraw.Draw(canvas)
    for n, e in enumerate(meta):
        tex = Image.open(os.path.join(OUT, e["png"]))
        tex.thumbnail((S, S), Image.LANCZOS)
        x, y = 6 + (n % cols) * (S + 6), 6 + (n // cols) * (S + 24)
        canvas.paste(tex, (x, y), tex)
        d.rectangle((x, y, x + tex.width, y + tex.height), outline=(90, 90, 90))
        d.text((x, y + S + 2), "%s c%d a%d" % (e["key"], e["cell"], e["area"]),
               fill=(255, 230, 120))
    canvas.save(os.path.join(OUT, "_contact.png"))
    print("=== 收割 %d 张火光贴图 -> %s ===" % (len(meta), OUT))


if __name__ == "__main__":
    main()
