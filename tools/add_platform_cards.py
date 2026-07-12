#!/usr/bin/env python3
"""
为统一表添加28张A段平台卡（platform_*）

这些卡是敌方平台部署系统用的，之前靠 enemy_unit_manifest.gd 硬编码 fallback。
现在统一加入 unified_card_table.gd 的 _TABLE，按标准曲线标定数值。

平台卡特性：
  - enemy_only = true（不在玩家商店出售）
  - era 和 combat_kind 从 manifest 硬编码值派生
  - tier 按 platform 类型映射（light→GRUNT, medium→VETERAN, heavy→ELITE, 等）
"""

import re

# 平台卡定义：从 manifest 硬编码值派生 era/combat_kind/tier/display_name
# tier 映射规则：
#   light/scout/raider/stealth → GRUNT (轻装侦察)
#   medium → VETERAN (中型)
#   heavy/guard_heavy → ELITE (重型)
#   fort/fortress/siege → FORT (堡垒/攻城)
#   radar → SUPPORT-GRUNT (雷达/支援)
#   medic → SUPPORT-GRUNT (医疗)
#   carrier/ifv → VETERAN (载具)

# HP 曲线 [WW1, WW2, ColdWar, Modern, NearFut]
HP_BASE = {
    'GRUNT':     [100, 150, 210, 280, 370],
    'VETERAN':   [170, 250, 360, 500, 720],
    'ELITE':     [300, 440, 620, 900, 1300],
    'FORT':      [600, 900, 1250, 1700, 2500],
}

# era 映射
ERA_MAP = {'ww1': 0, 'ww2': 1, 'cold': 2, 'modern': 3, 'future': 4}

# 平台卡定义
# (platform_key, era_prefix, combat_kind, tier, display_name, weapon_label, weapon_type, deploy_speed, base_speed, range_value)
PLATFORM_CARDS = [
    # 一战
    ('platform_ww1_light', 'ww1', 0, 'GRUNT', '一战轻型平台', '冲锋枪', 0, 5, 115, 1),
    ('platform_ww1_medium', 'ww1', 1, 'VETERAN', '一战中型平台', '机枪', 0, 3, 80, 2),
    ('platform_ww1_fort', 'ww1', 2, 'FORT', '一战炮台平台', '机枪', 0, 0, 0, 2),
    ('platform_ww1_radar', 'ww1', 2, 'GRUNT', '一战雷达平台', '机枪', 3, 0, 0, 2),
    ('platform_ww1_medic', 'ww1', 2, 'GRUNT', '一战医疗平台', '步枪', 3, 4, 75, 1),
    # 二战
    ('platform_ww2_light', 'ww2', 0, 'GRUNT', '二战轻型平台', '冲锋枪', 0, 5, 135, 1),
    ('platform_ww2_medium', 'ww2', 1, 'VETERAN', '二战中型平台', '步枪', 0, 4, 75, 2),
    ('platform_ww2_heavy', 'ww2', 1, 'ELITE', '二战重型平台', '坦克炮', 1, 2, 40, 2),
    ('platform_ww2_raider', 'ww2', 0, 'GRUNT', '二战突袭平台', '机枪', 0, 5, 100, 2),
    ('platform_ww2_radar', 'ww2', 2, 'GRUNT', '二战雷达平台', '步枪', 3, 0, 0, 2),
    ('platform_ww2_siege', 'ww2', 2, 'FORT', '二战攻城平台', '火炮', 1, 0, 0, 2),
    ('platform_ww2_fortress', 'ww2', 4, 'FORT', '二战要塞平台', '机枪', 0, 0, 0, 2),
    # 冷战
    ('platform_cold_light', 'cold', 0, 'GRUNT', '冷战轻型平台', '冲锋枪', 0, 5, 115, 1),
    ('platform_cold_medium', 'cold', 1, 'VETERAN', '冷战中型平台', '火炮', 1, 3, 80, 2),
    ('platform_cold_ifv', 'cold', 3, 'VETERAN', '冷战步战车平台', '机枪', 2, 4, 90, 2),
    ('platform_cold_scout', 'cold', 0, 'GRUNT', '冷战侦察平台', '冲锋枪', 0, 6, 135, 1),
    ('platform_cold_radar', 'cold', 2, 'GRUNT', '冷战雷达平台', '步枪', 3, 0, 0, 2),
    ('platform_cold_carrier', 'cold', 3, 'VETERAN', '冷战运输平台', '机枪', 2, 3, 90, 2),
    # 现代
    ('platform_modern_light', 'modern', 0, 'GRUNT', '现代轻型平台', '冲锋枪', 0, 5, 115, 1),
    ('platform_modern_medium', 'modern', 1, 'VETERAN', '现代中型平台', '火炮', 1, 3, 75, 2),
    ('platform_modern_radar', 'modern', 2, 'GRUNT', '现代雷达平台', '步枪', 3, 0, 0, 2),
    ('platform_modern_spg', 'modern', 2, 'FORT', '现代自行火炮平台', '火炮', 1, 0, 0, 2),
    ('platform_modern_stealth', 'modern', 0, 'GRUNT', '现代隐形平台', '冲锋枪', 0, 6, 115, 1),
    ('platform_modern_guard_heavy', 'modern', 1, 'ELITE', '现代重型卫戍平台', '轨道炮', 1, 2, 75, 3),
    # 近未来
    ('platform_future_light', 'future', 0, 'GRUNT', '近未来轻型平台', '光束步枪', 0, 5, 115, 2),
    ('platform_future_medium', 'future', 1, 'VETERAN', '近未来中型平台', '光束步枪', 0, 4, 100, 2),
    ('platform_future_radar', 'future', 2, 'GRUNT', '近未来雷达平台', '光束步枪', 3, 0, 0, 2),
    ('platform_future_heavy', 'future', 1, 'ELITE', '近未来重型平台', '粒子炮', 1, 1, 50, 3),
]

