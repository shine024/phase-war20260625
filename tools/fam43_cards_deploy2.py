# -*- coding: utf-8 -*-
"""fam43 卡重生成批部署 R2·4 张（2026-10-06 用户 (4).json「生图的没处理」→整链处理）。

  1. 备份旧卡 → fam43_cards_redo/_old/
  2. 新卡落位（敌方/根路径朝左=FLIP；player/ 朝右=直拷）
  3. 从朝右 staging _512 提锚定 + 预翻朝左（canvas 契约）+ 品红口袋净化
  4. 新锚定客观测枪口（air=最左本体列；幻影=肩带内最左；喷火车=中带最左）→ 打印建议
用法: python tools/fam43_cards_deploy2.py [--no-card 只重锚测口]
"""
import io
import json
import os
import shutil
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGE = os.path.join(ROOT, ".godot", "unit_review", "fam43_cards_redo")
BACKUP = os.path.join(STAGE, "_old")

import fam43_card_anchors as fca

# key → (游戏内卡路径, 部署是否镜像[朝左])
KEYS = {
    "ww2_air_dive_bomber": ("assets/card_icons/enemy/ww2_air_dive_bomber.png", True),
    "mod_air_multirole":   ("assets/card_icons/enemy/mod_air_multirole.png", True),
    "fe_helix_phantom":    ("assets/card_icons/player/fe_helix_phantom.png", False),
    "flame_raider_expert": ("assets/card_icons/flame_raider_expert.png", True),
}


def body_mask(arr):
    d = np.sqrt(((arr[:, :, :3].astype(int) - np.array([255, 0, 255])) ** 2).sum(axis=2))
    if arr.shape[2] == 4:
        return (arr[:, :, 3] >= 16) & (d >= 100)
    return d >= 100  # 品红场 RGB 无 α


def measure_muzzle(key, arr):
    """新锚定（朝左域）客观枪口：air=全图最左本体；幻影=上带(0-40%H)最左；喷火车=中带(40-88%H)最左。"""
    m = body_mask(arr)
    ys, xs = np.where(m)
    y0, y1 = ys.min(), ys.max()
    H = y1 - y0
    if key in ("ww2_air_dive_bomber", "mod_air_multirole"):
        band = m
    elif key == "fe_helix_phantom":
        band = np.zeros_like(m)
        band[y0 + int(0.02 * H): y0 + int(0.40 * H)] = m[y0 + int(0.02 * H): y0 + int(0.40 * H)]
    else:  # flame_raider_expert
        band = np.zeros_like(m)
        band[y0 + int(0.40 * H): y0 + int(0.88 * H)] = m[y0 + int(0.40 * H): y0 + int(0.88 * H)]
    ys2, xs2 = np.where(band)
    x = int(xs2.min())
    col = ys2[xs2 <= x + 3]
    return [x, int(col.mean())]


def main():
    no_card = "--no-card" in sys.argv
    os.makedirs(BACKUP, exist_ok=True)
    sug = {}
    for k, (rel, flip) in KEYS.items():
        src512 = os.path.join(STAGE, "%s_512.png" % k)
        dst = os.path.join(ROOT, rel)
        assert os.path.exists(src512), src512
        if not no_card:
            if os.path.exists(dst) and not os.path.exists(os.path.join(BACKUP, os.path.basename(rel))):
                shutil.copy2(dst, os.path.join(BACKUP, os.path.basename(rel)))
                print("[backup] %s" % rel)
            card = Image.open(src512).convert("RGBA")
            (card.transpose(Image.FLIP_LEFT_RIGHT) if flip else card).save(dst)
            print("[deploy] %s ← %s_512%s" % (rel, k, " (flipped)" if flip else ""))
        # 锚定：源=朝右 staging → 预翻朝左
        arr = fca.extract(src512)
        arr = arr[:, ::-1, :]
        arr, npix = fca.purge_pink_pockets(arr)
        Image.fromarray(arr).save(os.path.join(fca.OUT_DIR, "%s_anchor_raw.png" % k))
        mz = measure_muzzle(k, arr)
        sug[k] = mz
        print("[anchor] %-22s pocket=%d  建议枪口=%s" % (k, npix, mz))
    print(json.dumps(sug, ensure_ascii=False))


if __name__ == "__main__":
    main()
