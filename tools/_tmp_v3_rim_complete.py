# -*- coding: utf-8 -*-
"""v3 宪法批：卡图背光 rim 恒定开——补齐批（2026-09-26）。

依据：STYLE_BIBLE 第二章"rim 恒定开（背光侧一道极窄冷 rim，是内容层与 UI 层的缝合线，
不因单位时代而省略）" + §11.13 rim_pass 同款工艺 + 用户 2026-09-26 "按你新的标准进行修复" 授权。
名单 = v3 全量左缘扫描 cov<5% 且目视确认无档色缘（.godot/agent_tools/v3_repair/rim_cand_1-3.png 亲读）：
  ICE 60 张（历史写实系：ww1/ww2/cold/mod/vis 载具步兵结构）
  NEON 44 张（科幻剪形：fe_/fut_/drop_ 全体 + vis 机甲/悬浮/能量结构）
  RECOLOR 3 张（067/068/029 已有冷色缘但档位错 → 缘带换霓虹）
工艺（_tmp_w5_rim_pass.py 同款）：逐行最外圈不透明像素（a>=200）向档色混色（外 65% + 次像素 25%），
只改色不改 alpha（剪影/脚锚零变化）；enemy := flip(player) 重派。
备份 _art_backup/*-preRIM2-2026-09-26.png（双侧全备份）。
vis_xeno 族不动（§11.4 发现9 全族健康）；vis_player_069 已有霓虹缘跳过；028 微弱缘留观。
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PI = os.path.join(ROOT, "assets", "card_icons", "player")
EN = os.path.join(ROOT, "assets", "card_icons", "enemy")
BK = r"F:\godot fair duet\_art_backup"
SUF = "-preRIM2-2026-09-26.png"

ICE = (153, 217, 255)
NEON = (0, 240, 255)

ADD_ICE = [
    "cold_air_strike_fighter", "cold_arm_p18", "cold_arty_bmd1", "cold_arty_brem1",
    "cold_inf_metis", "cold_sup_bmp1_x",
    "mod_air_multirole", "mod_arty_rq7", "mod_inf_patriot", "mod_sup_growler", "mod_sup_m4_carbine",
    "vis_player_003", "vis_player_009", "vis_player_010", "vis_player_014", "vis_player_016",
    "vis_player_017", "vis_player_018", "vis_player_019", "vis_player_020", "vis_player_021",
    "vis_player_022", "vis_player_023", "vis_player_035", "vis_player_038", "vis_player_039",
    "vis_player_041", "vis_player_042", "vis_player_043", "vis_player_044", "vis_player_045",
    "vis_player_046", "vis_player_047", "vis_player_048", "vis_player_050", "vis_player_051",
    "vis_player_052", "vis_player_053", "vis_player_054", "vis_player_055", "vis_player_056",
    "vis_player_057", "vis_player_058", "vis_player_059", "vis_player_060", "vis_player_061",
    "vis_player_062", "vis_player_063", "vis_player_064", "vis_player_077", "vis_player_078",
    "vis_player_079", "vis_player_089", "vis_player_112",
    "ww1_arm_rolls_mk2", "ww1_inf_mp18_x", "ww1_sup_vickers", "ww2_air_meteor_e",
    "ww2_arty_hummel", "ww2_arty_pak40", "ww2_sup_gmc_truck",
]
ADD_NEON = [
    "drop_phase_lance", "drop_thunder_field",
    "fe_aether_hover_cavalry", "fe_aether_swarm_queen", "fe_frontier_mixed_company",
    "fe_frontier_veteran", "fe_helix_orbital_strike", "fe_helix_phantom",
    "fe_iron_wall_bastion", "fe_iron_wall_juggernaut", "fe_nova_devastator",
    "fe_nova_ghost_sniper", "fe_quantum_mobile_base", "fe_quantum_repair_drone",
    "fe_void_dimensional_soldier", "fe_void_phase_cannon",
    "fut_air_stealth_bomber", "fut_air_stealth_multirole", "fut_arm_hk07", "fut_arm_sdkfz",
    "fut_arty_hel30", "fut_arty_ssc1", "fut_attack_drone", "fut_inf_c96",
    "fut_inf_neural", "fut_sup_nrepair", "fut_sup_ps9", "fut_swarm",
    "vis_player_025", "vis_player_027", "vis_player_030", "vis_player_031", "vis_player_032",
    "vis_player_033", "vis_player_066", "vis_player_071", "vis_player_080", "vis_player_081",
    "vis_player_087", "vis_player_092", "vis_player_093", "vis_player_094", "vis_player_113",
    "vis_player_114",
]
RECOLOR_NEON = ["vis_player_029", "vis_player_067", "vis_player_068"]


def backup(path):
    dst = os.path.join(BK, os.path.splitext(os.path.basename(path))[0] + SUF)
    if not os.path.exists(dst):
        Image.open(path).convert("RGBA").save(dst)


def add_rim(im, tier_rgb):
    """rim_pass 工艺：逐行最外圈不透明像素向档色混色（外 65% + 次像素 25%），只改色。"""
    px = im.load()
    w, h = im.size
    for y in range(h):
        x0 = None
        for x in range(w):
            if px[x, y][3] >= 200:
                x0 = x
                break
        if x0 is None:
            continue
        x1 = x0 + 1
        if x1 >= w or px[x1, y][3] < 200:
            continue
        r0, g0, b0, a0 = px[x0, y]
        px[x0, y] = (
            int(r0 * 0.35 + tier_rgb[0] * 0.65),
            int(g0 * 0.35 + tier_rgb[1] * 0.65),
            int(b0 * 0.35 + tier_rgb[2] * 0.65),
            a0,
        )
        r1, g1, b1, a1 = px[x1, y]
        px[x1, y] = (
            int(r1 * 0.75 + tier_rgb[0] * 0.25),
            int(g1 * 0.75 + tier_rgb[1] * 0.25),
            int(b1 * 0.75 + tier_rgb[2] * 0.25),
            a1,
        )
    return im


def recolor_rim(im, tier_rgb):
    """缘带换色：已有冷色缘（b>r 的最外两像素）向霓虹档混色 60%/30%。"""
    px = im.load()
    w, h = im.size
    for y in range(h):
        x0 = None
        for x in range(w):
            if px[x, y][3] >= 200:
                x0 = x
                break
        if x0 is None:
            continue
        for x, k in ((x0, 0.60), (x0 + 1, 0.30)):
            if x >= w or px[x, y][3] < 200:
                continue
            r, g, b, a = px[x, y]
            if b > r + 20:  # 只动冷色缘，暖色内容不动
                px[x, y] = (
                    int(r * (1 - k) + tier_rgb[0] * k),
                    int(g * (1 - k) + tier_rgb[1] * k),
                    int(b * (1 - k) + tier_rgb[2] * k),
                    a,
                )
    return im


def main():
    os.makedirs(BK, exist_ok=True)
    n = 0
    for name in ADD_ICE + ADD_NEON:
        p = os.path.join(PI, name + ".png")
        backup(p)
        tier = ICE if name in ADD_ICE else NEON
        im = add_rim(Image.open(p).convert("RGBA"), tier)
        im.save(p)
        ename = name.replace("vis_player_", "vis_enemy_", 1) if name.startswith("vis_player_") else name
        im.transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(EN, ename + ".png"))
        n += 1
    for name in RECOLOR_NEON:
        p = os.path.join(PI, name + ".png")
        backup(p)
        im = recolor_rim(Image.open(p).convert("RGBA"), NEON)
        im.save(p)
        im.transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(EN, name.replace("vis_player_", "vis_enemy_", 1) + ".png"))
        n += 1
    print(f"processed {n} player cards (+ enemy flips), backups suffix {SUF}")


if __name__ == "__main__":
    main()
