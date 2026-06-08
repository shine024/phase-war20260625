#!/usr/bin/env python3
"""
Generate CSV with 3 weapon slots per card, each with weapon name + damage/speed.
"""
import re
import csv

# ── 武器名映射函数 ──

def _get_light_weapon(dmg):
    if dmg == 0: return ""
    if dmg <= 20: return "骑兵卡宾枪/马刀"
    if dmg <= 30: return "毛瑟G98步枪"
    if dmg <= 35: return "MP18冲锋枪"
    if dmg <= 45: return "暴风冲锋枪"
    if dmg <= 55: return "冲锋枪/步枪"
    if dmg <= 70: return "步枪/冲锋枪"
    if dmg <= 90: return "AK-47突击步枪"
    if dmg <= 110: return "M16A4步枪"
    if dmg <= 160: return "M4卡宾枪/SCAR-H"
    if dmg <= 220: return "植入式自动步枪/重型粒子炮"
    return "自动步枪"

def _get_armor_weapon_kind0(dmg):
    if dmg == 0: return ""
    if dmg <= 15: return "73mm/90mm反坦克炮"
    if dmg <= 25: return "火箭筒/轻型装甲武器"
    if dmg <= 90: return "85mm/105mm主炮"
    if dmg <= 120: return "120mm滑膛炮"
    if dmg <= 260: return "120mm/125mm主炮"
    return "120mm主炮"

def _get_air_weapon_kind0(dmg):
    if dmg == 0: return ""
    if dmg <= 15: return "便携式防空导弹"
    if dmg <= 22: return "20mm/25mm高炮"
    if dmg <= 40: return "防空机枪"
    if dmg <= 60: return "12.7mm重机枪"
    if dmg <= 220: return "萨姆-7导弹/防空导弹"
    return "防空导弹"

def _get_armor_weapon_kind1(dmg):
    if dmg == 0: return ""
    if dmg <= 22: return "37mm/57mm坦克炮"
    if dmg <= 35: return "57mm/75mm坦克炮"
    if dmg <= 45: return "75mm/76mm坦克炮"
    if dmg <= 55: return "85mm主炮"
    if dmg <= 70: return "100mm主炮"
    if dmg <= 80: return "105mm主炮"
    if dmg <= 110: return "105mm/120mm主炮"
    if dmg <= 135: return "122mm主炮"
    if dmg <= 180: return "125mm滑膛炮"
    if dmg <= 220: return "120mm/125mm主炮"
    if dmg <= 290: return "120mm主炮"
    if dmg <= 310: return "120mm L55主炮"
    if dmg <= 380: return "双联装电磁炮"
    if dmg <= 500: return "重型等离子加农炮"
    if dmg <= 550: return "攻城电磁炮"
    return "主炮"

def _get_air_weapon_kind1(dmg):
    if dmg == 0: return ""
    if dmg <= 40: return "14.5mm车载机枪"
    if dmg <= 70: return "20mm机炮"
    if dmg <= 100: return "25mm M242大毒蛇"
    return "40mm榴弹"

def _get_support_weapon(dmg):
    if dmg == 0: return ""
    if dmg <= 35: return "迫击炮/野战炮"
    if dmg <= 65: return "81mm/105mm火炮"
    if dmg <= 120: return "105mm/120mm榴弹炮"
    if dmg <= 180: return "227mm火箭炮"
    if dmg <= 280: return "电磁轨道炮"
    if dmg <= 600: return "等离子风暴发生器"
    return "火炮"

def _get_air_weapon_kind2(dmg):
    if dmg == 0: return ""
    if dmg <= 25: return "7.62mm/12.7mm高机枪"
    if dmg <= 45: return "20mm/25mm高炮"
    if dmg <= 150: return "23mm/30mm高射炮"
    if dmg <= 280: return "25mm近防炮"
    if dmg <= 400: return "点防御激光"
    return "防空导弹"

def _get_air_weapon_kind3(dmg):
    if dmg == 0: return ""
    if dmg <= 40: return "7.62mm舱门机枪/轻型机炮"
    if dmg <= 100: return "空空导弹/20mm机炮"
    if dmg <= 280: return "地狱火导弹/127mm舰炮"
    if dmg <= 350: return "轨道炮/激光"
    return "空载武器"

def _get_bunker_weapon(dmg):
    if dmg == 0: return ""
    if dmg <= 40: return "MG42/双联防空炮"
    if dmg <= 80: return "150mm要塞炮/88mm防空炮"
    if dmg <= 150: return "多管近防炮/88mm防空炮"
    if dmg <= 200: return "离子炮"
    if dmg <= 300: return "离子炮阵列"
    return "要塞武器"

