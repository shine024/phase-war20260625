# -*- coding: utf-8 -*-
"""堡垒 attack 分帧目视拼图 + 帧边截断检测（用户报：某堡垒开火帧火光被切半）"""
import json, os
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")
OUT = os.path.join(ROOT, ".godot", "audit_sheets")
os.makedirs(OUT, exist_ok=True)

FORTS = ["cold_fort_missile", "cold_fort_radar", "fut_fort_ion", "fut_fort_shield",
         "mod_fort_citadel", "mod_fort_phalanx", "ww1_fort_artillery",
         "ww1_fort_pillbox", "ww2_fort_bunker", "ww2_fort_flak"]

CELL, COLS = 220, 6

def frame_bbox_stats(arr, fs, idx, H):
    sub = arr[:, idx*fs:(idx+1)*fs]
    a = sub[:, :, 3] > 40
    if not a.any():
        return None
    ys, xs = np.where(a)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    touches = []
    if x0 <= 1: touches.append("L")
    if x1 >= fs - 2: touches.append("R")
    if y0 <= 1: touches.append("T")
    if y1 >= H - 2: touches.append("B")
    return (x0, x1, y0, y1, touches)

items = []
report = {}
for d in FORTS:
    p = os.path.join(ANIM, d)
    meta = json.load(open(os.path.join(p, "anim.json"), encoding="utf-8"))
    fs = int(meta["frame_size"]); n_att = int(meta["counts"]["attack"])
    sp = os.path.join(p, "sheet_attack.png")
    im = Image.open(sp).convert("RGBA")
    arr = np.asarray(im)
    H = arr.shape[0]
    # idle 参考 bbox（首帧）
    idle = Image.open(os.path.join(p, "sheet_idle.png")).convert("RGBA")
    ia = np.asarray(idle)[:, :fs]
    m = ia[:, :, 3] > 40
    iy0, iy1 = (np.where(m.any(axis=1))[0][[0, -1]] if m.any() else (0, 0))
    idle_h = iy1 - iy0 + 1
    rep = {"sheet": f"{im.width}x{H}", "n": n_att, "idle_h": idle_h, "frames": []}
    for i in range(n_att):
        st = frame_bbox_stats(arr, fs, i, H)
        if st is None:
            rep["frames"].append({"i": i, "empty": True})
            items.append((Image.new("RGBA", (fs, fs), (0,0,0,0)), f"{d}#{i}", "EMPTY"))
            continue
        x0, x1, y0, y1, touches = st
        h = y1 - y0 + 1
        fl = ""
        if touches: fl = "EDGE:" + "".join(touches)
        if h < idle_h * 0.55: fl += " SMALL"
        if h > idle_h * 1.45: fl += " BIG"
        rep["frames"].append({"i": i, "bbox": [int(x0), int(y0), int(x1), int(y1)],
                              "h_ratio": round(float(h) / idle_h, 2), "edge": touches})
        items.append((im.crop((i*fs, 0, (i+1)*fs, H)), f"{d}#{i}", fl))
    report[d] = rep

# 拼图：每个格子上一行标签
per = COLS * 4
for s in range(0, len(items), per):
    chunk = items[s:s+per]
    rows = (len(chunk) + COLS - 1) // COLS
    cv = Image.new("RGB", (COLS * CELL, rows * (CELL + 20)), (24, 26, 30))
    dr = ImageDraw.Draw(cv)
    for i, (img, lb, fl) in enumerate(chunk):
        cx, cy = (i % COLS) * CELL, (i // COLS) * (CELL + 20)
        th = img.copy(); th.thumbnail((CELL - 6, CELL - 6))
        bg = Image.new("RGBA", (CELL, CELL), (60, 62, 68, 255))
        bg.paste(th, ((CELL - th.width)//2, (CELL - th.height)//2), th)
        cv.paste(bg.convert("RGB"), (cx, cy))
        dr.text((cx+4, cy+CELL+4), f"{lb} {fl}".strip()[:46],
                fill=(255,120,80) if fl else (200,200,200))
    op = os.path.join(OUT, f"fort_attack_{s//per+1:02d}.png")
    cv.save(op)
    print("made", op)

json.dump(report, open(os.path.join(OUT, "fort_attack_report.json"), "w", encoding="utf-8"),
          ensure_ascii=False, indent=1, default=int)
print("report -> .godot/audit_sheets/fort_attack_report.json")
