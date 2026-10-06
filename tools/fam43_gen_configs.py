# -*- coding: utf-8 -*-
"""fam43 重生成批配置构建（codeanim 卡图直出，全部 facing=1 原生朝左/预翻已做）。

枪口/切割常数 = 2026-10-05 探针页目测（fam43_anchor_from_card/_probe_fam43_p*.png），
自动 L 仅起点；生成后 LAYERS/SHEET 目检迭代修。模式按体裁：
  cutout3=炮塔/炮管/车身分明坦克  burst=机枪/小口径点射  vfx=步兵/堡垒/能量/斜角炮
  rocket=火箭炮  bomb=投送/俯冲轰炸（crate=补给箱）
"""
import json
import os

SRC = os.path.join(".godot", "unit_review", "fam43_anchor_from_card")
D = dict(mode="vfx", cat="ground", src=SRC, flip=False, outline=False,
         gain=1.0, pink_scrub=True)

# key: (mode, muzzle, flash_angle, extra)
U = {
    # ---- 坦克/装甲主战：cutout3（常数=10-05 _cutout_zoom2.png 1:1 复测）----
    "ww2_inf_hellcat":   ("cutout3", (44, 450), -2, dict(split_y=480, barrel=(432, 468, 330), recoil=5)),
    "cold_arm_t55":      ("cutout3", (62, 494), -2, dict(split_y=512, barrel=(482, 508, 430), recoil=5)),
    "mod_arm_m1a2sep":   ("cutout3", (30, 470), -2, dict(split_y=545, barrel=(430, 540, 360), recoil=6)),
    "cold_t72":          ("cutout3", (62, 490), -2, dict(split_y=540, barrel=(472, 506, 430), recoil=5)),
    "ww1_boss_av7":      ("vfx", (57, 385), -2, dict(recoil=4, flash_scale=1.3)),  # A7V 整体浇铸车身无缝可切→全车摇
    "ww2_arty_hummel":   ("cutout3", (47, 406), -3, dict(split_y=575, barrel=(383, 432, 430), recoil=6)),
    "mod_sup_m6":        ("cutout3", (57, 410), -3, dict(split_y=535, barrel=(386, 434, 320), recoil=4)),
    "fut_arm_hovertank": ("vfx", (48, 495), -2, dict(recoil=3, flash_scale=1.2)),  # 气垫坦克单体车身→全车摇
    # ---- 机枪/小口径点射：burst ----
    "ww1_arm_rolls":     ("burst", (150, 425), -4, dict(recoil=2, smoke_n=1)),
    "cold_inf_btr60":    ("burst", (228, 330), -3, dict(recoil=2, smoke_n=1)),
    "cold_arm_btr_e":    ("burst", (230, 335), -3, dict(recoil=2, smoke_n=1)),
    "cold_bradley":      ("burst", (205, 335), -3, dict(recoil=2, smoke_n=1)),
    "mod_stryker":       ("burst", (220, 390), -3, dict(recoil=2, smoke_n=1)),
    "cold_sup_bmp1_x":   ("burst", (200, 645), -2, dict(recoil=3, smoke_n=1)),
    "cold_arty_brem1":   ("burst", (150, 545), -4, dict(recoil=2, smoke_n=1)),
    "mod_ranger":        ("burst", (233, 190), -4, dict(recoil=2, smoke_n=2)),
    # ---- 火箭炮：rocket ----
    "mod_arty_m270":     ("rocket", (945, 565), -120, dict(smoke_n=2)),
    "mod_arm_himars":    ("rocket", (650, 155), -35, dict(smoke_n=2)),
    # ---- 投送/俯冲轰炸：bomb ----
    "ww2_sup_gmc_truck":     ("bomb", (860, 580), 0, dict(crate=True, bomb_scale=2.4, recoil=0, smoke_n=0, bob=2)),
    "ww2_air_dive_bomber":   ("bomb", (420, 620), 0, dict(bomb_scale=1.6, cat="air", recoil=0, smoke_n=0)),
    "fut_air_stealth_bomber": ("bomb", (480, 610), 0, dict(bomb_scale=1.8, cat="air", recoil=0, smoke_n=0)),
    # ---- 步兵/支援/堡垒/能量：vfx ----
    "ww1_inf_cavalry":    ("vfx", (210, 95), -11, dict(recoil=1, smoke_n=0)),
    "ww2_inf_bazooka":    ("vfx", (100, 252), -2, dict(recoil=2, smoke_n=1)),  # 10-06 新专属卡重提锚定，跪姿肩射筒轴近水平
    "ww2_arty_m81":       ("vfx", (870, 175), -120, dict(recoil=1, smoke_n=1)),
    "ww1_arty_m81":       ("vfx", (170, 140), -40, dict(recoil=2, smoke_n=1)),
    "cold_sup_zsu23":     ("vfx", (428, 168), -45, dict(recoil=2, smoke_n=2)),
    "fut_arm_prism":      ("vfx", (330, 370), 0, dict(flash_color=[80, 170, 255], recoil=1, smoke_n=0)),
    "ww2_thompson":       ("vfx", (228, 300), -8, dict(recoil=1, smoke_n=1)),
    "cold_spetsnaz":      ("vfx", (205, 400), -4, dict(recoil=1, smoke_n=0)),
    "ww1_inf_mp18_x":     ("vfx", (140, 320), -15, dict(recoil=1, smoke_n=1)),
    "ww2_arm_garand_para": ("vfx", (160, 320), -12, dict(recoil=1, smoke_n=1)),
    "mod_sup_m4_carbine": ("vfx", (200, 210), -6, dict(recoil=1, smoke_n=0)),
    "mod_ah64":           ("vfx", (300, 745), -3, dict(cat="air", recoil=1, smoke_n=1)),
    "fut_air_drone":      ("vfx", (330, 600), -3, dict(cat="air", recoil=1, smoke_n=1)),
    "mod_air_multirole":  ("vfx", (110, 555), -2, dict(cat="air", recoil=2, smoke_n=1)),
    "fut_colossus":       ("vfx", (105, 640), -15, dict(recoil=2, smoke_n=1, flash_scale=1.2)),
    "ww1_fort_pillbox":   ("vfx", (105, 310), -3, dict(recoil=1, smoke_n=1)),
    "ww1_fort_artillery": ("vfx", (95, 145), -40, dict(recoil=2, smoke_n=1)),
    "ww2_fort_bunker":    ("vfx", (930, 520), 180, dict(recoil=2, smoke_n=1)),
    "ww2_fort_flak":      ("vfx", (150, 120), -50, dict(recoil=2, smoke_n=1)),
    "mod_fort_phalanx":   ("vfx", (100, 640), -3, dict(recoil=2, smoke_n=1, flash_scale=1.1)),
}

out = {}
for k, (mode, mz, ang, extra) in U.items():
    c = dict(D)
    c.update(mode=mode, muzzle=list(mz), flash_angle=ang)
    c.update(extra)
    out[k] = c

p = os.path.join(".godot", "unit_review", "codeanim_configs", "_configs_fam43.json")
json.dump(out, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("wrote", p, len(out), "units")