# ── 读取 default_cards.gd ──

with open(r"D:\godotplay\godot fair duel\phase-war\data\default_cards.gd", "r", encoding="utf-8") as f:
    content = f.read()

pattern = r'_unit\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'
pattern += r'(\d+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*'
pattern += r'(\d+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*'
pattern += r'(\d+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*'
pattern += r'(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)'

era_names = ["一战", "二战", "冷战", "现代", "近未"]
kind_names = ["轻装", "装甲", "支援", "空中", "堡垒"]

cards = []
for m in re.finditer(pattern, content):
    card_id = m.group(1)
    name = m.group(2)
    era = int(m.group(3))
    combat_kind = int(m.group(4))
    range_val = int(m.group(7))
    hp = int(m.group(9))
    
    atk_l = int(m.group(10))
    atk_l_speed = float(m.group(11))
    atk_a = int(m.group(14))
    atk_a_speed = float(m.group(15))
    atk_air = int(m.group(18))
    atk_air_speed = float(m.group(19))
    
    total_atk = atk_l + atk_a + atk_air
    if range_val >= 99 and total_atk > 0:
        fire_mode = "曲射"
    elif combat_kind == 3:
        fire_mode = "空射"
    elif range_val == 0 and total_atk == 0:
        fire_mode = "辅助"
    else:
        fire_mode = "直射"
    
    w_light, w_armor, w_air = "", "", ""
    
    if total_atk > 0:
        if combat_kind == 0:  # 轻装
            w_light = _get_light_weapon(atk_l)
            w_armor = _get_armor_weapon_kind0(atk_a)
            w_air = _get_air_weapon_kind0(atk_air)
        elif combat_kind == 1:  # 装甲
            w_light = _get_armor_weapon_kind1(atk_l)
            w_armor = _get_armor_weapon_kind1(atk_a)
            w_air = _get_air_weapon_kind1(atk_air)
        elif combat_kind == 2:  # 支援
            w_light = _get_support_weapon(atk_l)
            w_armor = _get_support_weapon(atk_a)
            w_air = _get_air_weapon_kind2(atk_air)
        elif combat_kind == 3:  # 空中
            w_light = _get_air_weapon_kind3(atk_l)
            w_armor = _get_air_weapon_kind3(atk_a)
            w_air = _get_air_weapon_kind3(atk_air)
        elif combat_kind == 4:  # 堡垒
            w_light = _get_bunker_weapon(atk_l)
            w_armor = _get_bunker_weapon(atk_a)
            w_air = _get_bunker_weapon(atk_air)
    
    cards.append({
        "id": card_id,
        "name": name,
        "era": era_names[era],
        "combat_kind": kind_names[combat_kind],
        "fire_mode": fire_mode,
        "atk_l": atk_l, "atk_l_speed": atk_l_speed,
        "atk_a": atk_a, "atk_a_speed": atk_a_speed,
        "atk_air": atk_air, "atk_air_speed": atk_air_speed,
        "w_light": w_light, "w_armor": w_armor, "w_air": w_air,
    })

era_order = {"一战": 0, "二战": 1, "冷战": 2, "现代": 3, "近未": 4}
combat_kind_order = ["轻装", "装甲", "支援", "空中", "堡垒"]
cards.sort(key=lambda c: (combat_kind_order.index(c["combat_kind"]), era_order[c["era"]]))

csv_path = r"D:\godotplay\godot fair duel\phase-war\docs\战斗卡武器配置.csv"
with open(csv_path, "w", encoding="utf-8-sig", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["", "ID", "中文名", "时代", "战斗定位", "攻击模式",
                       "武器1(轻装) - 武器名", "武器1 - 伤害", "武器1 - 攻速",
                       "武器2(装甲) - 武器名", "武器2 - 伤害", "武器2 - 攻速",
                       "武器3(对空) - 武器名", "武器3 - 伤害", "武器3 - 攻速",
                       "HP", "防御(轻/装/空)"])
    
    for c in cards:
        writer.writerow([
            "", c["id"], c["name"], c["era"], c["combat_kind"], c["fire_mode"],
            c["w_light"], c["atk_l"], f"{c['atk_l_speed']:.2f}",
            c["w_armor"], c["atk_a"], f"{c['atk_a_speed']:.2f}",
            c["w_air"], c["atk_air"], f"{c['atk_air_speed']:.2f}",
            "", "", ""
        ])

print(f"CSV written: {csv_path}")
print(f"Total cards: {len(cards)}")
