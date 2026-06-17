import re, os, subprocess

# 1. Parse data table keys
with open('data/captured_card_stats.gd', 'r', encoding='utf-8') as f:
    content = f.read()
data_keys = set(re.findall(r'"(captured_[^"]+)":', content))
print(f"=== Data table: {len(data_keys)} keys ===\n")

# 2. Get all .png files (including gitignored) - try multiple methods
units_dir = 'assets/card_icons/units'
png_files = []

# Method 1: find (works even for gitignored)
result = subprocess.run(
    ['find', units_dir, '-name', '*.png', '!', '-name', '*.png.import'],
    capture_output=True, text=True
)
found = [f for f in result.stdout.strip().split('\n') if f]
if found:
    png_files = found
else:
    # Method 2: os.walk as fallback
    for root, dirs, files in os.walk(units_dir):
        for fn in files:
            if fn.endswith('.png') and not fn.endswith('.png.import'):
                png_files.append(os.path.join(root, fn))

png_basenames = sorted([os.path.basename(f) for f in png_files])
print(f"=== Icons directory: {len(png_basenames)} .png files ===\n")

# 3. Build mappings
# Map naming conventions:
# fort_ww1_pillbox.png -> captured_fort_ww1_pillbox
# vis_player_001.png -> ???
# vis_enemy_036.png -> ???
# vis_pool_001.png -> captured_foe_pool_001
# omega_platform.png -> ???

fort_map = {}
pool_map = {}
other_icons = []

for icon in png_basenames:
    if icon.startswith('fort_'):
        key = 'captured_' + icon.replace('.png', '')
        fort_map[key] = icon
    elif icon.startswith('vis_pool_'):
        num = icon.replace('vis_pool_', '').replace('.png', '')
        key = f'captured_foe_pool_{num}'
        pool_map[key] = icon
    else:
        other_icons.append(icon)

# 4. Analysis
print("=== Fort icons vs data keys ===")
for key, icon in sorted(fort_map.items()):
    if key in data_keys:
        print(f"  MATCH: {icon} -> {key}")
    else:
        print(f"  ICON ONLY (no data key): {icon} -> {key}")

# Check data keys without fort icons
fort_data_keys = sorted([k for k in data_keys if k.startswith('captured_fort_')])
fort_icon_keys = set(fort_map.keys())
missing_icons = [k for k in fort_data_keys if k not in fort_icon_keys]
if missing_icons:
    print(f"\n  DATA KEYS WITHOUT ICONS: {missing_icons}")
else:
    print("\n  All fort data keys have icons.")

print("\n=== Pool icons vs data keys ===")
for key, icon in sorted(pool_map.items()):
    if key in data_keys:
        print(f"  MATCH: {icon} -> {key}")
    else:
        print(f"  ICON ONLY (no data key): {icon} -> {key}")

pool_data_keys = sorted([k for k in data_keys if k.startswith('captured_foe_pool_')])
pool_icon_keys = set(pool_map.keys())
missing_pool_icons = [k for k in pool_data_keys if k not in pool_icon_keys]
extra_pool_icons = [k for k in pool_icon_keys if k not in data_keys]
if missing_pool_icons:
    print(f"\n  DATA KEYS WITHOUT ICONS: {missing_pool_icons}")
if extra_pool_icons:
    print(f"\n  EXTRA ICONS WITHOUT DATA KEYS: {extra_pool_icons}")

print("\n=== Other icons (vis_player, vis_enemy, omega_platform) ===")
for icon in sorted(other_icons):
    print(f"  {icon}")

# 5. vis_player mapping analysis
print("\n=== vis_player_001..071 analysis ===")
player_icons = sorted([i for i in other_icons if i.startswith('vis_player_')])
enemy_icons = sorted([i for i in other_icons if i.startswith('vis_enemy_')])

# Look for any reference files that map these numbers to keys
print(f"  vis_player count: {len(player_icons)} (001-{player_icons[-1].replace('vis_player_','').replace('.png','') if player_icons else 'N/A'})")
print(f"  vis_enemy count: {len(enemy_icons)} (036-{enemy_icons[-1].replace('vis_enemy_','').replace('.png','') if enemy_icons else 'N/A'})")

# 6. Check for data keys without any icon at all
all_known_keys = set()
all_known_keys.update(fort_map.keys())
all_known_keys.update(pool_map.keys())

# foe keys (non-pool)
foe_non_pool = sorted([k for k in data_keys if k.startswith('captured_foe_') and not k.startswith('captured_foe_pool')])
enemy_keys_sorted = sorted([k for k in data_keys if k.startswith('captured_enemy_')])
elite_keys_sorted = sorted([k for k in data_keys if k.startswith('captured_elite_')])
boss_keys_sorted = sorted([k for k in data_keys if k.startswith('captured_boss_')])

print("\n=== Data key categories (no obvious icon mapping) ===")
print(f"  captured_foe_* (non-pool): {len(foe_non_pool)} keys")
for k in foe_non_pool:
    print(f"    {k} -> {data_keys.__class__.__name__}")

# Let's check if any foe key matches any icon pattern
print("\n=== Checking foe keys against icon files ===")
icon_basenames_no_ext = [i.replace('.png', '') for i in png_basenames]
for key in sorted(data_keys):
    # Try various mappings
    key_body = key.replace('captured_', '')
    matched = False

    # Direct match: key_body == icon name
    if key_body in icon_basenames_no_ext:
        print(f"  DIRECT: {key} -> {key_body}.png")
        matched = True
        continue

    # foe_XXX -> vis_player_NNN? No direct pattern
    # enemy_XXX -> vis_enemy_NNN? No direct pattern

    # fort_XXX -> fort_XXX.png
    if key.startswith('captured_fort_'):
        fort_name = key.replace('captured_fort_', '')
        if f'fort_{fort_name}' in icon_basenames_no_ext:
            print(f"  FORT MATCH: {key} -> fort_{fort_name}.png")
            matched = True
            continue

    # foe_pool_NNN -> vis_pool_NNN.png
    if key.startswith('captured_foe_pool_'):
        pool_num = key.replace('captured_foe_pool_', '')
        pool_icon = f'vis_pool_{pool_num}'
        if pool_icon in icon_basenames_no_ext:
            print(f"  POOL MATCH: {key} -> {pool_icon}.png")
            matched = True
            continue

    if not matched:
        print(f"  NO ICON FOUND: {key}")

print("\n=== Summary Statistics ===")
print(f"Total data keys: {len(data_keys)}")
print(f"Total .png files: {len(png_files)}")
print(f"  fort_*.png: {len(fort_map)}")
print(f"  vis_pool_*.png: {len(pool_map)}")
print(f"  vis_player_*.png: {len(player_icons)}")
print(f"  vis_enemy_*.png: {len(enemy_icons)}")
print(f"  omega_platform.png: 1")
print(f"  Total others: {len(other_icons)}")
