# -*- coding: utf-8 -*-
"""fam44 格3 焰移植手术（2026-10-07）：f3 唯一病=炮管偏长（重掷4张全废：
双管漂移/点名双管反噬出双炮塔）。车身用 f2 本体（标准单短管，零漂移），
大焰从 f3 色域抠取（暖偏移 R-B 做 alpha，灰管/灰烟/白底自动排除，
白热芯用「暖色膨胀区内亮白并入」保实心），按炮口相对位置对位贴附。
产出: <key>_fix_f3.png
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

S = ".godot/unit_review/img25_staging/"

# ---- 源：f3 焰窗口（全图系）与关键点 ----
FLASH_BOX = (480, 650, 820, 890)    # 焰+光晕窗口（下缘收到火花底，避开甲板部件渗漏）
FLASH_CORE = (705, 845)             # f3 白热芯中心
F3_MUZZLE = (760, 840)              # f3 长管炮口端面
# ---- 宿主：f2 与炮口 ----
HOST = S + "ww1_mark4_chainR1_f2.png"
F2_MUZZLE = (668, 795)              # f2 短管炮口端面

def main():
    f3 = Image.open(S + "ww1_mark4_chainR1_f3.png").convert("RGB")
    f2 = Image.open(HOST).convert("RGB")

    win = f3.crop(FLASH_BOX)
    a = np.asarray(win).astype(np.int16)
    R, G, B = a[..., 0], a[..., 1], a[..., 2]

    # 暖偏移 alpha：橙/黄焰实，白底/灰管/灰烟（R≈B）自动为 0
    warm = R - B
    alpha = np.clip((warm - 8) * 8, 0, 255).astype(np.float32)

    # 下缘 36px 线性羽化：压掉窗口底残存的甲板暖光渗漏
    h = alpha.shape[0]
    fade = np.ones(h, dtype=np.float32)
    fade[-36:] = np.linspace(1.0, 0.0, 36)
    alpha *= fade[:, None]

    alpha = alpha.astype(np.uint8)

    # 白热芯保实心：暖色 mask 膨胀后，膨胀区内的亮白像素并入
    m = Image.fromarray(np.where(alpha > 40, 255, 0).astype(np.uint8))
    m = m.filter(ImageFilter.MaxFilter(31))  # 膨胀 ~15px
    md = np.asarray(m) > 0
    lum = (R * 299 + G * 587 + B * 114) // 1000
    core_fill = md & (lum > 228)
    alpha[core_fill] = 255

    rgba = np.dstack([a.astype(np.uint8), alpha])
    patch = Image.fromarray(rgba, "RGBA")

    # 对位：焰心相对炮口的关系保持 f3 原状（焰心在炮口左侧）
    off = (FLASH_CORE[0] - F3_MUZZLE[0], FLASH_CORE[1] - F3_MUZZLE[1])
    dst = (F2_MUZZLE[0] + off[0], F2_MUZZLE[1] + off[1])  # 目标焰心
    paste_xy = (dst[0] - (FLASH_CORE[0] - FLASH_BOX[0]),
                dst[1] - (FLASH_CORE[1] - FLASH_BOX[1]))

    out = f2.copy()
    out.paste(patch, paste_xy, patch)
    fp = S + "ww1_mark4_fix_f3.png"
    out.save(fp)
    # 附炮口局部放大供目检
    out.crop((300, 560, 1000, 1040)).save(S + "_dbg_fix_f3_local.png")
    print("OK", fp)

if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
