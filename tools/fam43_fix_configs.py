# -*- coding: utf-8 -*-
"""fam43 v2 修复批配置补丁（2026-10-06 用户判定 JSON → tools/fam43_review.json）。

22 家要修分五路（目检核实见 .godot/unit_review/fam43_fix_audit/）：
  A 枪口重测 12 家（十字线网格放大实测 1024 坐标）
  B 提取期预翻 4 家（sheet 左向契约；锚定已翻，枪口=翻后坐标）
  C 抠坏 2 家 → 卡图重生成（fam43_cards_redo 批，另行处理）
  D 卡图重生成 6 家（m4/multirole/mp18_x/garand_para/prism/dive_bomber）
  E 动感 5 家（gmc 行驶/ah64 旋翼/multirole 浮动/colossus 后坐 → fam43_motion_driver；
    stealth 改 laser 开火）
本脚本只改 _configs_fam43.json 的 A/B/E-config 部分；C/D 家生成后另行回填。
用法: python tools/fam43_fix_configs.py
"""
import json
import os

P = os.path.join(".godot", "unit_review", "codeanim_configs", "_configs_fam43.json")

# key: 补丁 dict（浅合并进现有配置）
PATCH = {
    # ---- A 枪口重测 ----
    "cold_sup_bmp1_x":    dict(muzzle=[88, 344], flash_angle=-1),   # 炮塔炮改制，原(200,645)在底裙板
    "cold_sup_zsu23":     dict(muzzle=[35, 262], flash_angle=-45),  # 四管上端管尖，原(428,168)悬空
    "mod_arm_himars":     dict(muzzle=[578, 264], flash_angle=-20),  # 弹箱口朝左上，原(650,155)悬空
    "mod_fort_phalanx":   dict(muzzle=[24, 418], flash_angle=-2),   # 加特林枪管尖，原(100,640)偏下220px
    "ww1_arty_m81":       dict(muzzle=[130, 242], flash_angle=-3),  # 炮管左尖，原(170,140)悬空
    "ww1_fort_artillery": dict(muzzle=[66, 296], flash_angle=-3),   # 炮口面，原(95,145)悬空
    "ww1_fort_pillbox":   dict(muzzle=[126, 332], flash_angle=8),   # 射孔炮管尖微下压，原(105,310)悬空
    "ww1_inf_cavalry":    dict(muzzle=[114, 547], flash_angle=0),   # 卡宾枪口，原(210,95)高了450px
    "ww2_fort_flak":      dict(muzzle=[176, 222], flash_angle=-36), # 炮口面实测仰角36°，原-50
    # ---- B 预翻后坐标（锚定已翻）----
    "mod_ranger":     dict(muzzle=[172, 238], flash_angle=-2),   # 翻后枪口=1024-852
    "mod_ah64":       dict(muzzle=[116, 585], flash_angle=3, recoil=3, smoke_n=1),  # 颊部机枪口
    "mod_arty_m270":  dict(muzzle=[56, 548], flash_angle=-25),   # 翻后管口面，箱轴仰25°（原-120错）
    "ww2_arty_m81":   dict(muzzle=[99, 38], flash_angle=-54, flash_scale=0.85,
                           flash_off=[0, 26]),                   # 翻后管口贴顶缘，焰心下移防裁半
    # ---- E 动感/改模式 ----
    "fut_colossus": dict(muzzle=[132, 595], flash_angle=8, recoil=4, smoke_n=2,
                         flash_scale=1.2),                     # 加特林枪口微下压；后坐加强(动感)
    "fut_air_stealth_bomber": dict(mode="laser", muzzle=[58, 512], flash_angle=-2,
                                   flash_color=[110, 225, 255], recoil=1, smoke_n=0,
                                   bob=0),                     # 用户令：开火不是投弹；青束配卡面青电弧
    "ww2_sup_gmc_truck": dict(mode="vfx", flash_scale=0, smoke_n=0, recoil=0, bob=0),
    # （gmc 行驶颠簸由 fam43_motion_driver 后处理；此处先归零武器效果）
    "mod_air_multirole": dict(recoil=1),               # 抠坏/浮动另案（卡重生成+motion driver）
}

cfg = json.load(open(P, encoding="utf-8"))
for k, patch in PATCH.items():
    assert k in cfg, k
    cfg[k].update(patch)
json.dump(cfg, open(P, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("patched", len(PATCH), "units →", P)
