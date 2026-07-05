"""
D段补充池图整理：把 12/vis_pool_NNN.png 按统一命名规则补入 enemy/ 和 player/。
- enemy/<新id>.png = 原图（复制自 12/）
- player/<新id>.png = 水平翻转图
落实"敌方原图在 enemy/，我方翻转图在 player/"的统一规则。
"""
import os
import sys
from PIL import Image

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(PROJECT_ROOT, "assets", "card_icons", "12")
ENEMY_DIR = os.path.join(PROJECT_ROOT, "assets", "card_icons", "enemy")
PLAYER_DIR = os.path.join(PROJECT_ROOT, "assets", "card_icons", "player")

# vis_pool 编号 → 新 id（来自 docs/敌方单位统一表_v3.md D段）
MAPPING = {
    1: "ww1_inf_enfield", 2: "ww1_arm_rolls_mk2", 3: "ww1_sup_vickers",
    4: "ww1_sup_ford_ambulance", 5: "ww1_inf_mp18_x",
    6: "ww2_arm_garand_para", 7: "ww2_arty_hummel", 8: "ww2_arty_pak40",
    9: "ww2_sup_gmc_truck", 10: "ww2_inf_kar98k",
    11: "cold_arty_bmd1", 12: "cold_sup_bmp1_x", 13: "cold_inf_metis",
    14: "cold_arm_p18", 15: "cold_arty_brem1",
    16: "mod_sup_m4_carbine", 17: "mod_inf_patriot", 18: "mod_arm_himars",
    19: "mod_arty_rq7", 20: "mod_sup_growler",
    21: "fut_inf_neural", 22: "fut_arm_hk07", 23: "fut_arty_hel30",
    24: "fut_sup_nrepair", 25: "fut_inf_x9", 26: "fut_inf_c96",
    27: "fut_arm_sdkfz", 28: "fut_arty_ssc1", 29: "fut_sup_ps9",
}

def main():
    dry = "--dry-run" in sys.argv
    os.makedirs(ENEMY_DIR, exist_ok=True)
    os.makedirs(PLAYER_DIR, exist_ok=True)

    ok = 0
    skip = 0
    for n, new_id in sorted(MAPPING.items()):
        src = os.path.join(SRC_DIR, "vis_pool_%03d.png" % n)
        if not os.path.exists(src):
            print("  [跳过] 缺源: %s" % os.path.basename(src))
            skip += 1
            continue
        enemy_dst = os.path.join(ENEMY_DIR, "%s.png" % new_id)
        player_dst = os.path.join(PLAYER_DIR, "%s.png" % new_id)
        if dry:
            print("  [DRY] %03d -> enemy/%s.png + player/%s.png" % (n, new_id, new_id))
            ok += 1
            continue
        img = Image.open(src)
        if img.mode != "RGBA":
            img = img.convert("RGBA")
        img.save(enemy_dst, "PNG")          # 敌方原图
        flipped = img.transpose(Image.FLIP_LEFT_RIGHT)
        flipped.save(player_dst, "PNG")     # 我方翻转图
        ok += 1

    print("=== 完成 ===")
    print("处理: %d 张" % ok)
    print("跳过: %d 张" % skip)
    if not dry:
        print("敌方原图 -> assets/card_icons/enemy/<新id>.png")
        print("我方翻转 -> assets/card_icons/player/<新id>.png")

if __name__ == "__main__":
    main()
