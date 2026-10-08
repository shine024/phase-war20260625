# -*- coding: utf-8 -*-
"""fam44 格4/5 手术（2026-10-07「继续处理」）：f4 实锤朝向病帧（炮口翻右、烟留左端，
帧间炮口横跳=摇摆最重形态）。全卷车身统一 f2 本体血统：
  格4 = f2 本体 + f4 衰减光点（暖抠、镜像贴炮口，圆对称镜像无副作用）+ f5 烟带 alpha×1.25
  格5 = f2 本体 + f5 余烬（暖抠）+ f5 烟带原样
灰烟抠取：非白程度 alpha=(252-lum)×k，窗口限车身外烟区；f2 原炮口小烟先抹除防双烟叠加。
产出: ww1_mark4_fix_f4.png / ww1_mark4_fix_f5.png
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

S = ".godot/unit_review/img25_staging/"

# ---- 关键点（2048 原图系，displayed×1.02 测定）----
F2_MUZZLE = (668, 795)          # f2 短管炮口端面（朝左）
F4_SPOT = (1307, 781)           # f4 衰减光点中心（朝右帧，管口右侧）
F4_SPOT_BOX = (1250, 720, 1400, 845)
F5_EMBER = (692, 804)           # f5 余烬中心（朝左帧，管口左侧）
F5_MUZZLE = (726, 806)
F5_EMBER_BOX = (640, 745, 760, 860)
F5_SMOKE_BOX = (0, 690, 660, 880)   # f5 细烟带（车身外左侧烟区）
F2_SMOKE_WIPE = (30, 650, 540, 830)  # f2 原炮口小烟抹除区（避开炮管 x<668 与履带 y<830）


def warm_patch(img, box, core_lum=228, grow=31, fade_bottom=0):
    """暖色抠取（焰/光点/余烬）：暖偏移 alpha + 膨胀区内亮白并入白热芯。"""
    win = img.crop(box)
    a = np.asarray(win).astype(np.int16)
    R, B = a[..., 0], a[..., 2]
    alpha = np.clip(((R - B) - 8) * 8, 0, 255).astype(np.float32)
    m = Image.fromarray(np.where(alpha > 40, 255, 0).astype(np.uint8))
    m = m.filter(ImageFilter.MaxFilter(grow))
    md = np.asarray(m) > 0
    lum = (a[..., 0] * 299 + a[..., 1] * 587 + a[..., 2] * 114) // 1000
    alpha[md & (lum > core_lum)] = 255
    if fade_bottom:
        fade = np.ones(alpha.shape[0], dtype=np.float32)
        fade[-fade_bottom:] = np.linspace(1.0, 0.0, fade_bottom)
        alpha *= fade[:, None]
    return Image.fromarray(np.dstack([a.astype(np.uint8), alpha.astype(np.uint8)]), "RGBA")


def smoke_patch(img, box, gain=1.0, max_alpha=205, fade=0):
    """灰烟抠取：非白程度做 alpha（白底 255→0，烟核→max_alpha），低饱和门控，底边羽化。"""
    win = img.crop(box)
    a = np.asarray(win).astype(np.int16)
    lum = (a[..., 0] * 299 + a[..., 1] * 587 + a[..., 2] * 114) // 1000
    sat = np.abs(a[..., 0] - a[..., 2])
    alpha = np.clip((252 - lum) * 3.5 * gain, 0, max_alpha).astype(np.float32)
    alpha[sat > 30] = 0  # 彩色杂物排除
    if fade:
        fade_v = np.ones(alpha.shape[0], dtype=np.float32)
        fade_v[-fade:] = np.linspace(1.0, 0.0, fade)
        alpha *= fade_v[:, None]
    return Image.fromarray(np.dstack([a.astype(np.uint8), alpha.astype(np.uint8)]), "RGBA")


def main():
    f2 = Image.open(S + "ww1_mark4_chainR1_f2.png").convert("RGB")
    f4 = Image.open(S + "ww1_mark4_chainR2_f4.png").convert("RGB")
    f5 = Image.open(S + "ww1_mark4_chainR2_f5.png").convert("RGB")

    # ---- 素材 ----
    spot = warm_patch(f4, F4_SPOT_BOX)                       # f4 衰减光点
    ember = warm_patch(f5, F5_EMBER_BOX)                     # f5 余烬
    smoke = smoke_patch(f5, F5_SMOKE_BOX, fade=30)           # f5 烟带（底边羽化防切痕）
    smoke_hot = smoke_patch(f5, F5_SMOKE_BOX, gain=1.25, fade=30)  # 格4 增浓版

    # ---- 格4 = f2 本体 + 镜像光点 + 烟×1.25 ----
    g4 = f2.copy()
    g4.paste(Image.new("RGB", (F2_SMOKE_WIPE[2] - F2_SMOKE_WIPE[0],
                               F2_SMOKE_WIPE[3] - F2_SMOKE_WIPE[1]), (255, 255, 255)),
             F2_SMOKE_WIPE[:2])
    # 光点镜像：源中心在管口右侧 (+37,+4)，镜像后应贴管口左侧 (-37,+4)
    w, h = spot.size
    spot_m = spot.transpose(Image.FLIP_LEFT_RIGHT)
    cx_rel = F4_SPOT[0] - F4_SPOT_BOX[0]
    cy_rel = F4_SPOT[1] - F4_SPOT_BOX[1]
    # 镜像后光点中心（窗口内 x 翻转），贴到管口左侧 37px（源偏移 (+37,+4) 镜像为 (-37,+4)）
    paste_xy = (F2_MUZZLE[0] - 37 - (w - 1 - cx_rel), F2_MUZZLE[1] + 4 - cy_rel)
    g4.paste(spot_m, paste_xy, spot_m)
    g4.paste(smoke_hot, (-58, 679), smoke_hot)
    g4.save(S + "ww1_mark4_fix_f4.png")

    # ---- 格5 = f2 本体 + 余烬 + 烟原样 ----
    g5 = f2.copy()
    g5.paste(Image.new("RGB", (F2_SMOKE_WIPE[2] - F2_SMOKE_WIPE[0],
                               F2_SMOKE_WIPE[3] - F2_SMOKE_WIPE[1]), (255, 255, 255)),
             F2_SMOKE_WIPE[:2])
    ecx = F5_EMBER[0] - F5_EMBER_BOX[0]
    ecy = F5_EMBER[1] - F5_EMBER_BOX[1]
    # 余烬相对 f5 管口偏移 (-34,-2)，贴到 f2 管口同偏移
    g5.paste(ember, (F2_MUZZLE[0] - 34 - ecx, F2_MUZZLE[1] - 2 - ecy), ember)
    g5.paste(smoke, (-58, 679), smoke)
    g5.save(S + "ww1_mark4_fix_f5.png")

    # 局部目检
    g4.crop((100, 560, 1100, 1040)).save(S + "_dbg_fix_f4_local.png")
    g5.crop((100, 560, 1100, 1040)).save(S + "_dbg_fix_f5_local.png")
    print("OK fix_f4 / fix_f5")

if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
