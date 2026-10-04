# -*- coding: utf-8 -*-
"""unit_anims 全库系统审计：A 完整性 / B 朝向(attack↔idle) / C 大小(帧内容↔卡图内容)。
B 用原始列质量相关（非累积！累积分布恒 +1/-1 无鉴别力，2026-10-03 教训）。
输出控制台清单；只读不改。"""
import os, io, sys, re, json
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import numpy as np
from PIL import Image

ROOT = r"D:\godotplay\godot fair duel\phase-war"
ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")

# 重做清单 88 家的卡图映射（key → 卡图文件名）
doc = open(os.path.join(ROOT, "docs", "img25_重做清单_20260929.md"), encoding="utf-8").read()
DOC88 = {m.group(2): os.path.splitext(os.path.basename(m.group(5)))[0]
         for m in re.finditer(r"^\|\s*(\d+)\s*\|\s*([a-z0-9_]+)\s*\|\s*([^|]+)\|\s*([^|]+)\|\s*([a-zA-Z_/0-9.]+\.png)\s*\|", doc, re.M)}

# CONTENT_BBOX（卡图内容占画布比例 [w,h]）从 card_foot_anchors.gd 解析
fa = open(os.path.join(ROOT, "data", "card_foot_anchors.gd"), encoding="utf-8").read()
mb = re.search(r"const CONTENT_BBOX: Dictionary = \{(.*?)\n\}", fa, re.S)
BBOX = {m.group(1): [float(m.group(2)), float(m.group(3))]
        for m in re.finditer(r'"([a-zA-Z0-9_]+)":\s*\[\s*([\d.]+),\s*([\d.]+)\s*\]', mb.group(1))}

# 直接同名卡图也认（player/enemy 两目录）
def direct_icon(key):
    for sub in ("player", "enemy"):
        p = os.path.join(ROOT, "assets", "card_icons", sub, key + ".png")
        if os.path.exists(p):
            return key
    return None


def cell(im, i, fs):
    return im.crop((i * fs, 0, (i + 1) * fs, fs))


def cmass(img):
    """非透明像素列质量 profile（原始，非累积）。"""
    a = np.asarray(img.convert("RGBA"))
    m = a[:, :, 3] > 40
    cols = m.sum(axis=0).astype(float)
    return cols if cols.sum() > 0 else None


def bbox_frac(img):
    a = np.asarray(img.convert("RGBA"))
    m = a[:, :, 3] > 40
    if not m.any():
        return None
    xs = np.where(m.any(axis=0))[0]
    return (xs.max() - xs.min() + 1) / img.width, m.any(axis=1).sum() / img.height


keys = sorted(d for d in os.listdir(ANIM) if os.path.isdir(os.path.join(ANIM, d)))
print("目录数 %d" % len(keys))
issues_A, issues_B, ties_B, issues_C, ok_C = [], [], [], [], 0
for key in keys:
    d = os.path.join(ANIM, key)
    aj = os.path.join(d, "anim.json")
    idl_p = os.path.join(d, "sheet_idle.png")
    atk_p = os.path.join(d, "sheet_attack.png")
    if not (os.path.exists(aj) and os.path.exists(idl_p)):
        issues_A.append("%s 缺 anim.json/sheet_idle" % key)
        continue
    meta = json.load(open(aj, encoding="utf-8"))
    fs = int(meta.get("frame_size", 256))
    cnt = meta.get("counts", {})
    idl = Image.open(idl_p)
    if idl.width < fs or idl.height < fs:
        issues_A.append("%s idle %dx%d < 帧%d" % (key, idl.width, idl.height, fs))
        continue
    if idl.width != int(cnt.get("idle", 0)) * fs:
        issues_A.append("%s idle 宽%d != counts.idle%d*%d" % (key, idl.width, int(cnt.get("idle", 0)), fs))
    if os.path.exists(atk_p):
        atk = Image.open(atk_p)
        if atk.width != int(cnt.get("attack", 0)) * fs:
            issues_A.append("%s attack 宽%d != counts.attack%d*%d" % (key, atk.width, int(cnt.get("attack", 0)), fs))
        # B 朝向
        pi, pa = cmass(cell(idl, 0, fs)), cmass(cell(atk, 0, fs))
        if pi is not None and pa is not None and len(pi) == len(pa):
            n = min(len(pi), len(pa))
            pi2 = np.interp(np.linspace(0, 1, 64), np.linspace(0, 1, n), pi)
            pa2 = np.interp(np.linspace(0, 1, 64), np.linspace(0, 1, n), pa)
            same = float(np.corrcoef(pi2, pa2)[0, 1])
            mir = float(np.corrcoef(pi2, pa2[::-1])[0, 1])
            if mir > same + 0.03:
                issues_B.append("%s attack镜像胜出 same=%.3f mirror=%.3f" % (key, same, mir))
            elif same - mir < 0.05:
                ties_B.append("%s 近贴 same=%.3f mirror=%.3f" % (key, same, mir))
        # C 大小（帧内容 vs 卡图内容，画布占比直比）
        name = DOC88.get(key) or direct_icon(key)
        bb_c = BBOX.get(name) if name else None
        bf = bbox_frac(cell(idl, 0, fs))
        if bb_c and bf and bb_c[0] > 0.02:
            ratio = bf[0] / bb_c[0]
            line = "%s 帧 content_w=%.2f 卡图=%.2f ratio=%.2f (卡=%s)" % (key, bf[0], bb_c[0], ratio, name)
            if abs(ratio - 1.0) > 0.25:
                issues_C.append(line)
            else:
                ok_C += 1
print("\n=== A 完整性 %d 项 ===" % len(issues_A))
for s in issues_A:
    print(" ", s)
print("\n=== B 朝向反向 %d 项 ===" % len(issues_B))
for s in issues_B:
    print(" ", s)
print("--- B 近贴(<0.05) 需目验 %d 项 ---" % len(ties_B))
for s in ties_B:
    print(" ", s)
print("\n=== C 大小偏差>25%% %d 项（可比 %d 正常） ===" % (len(issues_C), ok_C and ok_C or 0))
for s in issues_C:
    print(" ", s)
