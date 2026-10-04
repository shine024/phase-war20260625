# -*- coding: utf-8 -*-
"""朝向审计 v2：attack f0 vs idle f0 的 2D 掩码模板匹配（平移搜索取最优 IoU），
same vs mirror 谁 IoU 高谁赢；差距小=近贴（对称车体指标失明，需目验）。
1D 列质量法的教训：不可靠（mod_ranger 已证伪）。只读不改。"""
import os, io, sys, json
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import numpy as np
from PIL import Image

ROOT = r"D:\godotplay\godot fair duel\phase-war"
ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")
S = 128
R = 20
STEP = 2


def mask128(img):
    a = np.asarray(img.convert("RGBA"))
    m = (a[:, :, 3] > 40).astype(np.float32)
    im = Image.fromarray((m * 255).astype(np.uint8)).resize((S, S), Image.BILINEAR)
    v = np.asarray(im).astype(np.float32) / 255.0
    return v


def best_iou(a, b):
    """a,b: S×S masks; 平移 b ±R px 找最大 IoU。"""
    ya, xa = np.where(a > 0.5)
    yb, xb = np.where(b > 0.5)
    if len(ya) == 0 or len(yb) == 0:
        return 0.0
    best = 0.0
    for dy in range(-R, R + 1, STEP):
        for dx in range(-R, R + 1, STEP):
            oy = int(round(np.mean(yb))) + dy - int(round(np.mean(ya)))
            ox = int(round(np.mean(xb))) + dx - int(round(np.mean(xa)))
            bs = np.zeros_like(a)
            y0s, y1s = max(0, oy), min(S, S + oy)
            x0s, x1s = max(0, ox), min(S, S + ox)
            if y1s <= y0s or x1s <= x0s:
                continue
            bs[y0s:y1s, x0s:x1s] = b[y0s - oy:y1s - oy, x0s - ox:x1s - ox]
            inter = np.minimum(a, bs).sum()
            union = np.maximum(a, bs).sum()
            if union > 0:
                best = max(best, float(inter / union))
    return best


rows = []
for key in sorted(d for d in os.listdir(ANIM) if os.path.isdir(os.path.join(ANIM, d))):
    d = os.path.join(ANIM, key)
    pi_p, pa_p = os.path.join(d, "sheet_idle.png"), os.path.join(d, "sheet_attack.png")
    aj = os.path.join(d, "anim.json")
    if not (os.path.exists(pi_p) and os.path.exists(pa_p) and os.path.exists(aj)):
        continue
    fs = int(json.load(open(aj, encoding="utf-8")).get("frame_size", 256))
    idl = Image.open(pi_p); atk = Image.open(pa_p)
    if idl.width < fs or atk.width < fs:
        continue
    mi = mask128(idl.crop((0, 0, fs, fs)))
    ma = mask128(atk.crop((0, 0, fs, fs)))
    same = best_iou(mi, ma)
    mir = best_iou(mi, ma[:, ::-1])
    rows.append((key, same, mir))

rows.sort(key=lambda r: r[1] - r[2])
print("=== 镜像胜出（attack 疑似与 idle 反向）===")
n = 0
for k, s, m in rows:
    if m > s:
        print("  %-24s same=%.3f mirror=%.3f" % (k, s, m)); n += 1
print("共 %d" % n)
print("=== 近贴（|same-mirror|<0.04，对称体失明需目验）===")
n = 0
for k, s, m in rows:
    if m <= s and s - m < 0.04:
        print("  %-24s same=%.3f mirror=%.3f" % (k, s, m)); n += 1
print("共 %d" % n)
print("=== 明确同向 %d 家（same-mirror>=0.04）===" % sum(1 for k, s, m in rows if s - m >= 0.04))
