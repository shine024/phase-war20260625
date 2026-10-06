# -*- coding: utf-8 -*-
"""fam43 卡重生成批部署（2026-10-06 用户拍板：6 张全部署）。

  1. 备份旧敌卡 → fam43_cards_redo/_old/
  2. 新卡镜像朝左 → 覆盖敌方卡（宪法口径：生成朝右、enemy=FLIP）
  3. fam43_card_anchors 同配方重提锚定（敌卡已朝左，不翻）
用法: python tools/fam43_cards_deploy.py
"""
import io
import json
import os
import shutil
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGE = os.path.join(ROOT, ".godot", "unit_review", "fam43_cards_redo")
BACKUP = os.path.join(STAGE, "_old")
OLD = {"ww2_air_dive_bomber": "assets/card_icons/enemy/ww2_air_dive_bomber.png",
       "fut_arm_prism": "assets/card_icons/enemy/vis_enemy_026.png",
       "ww1_inf_mp18_x": "assets/card_icons/enemy/ww1_inf_mp18_x.png",
       "ww2_arm_garand_para": "assets/card_icons/enemy/ww2_arm_garand_para.png",
       "mod_sup_m4_carbine": "assets/card_icons/enemy/mod_sup_m4_carbine.png",
       "mod_air_multirole": "assets/card_icons/enemy/mod_air_multirole.png"}


def main():
    import fam43_card_anchors as fca
    dump = json.load(open(fca.DUMP, encoding="utf-8"))
    cards = fca.key_to_card(dump)
    cards.update(fca.marked_icons())

    os.makedirs(BACKUP, exist_ok=True)
    for k, rel in OLD.items():
        src512 = os.path.join(STAGE, "%s_512.png" % k)
        dst = os.path.join(ROOT, rel)
        assert os.path.exists(src512), src512
        # 1. 备份
        if os.path.exists(dst) and not os.path.exists(os.path.join(BACKUP, os.path.basename(rel))):
            shutil.copy2(dst, os.path.join(BACKUP, os.path.basename(rel)))
            print("[backup] %s" % rel)
        # 2. 镜像朝左覆盖
        Image.open(src512).convert("RGBA").transpose(
            Image.FLIP_LEFT_RIGHT).save(dst)
        print("[deploy] %s ← %s_512 (flipped)" % (rel, k))
        # 3. 重提锚定（不翻；vis_enemy_026 等路径取 cards 映射）
        cp = cards.get(k)
        if cp and os.path.exists(cp):
            arr = fca.extract(cp)
            arr, npix = fca.purge_pink_pockets(arr)
            Image.fromarray(arr).save(os.path.join(fca.OUT_DIR, "%s_anchor_raw.png" % k))
            print("[anchor] %-22s pocket=%d" % (k, npix))
        else:
            print("[anchor?] %s 无卡路径映射" % k)


if __name__ == "__main__":
    main()
