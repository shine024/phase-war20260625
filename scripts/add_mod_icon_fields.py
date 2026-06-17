"""
Add icon fields to all 80 mods that don't have them yet.
Scans all mod files, extracts slot_type for each mod, and inserts icon line.
"""
import os, re

MOD_DIR = r'data\modification_modules'

SLOT_TYPE_MAP = {
    "aerodynamics": "mod_aerodynamics",
    "ammunition": "mod_ammunition",
    "armor": "mod_armor",
    "autoloader": "mod_autoloader",
    "automation": "mod_automation",
    "barrel": "mod_barrel",
    "bridge": "mod_bridge",
    "command": "mod_command",
    "comms": "mod_comms",
    "countermeasure": "mod_countermeasure",
    "deception": "mod_deception",
    "demolition": "mod_demolition",
    "designator": "mod_designator",
    "digging": "mod_digging",
    "drone": "mod_drone",
    "ecm": "mod_ecm",
    "electronics": "mod_electronics",
    "engine": "mod_engine",
    "engineering": "mod_engineering",
    "enhancement": "mod_enhancement",
    "environment": "mod_environment",
    "ergonomics": "mod_ergonomics",
    "exoskeleton": "mod_exoskeleton",
    "fire_control": "mod_fire_control",
    "fortification": "mod_fortification",
    "fuze": "mod_fuze",
    "guidance": "mod_guidance",
    "gun": "mod_gun",
    "helmet": "mod_helmet",
    "laser": "mod_laser",
    "logistics": "mod_logistics",
    "medical": "mod_medical",
    "minefield": "mod_minefield",
    "missile": "mod_missile",
    "mobility": "mod_mobility",
    "mount": "mod_mount",
    "navigation": "mod_navigation",
    "network": "mod_network",
    "obstacle": "mod_obstacle",
    "optics": "mod_optics",
    "power": "mod_power",
    "protection": "mod_protection",
    "radar": "mod_radar",
    "recon": "mod_recon",
    "recovery": "mod_recovery",
    "repair": "mod_repair",
    "shield": "mod_shield",
    "stealth": "mod_stealth",
    "survival": "mod_survival",
    "system": "mod_system",
    "thrust": "mod_thrust",
    "weapon": "mod_weapon",
    "weapons": "mod_weapons",
}

ICON_BASE = "res://assets/ui/icons/mod_icons/"

def add_icon_fields(filepath):
    """Add icon = ... after name_en = ... line for each mod entry."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Split into lines for precise insertion
    lines = content.split('\n')
    new_lines = []
    added = 0
    i = 0

    while i < len(lines):
        line = lines[i]
        new_lines.append(line)

        # Look for name_en line inside a mod entry block
        if 'name_en' in line and '=' in line:
            # Check if this entry already has icon
            # Look back to see if icon was already added in this block
            has_icon = False
            for j in range(max(0, i-10), i+1):
                if 'icon =' in lines[j]:
                    has_icon = True
                    break
            
            if not has_icon:
                # Find slot_type in next 20 lines
                slot_type = None
                for j in range(i+1, min(i+25, len(lines))):
                    sm = re.search(r'slot_type\s*=\s*"([^"]+)"', lines[j])
                    if sm:
                        slot_type = sm.group(1)
                        break
                
                if slot_type:
                    icon_filename = SLOT_TYPE_MAP.get(slot_type)
                    if icon_filename:
                        indent = line[:len(line) - len(line.lstrip())]
                        new_lines.append(f'{indent}icon = "{ICON_BASE}{icon_filename}.png",')
                        added += 1
                    else:
                        print(f"  WARNING: No icon for slot_type '{slot_type}' in {os.path.basename(filepath)}")
                else:
                    print(f"  WARNING: No slot_type found after name_en in {os.path.basename(filepath)}")

        i += 1

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines))

    return added


def main():
    total_added = 0
    for fname in sorted(os.listdir(MOD_DIR)):
        if not fname.endswith('.gd') or fname == '__init__.gd':
            continue
        fpath = os.path.join(MOD_DIR, fname)
        # Skip files that already have icon fields (they were handled separately)
        with open(fpath, 'r', encoding='utf-8') as f:
            if 'icon =' in f.read():
                print(f'SKIP: {fname} (already has icon fields)')
                continue
        
        added = add_icon_fields(fpath)
        if added > 0:
            print(f'Added {added} icon fields to {fname}')
        total_added += added

    print(f'\nTotal icons added: {total_added}')


if __name__ == "__main__":
    main()
