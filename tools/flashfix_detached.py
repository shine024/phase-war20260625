# -*- coding: utf-8 -*-
"""离群火光碎片修复（记录4·八轮）。

问题：攻击雪碧图中"与本体断开的亮色火光/弹头碎片"——两种形态：
  a) 贴左缘裁切（火光画出帧外只剩残条，77mm C 环同族）
  b) 半空悬浮（放错位的飞行弹/火光，ww1_enfield 弹头挂腰间）
判据：亮色连通域(≥10px)与本体的 2px 膨胀保护带不相交 = 离群碎片。
修复：BFS 沿非本体像素吞掉整个碎片（含灰暗弹体/描边）；在正确枪口位
（data/muzzle_anchors.gd 锚点优先，否则 idle 中上带左尖端）用碎片平均色
重画三层紧凑火光（中焰/白热核）。幂等：从 .godot/art_backup_flashfix2_20260927/ 备份重做。

用法：python tools/flashfix_detached.py tools/flashfix_units.json
      units.json = 单位名数组（来自 art_auto_inspect 的 edge_clip 扫描 +
      连通域断离判别，见 .godot/unit_review/flash_broken.json）
依赖：.godot/unit_review/gd_icon_map.json（tests/_tmp_dump_icon_map.gd 产物）
报告：.godot/unit_review/flashfix3_report.json
"""
import io
import json
import os
import re
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")
BAK = os.path.join(ROOT, ".godot", "art_backup_flashfix2_20260927")
GD = os.path.join(ROOT, ".godot", "unit_review", "gd_icon_map.json")
FS = 256


def load_mu():
    mu = {}
    src = io.open(os.path.join(ROOT, "data", "muzzle_anchors.gd"), encoding="utf-8")
    for line in src:
        m = re.match(r'\s*"([^"]+)":\s*\{"fireX":\s*([\d.]+),\s*"fireY_pct":\s*([\d.]+)\}', line)
        if m:
            mu[m.group(1)] = (float(m.group(2)), float(m.group(3)) / 100.0)
    return mu


