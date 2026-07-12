#!/usr/bin/env python3
"""
敌方卡牌数值重新标定工具 (Phase War v8.1)

策略：锚点缩放法
  - 定义每个 (era, tier) 的目标 HP 中位数（标准曲线，严格时代递进）
  - 计算当前 (era, tier) 中位数 → 目标中位数的缩放因子
  - 每张卡的 HP × 缩放因子（保留卡牌间相对差异：虎式仍比黑豹强）
  - 攻击/防御按新 HP 等比缩放（保持 DPS/HP 和 def/HP 比率）
  - 特殊处理：ULIMATE 卡因当前分布混乱（fut_stormcore 700 vs fut_arm_nexus 2000），
    直接锚定到固定值

同时修正：
  - weapon_type ∈ [0,3] 范围检查（新4值枚举）
  - 确保时代严格递进
"""

import re
import sys
import json
from collections import defaultdict

# ════════════════════════════════════════════════════════════════════════
# 标准 HP 曲线（目标中位数）
# 每个时代严格递增，每个档次严格递增
# ════════════════════════════════════════════════════════════════════════
# [WW1, WW2, ColdWar, Modern, NearFut]
TARGET_HP_MEDIAN = {
    'GRUNT':     [100, 150, 210, 280, 370],
    'VETERAN':   [170, 250, 360, 500, 720],
    'ELITE':     [300, 440, 620, 900, 1300],
    'CHAMPION':  [450, 620, 860, 1150, 1600],
    'BOSS':      [650, 1000, 1400, 1800, 2500],
    'ULTIMATE':  [2800, 2800, 2800, 2800, 3000],  # 仅近未来有
    'FORT':      [600, 900, 1250, 1700, 2500],
}

# DPS/HP 比率目标（按 tier，DPS 相对于 HP 的比例）
# 格式：该 tier 的 "总三维DPS" = HP × ratio
DPS_HP_RATIO = {
    'GRUNT':     0.45,   # 杂兵：低 DPS/HP（脆但输出有限）
    'VETERAN':   0.40,
    'ELITE':     0.38,
    'CHAMPION':  0.42,
    'BOSS':      0.45,
    'ULTIMATE':  0.35,
    'FORT':      0.30,   # 堡垒：低 DPS/HP（肉盾）
}

# 三维攻击分配比例 [attack_light, attack_armor, attack_air]（按 combat_kind）
ATK_RATIO = {
    0: [1.0, 0.3, 0.0],   # LIGHT 步兵
    1: [0.3, 1.0, 0.0],   # ARMOR 装甲
    2: [0.6, 1.0, 0.3],   # SUPPORT 支援/炮兵
    3: [0.5, 0.5, 1.0],   # AIR 空中
    4: [0.7, 1.2, 0.5],   # FORT 堡垒
}

# 攻速（次/秒）按 combat_kind [light, armor, air]
SPEED_BY_CK = {
    0: [1.5, 1.0, 1.0],
    1: [0.67, 0.5, 0.5],
    2: [1.0, 0.5, 2.5],
    3: [0.83, 0.67, 1.0],
    4: [1.0, 0.5, 2.0],
}

# 防御/HP 比率（防御值相对于 HP 的比例，按 combat_kind）
DEF_HP_RATIO = {
    0: 0.07,   # 步兵
    1: 0.10,   # 装甲
    2: 0.06,   # 支援
    3: 0.06,   # 空中
    4: 0.08,   # 堡垒
}

# 三维防御分配 [def_l, def_a, def_air]（按 combat_kind）
DEF_RATIO = {
    0: [1.0, 0.5, 0.3],
    1: [0.7, 1.0, 0.6],
    2: [0.5, 0.7, 0.3],
    3: [0.6, 0.4, 1.0],
    4: [1.3, 1.3, 1.2],
}

# windup/active 基础值（按攻速派生）
def calc_windup(spd):
    """攻速越快前摇越短"""
    if spd <= 0:
        return 0.2
    return round(max(0.05, min(0.6, 1.0 / (spd * 5))), 3)

def calc_active(spd):
    """动作时间 = windup × 0.5"""
    return round(calc_windup(spd) * 0.5, 3)


