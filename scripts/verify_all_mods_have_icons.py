import os, re

MOD_DIR = r'data\modification_modules'
total_with_icon = 0
total_without_icon = 0

for fname in sorted(os.listdir(MOD_DIR)):
    if not fname.endswith('.gd') or fname == '__init__.gd':
        continue
    fpath = os.path.join(MOD_DIR, fname)
    with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    # Count mod entries
    mod_count = len(re.findall(r'"[a-z]+_\d+_\w+"\s*=\s*\{', content))
    
    # Count icon fields
    icon_count = len(re.findall(r'\bicon\s*=\s*"', content))
    
    missing = mod_count - icon_count
    total_with_icon += icon_count
    if missing > 0:
        total_without_icon += missing
        print(f'{fname:30s} | mods={mod_count:3d} | icons={icon_count:3d} | missing={missing:3d}')
    else:
        print(f'{fname:30s} | mods={mod_count:3d} | icons={icon_count:3d} | OK')

print(f'\nTotal mods: {total_with_icon + total_without_icon}')
print(f'Total with icons: {total_with_icon}')
print(f'Total without icons: {total_without_icon}')
