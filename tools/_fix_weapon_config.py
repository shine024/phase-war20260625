#!/usr/bin/env python3
"""批量修复武器配置（B1~B5）。
直接修改 data/unified_card_table.gd 的武器字段。

修复策略：
- B1 防空槽有名字但atk_air=0：按武器类型给标准 atk_air 值
  * 便携式防空导弹/点防御激光（专用防空）→ atk_l 的 50%
  * 12.7mm/14.5mm重机枪/车载机枪（辅助防空）→ atk_l 的 20%
  * 20mm机炮/25mm机炮（防空炮）→ atk_l 的 30%
  * 40mm榴弹（榴弹防空弱）→ atk_l 的 15%
  * "机枪"（笼统）→ atk_l 的 15%
- B2 时代错乱：替换为同时代合理武器
- B3 荒谬武器名：替换为合理武器
- B4 weapon_label 矛盾：改为匹配单位身份
- B5 有攻值但武器名为无：给合理武器名
"""
import re
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FP = os.path.join(ROOT, "data", "unified_card_table.gd")

with open(FP, "r", encoding="utf-8") as f:
    text = f.read()

original = text
changes = []


def fix_entry(cid, field, old_val, new_val):
    """在 card_id=cid 的条目内替换 field 的值。"""
    global text
    old_val = str(old_val)
    new_val = str(new_val)
    # 匹配 "card_id":"cid" ... "field":"old_val"
    # 需要在同一条目内，用非贪婪匹配到 w_air 行为止（每条目最后一行是 w_light/w_armor/w_air）
    pattern = r'("card_id":"' + re.escape(cid) + r'"[^}]*?"' + re.escape(field) + r'":")' + re.escape(old_val) + r'(")'
    new_text, n = re.subn(pattern, r'\g<1>' + new_val + r'\g<2>', text, count=1, flags=re.S)
    if n > 0:
        text = new_text
        changes.append(f"B: {cid}.{field}: '{old_val}' -> '{new_val}'")
        return True
    else:
        # 数值字段（无引号）— field 后是 ": 而非 :
        pattern2 = r'("card_id":"' + re.escape(cid) + r'"[^}]*?"' + re.escape(field) + r'":)' + re.escape(str(old_val)) + r'([,}])'
        new_text2, n2 = re.subn(pattern2, r'\g<1>' + str(new_val) + r'\g<2>', text, count=1, flags=re.S)
        if n2 > 0:
            text = new_text2
            changes.append(f"B: {cid}.{field}: {old_val} -> {new_val}")
            return True
    changes.append(f"!! MISS: {cid}.{field}: '{old_val}'")
    return False


# ════════════════════════════════════════
# B1: 防空槽有名字但 atk_air=0 → 给合理 atk_air
# 按武器类型分配标准比例
# ════════════════════════════════════════
# 格式: (card_id, w_air武器名, atk_air新值)
B1_FIXES = [
    # 便携式防空导弹/点防御激光（专用防空，atk_l的50%）
    ("cold_spetsnaz", "便携式防空导弹", 30),      # atk_l=60 → 30
    ("mod_ranger", "便携式防空导弹", 108),         # atk_l=215 → 108
    ("mod_javelin", "便携式防空导弹", 76),         # atk_l=152 → 76
    ("mod_inf_technical", "便携式防空导弹", 67),   # atk_l=133 → 67
    ("mod_hummer_tow", "便携式防空导弹", 64),      # atk_l=128 → 64
    ("fut_heavy_trooper", "便携式防空导弹", 152),  # atk_l=304 → 152
    ("fut_inf_scout_mech", "点防御激光", 133),     # atk_l=266 → 133
    # 12.7mm/14.5mm 重机枪/车载机枪（辅助防空，atk_l的20%）
    ("cold_m60", "12.7mm重机枪", 18),             # atk_l=92 → 18
    ("cold_rpk", "12.7mm重机枪", 18),             # atk_l=90 → 18
    ("cold_inf_btr60", "14.5mm车载机枪", 18),     # atk_l=89 → 18
    ("cold_inf_bmp1", "14.5mm车载机枪", 19),      # atk_l=97 → 19
    ("cold_bradley", "14.5mm车载机枪", 21),       # atk_l=105 → 21
    ("mod_hummer_m2", "12.7mm重机枪", 28),        # atk_l=138 → 28
    ("ww1_arm_rolls", "14.5mm车载机枪", 11),      # atk_l=55 → 11
    ("ww1_lanchest", "14.5mm车载机枪", 11),       # atk_l=53 → 11
    ("fut_spectre", "12.7mm重机枪", 48),          # atk_l=241 → 48
    # 20mm/25mm 机炮（防空炮，atk_l的30%）
    ("mod_stryker_m2", "20mm机炮", 109),          # atk_l=362 → 109
    ("fut_assault_mech", "20mm机炮", 103),        # atk_l=344 → 103
    ("fut_arm_heavy_mech", "20mm机炮", 125),      # atk_l=417 → 125
    ("fut_arm_hovertank", "20mm机炮", 96),        # atk_l=319 → 96
    ("fut_arm_prism", "25mm M242大毒蛇", 85),     # atk_l=282 → 85
    ("fut_colossus", "25mm M242大毒蛇", 141),     # atk_l=470 → 141
    ("fut_arm_omega", "25mm M242大毒蛇", 141),    # atk_l=470 → 141
    # 40mm榴弹（防空弱，atk_l的15%）
    ("fut_arm_nexus", "40mm榴弹", 74),            # atk_l=495 → 74
    ("fut_boss_nexus", "40mm榴弹", 76),           # atk_l=504 → 76
    # "机枪"（笼统，atk_l的15%）
    ("ww1_boss_av7", "机枪", 20),                 # atk_l=131 → 20
    ("ww2_boss_kingtiger", "机枪", 30),           # atk_l=201 → 30
]

