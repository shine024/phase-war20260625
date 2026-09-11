#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v3 动画验收：规格检查 + 全帧条带图输出到 .godot/anim_review/。"""
import glob
import hashlib
import os
import sys

from PIL import Image

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
ROOT = r"F:\godot fair duet\create\phase-war"
OUT = os.path.join(ROOT, ".godot", "anim_review")
TARGET = {"idle": 8, "attack": 12}
UNITS = {
    "fut_inf_c96": "039_fut_inf_c96_毛瑟 C96 征召兵排",
    "ww1_arm_rolls": "041_ww1_arm_rolls_罗尔斯装甲车",
    "ww2_fort_flak": "077_ww2_fort_flak_88mm防空塔",
}

ok_all = True
for unit, d in UNITS.items():
    for anim, want in TARGET.items():
        sheet_path = os.path.join(ROOT, "资料", "单位分帧动画", d, anim, "sheet_%s.png" % anim)
        if not os.path.exists(sheet_path):
            print("[MISS] %s/%s 无 %s" % (unit, anim, sheet_path))
            ok_all = False
            continue
        im = Image.open(sheet_path).convert("RGBA")
        W, H = im.size
        fs = W // want
        n = H // fs * (W // fs)
        frames = [im.crop((i * fs, 0, (i + 1) * fs, fs)) for i in range(W // fs)]
        hashes = [hashlib.md5(f.tobytes()).hexdigest()[:6] for f in frames]
        distinct = len(set(hashes))
        tt = tb = 0
        hts = []
        for f in frames:
            bb = f.split()[3].getbbox()
            if bb is None:
                tt += 1; tb += 1; hts.append(0); continue
            if bb[1] <= 3: tt += 1
            if bb[3] >= fs - 4: tb += 1
            hts.append((bb[3] - bb[1]) / fs)
        drift = (max(hts) - min(hts)) if hts else 0
        status = "OK" if (len(frames) == want and distinct == want and tt == 0 and tb == 0) else "CHECK"
        if status != "OK":
            ok_all = False
        print("[%s] %s/%s %dx%d 帧%d/%d 去重%d 贴顶%d 贴底%d 内容高%.2f~%.2f 漂移%.2f"
              % (status, unit, anim, W, H, len(frames), want, distinct, tt, tb,
                 min(hts), max(hts), drift))
        # 全帧条带图（96px/帧）
        strip = Image.new("RGBA", (96 * len(frames), 96), (44, 44, 52, 255))
        for i, f in enumerate(frames):
            strip.paste(f.resize((96, 96), Image.LANCZOS), (i * 96, 0))
        strip.save(os.path.join(OUT, "v3_%s_%s_strip.png" % (unit, anim)))

print("PASS" if ok_all else "FAIL")
