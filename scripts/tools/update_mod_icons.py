#!/usr/bin/env python3
"""批量更新改造模块图标路径"""

import os
import re

ICON_DIR = r"F:\godot fair duet\create\phase-war\assets\ui\icons\mod_icons"
ICON_BASE = "res://assets/ui/icons/mod_icons/mod_"

FALLBACK_MAP = {
    "active": "armor_special",
    "deception": "stealth",
    "enemy_origin": "command",
    "enhancement": "fire_control",
    "fuze": "ammunition",
    "guidance": "radar",
    "helmet": "shield",
    "system": "command",
    "thrust": "engine",
    "weapons": "weapon_air",
}

DEFAULT_FALLBACK = "weapon"

MOD_FILES = [
    r"F:\godot fair duet\create\phase-war\data\modification_modules\infantry_mods.gd",
    r"F:\godot fair duet\create\phase-war\data\modification_modules\armor_mods.gd",
    r"F:\godot fair duet\create\phase-war\data\modification_modules\artillery_mods.gd",
    r"F:\godot fair duet\create\phase-war\data\modification_modules\anti_air_mods.gd",
    r"F:\godot fair duet\create\phase-war\data\modification_modules\air_mods.gd",
    r"F:\godot fair duet\create\phase-war\data\modification_modules\recon_mods.gd",
    r"F:\godot fair duet\create\phase-war\data\modification_modules\engineer_mods.gd",
    r"F:\godot fair duet\create\phase-war\data\modification_modules\fort_mods.gd",
    r"F:\godot fair duet\create\phase-war\data\modification_modules\universal_mods.gd",
    r"F:\godot fair duet\create\phase-war\data\modification_modules\enhancement_mods.gd",
]


def load_existing_icons():
    existing = set()
    if os.path.exists(ICON_DIR):
        for f in os.listdir(ICON_DIR):
            if f.endswith(".png") and not f.endswith(".import"):
                existing.add(f[:-4])
    return existing


def get_icon_path(slot_type, existing):
    if slot_type in existing:
        return ICON_BASE + slot_type + ".png"
    if slot_type in FALLBACK_MAP:
        fb = FALLBACK_MAP[slot_type]
        if fb in existing:
            return ICON_BASE + fb + ".png"
    return ICON_BASE + DEFAULT_FALLBACK + ".png"


def update_file(filepath, existing):
    with open(filepath, "r", encoding="utf-8") as f:
        lines = f.readlines()

    count = 0
    new_lines = []

    for i, line in enumerate(lines):
        new_lines.append(line)

        # 检查是否是 slot_type 行
        slot_match = re.search(r'slot_type\s*=\s*"([^"]+)"', line)
        if slot_match:
            slot_type = slot_match.group(1)
            icon_path = get_icon_path(slot_type, existing)

            # 检查下一行是否已有 icon
            if i + 1 < len(lines) and "icon" in lines[i + 1]:
                continue

            # 在 slot_type 行后面插入 icon 行
            indent = "\t\t"
            new_lines.append(indent + 'icon = "' + icon_path + '",\n')
            count += 1

    if count > 0:
        with open(filepath, "w", encoding="utf-8") as f:
            f.writelines(new_lines)

    return count


def main():
    existing = load_existing_icons()
    print(f"Found {len(existing)} existing icons")

    total = 0
    for filepath in MOD_FILES:
        if not os.path.exists(filepath):
            print(f"SKIP (not found): {os.path.basename(filepath)}")
            continue
        count = update_file(filepath, existing)
        if count > 0:
            print(f"Updated: {os.path.basename(filepath)} ({count} icons)")
        total += count

    print(f"\nTotal icons added: {total}")


if __name__ == "__main__":
    main()
