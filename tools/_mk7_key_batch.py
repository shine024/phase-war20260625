# -*- coding: utf-8 -*-
"""MK7 第一批：10 张黑盒攻击卷 V 空间钥匙化（MK6 配方）+ 若 needs 已透明则跳过。
V<4 → alpha 0；V 4-18 线性羽化。直方图校验打印（峰位/谷段/内容量）。
备份 .godot/art_backup_mk7_20261004/（if-not-exists，防 MK6 备份链冲掉教训重演）。
用法: python tools/_mk7_key_batch.py
"""
import io
import json
import os
import shutil
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UA = os.path.join(ROOT, "assets", "effects", "unit_anims")
BAK = os.path.join(ROOT, ".godot", "art_backup_mk7_20261004")
STG = os.path.join(ROOT, ".godot", "unit_review", "mk6_staging")
os.makedirs(BAK, exist_ok=True)
os.makedirs(STG, exist_ok=True)

UNITS = [
    "cold_arm_t55", "cold_t72", "cold_inf_btr60", "cold_sup_bmp1_x",
    "cold_sup_zsu23", "ww1_arm_rolls", "ww2_arty_hummel", "ww2_fort_flak",
    "mod_arm_himars", "guardian_ww1_ironclad",
]


def backup_once(unit, *files):
    d = os.path.join(BAK, unit)
    os.makedirs(d, exist_ok=True)
    for f in files:
        src = os.path.join(UA, unit, f)
        dst = os.path.join(d, f)
        if os.path.exists(src) and not os.path.exists(dst):
            shutil.copy2(src, dst)
            print("  [bak] %s/%s" % (unit, f))


def key_frame(arr):
    """黑盒帧 → 透明：V<4 全透，4-18 线性羽化。返回 (新arr, 统计)。"""
    hsv = np.asarray(Image.fromarray(arr[:, :, :3].astype(np.uint8)).convert("HSV")).astype(int)
    V = hsv[:, :, 2]
    alpha = arr[:, :, 3].astype(float)
    feather = np.clip((V.astype(float) - 4.0) / (18.0 - 4.0), 0, 1)
    na = alpha * feather
    out = arr.copy()
    out[:, :, 3] = na.astype(np.uint8)
    return out


def histogram_check(arr, tag):
    """键化后校验：暗峰应消失，内容量(V>=20 & a>40)应保留。"""
    hsv = np.asarray(Image.fromarray(arr[:, :, :3].astype(np.uint8)).convert("HSV")).astype(int)
    V = hsv[:, :, 2]
    H, W = V.shape
    lo = int(((V < 2) & (arr[:, :, 3] > 40)).sum())          # 残留近黑不透明
    content = int(((V >= 20) & (arr[:, :, 3] > 40)).sum())   # 有效内容
    frac = 100.0 * content / (H * W)
    print("  [%s] 近黑残留=%d  内容=%.1f%%" % (tag, lo, frac))
    return lo, frac


def main():
    units = sys.argv[1:] or UNITS
    for unit in units:
        sp = os.path.join(UA, unit, "sheet_attack.png")
        mp = os.path.join(UA, unit, "anim.json")
        if not os.path.exists(sp):
            print("[miss] %s" % unit)
            continue
        sh = Image.open(sp).convert("RGBA")
        a = np.asarray(sh)
        op = 100.0 * (a[:, :, 3] > 250).sum() / (a.shape[0] * a.shape[1])
        if op < 90:
            print("[skip] %s 已透明 (%.0f%%)" % (unit, op))
            continue
        backup_once(unit, "sheet_attack.png", "anim.json")
        meta = json.load(open(mp, encoding="utf-8")) if os.path.exists(mp) else {"counts": {"attack": sh.width // 256}, "frame_size": 256}
        n = int(meta.get("counts", {}).get("attack", sh.width // max(1, sh.height)))
        fs = sh.width // n
        frames = [a[:, i * fs:(i + 1) * fs].copy() for i in range(n)]
        out = []
        print("── %s (%d帧 %dpx, 原不透明%.0f%%)" % (unit, n, fs, op))
        ok = True
        for i, fr in enumerate(frames):
            nf = key_frame(fr)
            lo, frac = histogram_check(nf, "f%d" % i)
            if lo > fs * fs * 0.02 or frac < 3:   # 近黑残留>2% 或 内容<3% = 键化可疑
                ok = False
            out.append(Image.fromarray(nf))
        strip = Image.new("RGBA", (fs * n, fs), (0, 0, 0, 0))
        for i, f in enumerate(out):
            strip.paste(f, (i * fs, 0))
        strip.save(sp)
        json.dump(meta, open(mp, "w", encoding="utf-8"), ensure_ascii=False)
        # 预览（深底）
        g = Image.new("RGB", (min(n, 12) * fs, fs), (38, 42, 50))
        for i, f in enumerate(out[:12]):
            g.paste(f, (i * fs, 0), f)
        g.save(os.path.join(STG, "verify_%s_attack_keyed.png" % unit))
        print("  [save] n=%d %s" % (n, "OK" if ok else "可疑!需目验"))
    print("完成。下一步: 目验 verify_*_keyed.png → 火光手术")


if __name__ == "__main__":
    main()
