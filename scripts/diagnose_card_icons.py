import os, re

base = r"F:\godot fair duet\create\phase-war"

with open(os.path.join(base, "data", "enemy_unit_manifest.gd"), "r", encoding="utf-8") as f:
    content = f.read()

def extract_ids(name):
    m = re.search(rf'const {name}.*?\[(.*?)\n\]', content, re.DOTALL)
    if not m:
        return []
    return re.findall(r'"([^"]+)"', m.group(1))

foe_platform_ids = extract_ids('FOE_PLATFORM_CARD_IDS')
foe_special_ids = extract_ids('FOE_SPECIAL_CARD_IDS')
fixed_enemy_ids = extract_ids('FIXED_ENEMY_IDS')
pool_enemy_ids = extract_ids('POOL_ENEMY_IDS')

def visual_id_for_source(sid):
    if sid in foe_special_ids:
        return f"vis_player_{30 + foe_special_ids.index(sid):03d}"
    if sid in foe_platform_ids:
        return f"vis_player_{1 + foe_platform_ids.index(sid):03d}"
    if sid in fixed_enemy_ids:
        return f"vis_enemy_{36 + fixed_enemy_ids.index(sid):03d}"
    if sid in pool_enemy_ids:
        return f"vis_pool_{1 + pool_enemy_ids.index(sid):03d}"
    return sid

# 战斗卡列表
with open(os.path.join(base, "data", "default_cards.gd"), "r", encoding="utf-8") as f:
    card_entries = re.findall(r'_unit\(\s*"([^"]+)"', f.read())

# 文件清单
root_dir = os.path.join(base, "assets", "card_icons")
root_files = set(fn[:-4] for fn in os.listdir(root_dir) if fn.endswith('.png'))

units_dir = os.path.join(root_dir, "units")
units_files = set()
if os.path.exists(units_dir):
    units_files = set(fn[:-4] for fn in os.listdir(units_dir) if fn.endswith('.png'))

# 诊断
results = []
for card_id in card_entries:
    # manifest: foe_<card_id> → visual_id_for_source(card_id) → units/vis_player_XXX.png
    source = card_id
    vid = visual_id_for_source(source)
    full = f"res://assets/card_icons/units/{vid}.png"
    exists = vid in units_files
    
    if exists:
        if vid.startswith("vis_player"):
            results.append((card_id, "OK", f"units/{vid}.png"))
        elif vid.startswith("vis_enemy") or vid.startswith("vis_pool"):
            results.append((card_id, "WRONG_VIS", f"units/{vid}.png (应为 vis_player)") if not card_id in fixed_enemy_ids else f"units/{vid}.png (fixed)")
        else:
            results.append((card_id, f"OTHER_VIS({vid})", f"units/{vid}.png"))
    else:
        # fallback 检查 root 目录
        if card_id in root_files:
            results.append((card_id, "ROOT_FALLBACK", f"root/{card_id}.png"))
        else:
            results.append((card_id, "MISSING", "无文件"))

# 统计
from collections import Counter
sc = Counter(r[1] for r in results)
print(f"战斗卡总数: {len(card_entries)}")
print(f"\n--- 状态统计 ---")
for s, c in sc.most_common():
    print(f"  {s}: {c}")

# 分类输出
for label in ["MISSING", "WRONG_VIS", "ROOT_FALLBACK", "OTHER_VIS(*)"]:
    items = [r for r in results if r[1] == label or (label == "OTHER_VIS(*)" and r[1].startswith("OTHER_VIS"))]
    if items:
        print(f"\n--- {label} ({len(items)}) ---")
        for card_id, st, detail in sorted(items):
            print(f"  {card_id:30s} → {detail}")

# OK 列表
ok_items = [r for r in results if r[1] == "OK"]
print(f"\n--- OK (vis_player_*) ({len(ok_items)}) ---")
for card_id, st, detail in sorted(ok_items):
    print(f"  {card_id:30s} → {detail}")
