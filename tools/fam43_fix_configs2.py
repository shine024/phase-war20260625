# -*- coding: utf-8 -*-
"""fam43 v2 修复批·第二批配置（6 张新卡重生成后回填，2026-10-06 拍板部署）。

枪口=镜像朝左新锚定实测（fam43_fix_audit/muzzle2/）：
  dive_bomber 机翼前缘机枪口 (230,480)；prism 棱镜炮口 (66,431)；
  mp18 枪口 (258,390)；garand (198,278)；m4 (212,310)；multirole 机首 (170,505)
模式改型：dive_bomber 用户令"做开火不是投弹"→burst 扫射；
  prism 棱镜坦克→laser 青束；mp18/m4/multirole→burst 点射。
用法: python tools/fam43_fix_configs2.py
"""
import json
import os

P = os.path.join(".godot", "unit_review", "codeanim_configs", "_configs_fam43.json")

PATCH = {
    "ww2_air_dive_bomber": dict(mode="burst", cat="air", muzzle=[230, 480],
                                flash_angle=0, recoil=0, smoke_n=0),  # 机翼机枪扫射
    "fut_arm_prism": dict(mode="laser", muzzle=[66, 431], flash_angle=0,
                          flash_color=[110, 225, 255], recoil=1, smoke_n=0,
                          bob=0),                                     # 棱镜光束
    "ww1_inf_mp18_x": dict(muzzle=[258, 390], flash_angle=-6, recoil=1,
                           smoke_n=1),                                # burst 模式不变，仅改口
    "ww2_arm_garand_para": dict(muzzle=[198, 278], flash_angle=-3, recoil=1,
                                smoke_n=1),
    "mod_sup_m4_carbine": dict(mode="burst", muzzle=[212, 310], flash_angle=-3,
                               recoil=2, smoke_n=1),
    "mod_air_multirole": dict(mode="burst", cat="air", muzzle=[170, 505],
                              flash_angle=0, recoil=1, smoke_n=0),
}

cfg = json.load(open(P, encoding="utf-8"))
for k, patch in PATCH.items():
    assert k in cfg, k
    cfg[k].update(patch)
json.dump(cfg, open(P, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("patched", len(PATCH), "units →", P)