def flood_components(fire):
    seen = np.zeros_like(fire, bool)
    comps = []
    for y0, x0 in zip(*np.where(fire)):
        if seen[y0, x0]:
            continue
        dq = deque([(y0, x0)])
        seen[y0, x0] = True
        px = []
        while dq:
            y, x = dq.popleft()
            px.append((y, x))
            for ny, nx in ((y-1,x),(y+1,x),(y,x-1),(y,x+1),(y-1,x-1),(y-1,x+1),(y+1,x-1),(y+1,x+1)):
                if 0 <= ny < fire.shape[0] and 0 <= nx < fire.shape[1] and fire[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    dq.append((ny, nx))
        comps.append(px)
    return comps


def bfs_eat(alpha, protected, seeds):
    h, w = alpha.shape
    seen = np.zeros((h, w), bool)
    eaten = []
    dq = deque()
    for y, x in seeds:
        if not protected[y, x] and alpha[y, x] > 10 and not seen[y, x]:
            seen[y, x] = True
            dq.append((y, x))
    while dq:
        y, x = dq.popleft()
        eaten.append((y, x))
        for ny, nx in ((y-1,x),(y+1,x),(y,x-1),(y,x+1),(y-1,x-1),(y-1,x+1),(y+1,x-1),(y+1,x+1)):
            if 0 <= ny < h and 0 <= nx < w and not seen[ny, nx] and alpha[ny, nx] > 10 and not protected[ny, nx]:
                seen[ny, nx] = True
                dq.append((ny, nx))
    return eaten


def main(units_file):
    units = json.load(open(units_file, encoding="utf-8"))
    mu = load_mu()
    gd = json.load(open(GD, encoding="utf-8"))
    arch_of_anim = {}
    for arch, v in gd.items():
        k = v.get("anim", "")
        if k:
            arch_of_anim.setdefault(k, []).append(arch)
    os.makedirs(BAK, exist_ok=True)
    report = {}
    for key in units:
        d = os.path.join(ANIM, key)
        sp = os.path.join(d, "sheet_attack.png")
        bakp = os.path.join(BAK, "sheet_attack_%s.png" % key)
        if not os.path.exists(bakp):
            import shutil
            shutil.copy2(sp, bakp)
        src = Image.open(bakp).convert("RGBA")
        arr = np.asarray(src).astype(np.int16).copy()
        idle = np.asarray(Image.open(os.path.join(d, "sheet_idle.png")).convert("RGBA")).astype(np.int16)[:, :FS, :4]
        body = idle[:, :, 3] > 12
        prot = body.copy()
        for _ in range(2):
            q = prot.copy()
            q[1:, :] |= prot[:-1, :]
            q[:-1, :] |= prot[1:, :]
            q[:, 1:] |= prot[:, :-1]
            q[:, :-1] |= prot[:, 1:]
            prot = q
        mp = None
        for arch in arch_of_anim.get(key, []):
            if arch in mu:
                fx, fy = mu[arch]
                mp = (int(fx * FS), int(fy * FS))
                break
        if mp is None:
            a = idle[:, :, 3]
            ys, xs = np.where(a > 12)
            band = (ys > ys.min() + (ys.max()-ys.min())*0.22) & (ys < ys.min() + (ys.max()-ys.min())*0.62)
            if band.any():
                txi = xs[band].argmin()
                mp = (int(xs[band][txi]), int(ys[band][txi]))
        n_atk = min(12, arr.shape[1] // FS)
        frames_fixed = []
        for i in range(n_atk):
            x0 = i * FS
            fr = arr[:, x0:(x0+FS)]
            r, g, b, al = fr[:,:,0], fr[:,:,1], fr[:,:,2], fr[:,:,3]
            fire = ((r>200)&(g>120)&(b<110)&(al>150)) | ((r>235)&(g>235)&(b>200)&(al>150))
            if not fire.any():
                continue
            seeds = []
            for px in flood_components(fire):
                if len(px) < 10:
                    continue
                touches = any(body[max(0,y-2):y+3, max(0,x-2):x+3].any() for y, x in px)
                if not touches:
                    seeds.extend(px)
            if not seeds:
                continue
            eaten = bfs_eat(fr[:,:,3], prot, seeds)
            frag_mean = None
            if eaten:
                cols = np.array([[r[y,x], g[y,x], b[y,x]] for y, x in eaten if r[y,x] > 120])
                if len(cols):
                    frag_mean = cols.mean(axis=0)
            for y, x in eaten:
                fr[y, x, 3] = 0
            if mp and eaten:
                cx, cy = mp
                rad = max(10, min(22, int((len(eaten) / 3.14) ** 0.5)))
                fm = frag_mean if frag_mean is not None else np.array([255, 200, 80])
                mid = tuple(int(c) for c in np.clip(fm * 0.85 + 50, 0, 255))
                sub = Image.fromarray(fr.astype(np.uint8)).convert("RGBA")
                dr = ImageDraw.Draw(sub)
                dr.ellipse([cx-rad*1.3, cy-rad*0.55, cx+rad*0.5, cy+rad*0.55], fill=(*mid, 235))
                dr.ellipse([cx-rad*0.55, cy-rad*0.26, cx+rad*0.2, cy+rad*0.26], fill=(255, 248, 225, 255))
                arr[:, x0:(x0+FS)] = np.asarray(sub).astype(np.int16)
            frames_fixed.append(i)
        Image.fromarray(arr.astype(np.uint8)).save(sp)
        report[key] = {"frames": frames_fixed, "muzzle": mp}
        print(key, "| 修复帧:", frames_fixed, "| 枪口:", mp)
    json.dump(report, open(os.path.join(ROOT, ".godot", "unit_review", "flashfix3_report.json"),
              "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print("DONE units=%d" % len(report))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, ".godot", "unit_review", "flash_broken.json"))
