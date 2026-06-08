#!/usr/bin/env python3
"""
修复 card_resource.gd 中 for 循环内的缩进问题
"""

from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent

def fix_card_resource_detailed():
    """修复 card_resource.gd 中的详细缩进问题"""
    file_path = PROJECT_ROOT / "resources" / "card_resource.gd"

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 修复第 378-379 行：for 循环内的 if 语句需要额外缩进
    # 原始：\tif weapon is WeaponResource:\n\t\tnew_card.weapon_slots.append(weapon.duplicate())
    # 应该是：\tif weapon is WeaponResource:\n\t\t\tnew_card.weapon_slots.append(weapon.duplicate())
    content = content.replace(
        "\tfor weapon in weapon_slots:\n\tif weapon is WeaponResource:\n\tnew_card.weapon_slots.append(weapon.duplicate())",
        "\tfor weapon in weapon_slots:\n\t\tif weapon is WeaponResource:\n\t\t\tnew_card.weapon_slots.append(weapon.duplicate())"
    )

    # 修复第 393-395 行：for 循环内的 if 语句需要额外缩进
    content = content.replace(
        "\tfor s in module_slots:\n\tif s is ModuleSlot:\n\tnew_card.module_slots.append(s.duplicate_slot())",
        "\tfor s in module_slots:\n\t\tif s is ModuleSlot:\n\t\t\tnew_card.module_slots.append(s.duplicate_slot())"
    )

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f"已修复 {file_path}")

if __name__ == "__main__":
    fix_card_resource_detailed()
    print("完成！")
