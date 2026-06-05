## Generate Player Card Icons from Enemy Mirrors
## 
## Mirrors vis_enemy_*.png images (facing left) horizontally to create
## player card icons (facing right) for cards missing independent art.
##
## Strategy:
##   1. Map each player card to vis_enemy by (era, combat_kind) match
##   2. If exact match doesn't exist, fallback across combat_kinds
##   3. Fortress/omega cards use shape_key fallback
##   4. A-segment 28 cards already have icons via manifest (vis_player_*.png)
##   5. B-segment 6 cards have vis_player_030~035 (already exist)
##
## Usage:
##   python scripts/generate_card_icons_from_enemies.py
##
## Output:
##   assets/card_icons/<card_id>.png — mirrored enemy icons for player cards

import os
from PIL import Image

base = r"F:\godot fair duet\create\phase-war"
units_dir = os.path.join(base, "assets", "card_icons", "units")
output_dir = os.path.join(base, "assets", "card_icons")

# ─── C-segment enemy mapping ───
# (archetype_id, era, combat_kind, vis_enemy_index)
# combat_kind: 0=轻步兵 1=装甲 2=阵地 3=支援/空 4=堡垒
c_enemies = [
    # WW1 (vis_enemy_036~042)
    ("enemy_ww1_infantry_basic",    0, 0, 36),
    ("enemy_ww1_infantry_rifle",    0, 0, 37),
    ("enemy_ww1_mg_nest",           0, 2, 38),
    ("enemy_ww1_mortar",            0, 2, 39),
    ("enemy_ww1_storm",             0, 0, 40),  # elite_ww1_storm → kind 0
    ("enemy_ww1_armored",           0, 1, 41),  # elite_ww1_armored → kind 1
    ("enemy_ww1_av7",               0, 1, 42),  # boss_ww1_av7 → kind 1
    # WW2 (vis_enemy_043~049)
    ("enemy_ww2_infantry",          1, 0, 43),
    ("enemy_ww2_rifleman",          1, 0, 44),
    ("enemy_ww2_mg42",              1, 2, 45),
    ("enemy_ww2_panzerschreck",     1, 0, 46),
    ("enemy_ww2_paratrooper",       1, 0, 47),
    ("enemy_ww2_panther",           1, 1, 48),
    ("enemy_ww2_kingtiger",         1, 1, 49),
    # Cold War (vis_enemy_050~056)
    ("enemy_cold_ak",               2, 0, 50),
    ("enemy_cold_m60",              2, 0, 51),
    ("enemy_cold_btr",              2, 1, 52),
    ("enemy_cold_m113",             2, 1, 53),
    ("enemy_cold_spetsnaz",         2, 0, 54),
    ("enemy_cold_t72",              2, 1, 55),
    ("enemy_cold_mig",              2, 3, 56),  # boss_cold_mig → kind 3
    # Modern (vis_enemy_057~064)
    ("enemy_modern_marine",         3, 0, 57),
    ("enemy_modern_technical",      3, 0, 58),
    ("enemy_modern_stryker",        3, 1, 59),
    ("enemy_modern_mlrs",           3, 2, 60),
    ("enemy_modern_delta",          3, 0, 61),
    ("enemy_modern_abrams",         3, 1, 62),
    ("enemy_modern_apache",         3, 3, 63),
    ("enemy_modern_command",        3, 0, 64),
    # Future (vis_enemy_065~071)
    ("enemy_future_drone",          4, 0, 65),
    ("enemy_future_cyborg",         4, 0, 66),
    ("enemy_future_mech",           4, 1, 67),
    ("enemy_future_hovertank",      4, 1, 68),
    ("enemy_future_spectre",        4, 0, 69),
    ("enemy_future_colossus",       4, 1, 70),
    ("enemy_future_nexus",          4, 1, 71),
]

# ─── Load enemy images ───
enemy_images = {}
for eid, era, ck, vis_idx in c_enemies:
    path = os.path.join(units_dir, f"vis_enemy_{vis_idx:03d}.png")
    if os.path.exists(path):
        img = Image.open(path).convert("RGBA")
        enemy_images[(era, ck)] = enemy_images.get((era, ck), [])
        enemy_images[(era, ck)].append(img)
        print(f"  Loaded vis_enemy_{vis_idx:03d}.png ({img.size}) for {eid} (era={era}, kind={ck})")
    else:
        print(f"  MISSING: {path}")

# ─── Fallback strategy for mismatched counts ───
# Fallback priority for each (era, kind) when exact match is exhausted:
#   1. Same era, same kind (best)
#   2. Same era, next closest kind
#   3. Any era, any kind (last resort)
#
# Kind proximity (most to least similar):
#   轻步兵(0): 轻→甲→阵地→支援→堡垒
#   装甲(1):  甲→轻→援→阵地→堡垒
#   阵地(2):  阵地→援→轻→甲→堡垒
#   支援(3):  支援→阵地→轻→空→甲
#   堡垒(4):  堡垒→阵地→援→甲→轻

kind_fallback_order = {
    0: [0, 1, 2, 3, 4],    # 轻
    1: [1, 0, 3, 2, 4],    # 甲
    2: [2, 3, 0, 1, 4],    # 阵地
    3: [3, 0, 1, 2, 4],    # 支援/空
    4: [4, 2, 3, 1, 0],    # 堡垒
}

