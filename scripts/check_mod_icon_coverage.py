import os, re

MOD_DIR = 'data/modification_modules'
total = 0
with_icon = 0
without_icon = 0
slot_types_with_icon = set()
slot_types_without_icon = set()

for fname in sorted(os.listdir(MOD_DIR)):
    if not fname.endswith('.gd') or fname == '__init__.gd':
        continue
    fpath = os.path.join(MOD_DIR, fname)
    with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    count = len(re.findall(r'"[a-z]+_\d+_\w+"\s*=', content))
    total += count
    
    has_icon = 'icon =' in content
    if has_icon:
        with_icon += count
        for m in re.finditer(r'slot_type\s*=\s*"([^"]+)"', content):
            slot_types_with_icon.add(m.group(1))
    else:
        without_icon += count
        for m in re.finditer(r'slot_type\s*=\s*"([^"]+)"', content):
            slot_types_without_icon.add(m.group(1))

ICON_DIR = 'assets/ui/icons/mod_icons'
existing = set()
for f in os.listdir(ICON_DIR):
    if f.startswith('mod_') and f.endswith('.png'):
        existing.add(f[4:-4])

print(f'Total mod definitions: {total}')
print(f'With icon field: {with_icon} (infantry_mods + armor_mods)')
print(f'Without icon field: {without_icon} (8 other files)')
print()
print(f'Slot types in icon files: {sorted(slot_types_with_icon)}')
print(f'Slot types in non-icon files: {sorted(slot_types_without_icon)}')
print()
missing = slot_types_with_icon - existing
print(f'Icon coverage: {len(slot_types_with_icon)} slot_types, {len(existing)} icons')
print(f'  Missing: {sorted(missing) if missing else "NONE - all covered!"}')
