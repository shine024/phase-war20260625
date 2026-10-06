# -*- coding: utf-8 -*-
"""fam43 卡重生成批 → B4 部署配方 staging（2026-10-06）。

对 fam43_cards_redo/ 的 6 张 raw：
  1. flood_white_to_alpha(238)
  2. 封闭白口袋→透明（bazooka 教训：透缝语义，勿填色）
  3. grow_alpha(215, max_iter=30)
  4. fit_square(512, 0.88)
  5. 拼审查蒙太奇：上=新卡（白底/暗底双视图），下=旧病卡对照
只落 staging，不写 assets/（§十 铁律）。用法: python tools/fam43_cards_stage.py
"""
import io
import json
import os
import sys
import types

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from PIL import Image, ImageDraw
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGE = os.path.join(ROOT, ".godot", "unit_review", "fam43_cards_redo")
OLD = {"ww2_air_dive_bomber": "assets/card_icons/enemy/ww2_air_dive_bomber.png",
       "fut_arm_prism": "assets/card_icons/enemy/vis_enemy_026.png",
       "ww1_inf_mp18_x": "assets/card_icons/enemy/ww1_inf_mp18_x.png",
       "ww2_arm_garand_para": "assets/card_icons/enemy/ww2_arm_garand_para.png",
       "mod_sup_m4_carbine": "assets/card_icons/enemy/mod_sup_m4_carbine.png",
       "mod_air_multirole": "assets/card_icons/enemy/mod_air_multirole.png",
       # R2 批（2026-10-06 判定 (2).json 生图组）
       "fe_helix_phantom": "assets/card_icons/player/fe_helix_phantom.png",
       "flame_raider_expert": "assets/card_icons/flame_raider_expert.png"}


def load(name, path):
    lines = open(path, encoding="utf-8").read().split("\n")
    mod = types.ModuleType(name)
    mod.__file__ = path
    exec(compile("\n".join(lines), path, "exec"), mod.__dict__)
    return mod


img25 = load("f43_img25", os.path.join(ROOT, "tools", "img25_card_sideview_redo.py"))


def pockets_transparent(rgba):
    """封闭白口袋→透明洞 + 2 迭代边缘咬蚀（bazooka cand 修法）。返回 (图, 洞像素数)。"""
    a = np.asarray(rgba).copy()
    al = a[:, :, 3]
    from scipy import ndimage
    solid = al >= 16
    lab, n = ndimage.label(~solid)  # ~solid 含外背景+内口袋
    border = set(lab[0, :]) | set(lab[-1, :]) | set(lab[:, 0]) | set(lab[:, -1])
    border.discard(0)
    pocket = (~solid) & ~np.isin(lab, list(border))
    tot = int(pocket.sum())
    if not tot:
        return rgba, 0
    a[:, :, 3] = np.where(pocket, 0, al)
    # 边缘咬蚀：口袋邻接的半透明白晕 2 圈降 alpha
    for _ in range(2):
        grow = ndimage.binary_dilation(pocket) & ~pocket & (a[:, :, 3] > 0)
        a[:, :, 3] = np.where(grow, np.maximum(a[:, :, 3] - 120, 0), a[:, :, 3])
        pocket = grow
    return Image.fromarray(a), tot


def main():
    keys = [k for k in OLD
            if os.path.exists(os.path.join(STAGE, "%s_raw.png" % k))]
    for k in keys:
        src = os.path.join(STAGE, "%s_raw.png" % k)
        im = Image.open(src).convert("RGB")
        rgba = img25.flood_white_to_alpha(im, 238)
        rgba, npx = pockets_transparent(rgba)
        rgba = img25.grow_alpha(rgba, 215, max_iter=30)
        out = img25.fit_square(rgba, 512, 0.88)
        out.save(os.path.join(STAGE, "%s_512.png" % k))
        print("[512] %-22s holes=%d" % (k, npx))

    # 审查蒙太奇：上排新卡白底/暗底，下排旧病卡暗底对照
    T = 360
    page = Image.new("RGB", (T * 3 + 8, (T + 18) * len(keys) * 2 + 10), (26, 28, 33))
    d = ImageDraw.Draw(page)
    y = 0
    for k in keys:
        fp = os.path.join(STAGE, "%s_512.png" % k)
        if os.path.exists(fp):
            im = Image.open(fp).convert("RGBA").resize((T, T), Image.LANCZOS)
            for j, bgc in enumerate(((240, 240, 238, 255), (24, 24, 28, 255))):
                bg = Image.new("RGBA", im.size, bgc)
                bg.alpha_composite(im)
                page.paste(bg.convert("RGB"), (j * (T + 4), y))
        d.text((4, y + T + 2), "%s 新卡（左白底/右暗底）" % k, fill=(255, 220, 120))
        y += T + 18
        op = os.path.join(ROOT, OLD[k])
        if os.path.exists(op):
            om = Image.open(op).convert("RGBA").resize((T, T), Image.LANCZOS)
            bg = Image.new("RGBA", om.size, (24, 24, 28, 255))
            bg.alpha_composite(om)
            page.paste(bg.convert("RGB"), (0, y))
        d.text((4, y + T + 2), "%s 旧病卡（暗底对照）" % k, fill=(160, 200, 255))
        y += T + 18
    page.save(os.path.join(STAGE, "_review_montage.png"))
    print("wrote", os.path.join(STAGE, "_review_montage.png"))


if __name__ == "__main__":
    main()