era_order = [0, 1, 2, 3, 4]  # ww1, ww2, cold, mod, fut
era_names = ['ww1', 'ww2', 'cold', 'mod', 'fut']

# ─── Parse player cards from default_cards.gd ───
import re
with open(os.path.join(base, "data", "default_cards.gd"), 'r', encoding='utf-8') as f:
    cc = f.read()

# Parse _unit("id", "name", era, combat_kind, power, ...)
pattern = r'_unit\("([^"]+)",\s*"([^"]+)",\s*(\d+),\s*(\d+),\s*(\d+)'
matches = re.findall(pattern, cc)

# A-segment already has icons via manifest
a_segment = [
    "ww1_rolls", "ww1_ft17", "ww1_77mm", "ww1_cavalry", "ww1_engineer",
    "ww2_hellcat", "ww2_sherman", "ww2_tiger", "ww2_bazooka", "ww2_panzerschrek",
    "ww2_m81", "ww1_m81",
    "cold_btr60", "cold_t55", "cold_bmp1", "cold_m113", "cold_zsu23",
    "mod_technical", "mod_m1a1", "mod_m6", "mod_m270", "fut_scout_drone",
    "mod_m1a2sep",
    "fut_scout_mech", "fut_hovertank", "fut_prism", "fut_heavy_mech",
    "fut_nexus",
]

# Player cards that need icons
player_cards = []
for cid, name, era, ck, power in matches:
    if cid in a_segment:
        continue
    player_cards.append({
        'card_id': cid,
        'name': name,
        'era': int(era),
        'combat_kind': int(ck),
        'power': int(power),
    })

print(f"\nGenerating {len(player_cards)} player card icons from enemy mirrors...")
print(f"  (A-segment {len(a_segment)} already have icons via manifest)")

# ─── Generate mirrored icons ───
kind_labels = ["轻", "甲", "阵地", "支援", "堡垒"]
stats = {
    'exact_match': 0,
    'same_era_other_kind': 0,
    'any_era_fallback': 0,
    'fortress_shape': 0,
    'failed': 0,
}

for card in player_cards:
    card_id = card['card_id']
    card_era = card['era']
    card_kind = card['combat_kind']
    era_name = era_names[card_era] if card_era < 5 else 'other'
    
    # Determine source image
    source_img = None
    source_type = "unknown"
    
    # Fortress cards: use shape_key based PNGs that already exist
    if card_id.startswith('fort_') or card_id == 'omega_platform':
        # These need independent art — skip for now
        # Check if there's a shape_key fallback in card_icons root
        shape_path = os.path.join(output_dir, card_id + ".png")
        if os.path.exists(shape_path):
            source_img = Image.open(shape_path).convert("RGBA")
            source_type = "existing_shape"
            stats['fortress_shape'] += 1
        else:
            stats['failed'] += 1
            print(f"  SKIP: {card_id} (fortress, no mirror available)")
            continue
    
    # Try exact match first: (era, kind)
    key = (card_era, card_kind)
    if key in enemy_images and enemy_images[key]:
        idx = len(enemy_images[key]) % len(enemy_images[key])  # cycle through available
        source_img = enemy_images[key][idx].copy()
        source_type = "exact"
        stats['exact_match'] += 1
    else:
        # Fallback: try other kinds in same era
        found = False
        for fallback_kind in kind_fallback_order.get(card_kind, [card_kind]):
            fb_key = (card_era, fallback_kind)
            if fb_key in enemy_images and enemy_images[fb_key]:
                idx = len(enemy_images[fb_key]) % len(enemy_images[fb_key])
                source_img = enemy_images[fb_key][idx].copy()
                source_type = f"fallback_kind={kind_labels[fallback_kind]}"
                stats['same_era_other_kind'] += 1
                found = True
                break
        
        if not found:
            # Last resort: any era, any kind
            for era in era_order:
                for kind in kind_fallback_order.get(card_kind, [card_kind]):
                    fb_key = (era, kind)
                    if fb_key in enemy_images and enemy_images[fb_key]:
                        idx = len(enemy_images[fb_key]) % len(enemy_images[fb_key])
                        source_img = enemy_images[fb_key][idx].copy()
                        source_type = f"fallback_era={era_names[era]}_kind={kind_labels[kind]}"
                        stats['any_era_fallback'] += 1
                        found = True
                        break
                if found:
                    break
    
    if source_img is None:
        stats['failed'] += 1
        print(f"  FAILED: {card_id} (era={era_name}, kind={kind_labels[card_kind]})")
        continue
    
    # Horizontal mirror (flip left-right)
    mirrored = source_img.transpose(Image.FLIP_LEFT_RIGHT)
    
    # Save to output
    out_path = os.path.join(output_dir, f"{card_id}.png")
    mirrored.save(out_path, "PNG")
    
    if source_type in ('exact',):
        print(f"  {card_id:30s} → {out_path} (exact era={era_name} kind={kind_labels[card_kind]})")
    else:
        print(f"  {card_id:30s} → {out_path} ({source_type})")

# ─── Summary ───
print(f"\n{'='*60}")
print(f"Generation complete!")
print(f"  Exact era+kind match: {stats['exact_match']}")
print(f"  Same era, different kind: {stats['same_era_other_kind']}")
print(f"  Cross-era fallback: {stats['any_era_fallback']}")
print(f"  Fortress/shape: {stats['fortress_shape']}")
print(f"  Failed: {stats['failed']}")
print(f"{'='*60}")
