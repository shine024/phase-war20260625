# -*- coding: utf-8 -*-
import json, io, sys, re
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

with open('tools/_mycard_ids.json', encoding='utf-8') as f:
    mycards = json.load(f)
with open('tools/_icon_standard_mapping.json', encoding='utf-8') as f:
    std = json.load(f)

# enemy num -> (card_id, name)
en = {}
for cid,v in std.items():
    if v['icon_num'] is not None:
        en[v['icon_num']] = (cid, v['display_name'])

with open('data/default_cards.gd', encoding='utf-8') as f:
    dc = f.read()
meta = {}
for m in re.finditer(r'_unit\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*(\d+)\s*,\s*(\d+)', dc):
    meta[m.group(1)] = {'era':int(m.group(3)),'kind':int(m.group(4)),'name':m.group(2)}

# manifest 命中的（跳过）
FOE_PLATFORM = ["ww1_arm_rolls","ww1_arm_ft17","ww1_arty_77mm","ww1_inf_cavalry","ww1_sup_engineer","ww2_inf_hellcat","ww2_arm_sherman","ww2_arm_tiger","ww2_inf_bazooka","ww2_inf_panzerschrek","ww2_arty_m81","ww1_arty_m81","cold_inf_btr60","cold_arm_t55","cold_inf_bmp1","cold_sup_m113","cold_sup_zsu23","mod_inf_technical","mod_arm_m1a1","mod_sup_m6","mod_arty_m270","mod_inf_scout_drone","mod_arm_m1a2sep","fut_inf_scout_mech","fut_arm_hovertank","fut_arm_prism","fut_arm_heavy_mech","fut_arm_nexus"]
manifest_ids = set(FOE_PLATFORM + ["ww1_arty_m81","ww2_arty_m81","fut_inf_scout_mech","fut_arm_heavy_mech","fut_arm_hovertank","fut_arm_prism","fut_arm_nexus","mod_arm_m1a2sep","mod_inf_scout_drone"] + [c['card_id'] for c in mycards if c['card_id'] in (set(std.keys()))])

