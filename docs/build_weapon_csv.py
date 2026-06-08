#!/usr/bin/env python3
"""
Generate a CSV with 3 weapon slots per card, each with weapon name + damage/speed.
Weapon names are mapped from per-target attack stats using the WeaponTypeLegacy lookup.
"""
import re
import csv

# ── WeaponTypeLegacy mapping: (damage range, speed range, context) → Chinese weapon name ──
# Based on _WEAPON_BASE in unit_stats_table.gd:
# 0=SMG(8 dmg), 1=RIFLE(14), 2=MG(7), 3=ROCKET(30), 4=PISTOL(7), 5=SHOTGUN(22), 6=SNIPER(22),
# 7=FLAK(9), 8=LASER(13), 9=MISSILE(38), 10=OMEGA_CANNON(220), 11=RAIL_CANNON(140)
#
# We map per-target damage (base, before era scaling) to the closest legacy weapon type.

def get_weapon_name_legacy(slot_type, atk_dmg):
    """Given slot type (0=light, 1=armor, 2=air) and base damage, return Chinese weapon name."""
    if atk_dmg == 0:
        return None
    
    # Slot-type specific defaults for low-dmg infantry weapons
    if slot_type == 0:  # 轻装
        if atk_dmg >= 200:   return "植入式自动步枪"
        if atk_dmg >= 150:   return "重型粒子步枪"
        if atk_dmg >= 100:   return "M4卡宾枪"
        if atk_dmg >= 80:    return "M16A4步枪"
        if atk_dmg >= 50:    return "AK-47突击步枪"
        if atk_dmg >= 40:    return "MP18冲锋枪"
        if atk_dmg >= 25:    return "毛瑟步枪"
        if atk_dmg >= 20:    return "李恩菲尔德步枪"
        if atk_dmg >= 10:    return "冲锋枪"
        return "轻武器"
    
    elif slot_type == 1:  # 装甲
        if atk_dmg >= 400:   return "重型等离子加农炮"
        if atk_dmg >= 300:   return "攻城电磁炮"
        if atk_dmg >= 200:   return "120mm滑膛炮"
        if atk_dmg >= 150:   return "120mm主炮"
        if atk_dmg >= 100:   return "105mm主炮"
        if atk_dmg >= 80:    return "85mm主炮"
        if atk_dmg >= 60:    return "75mm主炮"
        if atk_dmg >= 50:    return "77mm野战炮"
        if atk_dmg >= 40:    return "57mm坦克炮"
        if atk_dmg >= 30:    return "37mm反坦克炮"
        if atk_dmg >= 15:    return "火箭筒"
        if atk_dmg >= 10:    return "机枪"
        return "轻型装甲武器"
    
    elif slot_type == 2:  # 对空
        if atk_dmg >= 300:   return "点防御激光"
        if atk_dmg >= 200:   return "近防炮"
        if atk_dmg >= 150:   return "23mm高射炮"
        if atk_dmg >= 100:   return "防空导弹"
        if atk_dmg >= 60:    return "萨姆-7导弹"
        if atk_dmg >= 50:    return "37mm高射炮"
        if atk_dmg >= 40:    return "防空机枪"
        if atk_dmg >= 20:    return "小口径高炮"
        if atk_dmg >= 10:    return "便携式防空导弹"
        return "对空武器"
    
    return "武器"


