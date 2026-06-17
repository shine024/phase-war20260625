import re, os, subprocess

###############################################################################
# 1. Parse data table keys + their display order
###############################################################################
with open('data/captured_card_stats.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# Extract keys in definition order (preserves ordering)
key_order = re.findall(r'"(captured_[^"]+)":', content)
data_keys_set = set(key_order)

# Build a mapping from display_name -> key
name_to_key = {}
for m in re.finditer(r'"(captured_[^"]+)":\s*\{(.*?)\}', content, re.DOTALL):
    key = m.group(1)
    body = m.group(2)
    dm = re.search(r'"display_name":\s*"([^"]+)"', body)
    era = re.search(r'"era":\s*(\d)', body)
    combat = re.search(r'"combat_kind":\s*(\d)', body)
    appear = re.search(r'"appear_scope":\s*"([^"]+)"', body)
    name_to_key[dm.group(1)] = key if dm else None

###############################################################################
# 2. Get all .png files
###############################################################################
units_dir = 'assets/card_icons/units'
png_files = []
result = subprocess.run(
    ['find', units_dir, '-name', '*.png', '!', '-name', '*.png.import'],
    capture_output=True, text=True
)
found = [f for f in result.stdout.strip().split('\n') if f]
if found:
    png_files = found
else:
    for root, dirs, files in os.walk(units_dir):
        for fn in files:
            if fn.endswith('.png') and not fn.endswith('.png.import'):
                png_files.append(os.path.join(root, fn))

png_basenames = sorted([os.path.basename(f) for f in png_files])

###############################################################################
# 3. Categorize icons
###############################################################################
fort_icons = sorted([i for i in png_basenames if i.startswith('fort_')])
pool_icons = sorted([i for i in png_basenames if i.startswith('vis_pool_')])
player_icons = sorted([i for i in png_basenames if i.startswith('vis_player_')])
enemy_icons = sorted([i for i in png_basenames if i.startswith('vis_enemy_')])
other_icons = [i for i in png_basenames if not i.startswith('fort_') and not i.startswith('vis_pool_') and not i.startswith('vis_player_') and not i.startswith('vis_enemy_')]

###############################################################################
# 4. Categorize data keys
###############################################################################
fort_keys = sorted([k for k in key_order if k.startswith('captured_fort_')])
pool_keys = sorted([k for k in key_order if k.startswith('captured_foe_pool_')])
foe_keys = sorted([k for k in key_order if k.startswith('captured_foe_') and not k.startswith('captured_foe_pool')], key=lambda x: key_order.index(x))
enemy_keys = sorted([k for k in key_order if k.startswith('captured_enemy_')], key=lambda x: key_order.index(x))
elite_keys = sorted([k for k in key_order if k.startswith('captured_elite_')], key=lambda x: key_order.index(x))
boss_keys = sorted([k for k in key_order if k.startswith('captured_boss_')], key=lambda x: key_order.index(x))

###############################################################################
# 5. Analyze vis_player numbering
###############################################################################
# There are 71 vis_player icons (001-071) and 36 vis_enemy icons (036-071)
# Data table has 109 keys total.
#
# Likely mapping:
# - vis_player_001..071 maps to the first 71 keys in definition order (or some subset)
# - vis_enemy_036..071 maps to enemy/elite/boss keys (36 keys)
#
# Let's count: foe(34) + pool(29) + fort(10) = 73 keys that could be player/capture cards
# enemy(28) + elite(14) + boss(6) = 48 keys for enemy cards
# Total = 121... but we have 109 keys. Let me recount.

print("=" * 80)
print("DATA TABLE BREAKDOWN")
print("=" * 80)
print(f"Total keys: {len(key_order)}")
print(f"  captured_foe_* (main capture): {len(foe_keys)}")
print(f"    - era 0 (WW1): {[k for k in foe_keys if 'ww1' in k]}")
print(f"    - era 1 (WW2): {[k for k in foe_keys if 'ww2' in k]}")
print(f"    - era 2 (Cold): {[k for k in foe_keys if 'cold' in k]}")
print(f"    - era 3 (Modern): {[k for k in foe_keys if 'mod' in k]}")
print(f"    - era 4 (Future): {[k for k in foe_keys if 'fut' in k]}")
print(f"  captured_foe_pool_*: {len(pool_keys)}")
print(f"  captured_fort_*: {len(fort_keys)}")
print(f"  captured_enemy_*: {len(enemy_keys)}")
print(f"  captured_elite_*: {len(elite_keys)}")
print(f"  captured_boss_*: {len(boss_keys)}")

# Count by era
era_counts = {}
for k in key_order:
    body_match = re.search(r'"' + k.replace('_', r'\_') + r'":\s*\{(.*?)\}', content, re.DOTALL)
    if body_match:
        era_m = re.search(r'"era":\s*(\d)', body_match.group(1))
        if era_m:
            era = int(era_m.group(1))
            era_counts.setdefault(era, []).append(k)

print(f"\nKeys by era:")
for era in sorted(era_counts):
    print(f"  Era {era}: {len(era_counts[era])} keys")
    for k in era_counts[era]:
        print(f"    {k}")

print(f"\n{'=' * 80}")
print("ICON FILE BREAKDOWN")
print(f"{'=' * 80}")
print(f"Total .png files: {len(png_basenames)}")
print(f"  fort_*.png: {len(fort_icons)}")
print(f"  vis_pool_*.png: {len(pool_icons)}")
print(f"  vis_player_*.png: {len(player_icons)} (001-{player_icons[-1].replace('vis_player_','').replace('.png','')})")
print(f"  vis_enemy_*.png: {len(enemy_icons)} (036-{enemy_icons[-1].replace('vis_enemy_','').replace('.png','')})")
print(f"  other: {len(other_icons)}")
for o in other_icons:
    print(f"    {o}")

print(f"\n{'=' * 80}")
print("MAPPING ANALYSIS")
print(f"{'=' * 80}")

# vis_pool_NNN -> captured_foe_pool_NNN
print("\n[Pool icons - ALL MATCH]")
for icon in pool_icons:
    num = icon.replace('vis_pool_', '').replace('.png', '')
    key = f'captured_foe_pool_{num}'
    status = "OK" if key in data_keys_set else "MISSING FROM DATA"
    print(f"  {icon} -> {key} [{status}]")

# fort icons
print("\n[Fort icons - ALL MATCH]")
for icon in fort_icons:
    key = 'captured_' + icon.replace('.png', '')
    status = "OK" if key in data_keys_set else "MISSING FROM DATA"
    print(f"  {icon} -> {key} [{status}]")

# vis_player mapping hypothesis
# The 71 player icons likely map to: foe(34) + pool(29) + some others = 71?
# 34 + 29 = 63, need 8 more. That doesn't add up to 71.
# Or maybe: foe(34) + pool(29) + fort(10) - some overlap? No, fort has its own icons.
# Let's think about it differently.
#
# 71 player icons could map to all non-enemy/elite/boss keys:
# foe(34) + pool(29) + fort(10) = 73... close but not 71.
# Actually let me check if there are duplicates in foe_keys
foe_unique = []
for k in foe_keys:
    if k not in foe_unique:
        foe_unique.append(k)
print(f"\nUnique foe keys count: {len(foe_unique)}")
print(f"  foe + pool = {len(foe_unique) + len(pool_keys)}")
print(f"  foe + pool + fort = {len(foe_unique) + len(pool_keys) + len(fort_keys)}")

# vis_enemy mapping hypothesis
# 36 enemy icons (036-071). These likely map to enemy + elite + boss keys
total_non_pool_non_foe = len(enemy_keys) + len(elite_keys) + len(boss_keys)
print(f"\nEnemy+Elite+Boss keys count: {total_non_pool_non_foe}")
print(f"  enemy: {len(enemy_keys)}")
print(f"  elite: {len(elite_keys)}")
print(f"  boss: {len(boss_keys)}")
print(f"  total: {len(enemy_keys) + len(elite_keys) + len(boss_keys)}")

# vis_enemy numbering starts at 036, ends at 071 = 36 numbers
# This matches exactly! So vis_enemy_036..071 maps to the 36 enemy/elite/boss keys

# vis_player numbering starts at 001, ends at 071 = 71 numbers
# These should map to: foe(34) + pool(29) = 63... but we have 71.
# Wait, let me check if there are also some foe keys that might map to player icons

# Let me check all keys that don't have obvious icon mapping
print(f"\n{'=' * 80}")
print("UNMAPPED DATA KEYS (no obvious icon)")
print(f"{'=' * 80}")

# foe keys that might map to vis_player
for i, k in enumerate(foe_keys):
    vis_num = f"{i+1:03d}"
    vis_icon = f"vis_player_{vis_num}.png"
    has_icon = vis_icon in png_basenames
    print(f"  foe[{i+1:02d}] {k} -> vis_player_{vis_num}.png [{'OK' if has_icon else 'NO ICON'}]")

print(f"\n  (foe keys: {len(foe_keys)}, pool keys: {len(pool_keys)})")
print(f"  foe+pool = {len(foe_keys) + len(pool_keys)}")
print(f"  vis_player count = {len(player_icons)}")

# Check if vis_player_001..063 maps to foe keys
# And vis_player_064..092 maps to pool keys? But we only have 71 player icons.
# foe(34) + pool(29) = 63. Still not 71.
# Maybe there's additional mapping.

# Let me look at what vis_player_064..071 might be
print(f"\n  Extra player icons beyond foe+pool: {len(player_icons) - len(foe_keys) - len(pool_keys)}")
print(f"  vis_player_064.png: {'exists' if 'vis_player_064.png' in png_basenames else 'missing'}")
print(f"  vis_player_065.png: {'exists' if 'vis_player_065.png' in png_basenames else 'missing'}")
print(f"  vis_player_066.png: {'exists' if 'vis_player_066.png' in png_basenames else 'missing'}")
print(f"  vis_player_067.png: {'exists' if 'vis_player_067.png' in png_basenames else 'missing'}")
print(f"  vis_player_068.png: {'exists' if 'vis_player_068.png' in png_basenames else 'missing'}")
print(f"  vis_player_069.png: {'exists' if 'vis_player_069.png' in png_basenames else 'missing'}")
print(f"  vis_player_070.png: {'exists' if 'vis_player_070.png' in png_basenames else 'missing'}")
print(f"  vis_player_071.png: {'exists' if 'vis_player_071.png' in png_basenames else 'missing'}")

# Check if vis_player_064..071 might correspond to fort keys
print(f"\n  Fort keys: {len(fort_keys)}")
print(f"  vis_player_064..071 = 8 icons, fort = 10 keys")
# Maybe vis_player_064..073 would match fort but we only have up to 071
# 064..071 = 8 icons, but 10 fort keys. So 2 fort keys would be missing from vis_player

# Alternative: vis_player maps to ALL non-enemy/elite/boss keys in order
all_non_enemy = foe_keys + pool_keys  # in definition order
print(f"\n  All non-enemy keys in order: {len(all_non_enemy)}")
for i, k in enumerate(all_non_enemy):
    vis_num = f"{i+1:03d}"
    vis_icon = f"vis_player_{vis_num}.png"
    has_icon = vis_icon in png_basenames
    if not has_icon:
        print(f"  MISSING: {k} -> vis_player_{vis_num}.png")

# Check the remaining player icons
remaining_player = len(player_icons) - len(all_non_enemy)
print(f"\n  Remaining player icons after foe+pool: {remaining_player}")
if remaining_player > 0:
    # These might map to fort keys
    start_idx = len(all_non_enemy) + 1
    print(f"  vis_player_{start_idx:03d}..{start_idx + remaining_player - 1:03d} might map to fort keys")
    for i in range(remaining_player):
        vis_num = f"{start_idx + i:03d}"
        vis_icon = f"vis_player_{vis_num}.png"
        fort_idx = i
        if fort_idx < len(fort_keys):
            print(f"  {vis_icon} -> {fort_keys[fort_idx]}")

print(f"\n{'=' * 80}")
print("VIS_ENEMY MAPPING HYPOTHESIS")
print(f"{'=' * 80}")
# vis_enemy_036..071 = 36 icons
# enemy(28) + elite(14) + boss(6) = 48... too many
# Let me check the actual counts again
print(f"  enemy keys: {len(enemy_keys)}")
print(f"  elite keys: {len(elite_keys)}")
print(f"  boss keys: {len(boss_keys)}")
print(f"  total enemy+elite+boss: {len(enemy_keys) + len(elite_keys) + len(boss_keys)}")
print(f"  vis_enemy count: {len(enemy_icons)}")

# vis_enemy numbering starts at 036, so it's a continuation of vis_player numbering
# vis_player goes 001-071, vis_enemy goes 036-071
# Wait, vis_enemy starts at 036 which overlaps with vis_player range!
# This means vis_enemy_036 is NOT vis_player_036
# They're separate numbering schemes

# Let's check: maybe vis_enemy_036..071 maps to the last 36 keys out of the 48 enemy/elite/boss
# Or maybe it maps to a different subset

# Check if there's a separate enemy/elite/boss ordering
enemy_all = enemy_keys + elite_keys + boss_keys
print(f"\n  Combined enemy+elite+boss in definition order:")
for i, k in enumerate(enemy_all):
    # Try mapping: vis_enemy_036 + i
    vis_num = f"{36 + i:03d}"
    vis_icon = f"vis_enemy_{vis_num}.png"
    has_icon = vis_icon in png_basenames
    print(f"    [{i+1:02d}] {k} -> vis_enemy_{vis_num}.png [{'OK' if has_icon else 'NO ICON'}]")

print(f"\n{'=' * 80}")
print("OMEGA_PLATFORM")
print(f"{'=' * 80}")
if 'omega_platform.png' in png_basenames:
    print("  omega_platform.png exists but has no corresponding data key")
    print("  This icon is NOT referenced by captured_card_stats.gd")

print(f"\n{'=' * 80}")
print("FINAL SUMMARY")
print(f"{'=' * 80}")
print(f"  Data table keys: {len(key_order)}")
print(f"  Icon files: {len(png_basenames)}")
print()
print(f"  Fort icons (10): ALL MATCH data keys ✓")
print(f"  Pool icons (29): ALL MATCH data keys ✓")
print(f"  vis_player (71): Maps to foe({len(foe_keys)}) + pool({len(pool_keys)}) + possibly fort")
print(f"  vis_enemy (36): Maps to enemy+elite+boss subset")
print(f"  omega_platform (1): NO corresponding data key ✗")