# ATK_RATIO by combat_kind [light, armor, air]
ATK_RATIO = {
    0: [1.0, 0.3, 0.0],
    1: [0.3, 1.0, 0.0],
    2: [0.6, 1.0, 0.3],
    3: [0.5, 0.5, 1.0],
    4: [0.7, 1.2, 0.5],
}

# SPEED by combat_kind [light, armor, air]
SPEED_BY_CK = {
    0: [1.5, 1.0, 1.0],
    1: [0.67, 0.5, 0.5],
    2: [1.0, 0.5, 2.5],
    3: [0.83, 0.67, 1.0],
    4: [1.0, 0.5, 2.0],
}

# DEF_HP_RATIO by combat_kind
DEF_HP_RATIO = {0: 0.07, 1: 0.10, 2: 0.06, 3: 0.06, 4: 0.08}
DEF_RATIO = {
    0: [1.0, 0.5, 0.3],
    1: [0.7, 1.0, 0.6],
    2: [0.5, 0.7, 0.3],
    3: [0.6, 0.4, 1.0],
    4: [1.3, 1.3, 1.2],
}
DPS_HP_RATIO = {'GRUNT': 0.45, 'VETERAN': 0.40, 'ELITE': 0.38, 'FORT': 0.30}

def calc_windup(spd):
    if spd <= 0:
        return 0.2
    return round(max(0.05, min(0.6, 1.0 / (spd * 5))), 3)

def calc_active(spd):
    return round(calc_windup(spd) * 0.5, 3)


def build_platform_entry(card):
    key, era_prefix, ck, tier, display_name, weapon_label, weapon_type, deploy_speed, base_speed, range_value = card
    era = ERA_MAP[era_prefix]

    hp = HP_BASE[tier][era]
    total_dps = hp * DPS_HP_RATIO[tier]
    speeds = SPEED_BY_CK[ck]
    ratios = ATK_RATIO[ck]

    atk_values = []
    for i in range(3):
        dim_dps = total_dps * ratios[i]
        spd = speeds[i]
        dmg = dim_dps / spd if spd > 0 else 0
        atk_values.append(max(0, round(dmg)))

    total_def = hp * DEF_HP_RATIO[ck]
    def_ratios = DEF_RATIO[ck]
    def_values = [max(0, round(total_def * r)) for r in def_ratios]

    spd_l, spd_a, spd_air = speeds
    atk_l, atk_a, atk_air = atk_values
    def_l, def_a, def_air = def_values

    windup_l = calc_windup(spd_l)
    windup_a = calc_windup(spd_a)
    windup_air = calc_windup(spd_air)
    active_l = calc_active(spd_l)
    active_a = calc_active(spd_a)
    active_air = calc_active(spd_air)

    # power
    total_def_sum = def_l + def_a + def_air
    power = max(10, int(hp * 0.3 + total_dps * 2.0 + total_def_sum * 1.5 + base_speed * 0.1))

    tier_full = f'Tier.{tier}'

    lines = [
        f'\t{{"card_id":"{key}","display_name":"{display_name}","era":{era},"combat_kind":{ck},"tier":{tier_full},',
        f'\t "base_hp":{hp},"range_value":{range_value},"deploy_speed":{deploy_speed},"base_speed":{int(base_speed)},"power":{power},"weapon_type":{weapon_type},',
        f'\t "weapon_label":"{weapon_label}","enemy_only":true,',
        f'\t "atk_l":{atk_l},"atk_l_speed":{spd_l},"atk_l_windup":{windup_l},"atk_l_active":{active_l},',
        f'\t "atk_a":{atk_a},"atk_a_speed":{spd_a},"atk_a_windup":{windup_a},"atk_a_active":{active_a},',
        f'\t "atk_air":{atk_air},"atk_air_speed":{spd_air},"atk_air_windup":{windup_air},"atk_air_active":{active_air},',
        f'\t "def_l":{def_l},"def_a":{def_a},"def_air":{def_air},',
        f'\t "w_light":"{weapon_label}","w_armor":"","w_air":""}},',
    ]
    return '\n'.join(lines)


def main():
    input_file = 'data/unified_card_table.gd'

    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # 找到 _TABLE 的结束位置（第一个 \n]\n 之后）
    table_end_marker = '\n]\n'
    # 找到 _TABLE 内最后一个 }, 之后的位置
    # 实际上找 "]\n" 在 _TABLE 区域
    table_start = content.find('const _TABLE: Array = [')
    if table_start < 0:
        print("ERROR: _TABLE not found")
        return

    # 从 table_start 找第一个 '\n]\n'
    search_from = table_start + 100
    table_end_idx = content.find('\n]\n', search_from)
    if table_end_idx < 0:
        print("ERROR: _TABLE end not found")
        return

    # 在 table_end 之前插入平台卡
    platform_entries = []
    platform_entries.append('\n\t# ══════════════ A段平台卡（enemy_only，敌方部署用）v8.1 新增 ══════════════')

    for card in PLATFORM_CARDS:
        platform_entries.append(build_platform_entry(card))

    platform_block = '\n'.join(platform_entries) + '\n'

    # 插入到 _TABLE 结束 ] 之前
    new_content = content[:table_end_idx] + platform_block + content[table_end_idx:]

    with open(input_file, 'w', encoding='utf-8') as f:
        f.write(new_content)

    print(f"Added {len(PLATFORM_CARDS)} platform cards to _TABLE")


if __name__ == '__main__':
    main()