for cid, wname, new_atk_air in B1_FIXES:
    fix_entry(cid, "atk_air", 0, new_atk_air)


# ════════════════════════════════════════
# B2: 时代错乱武器替换
# ════════════════════════════════════════
# ww1_fort_pillbox: w_air MG42(二战) → 马克沁机枪(一战)
fix_entry("ww1_fort_pillbox", "w_air", "MG42/双联防空炮", "马克沁重机枪/双联防空枪架")
# ww2_fort_flak: w_air 离子炮(近未来) → 高射炮(二战)
fix_entry("ww2_fort_flak", "w_air", "离子炮", "双联37mm高射炮")
# cold_fort_missile: w_armor 离子炮 → 反舰导弹(冷战)
fix_entry("cold_fort_missile", "w_armor", "离子炮", "反舰巡航导弹")
# mod_fort_phalanx: w_air 离子炮阵列(近未来) → 密集阵近防炮(现代)
fix_entry("mod_fort_phalanx", "w_air", "离子炮阵列", "密集阵20mm近防炮")


# ════════════════════════════════════════
# B3: 荒谬武器名替换
# ════════════════════════════════════════
# 飞机/直升机不该有127mm舰炮 → 改为合理武器
# cold_mig21/cold_f4: w_air "空空导弹/20mm机炮" 已经合理，但w_light含"地狱火导弹/127mm舰炮"
fix_entry("cold_mig21", "w_light", "空空导弹/20mm机炮", "23mm航炮")
fix_entry("cold_mig21", "w_armor", "空空导弹/20mm机炮", "23mm航炮")
fix_entry("cold_f4", "w_light", "空空导弹/20mm机炮", "20mm航炮")
fix_entry("cold_f4", "w_armor", "空空导弹/20mm机炮", "20mm航炮")
# mod_ah64/mod_ah1: w_light/w_armor "地狱火导弹/127mm舰炮" → "地狱火导弹/30mm链炮"
fix_entry("mod_ah64", "w_light", "地狱火导弹/127mm舰炮", "地狱火导弹/30mm链炮")
fix_entry("mod_ah64", "w_armor", "地狱火导弹/127mm舰炮", "地狱火导弹/30mm链炮")
fix_entry("mod_ah1", "w_light", "地狱火导弹/127mm舰炮", "地狱火导弹/20mm链炮")
fix_entry("mod_ah1", "w_armor", "地狱火导弹/127mm舰炮", "地狱火导弹/20mm链炮")
fix_entry("mod_ah64", "weapon_label", "地狱火导弹/127mm舰炮", "地狱火导弹/30mm链炮")
fix_entry("mod_ah1", "weapon_label", "地狱火导弹/127mm舰炮", "地狱火导弹/20mm链炮")
# fut_attack_drone: "地狱火导弹/127mm舰炮" → "地狱火导弹/激光"
fix_entry("fut_attack_drone", "w_light", "地狱火导弹/127mm舰炮", "地狱火导弹/激光炮")
fix_entry("fut_attack_drone", "w_armor", "地狱火导弹/127mm舰炮", "地狱火导弹/激光炮")
# fut_space_fighter: w_light "地狱火导弹/127mm舰炮" → "空天导弹/粒子炮"
fix_entry("fut_space_fighter", "w_light", "地狱火导弹/127mm舰炮", "空天导弹/粒子炮")
# 再生骨架 主武器"手枪" → "激光炮"
fix_entry("fut_air_regen_frame", "weapon_label", "手枪", "激光炮")
fix_entry("fut_air_regen_frame", "w_light", "手枪", "激光炮")


