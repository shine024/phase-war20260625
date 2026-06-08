#!/usr/bin/env python3
"""
重写 default_cards.gd 中 _unit 函数的武器槽位代码块，使用正确的缩进
"""

from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent

# 正确的武器槽位代码块
WEAPON_SLOTS_CODE = '''
\t# === 武器槽位系统（v6.0）===
\t# 初始化三个槽位（轻装/装甲/对空）
\tc.weapon_slots = []
\t# 轻装武器槽位
\tif atk_l > 0:
\t\tvar w_light = WeaponResource.create_from_legacy(
\t\t\t0, atk_l, atk_l_speed, atk_l_windup, atk_l_active,
\t\t\tc.weapon_type, range
\t\t)
\t\tw_light.weapon_id = id + "_slot_light"
\t\tw_light.display_name = _get_weapon_label(c.weapon_type)
\t\tc.weapon_slots.append(w_light)
\telse:
\t\tc.weapon_slots.append(WeaponResource.create_empty_slot(0))
\t# 装甲武器槽位
\tif atk_a > 0:
\t\tvar w_armor = WeaponResource.create_from_legacy(
\t\t\t1, atk_a, atk_a_speed, atk_a_windup, atk_a_active,
\t\t\tc.weapon_type, range
\t\t)
\t\tw_armor.weapon_id = id + "_slot_armor"
\t\tw_armor.display_name = _get_weapon_label(c.weapon_type)
\t\tc.weapon_slots.append(w_armor)
\telse:
\t\tc.weapon_slots.append(WeaponResource.create_empty_slot(1))
\t# 对空武器槽位
\tif atk_air > 0:
\t\tvar w_air = WeaponResource.create_from_legacy(
\t\t\t2, atk_air, atk_air_speed, atk_air_windup, atk_air_active,
\t\t\tc.weapon_type, range
\t\t)
\t\tw_air.weapon_id = id + "_slot_air"
\t\tw_air.display_name = _get_weapon_label(c.weapon_type)
\t\tc.weapon_slots.append(w_air)
\telse:
\t\tc.weapon_slots.append(WeaponResource.create_empty_slot(2))

'''

def rewrite_weapon_slots():
    """重写武器槽位代码块"""
    file_path = PROJECT_ROOT / "data" / "default_cards.gd"

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 找到 c.is_unlocked = false 后的换行
    marker = '\tc.is_unlocked = false\n'
    if marker in content:
        # 替换从 c.is_unlocked = false 到 return c 之间的所有内容
        parts = content.split(marker, 1)
        if len(parts) == 2:
            # 找到 return c 的位置
            rest = parts[1]
            return_pos = rest.find('\n\treturn c')
            if return_pos != -1:
                # 重写中间部分
                new_content = parts[0] + marker + WEAPON_SLOTS_CODE + rest[return_pos:]
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print(f"已修复 {file_path}")
                return

    print("未找到预期的代码位置")

if __name__ == "__main__":
    rewrite_weapon_slots()
    print("完成！")