# 我手工设计的语义匹配表: 我方card_id -> enemy num
# 原则: 同时代+同类型+名称最接近的 enemy 图
PROPOSE = {
 # 一战 轻装步兵 → 用 ww1 步兵图
 "ww1_mp18": 36,        # ww1_inf_mp18 步兵班·MP18 ← 完美同名!
 "ww1_mauser": 37,      # ww1_inf_rifle 步兵班·步枪
 "ww1_enfield": 37,     # ww1_inf_rifle 步兵班·步枪 (李恩菲尔德=步枪)
 "ww1_storm": 40,       # ww1_inf_storm_e 暴风突击队 ← 完美同名!
 "ww1_flame": 36,       # 步兵班 (无火焰兵图，用步兵)
 # 一战 支援/火炮
 "ww1_mg08": 38,        # ww1_sup_mg_nest 机枪巢
 "ww1_vickers": 38,     # ww1_sup_mg_nest 机枪巢
 "ww1_m76": 39,         # ww1_arty_mortar 迫击炮组
 "ww1_105mm": 3,        # 77mm野战炮 (重炮用炮图)
 "ww1_37mm": 3,         # 野战炮 (高射炮无专属，用炮)
 # 一战 装甲
 "ww1_lanchest": 1,     # 罗尔斯装甲车 (同类轮式装甲车)
 "ww1_saint": 42,       # ww1_boss_av7 圣沙蒙坦克! ← 完美 (圣沙蒙=Saint Chamond)
 "ww1_a7v": 42,         # 圣沙蒙坦克 (同期重型坦克)
 "ww1_mark4": 41,       # ww1_arm_rolls_e 装甲车 (无马克图，用同期)
 # 二战 轻装
 "ww2_thompson": 43,    # ww2_inf_thompson 步兵班·汤普森! ← 完美同名
 "ww2_garand": 44,      # ww2_inf_garand 步枪班·加兰德! ← 完美同名
 "ww2_mp40": 43,        # 汤普森 (冲锋枪班)
 "ww2_ppsh": 43,        # 汤普森
 # 二战 支援
 "ww2_mg42": 45,        # ww2_sup_mg42 MG42机枪组! ← 完美同名
 "ww2_browning": 45,    # MG42 (机枪组)
 "ww2_m120": 11,        # 81mm迫击炮 (重迫击炮)
 # 二战 装甲
 "ww2_pz3": 7,          # 谢尔曼 (中型坦克)
 "ww2_pz4": 7,          # 谢尔曼
 "ww2_panther": 48,     # ww2_arm_panther_e 黑豹坦克! ← 完美同名
 "ww2_kingtiger": 49,   # ww2_boss_kingtiger 虎王坦克! ← 完美同名
 "ww2_t34_76": 7,       # 谢尔曼 (中型坦克通用)
 "ww2_t34_85": 7,       # 谢尔曼
 "ww2_is2": 8,          # 虎式 (重型坦克)
 # 冷战 轻装
 "cold_rpg": 46,        # ww2 反坦克组 (火箭筒)
 "cold_ak47": 50,       # cold_inf_ak 苏军步兵! AK47
 "cold_m14": 51,        # cold_inf_m60 美军步兵
 "cold_m60": 45,        # MG42 (机枪班，用机枪图)
 "cold_rpk": 45,        # 机枪
 "cold_spetsnaz": 54,   # cold_inf_spetsnaz_e 特种部队! ← 完美
 # 冷战 装甲
 "cold_bradley": 53,    # cold_air_m113_e M113 (步战车)
 "cold_t62": 55,        # cold_arm_t72_e T-72 (苏系坦克)
 "cold_t72": 55,        # cold_arm_t72_e T-72! ← 完美同名
 "cold_m60t": 52,       # cold_arm_btr_e BTR装甲车 (美系)
 "cold_m1": 52,         # BTR (无M1冷战图)
 "cold_leo1": 52,       # BTR
 "cold_chieftain": 55,  # T-72 (重型坦克)
 "cold_sam7": 17,       # ZSU-23 (防空)
 # 冷战 空中
 "cold_mig21": 56,      # cold_boss_mig 米格-29! ← 米格系列
 "cold_f4": 56,         # 米格 (战机)
 # 现代 轻装/支援
 "mod_marine": 57,      # mod_inf_marine 海军陆战队! ← 完美同名
 "mod_ranger": 61,      # mod_inf_delta_e 三角洲部队 (精锐步兵)
 "mod_javelin": 46,     # 反坦克组 (导弹兵)
 "mod_stinger": 63,     # mod_air_apache_e 阿帕奇 (防空导弹→飞行器)
 "mod_hummer_tow": 58,  # mod_air_technical_e 皮卡武装 (轮式)
 "mod_hummer_m2": 58,   # 皮卡武装 (轮式)
 # 现代 装甲
 "mod_stryker_mgs": 59, # mod_arm_stryker_e 斯特赖克! ← 完美同名
 "mod_stryker_m2": 59,  # 斯特赖克
 "mod_m1a2": 62,        # mod_arm_abrams_e M1A2坦克! ← 完美同名
 "mod_t90": 55,         # T-72 (苏系现代坦克)
 "mod_leo2a6": 62,      # M1A2 (西方主战坦克)
 "mod_challenger2": 62, # M1A2
 # 现代 空中
 "mod_ah64": 63,        # mod_air_apache_e 阿帕奇! ← 完美同名
 "mod_ah1": 63,         # 阿帕奇 (武装直升机)
 "mod_uh60": 63,        # 阿帕奇 (直升机通用)
 # 近未来
 "fut_swarm": 65,       # fut_air_drone 无人机群! ← 完美
 "fut_attack_drone": 65,# 无人机群
 "fut_cyborg": 66,      # fut_inf_cyborg 机械步兵! ← 完美同名
 "fut_heavy_trooper": 66,# 机械步兵
 "fut_assault_mech": 67,# fut_arm_mech_e 机甲步兵
 "fut_howitzer": 60,    # mod_arty_mlrs_e 火箭炮车 (自行火炮)
 "fut_aa_hover": 60,    # 火箭炮
 "fut_stealth_bomber": 65,# 无人机 (飞行器)
 "fut_space_fighter": 65,# 无人机
 "fut_spectre": 69,     # fut_inf_spectre_e 幽灵特工! ← 完美同名
 "fut_nano_drone": 65,  # 无人机
 "fut_shield": 81,      # fut_fort_shield 能量护盾! ← 完美
 "fut_colossus": 70,    # fut_arm_colossus_e 巨神机甲! ← 完美同名
 "fut_stormcore": 71,   # fut_boss_nexus 风暴核心! ← 完美 (风暴核心原型)
 "fut_arm_omega": 70,   # 巨神机甲 (重型机甲)
}

# 输出建议
print("===== 74张回退卡 → 专属图 建议映射 =====")
print("%-24s %-16s %-8s -> %-6s %s" % ("我方card_id","名称","现用","建议","enemy图名称"))
print("-"*90)
for c in mycards:
    cid = c['card_id']; name = c['name']
    if cid in FOE_PLATFORM or cid in ("ww1_arty_m81","ww2_arty_m81"):
        continue
    # 判断是否 manifest 命中
    m = meta.get(cid)
    if cid not in PROPOSE:
        # 检查是不是命中的
        if cid in std:
            continue
        print(f"  [遗漏] {cid} {name}")
        continue
    n = PROPOSE[cid]
    eid, ename = en.get(n, ('???','???'))
    # 现用编号
    ERA_KIND = {"0_0":4,"0_1":1,"0_2":3,"0_3":15,"0_4":3,"1_0":9,"1_1":7,"1_2":11,"1_3":22,"1_4":11,"2_0":18,"2_1":14,"2_2":16,"2_3":15,"2_4":16,"3_0":18,"3_1":19,"3_2":20,"3_3":22,"3_4":20,"4_0":24,"4_1":25,"4_2":20,"4_3":22,"4_4":25}
    ek = "%d_%d"%(m['era'],m['kind'])
    cur = ERA_KIND.get(ek,'?')
    perfect = "★完美" if name == ename or ename in name or name in ename else ""
    print("%-24s %-16s %03d     -> %03d    %s %s" % (cid, name, cur, n, ename, perfect))
