import os
import shutil
import re

SRC_DIR = r"F:\godot fair duet\create\phase-war\assets\card_icons"
DST_DIR = r"F:\godot fair duet\create\phase-war\assets\card_icons\enemy_card_icons_zh"

# Step 1: Extract all display_name mappings from archetype files
def extract_display_names(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    results = {}
    pattern = r'"([^"]+)":\s*\{[^}]*"display_name":\s*"([^"]+)"'
    matches = re.findall(pattern, content, re.DOTALL)
    for arch_id, display_name in matches:
        results[arch_id] = display_name
    return results

ww_file = r"F:\godot fair duet\create\phase-war\data\enemy_archetypes_ww.gd"
cold_modern_file = r"F:\godot fair duet\create\phase-war\data\enemy_archetypes_cold_modern.gd"
future_file = r"F:\godot fair duet\create\phase-war\data\enemy_archetypes_future.gd"

all_names = {}
all_names.update(extract_display_names(ww_file))
all_names.update(extract_display_names(cold_modern_file))
all_names.update(extract_display_names(future_file))

# Step 2: Extract _get_foe_display_name and _get_fort_display_name from manifest
manifest_file = r"F:\godot fair duet\create\phase-war\data\enemy_unit_manifest.gd"
with open(manifest_file, 'r', encoding='utf-8') as f:
    manifest_content = f.read()

# Extract match cases from _get_foe_display_name
foe_display_pattern = r'"([^"]+)":\s*return\s+"([^"]+)"'
foe_display_matches = re.findall(foe_display_pattern, manifest_content)
for arch_id, display_name in foe_display_matches:
    if arch_id not in all_names:
        all_names[arch_id] = display_name

# Step 3: Pool display names from manifest
pool_display_names = [
    "李-恩菲尔德志愿兵排", "劳斯莱斯 Mk.II 装甲车", "维克斯 .303 机枪阵地", "福特 T 型战地救护车", "MP18 突击队",
    "M1 加兰德伞兵班", "黄蜂 Hummel 自行火炮", "PaK 40 反坦克炮组", "GMC 2.5t 补给卡车", "毛瑟 Kar98k 狙击组",
    "BMD-1 空降战车", "BMP-1 步兵战车", "9K111 法特导弹组", "P-18 雷达警戒车", "BREM-1 装甲抢修车",
    "M4 卡宾特遣班", "爱国者 PAC-3 发射车", "HIMARS 火箭炮组", "RQ-7 影子无人机班", "EA-18G 电子战小组",
    "神经接口突击兵", "HK-07 量产机兵", "HEL-30 激光炮阵列", "N-Repair 纳米工程车", "X-9 猎杀者渗透组",
    "毛瑟 C96 征召兵排", "Sd.Kfz.251/1 半履带车", "SS-C-1 岸防导弹组", "PS-9 相位中继站",
]

# Step 4: Build mapping from enemy_*.png filename to Chinese name
# The enemy_*.png files in card_icons/ are named after their archetype_id
# So enemy_cold_ak.png -> archetype_id = "enemy_cold_ak" -> Chinese name from all_names

# Get all enemy_*.png files
enemy_files = []
for f in sorted(os.listdir(SRC_DIR)):
    if f.startswith('enemy_') and f.endswith('.png') and not f.endswith('.import'):
        enemy_files.append(f)

# Also get fort_*.png files
fort_files = []
for f in sorted(os.listdir(SRC_DIR)):
    if f.startswith('fort_') and f.endswith('.png') and not f.endswith('.import'):
        fort_files.append(f)

# And elite_*, boss_* files
special_files = []
for f in sorted(os.listdir(SRC_DIR)):
    if (f.startswith('elite_') or f.startswith('boss_')) and f.endswith('.png') and not f.endswith('.import'):
        special_files.append(f)

all_files = enemy_files + fort_files + special_files

print(f"Total files to process: {len(all_files)}")
print(f"Total archetype->name mappings available: {len(all_names)}")

# Step 5: Create the output folder if it doesn't exist
os.makedirs(DST_DIR, exist_ok=True)

# Step 6: Copy files with Chinese names
copied = 0
missing = 0
unmapped = []

for fname in all_files:
    base = fname[:-4]  # remove .png
    zh_name = all_names.get(base, "")
    
    if zh_name:
        dst_name = f"{base}_{zh_name}.png"
        src_path = os.path.join(SRC_DIR, fname)
        dst_path = os.path.join(DST_DIR, dst_name)
        
        if os.path.exists(src_path):
            shutil.copy2(src_path, dst_path)
            copied += 1
            print(f"COPIED: {fname} -> {dst_name}")
        else:
            missing += 1
            print(f"MISSING FILE: {fname}")
    else:
        unmapped.append(base)
        print(f"UNMAPPED: {fname} (no Chinese name found)")

print(f"\n=== SUMMARY ===")
print(f"Total files: {len(all_files)}")
print(f"Copied: {copied}")
print(f"Missing files: {missing}")
print(f"Unmapped (no Chinese name): {len(unmapped)}")

if unmapped:
    print("\nUnmapped files:")
    for u in unmapped:
        print(f"  {u}")
