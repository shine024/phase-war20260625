#!/usr/bin/env python3
"""
Generate a Chinese weapon config table for all battle cards in default_cards.gd.
Reads the _unit() calls from default_cards.gd and extracts per-target (light/armor/air) stats.
"""
import re

with open(r"D:\godotplay\godot fair duel\phase-war\data\default_cards.gd", "r", encoding="utf-8") as f:
    content = f.read()

# Find all _unit() calls
pattern = r'_unit\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'
pattern += r'(\d+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*'
pattern += r'(\d+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*'
pattern += r'(\d+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*'
pattern += r'(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)'

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
    atk_l_windup = float(m.group(12))
    atk_l_active = float(m.group(13))
    
    atk_a = int(m.group(14))
    atk_a_speed = float(m.group(15))
    atk_a_windup = float(m.group(16))
    atk_a_active = float(m.group(17))
    
    atk_air = int(m.group(18))
    atk_air_speed = float(m.group(19))
    atk_air_windup = float(m.group(20))
    atk_air_active = float(m.group(21))
    
    def_l = int(m.group(22))
    def_a = int(m.group(23))
    def_air = int(m.group(24))
    
    era_names = ["一战", "二战", "冷战", "现代", "近未"]
    kind_names = ["轻装", "装甲", "支援", "空中", "堡垒"]
    
    # Infer weapon label from per-target attacks
    weapon_parts = []
    if atk_l > 0:
        if atk_a > 0 or atk_air > 0:
            weapon_parts.append("步枪/机枪")
        else:
            weapon_parts.append("步枪/机枪")
    if atk_a > 0:
        if weapon_parts and weapon_parts[-1] != "步枪/机枪":
            pass
        elif not weapon_parts:
            weapon_parts.append("步枪/机枪")
    if atk_air > 0:
        if combat_kind == 3:
            weapon_parts.append("防空导弹/高炮")
        elif atk_air > 100:
            weapon_parts.append("重型火箭/导弹")
        else:
            weapon_parts.append("防空导弹/高炮")
    
    # range=99 → 曲射, combat_kind=3 → 空射
    if range_val >= 99 and (atk_l + atk_a + atk_air > 0):
        fire_mode = "曲射"
    elif combat_kind == 3:
        fire_mode = "空射"
    elif range_val == 0 and (atk_l + atk_a + atk_air == 0):
        fire_mode = "辅助"
    else:
        fire_mode = "直射"
    
    cards.append({
        "id": card_id,
        "name": name,
        "era": era_names[era],
        "combat_kind": kind_names[combat_kind],
        "range": range_val,
        "hp": hp,
        "atk_l": atk_l, "atk_l_speed": atk_l_speed,
        "atk_a": atk_a, "atk_a_speed": atk_a_speed,
        "atk_air": atk_air, "atk_air_speed": atk_air_speed,
        "def_l": def_l, "def_a": def_a, "def_air": def_air,
        "weapon_label": "/".join(weapon_parts) if weapon_parts else "无",
        "fire_mode": fire_mode,
        "power": power,
    })

# Sort by combat_kind, then era
era_order = {"一战": 0, "二战": 1, "冷战": 2, "现代": 3, "近未": 4}
combat_kind_order = ["轻装", "装甲", "支援", "空中", "堡垒"]

cards.sort(key=lambda c: (combat_kind_order.index(c["combat_kind"]), era_order[c["era"]]))

# Generate table
lines = []
lines.append("战斗卡默认武器配置表（含三种武器槽位数据）")
lines.append("=" * 120)
lines.append("")
lines.append("图例:")
lines.append("  武器槽位：[轻装] [装甲] [对空] 三列，分别对应该卡对三类敌人的伤害值")
lines.append("  S=攻速(次/秒) | 射程99=全图曲射 | 辅助=无攻击能力")
lines.append("  数值为0 = 该武器槽位无攻击能力")
lines.append("")

for kind in combat_kind_order:
    kind_cards = [c for c in cards if c["combat_kind"] == kind]
    lines.append("-" * 120)
    lines.append(f"  [{kind}]  共 {len(kind_cards)} 张")
    lines.append("-" * 120)
    
    # Header
    lines.append(f"  {'时代':>4}  {'ID':>18}  |  {'中文名':<12} | {'模式':>4} | {'[轻装] 伤害/攻速':>16} | {'[装甲] 伤害/攻速':>16} | {'[对空] 伤害/攻速':>16}")
    lines.append(f"  {'---':>4}  {'---'*3:>20}  |  {'---':<12} | {'---':>4} | {'---'*4:>18} | {'---'*4:>18} | {'---'*4:>18}")
    
    for c in kind_cards:
        atk_l_str = f"{c['atk_l']}/S{c['atk_l_speed']:.2f}" if c['atk_l'] > 0 else "-"
        atk_a_str = f"{c['atk_a']}/S{c['atk_a_speed']:.2f}" if c['atk_a'] > 0 else "-"
        atk_air_str = f"{c['atk_air']}/S{c['atk_air_speed']:.2f}" if c['atk_air'] > 0 else "-"
        
        lines.append(f"  {c['era']:>4}  {c['id']:>18}  |  {c['name']:<12} | {c['fire_mode']:>4} | {atk_l_str:>16} | {atk_a_str:>16} | {atk_air_str:>16}")
    
    lines.append("")

lines.append("=" * 120)
lines.append("")
lines.append(f"── 总计: {len(cards)} 张战斗卡（含能量卡）")
lines.append("")
lines.append("── 武器槽位说明 ──")
lines.append("  [轻装] 该单位对轻装类敌人的攻击力 + 攻速")
lines.append("  [装甲] 该单位对装甲类敌人的攻击力 + 攻速")
lines.append("  [对空] 该单位对空中类敌人的攻击力 + 攻速")
lines.append("  数值为0或'-'表示该武器槽位无攻击能力")
lines.append("")
lines.append("── 攻击类型 ──")
lines.append("  直射: 有射程衰减，攻击范围内最近敌人")
lines.append("  曲射: 全图攻击（range=99），无视距离衰减")
lines.append("  空射: 空中单位全图攻击，可被防空拦截")
lines.append("  辅助: 无攻击能力（力场发生器/雷达站/能量护盾/纳米修复机）")
lines.append("")

out = "\n".join(lines)
print(out)

# Also write to file
with open(r"D:\godotplay\godot fair duel\phase-war\docs\战斗卡默认武器配置表_含三种武器.md", "w", encoding="utf-8") as f:
    f.write(out)

print("\n--- Written to docs/战斗卡默认武器配置表_含三种武器.md ---")