def median(values):
    """计算中位数"""
    if not values:
        return 0
    s = sorted(values)
    n = len(s)
    if n % 2 == 1:
        return s[n // 2]
    return (s[n // 2 - 1] + s[n // 2]) / 2


def parse_entry(raw):
    """解析 GDScript 卡牌条目为字段字典"""
    fields = {}
    # 匹配 "key":value
    for m in re.finditer(r'"(\w+)":([^,}]+)', raw):
        key = m.group(1)
        val = m.group(2).strip().rstrip(',')
        fields[key] = val
    # 检测 enemy_only 标记（无值的 bool）
    if 'enemy_only' in raw and 'enemy_only' not in fields:
        fields['enemy_only'] = 'true'
    return fields


def recalibrate():
    input_file = 'data/unified_card_table.gd'

    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # 提取 _TABLE
    table_start = content.find('const _TABLE: Array = [')
    table_end_marker = '\n]\n'
    table_end = content.find(table_end_marker, table_start)
    if table_start < 0 or table_end < 0:
        print("ERROR: Could not find _TABLE boundaries")
        sys.exit(1)

    table_header = content[table_start:table_start + len('const _TABLE: Array = [\n')]
    table_body = content[table_start + len('const _TABLE: Array = [\n'):table_end]
    after_table = content[table_end + len(table_end_marker):]

    # 提取所有卡牌条目（每条以 {"card_id" 开始）
    # 需要保留注释行
    raw_lines = table_body.split('\n')

    # 重新组织：按卡牌条目分段，保留注释
    entries = []  # list of (comment_lines, entry_text)
    current_comments = []
    current_entry = []
    in_entry = False

    for line in raw_lines:
        stripped = line.strip()
        if stripped.startswith('#') or stripped.startswith('//'):
            if in_entry:
                # 注释出现在条目内部（罕见），跳过
                pass
            else:
                current_comments.append(line)
        elif stripped.startswith('{"card_id"'):
            in_entry = True
            current_entry = [line]
        elif in_entry:
            current_entry.append(line)
            if stripped.endswith('},') or stripped == '},':
                entries.append((current_comments, '\n'.join(current_entry)))
                current_comments = []
                current_entry = []
                in_entry = False
        elif stripped == '':
            # 空行在条目之间，归入注释
            if not in_entry and current_entry == []:
                current_comments.append(line)
        else:
            # 其他行（如注释内的内容）
            current_comments.append(line)

    print(f"Found {len(entries)} card entries")

    # 第一遍：解析所有卡牌，计算 (era, tier) 当前中位数
    all_cards = []
    for i, (comments, raw) in enumerate(entries):
        f = parse_entry(raw)
        card = {
            'index': i,
            'comments': comments,
            'raw': raw,
            'fields': f,
            'card_id': f.get('card_id', ''),
            'era': int(f.get('era', 0)),
            'tier': f.get('tier', 'Tier.GRUNT').replace('Tier.', ''),
            'ck': int(f.get('combat_kind', 0)),
            'hp': float(f.get('base_hp', 100)),
            'enemy_only': f.get('enemy_only', '') == 'true',
        }
        all_cards.append(card)

    # 计算当前 (era, tier) HP 中位数
    current_medians = defaultdict(list)
    for c in all_cards:
        current_medians[(c['era'], c['tier'])].append(c['hp'])

    current_median_val = {}
    for key, hps in current_medians.items():
        current_median_val[key] = median(hps)

    # 第二遍：计算缩放因子并重新标定
    new_entries = []
    stats = {'recalibrated': 0, 'unchanged': 0}

    for c in all_cards:
        era = c['era']
        tier = c['tier']
        ck = c['ck']
        old_hp = c['hp']

        # 目标中位数
        target_med = TARGET_HP_MEDIAN.get(tier, [100]*5)[era]
        # 当前中位数
        cur_med = current_median_val.get((era, tier), old_hp)

        # 缩放因子
        if cur_med > 0:
            scale = target_med / cur_med
        else:
            scale = 1.0

        # 限制缩放幅度，防止极端值。高 tier 允许更大缩放（B段低HP卡需大幅提升）
        max_scale = {'GRUNT': 1.8, 'VETERAN': 2.0, 'ELITE': 2.5, 'CHAMPION': 2.5,
                     'BOSS': 3.0, 'ULTIMATE': 4.0, 'FORT': 2.0}.get(tier, 2.0)
        scale = max(0.5, min(max_scale, scale))

        # 新 HP
        new_hp = int(round(old_hp * scale))
        new_hp = max(50, new_hp)  # 下限 50

        # DPS 总量 = new_hp × DPS_HP_RATIO
        total_dps = new_hp * DPS_HP_RATIO.get(tier, 0.40)

        # 三维攻击 = total_dps × ratio / speed（伤害 = DPS / 攻速）
        speeds = SPEED_BY_CK.get(ck, SPEED_BY_CK[0])
        ratios = ATK_RATIO.get(ck, [1.0, 0.3, 0.0])
        atk_values = []
        for i in range(3):
            dim_dps = total_dps * ratios[i]
            spd = speeds[i]
            dmg = dim_dps / spd if spd > 0 else 0
            atk_values.append(max(0, round(dmg)))

        # 三维防御
        total_def = new_hp * DEF_HP_RATIO.get(ck, 0.07)
        def_ratios = DEF_RATIO.get(ck, [1.0, 0.5, 0.3])
        def_values = [max(0, round(total_def * r)) for r in def_ratios]

        # 构建新条目
        f = c['fields']
        new_raw = build_entry(f, new_hp, atk_values, def_values, speeds, c['enemy_only'])

        new_entries.append((c['comments'], new_raw))
        if abs(scale - 1.0) > 0.05:
            stats['recalibrated'] += 1
        else:
            stats['unchanged'] += 1

    # 重建 table_body
    new_table_lines = []
    for comments, raw in new_entries:
        for cl in comments:
            new_table_lines.append(cl)
        new_table_lines.append(raw)
        new_table_lines.append('')

    new_table_body = '\n'.join(new_table_lines)

    # 重建完整文件
    new_content = content[:table_start] + table_header + '\n' + new_table_body + '\n]\n' + after_table

    with open(input_file, 'w', encoding='utf-8') as f:
        f.write(new_content)

    print(f"Recalibration complete: {stats['recalibrated']} recalibrated, {stats['unchanged']} ~unchanged")

    # 打印 era progression 验证
    print("\n=== Post-recalibration era progression (HP median by tier×era) ===")
    new_medians = defaultdict(list)
    for c in all_cards:
        era = c['era']
        tier = c['tier']
        target_med = TARGET_HP_MEDIAN.get(tier, [100]*5)[era]
        cur_med = current_median_val.get((era, tier), c['hp'])
        max_scale = {'GRUNT': 1.8, 'VETERAN': 2.0, 'ELITE': 2.5, 'CHAMPION': 2.5,
                     'BOSS': 3.0, 'ULTIMATE': 4.0, 'FORT': 2.0}.get(tier, 2.0)
        scale = max(0.5, min(max_scale, target_med / cur_med if cur_med > 0 else 1.0))
        new_hp = max(50, int(round(c['hp'] * scale)))
        new_medians[(era, tier)].append(new_hp)

    for tier in ['GRUNT', 'VETERAN', 'ELITE', 'CHAMPION', 'BOSS', 'ULTIMATE', 'FORT']:
        row = f'{tier:<12}'
        for era in range(5):
            hps = new_medians.get((era, tier), [])
            if hps:
                med = int(median(hps))
                target = TARGET_HP_MEDIAN.get(tier, [0]*5)[era]
                row += f' era{era}:{med}(→{target})  '
            else:
                row += f' era{era}:-           '
        print(row)


def build_entry(f, new_hp, atk_values, def_values, speeds, enemy_only):
    """从字段构建新的 GDScript 卡牌条目"""
    card_id = f.get('card_id', '')
    display_name = f.get('display_name', card_id)
    era = f.get('era', '0')
    ck = f.get('combat_kind', '0')
    tier = f.get('tier', 'Tier.GRUNT')
    range_value = f.get('range_value', '3')
    deploy_speed = f.get('deploy_speed', '3')
    base_speed = f.get('base_speed', '80')
    power = f.get('power', '10')
    weapon_type = f.get('weapon_type', '0')
    weapon_label = f.get('weapon_label', '')
    w_light = f.get('w_light', '')
    w_armor = f.get('w_armor', '')
    w_air = f.get('w_air', '')

    # 确保引号正确处理
    def fmt_str(s):
        return s.strip().strip('"').strip("'")

    spd_l, spd_a, spd_air = speeds
    windup_l = calc_windup(spd_l)
    windup_a = calc_windup(spd_a)
    windup_air = calc_windup(spd_air)
    active_l = calc_active(spd_l)
    active_a = calc_active(spd_a)
    active_air = calc_active(spd_air)

    # fmt floats
    def fmt_num(v):
        if isinstance(v, float) and v == int(v):
            return str(int(v))
        return str(v)

    atk_l, atk_a, atk_air = atk_values
    def_l, def_a, def_air = def_values

    eo_str = '"enemy_only":true,' if enemy_only else ''

    lines = [
        f'\t{{"card_id":"{fmt_str(card_id)}","display_name":"{fmt_str(display_name)}","era":{era},"combat_kind":{ck},"tier":{tier},',
        f'\t "base_hp":{new_hp},"range_value":{range_value},"deploy_speed":{deploy_speed},"base_speed":{fmt_num(float(base_speed))},"power":{power},"weapon_type":{weapon_type},',
        f'\t "weapon_label":"{fmt_str(weapon_label)}",{eo_str}',
        f'\t "atk_l":{atk_l},"atk_l_speed":{spd_l},"atk_l_windup":{windup_l},"atk_l_active":{active_l},',
        f'\t "atk_a":{atk_a},"atk_a_speed":{spd_a},"atk_a_windup":{windup_a},"atk_a_active":{active_a},',
        f'\t "atk_air":{atk_air},"atk_air_speed":{spd_air},"atk_air_windup":{windup_air},"atk_air_active":{active_air},',
        f'\t "def_l":{def_l},"def_a":{def_a},"def_air":{def_air},',
        f'\t "w_light":"{fmt_str(w_light)}","w_armor":"{fmt_str(w_armor)}","w_air":"{fmt_str(w_air)}"}},',
    ]
    return '\n'.join(lines)


if __name__ == '__main__':
    recalibrate()