# ════════════════════════════════════════
# B4: weapon_label 与单位身份矛盾
# ════════════════════════════════════════
# 机枪巢/组标注火炮 → 改为机枪
fix_entry("ww1_mg08", "weapon_label", "81mm/105mm火炮", "MG08重机枪")
fix_entry("ww1_vickers", "weapon_label", "81mm/105mm火炮", "维克斯重机枪")
fix_entry("ww2_mg42", "weapon_label", "105mm/120mm榴弹炮", "MG42通用机枪")
fix_entry("ww2_browning", "weapon_label", "81mm/105mm火炮", "勃朗宁重机枪")
# 高射炮标注迫击炮 → 改为高射炮
fix_entry("ww1_37mm", "weapon_label", "迫击炮/野战炮", "37mm高射炮")
fix_entry("cold_sup_zsu23", "weapon_label", "迫击炮/野战炮", "23mm自行高射炮")
fix_entry("mod_sup_m6", "weapon_label", "81mm/105mm火炮", "40mm自行高射炮")
fix_entry("fut_aa_hover", "weapon_label", "迫击炮/野战炮", "防空激光炮")
# M113 不是火炮 → 改为机枪（已是装甲类）
fix_entry("cold_sup_m113", "weapon_label", "81mm/105mm火炮", "12.7mm车载机枪")
# 标枪导弹兵标注M4卡宾枪 → 改为标枪导弹
fix_entry("mod_javelin", "weapon_label", "M4卡宾枪", "标枪反坦克导弹")
# 近防炮系统标注要塞炮 → 改为近防炮
fix_entry("mod_fort_phalanx", "weapon_label", "150mm要塞炮/88mm防空炮", "密集阵近防炮系统")


# ════════════════════════════════════════
# B5: 有攻值但武器名为"无"/空 → 给合理武器名
# ════════════════════════════════════════
fix_entry("ww1_sup_ford_ambulance", "weapon_label", "无", "自卫手枪/急救设备")
fix_entry("ww1_sup_ford_ambulance", "w_light", "手枪", "自卫手枪")
fix_entry("ww2_sup_gmc_truck", "weapon_label", "无", "自卫武器/补给设备")
fix_entry("ww2_sup_gmc_truck", "w_light", "手枪", "自卫手枪")
fix_entry("cold_arm_p18", "weapon_label", "无", "雷达电子战设备")
fix_entry("cold_fort_radar", "weapon_label", "无", "雷达侦测/电子对抗系统")
fix_entry("fut_nano_drone", "weapon_label", "", "纳米修复射线")
fix_entry("fut_nano_drone", "w_light", "", "纳米修复射线")
fix_entry("fut_shield", "weapon_label", "", "能量护盾发生器")
fix_entry("fut_shield", "w_light", "", "能量护盾发生器")
fix_entry("fut_fort_shield", "weapon_label", "", "能量护盾发生器")


# ════════════════════════════════════════
# B4 补充：w_armor 槽 copy-paste 错误
# ════════════════════════════════════════
# mod_stinger w_armor="M4卡宾枪"(copy w_light) → "毒刺防空导弹"
fix_entry("mod_stinger", "w_armor", "M4卡宾枪", "毒刺防空导弹")
# mod_hummer_m2 w_armor="M4卡宾枪" → "12.7mm重机枪"
fix_entry("mod_hummer_m2", "w_armor", "M4卡宾枪", "12.7mm重机枪")


# ════════════════════════════════════════
# 输出结果
# ════════════════════════════════════════
if text != original:
    with open(FP, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"=== 修改完成: {len([c for c in changes if not c.startswith('!!')])} 处 ===")
    for c in changes:
        print(c)
    misses = [c for c in changes if c.startswith("!!")]
    if misses:
        print(f"\n!!! {len(misses)} 处未匹配（需手动检查）:")
        for m in misses:
            print(m)
else:
    print("无修改")
