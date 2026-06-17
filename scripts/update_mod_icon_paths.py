"""
Batch update icon paths for infantry_mods.gd and armor_mods.gd.

Strategy: For each mod entry, find icon line and slot_type line,
then replace the icon path based on slot_type.
"""
import re, os

INFANTRY_FILE = r"data\modification_modules\infantry_mods.gd"
ARMOR_FILE = r"data\modification_modules\armor_mods.gd"

SLOT_TYPE_MAP = {
    "weapon": "mod_weapon",
    "ammunition": "mod_ammunition",
    "optics": "mod_optics",
    "ergonomics": "mod_ergonomics",
    "armor": "mod_armor",
    "helmet": None,
    "mobility": "mod_mobility",
    "shield": "mod_shield",
    "exoskeleton": "mod_exoskeleton",
    "medical": "mod_medical",
    "comms": None,
    "environment": "mod_environment",
    "active": None,
    "gun": "mod_gun",
    "autoloader": "mod_autoloader",
    "engine": "mod_engine",
    "fire_control": "mod_fire_control",
    "engineering": "mod_engineering",
    "command": "mod_command",
}

ICON_BASE = "res://assets/ui/icons/mod_icons/"

def process_file(filepath):
    """Process a mod file and update icon paths."""
    with open(filepath, "r", encoding="utf-8") as f:
        lines = f.readlines()

    missing_slots = set()
    updated = 0
    i = 0

    while i < len(lines):
        line = lines[i]
        # Find icon line
        icon_match = re.match(r'^(\s+)icon\s*=\s*"([^"]+)"', line)
        if icon_match:
            indent = icon_match.group(1)
            old_path = icon_match.group(2)

            # Look ahead for slot_type within next 20 lines
            slot_type = None
            for j in range(i+1, min(i+25, len(lines))):
                slot_match = re.match(r'^\s+slot_type\s*=\s*"([^"]+)"', lines[j])
                if slot_match:
                    slot_type = slot_match.group(1)
                    break

            if slot_type:
                icon_filename = SLOT_TYPE_MAP.get(slot_type)
                if icon_filename is None:
                    missing_slots.add(slot_type)
                else:
                    new_path = f"{ICON_BASE}{icon_filename}.png"
                    lines[i] = f'{indent}icon = "{new_path}",\n'
                    updated += 1
        i += 1

    with open(filepath, "w", encoding="utf-8") as f:
        f.writelines(lines)

    print(f"Updated {os.path.basename(filepath)}: {updated} icon paths changed")
    if missing_slots:
        print(f"  Missing slot_types: {missing_slots}")

    return missing_slots


def main():
    all_missing = set()
    for filepath in [INFANTRY_FILE, ARMOR_FILE]:
        missing = process_file(filepath)
        all_missing.update(missing)

    print(f"\n{'='*50}")
    print(f"Total missing slot_types: {all_missing}")
    return all_missing


if __name__ == "__main__":
    main()