def get_vehicle_weapon_name(combat_kind, atk_dmg):
    """For vehicle units (tanks, APCs), use vehicle-appropriate weapon names."""
    if atk_dmg == 0:
        return None
    
    if combat_kind == 1:  # 装甲/坦克
        if atk_dmg >= 500:   return "重型等离子炮"
        if atk_dmg >= 300:   return "120mm主炮"
        if atk_dmg >= 200:   return "120mm滑膛炮"
        if atk_dmg >= 150:   return "105mm/120mm主炮"
        if atk_dmg >= 100:   return "105mm主炮"
        if atk_dmg >= 80:    return "85mm主炮"
        if atk_dmg >= 60:    return "75mm/100mm主炮"
        if atk_dmg >= 50:    return "75mm主炮"
        if atk_dmg >= 40:    return "57mm/75mm坦克炮"
        if atk_dmg >= 30:    return "37mm/50mm坦克炮"
        if atk_dmg >= 15:    return "73mm/90mm反坦克炮"
        if atk_dmg >= 10:    return "12.7mm车载机枪"
        return "坦克主炮"
    
    elif combat_kind == 2:  # 支援/防空
        if atk_dmg >= 250:   return "25mm近防炮"
        if atk_dmg >= 150:   return "23mm高射炮"
        if atk_dmg >= 80:    return "20mm/25mm高炮"
        if atk_dmg >= 60:    return "12.7mm重机枪"
        if atk_dmg >= 40:    return "75mm/105mm火炮"
        if atk_dmg >= 30:    return "40mm火炮"
        if atk_dmg >= 20:    return "14.5mm机枪"
        if atk_dmg >= 10:    return "20mm高射炮"
        return "火炮"
    
    elif combat_kind == 3:  # 空中
        if atk_dmg >= 300:   return "轨道炮"
        if atk_dmg >= 200:   return "等离子炮"
        if atk_dmg >= 150:   return "地狱火导弹"
        if atk_dmg >= 100:   return "空空导弹"
        if atk_dmg >= 60:    return "R-3空空导弹"
        if atk_dmg >= 40:    return "20mm机炮"
        if atk_dmg >= 20:    return "7.62mm舱门机枪"
        return "机载武器"
    
    elif combat_kind == 4:  # 堡垒
        if atk_dmg >= 200:   return "离子炮"
        if atk_dmg >= 100:   return "多管近防炮"
        if atk_dmg >= 80:    return "88mm防空炮"
        if atk_dmg >= 60:    return "150mm要塞炮"
        if atk_dmg >= 50:    return "双联高射炮"
        if atk_dmg >= 40:    return "MG42/防空炮"
        return "要塞武器"
    
    return "武器"


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
    power = int(m.group(5))
    deploy_speed = int(m.group(6))
    range_val = int(m.group(7))
    energy_cost = int(m.group(8))
    hp = int(m.group(9))
    
    atk_l = int(m.group(10))
    atk_l_speed = float(m.group(11))
    atk_a = int(m.group(14))
    atk_a_speed = float(m.group(15))
    atk_air = int(m.group(18))
    atk_air_speed = float(m.group(19))
    
    def_l = int(m.group(22))
    def_a = int(m.group(23))
    def_air = int(m.group(24))
    
    # Determine fire mode
    total_atk = atk_l + atk_a + atk_air
    if range_val >= 99 and total_atk > 0:
        fire_mode = "曲射"
    elif combat_kind == 3:
        fire_mode = "空射"
    elif range_val == 0 and total_atk == 0:
        fire_mode = "辅助"
    else:
        fire_mode = "直射"
    
    # Determine weapon names for each slot
    if combat_kind == 0:  # 轻装步兵
        w_light = get_weapon_name_legacy(0, atk_l)
        w_armor = get_vehicle_weapon_name(1, atk_a) if atk_a > 0 else None
        w_air = get_vehicle_weapon_name(2, atk_air) if atk_air > 0 else None
    elif combat_kind == 1:  # 装甲
        w_light = get_vehicle_weapon_name(1, atk_l)
        w_armor = get_vehicle_weapon_name(1, atk_a)
        w_air = get_vehicle_weapon_name(3, atk_air) if atk_air > 0 else None
    elif combat_kind == 2:  # 支援
        w_light = get_vehicle_weapon_name(2, atk_l)
        w_armor = get_vehicle_weapon_name(2, atk_a)
        w_air = get_vehicle_weapon_name(2, atk_air)
    elif combat_kind == 3:  # 空中
        w_light = get_vehicle_weapon_name(3, atk_l)
        w_armor = get_vehicle_weapon_name(3, atk_a)
        w_air = get_vehicle_weapon_name(3, atk_air)
    elif combat_kind == 4:  # 堡垒
        w_light = get_vehicle_weapon_name(4, atk_l)
        w_armor = get_vehicle_weapon_name(4, atk_a)
        w_air = get_vehicle_weapon_name(4, atk_air)
    else:
        w_light = get_weapon_name_legacy(0, atk_l)
        w_armor = get_vehicle_weapon_name(1, atk_a) if atk_a > 0 else None
        w_air = get_vehicle_weapon_name(2, atk_air) if atk_air > 0 else None
    
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

# Sort by combat_kind, then era
era_order = {"一战": 0, "二战": 1, "冷战": 2, "现代": 3, "近未": 4}
combat_kind_order = ["轻装", "装甲", "支援", "空中", "堡垒"]

cards.sort(key=lambda c: (combat_kind_order.index(c["combat_kind"]), era_order[c["era"]]))

# Write CSV
csv_path = r"D:\godotplay\godot fair duel\phase-war\docs\战斗卡武器配置.csv"
with open(csv_path, "w", encoding="utf-8-sig", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["", "ID", "中文名", "时代", "战斗定位", "攻击模式",
                       "武器1(轻装) - 武器名", "武器1 - 伤害", "武器1 - 攻速",
                       "武器2(装甲) - 武器名", "武器2 - 伤害", "武器2 - 攻速",
                       "武器3(对空) - 武器名", "武器3 - 伤害", "武器3 - 攻速",
                       "HP", "防御(轻/装/空)"])
    
    for c in cards:
        # Slot 1: 轻装
        w1_name = c["w_light"] if c["w_light"] else ""
        w1_dmg = c["atk_l"]
        w1_speed = c["atk_l_speed"]
        
        # Slot 2: 装甲
        w2_name = c["w_armor"] if c["w_armor"] else ""
        w2_dmg = c["atk_a"]
        w2_speed = c["atk_a_speed"]
        
        # Slot 3: 对空
        w3_name = c["w_air"] if c["w_air"] else ""
        w3_dmg = c["atk_air"]
        w3_speed = c["atk_air_speed"]
        
        writer.writerow([
            "", c["id"], c["name"], c["era"], c["combat_kind"], c["fire_mode"],
            w1_name, w1_dmg, f"{w1_speed:.2f}",
            w2_name, w2_dmg, f"{w2_speed:.2f}",
            w3_name, w3_dmg, f"{w3_speed:.2f}",
            "", "", ""
        ])

print(f"CSV written: {csv_path}")
print(f"Total rows: {len(cards)}")
