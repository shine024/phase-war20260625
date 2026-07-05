import os
import shutil

SRC_DIR = r"F:\godot fair duet\create\phase-war\assets\card_icons"
DST_DIR = r"F:\godot fair duet\create\phase-war\assets\card_icons\enemy_card_icons_zh"

# Legacy files mapping to Chinese names
legacy_to_chinese = {
    "enemy_cold_bmp1": "布雷德利步战车",
    "enemy_cold_btr60": "布雷德利步战车",
    "enemy_cold_m113": "BMP步战车",
    "enemy_cold_t55": "T-72主战坦克",
    "enemy_cold_zsu23": "电子对抗站",
    "enemy_future_heavy_mech": "机甲步行者",
    "enemy_future_hovertank": "悬浮坦克",
    "enemy_future_nexus": "全装型机动舱",
    "enemy_future_prism": "机甲步行者",
    "enemy_future_scout_drone": "光学隐匿侦察车",
    "enemy_future_scout_mech": "光学侦察车",
    "enemy_modern_m1a1": "艾布拉姆斯坦克",
    "enemy_modern_m1a2sep": "豹2A7主战坦克",
    "enemy_modern_m270": "帕拉丁自行火炮",
    "enemy_modern_m6": "相控阵雷达车",
    "enemy_modern_technical": "北极星全地形车",
    "enemy_ww1_77mm": "要塞固定炮",
    "enemy_ww1_cavalry": "威克斯侦察车",
    "enemy_ww1_engineer": "野战救护车",
    "enemy_ww1_ft17": "马克V型坦克",
    "enemy_ww1_m81": "要塞固定炮",
    "enemy_ww1_rolls": "马克V型坦克",
    "enemy_ww2_bazooka": "M8灰狗装甲车",
    "enemy_ww2_hellcat": "BA-64轻型突击车",
    "enemy_ww2_m81": "混凝土碉堡",
    "enemy_ww2_panzerschrek": "M8灰狗装甲车",
    "enemy_ww2_sherman": "谢尔曼坦克",
    "enemy_ww2_tiger": "虎式坦克",
}

# Files that remain without Chinese names (pure legacy blueprint IDs)
# These are old generated files that don't map to any current game entity
unmapped_legacy = [
    "enemy_cold_ak47", "enemy_cold_bradley", "enemy_cold_chieftain",
    "enemy_cold_f4", "enemy_cold_leo1", "enemy_cold_m1", "enemy_cold_m14",
    "enemy_cold_m60t", "enemy_cold_mig21", "enemy_cold_rpg", "enemy_cold_rpk",
    "enemy_cold_sam7", "enemy_cold_spetsnaz", "enemy_cold_t62", "enemy_cold_t72",
    "enemy_future_aa_hover", "enemy_future_assault_mech", "enemy_future_attack_drone",
    "enemy_future_colossus", "enemy_future_heavy_trooper", "enemy_future_howitzer",
    "enemy_future_nano_drone", "enemy_future_shield", "enemy_future_space_fighter",
    "enemy_future_spectre", "enemy_future_stealth_bomber", "enemy_future_stormcore",
    "enemy_future_swarm",
    "enemy_modern_ah1", "enemy_modern_ah64", "enemy_modern_challenger2",
    "enemy_modern_hummer_m2", "enemy_modern_hummer_tow", "enemy_modern_javelin",
    "enemy_modern_leo2a6", "enemy_modern_m1a2", "enemy_modern_ranger",
    "enemy_modern_stinger", "enemy_modern_stryker_m2", "enemy_modern_stryker_mgs",
    "enemy_modern_t90", "enemy_modern_uh60",
    "enemy_ww1_105mm", "enemy_ww1_37mm", "enemy_ww1_a7v", "enemy_ww1_enfield",
    "enemy_ww1_flame", "enemy_ww1_lanchest", "enemy_ww1_m76", "enemy_ww1_mark4",
    "enemy_ww1_mauser", "enemy_ww1_mg08", "enemy_ww1_mp18", "enemy_ww1_saint",
    "enemy_ww1_storm", "enemy_ww1_vickers",
    "enemy_ww2_browning", "enemy_ww2_garand", "enemy_ww2_is2",
    "enemy_ww2_kingtiger", "enemy_ww2_m120", "enemy_ww2_mp40",
    "enemy_ww2_panther", "enemy_ww2_ppsh", "enemy_ww2_pz3",
    "enemy_ww2_pz4", "enemy_ww2_t34_76", "enemy_ww2_t34_85",
    "enemy_ww2_thompson",
]

# Step 1: Copy legacy files with Chinese names
print("=== Copying legacy files with Chinese names ===")
copied_with_name = 0
for legacy, chinese in legacy_to_chinese.items():
    src_path = os.path.join(SRC_DIR, f"{legacy}.png")
    dst_name = f"{legacy}_{chinese}.png"
    dst_path = os.path.join(DST_DIR, dst_name)
    
    if os.path.exists(src_path):
        shutil.copy2(src_path, dst_path)
        copied_with_name += 1
        print(f"COPIED: {legacy}.png -> {dst_name}")
    else:
        print(f"MISSING: {legacy}.png")

# Step 2: Copy legacy files without Chinese names (keep original filename)
print("\n=== Copying legacy files without Chinese names ===")
copied_without_name = 0
for legacy in unmapped_legacy:
    src_path = os.path.join(SRC_DIR, f"{legacy}.png")
    dst_path = os.path.join(DST_DIR, f"{legacy}.png")
    
    if os.path.exists(src_path):
        shutil.copy2(src_path, dst_path)
        copied_without_name += 1
        print(f"COPIED: {legacy}.png (no Chinese name)")
    else:
        print(f"MISSING: {legacy}.png")

print(f"\n=== SUMMARY ===")
print(f"Files copied with Chinese names: {copied_with_name}")
print(f"Files copied without Chinese names: {copied_without_name}")
print(f"Total: {copied_with_name + copied_without_name}")
