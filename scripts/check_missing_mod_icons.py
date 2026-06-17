import os, re

MOD_DIR = 'data/modification_modules'
slot_types_needed = set()

for fname in sorted(os.listdir(MOD_DIR)):
    if not fname.endswith('.gd') or fname == '__init__.gd':
        continue
    with open(os.path.join(MOD_DIR, fname), 'r', encoding='utf-8', errors='ignore') as f:
        for m in re.finditer(r'slot_type\s*=\s*"([^"]+)"', f.read()):
            slot_types_needed.add(m.group(1))

ICON_DIR = 'assets/ui/icons/mod_icons'
existing = set()
for f in os.listdir(ICON_DIR):
    if f.startswith('mod_') and f.endswith('.png'):
        existing.add(f[4:-4])

missing = slot_types_needed - existing
print(f'Total slot_types: {len(slot_types_needed)}')
print(f'Existing icons: {len(existing)}')
print(f'Missing: {sorted(missing)}')
