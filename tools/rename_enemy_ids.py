"""
敌方单位 id 统一改名工具
把旧 id（enemy_/elite_/boss_/fort_/foe_pool_ + A/B 段裸 id）改为新三段式 id。

处理三种形态：
1. 裸 id：如 ww1_rolls → ww1_arm_rolls（在 FOE_PLATFORM_CARD_IDS 等常量里）
2. 带 foe_ 前缀：foe_ww1_rolls → foe_ww1_arm_rolls（运行时拼接 + 部分 key）
3. 带 captured_ 前缀：captured_foe_ww1_rolls → captured_foe_ww1_arm_rolls（缴获卡 key）
4. C/D/E 段完整 id：enemy_cold_t72 → cold_arm_t72_e（无 foe_ 前缀）

策略：对每个旧 id，生成所有可能的前缀变体，用正则单词边界替换（避免子串误伤）。
长 id 先替换（防止短 id 是长 id 子串导致重复替换）。

用法：
    python tools/rename_enemy_ids.py --dry-run    # 预览改动
    python tools/rename_enemy_ids.py              # 实际写入
"""
import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)

# 旧裸 id → 新裸 id（A/B/omega 段，拼接 foe_ 前缀的基准）
BASE_MAPPING = {
    # A段 平台卡（28）
    'ww1_rolls': 'ww1_arm_rolls', 'ww1_ft17': 'ww1_arm_ft17', 'ww1_77mm': 'ww1_arty_77mm',
    'ww1_cavalry': 'ww1_inf_cavalry', 'ww1_engineer': 'ww1_sup_engineer',
    'ww2_hellcat': 'ww2_inf_hellcat', 'ww2_sherman': 'ww2_arm_sherman', 'ww2_tiger': 'ww2_arm_tiger',
    'ww2_bazooka': 'ww2_inf_bazooka', 'ww2_panzerschrek': 'ww2_inf_panzerschrek',
    'ww2_m81': 'ww2_arty_m81', 'ww1_m81': 'ww1_arty_m81',
    'cold_btr60': 'cold_inf_btr60', 'cold_t55': 'cold_arm_t55', 'cold_bmp1': 'cold_inf_bmp1',
    'cold_m113': 'cold_sup_m113', 'cold_zsu23': 'cold_sup_zsu23',
    'mod_technical': 'mod_inf_technical', 'mod_m1a1': 'mod_arm_m1a1', 'mod_m6': 'mod_sup_m6',
    'mod_m270': 'mod_arty_m270', 'fut_scout_drone': 'mod_inf_scout_drone', 'mod_m1a2sep': 'mod_arm_m1a2sep',
    'fut_scout_mech': 'fut_inf_scout_mech', 'fut_hovertank': 'fut_arm_hovertank',
    'fut_prism': 'fut_arm_prism', 'fut_heavy_mech': 'fut_arm_heavy_mech', 'fut_nexus': 'fut_arm_nexus',
    # B段 特殊（6）
    'bulwark': 'fut_sup_bulwark', 'titan_mk2': 'fut_arm_titan_mk2', 'storm_rider': 'fut_inf_storm_rider',
    'heavy_carrier': 'fut_air_heavy_carrier', 'regen_frame': 'fut_air_regen_frame', 'abrams_mk2': 'mod_arm_abrams_mk2',
    # omega（1）
    'omega_platform': 'fut_arm_omega',
}

# C/D/E 段：完整旧 id → 新 id（这些不带 foe_ 前缀，直接替换）
FULL_MAPPING = {
    # C段 固定敌人（36）
    'enemy_ww1_infantry_basic': 'ww1_inf_mp18', 'enemy_ww1_infantry_rifle': 'ww1_inf_rifle',
    'enemy_ww1_mg_nest': 'ww1_sup_mg_nest', 'enemy_ww1_mortar': 'ww1_arty_mortar',
    'elite_ww1_storm': 'ww1_inf_storm_e', 'elite_ww1_armored': 'ww1_arm_rolls_e', 'boss_ww1_av7': 'ww1_boss_av7',
    'enemy_ww2_infantry': 'ww2_inf_thompson', 'enemy_ww2_rifleman': 'ww2_inf_garand',
    'enemy_ww2_mg42': 'ww2_sup_mg42', 'enemy_ww2_panzerschreck': 'ww2_inf_panzerschreck_e',
    'elite_ww2_paratrooper': 'ww2_inf_para_e', 'elite_ww2_panther': 'ww2_arm_panther_e', 'boss_ww2_kingtiger': 'ww2_boss_kingtiger',
    'enemy_cold_ak': 'cold_inf_ak', 'enemy_cold_m60': 'cold_inf_m60', 'enemy_cold_btr': 'cold_arm_btr_e',
    'enemy_cold_m113': 'cold_air_m113_e', 'elite_cold_spetsnaz': 'cold_inf_spetsnaz_e',
    'elite_cold_t72': 'cold_arm_t72_e', 'boss_cold_mig': 'cold_boss_mig',
    'enemy_modern_marine': 'mod_inf_marine', 'enemy_modern_technical': 'mod_air_technical_e',
    'enemy_modern_stryker': 'mod_arm_stryker_e', 'enemy_modern_mlrs': 'mod_arty_mlrs_e',
    'elite_modern_delta': 'mod_inf_delta_e', 'elite_modern_abrams': 'mod_arm_abrams_e',
    'elite_modern_apache': 'mod_air_apache_e', 'boss_modern_command': 'mod_boss_command',
    'enemy_future_drone': 'fut_air_drone', 'enemy_future_cyborg': 'fut_inf_cyborg',
    'enemy_future_mech': 'fut_arm_mech_e', 'enemy_future_hovertank': 'fut_arm_hovertank_e',
    'elite_future_spectre': 'fut_inf_spectre_e', 'elite_future_colossus': 'fut_arm_colossus_e', 'boss_future_nexus': 'fut_boss_nexus',
    # E段 堡垒（10）
    'fort_ww1_pillbox': 'ww1_fort_pillbox', 'fort_ww1_artillery': 'ww1_fort_artillery',
    'fort_ww2_bunker': 'ww2_fort_bunker', 'fort_ww2_flak': 'ww2_fort_flak',
    'fort_cold_missile': 'cold_fort_missile', 'fort_cold_radar': 'cold_fort_radar',
    'fort_modern_citadel': 'mod_fort_citadel', 'fort_modern_phalanx': 'mod_fort_phalanx',
    'fort_future_ion': 'fut_fort_ion', 'fort_future_shield': 'fut_fort_shield',
    # D段 补充池（29）
    'foe_pool_001': 'ww1_inf_enfield', 'foe_pool_002': 'ww1_arm_rolls_mk2', 'foe_pool_003': 'ww1_sup_vickers',
    'foe_pool_004': 'ww1_sup_ford_ambulance', 'foe_pool_005': 'ww1_inf_mp18_x',
    'foe_pool_006': 'ww2_arm_garand_para', 'foe_pool_007': 'ww2_arty_hummel', 'foe_pool_008': 'ww2_arty_pak40',
    'foe_pool_009': 'ww2_sup_gmc_truck', 'foe_pool_010': 'ww2_inf_kar98k',
    'foe_pool_011': 'cold_arty_bmd1', 'foe_pool_012': 'cold_sup_bmp1_x', 'foe_pool_013': 'cold_inf_metis',
    'foe_pool_014': 'cold_arm_p18', 'foe_pool_015': 'cold_arty_brem1',
    'foe_pool_016': 'mod_sup_m4_carbine', 'foe_pool_017': 'mod_inf_patriot', 'foe_pool_018': 'mod_arm_himars',
    'foe_pool_019': 'mod_arty_rq7', 'foe_pool_020': 'mod_sup_growler',
    'foe_pool_021': 'fut_inf_neural', 'foe_pool_022': 'fut_arm_hk07', 'foe_pool_023': 'fut_arty_hel30',
    'foe_pool_024': 'fut_sup_nrepair', 'foe_pool_025': 'fut_inf_x9', 'foe_pool_026': 'fut_inf_c96',
    'foe_pool_027': 'fut_arm_sdkfz', 'foe_pool_028': 'fut_arty_ssc1', 'foe_pool_029': 'fut_sup_ps9',
}

# 待处理的文件（相对项目根）
TARGET_FILES = [
    "data/json/enemy_archetypes.json",
    "data/captured_card_stats.gd",
    "data/captured_unit_cards.gd",
    "data/enemy_unit_manifest.gd",
    "data/enemy_archetypes.gd",
    "data/enemy_archetypes_ww.gd",
    "data/enemy_archetypes_cold_modern.gd",
    "data/enemy_archetypes_future.gd",
    "data/default_cards.gd",
    "data/blueprint_definitions.gd",
    "data/unit_lineage_config.gd",
    "data/evolution_paths_supplement.gd",
    "data/evolution_paths/fort_evolution.gd",
    "data/weapon_names_table.gd",
    "scenes/units/construct_unit.gd",
    "scenes/units/enemy_phase_field_driver.gd",
    "scenes/units/swarm_enemy_slot.gd",
    "scenes/tools/enemy_preview.gd",
    "scripts/systems/evolution_path_registry.gd",
    "tests/battle_card_visual_audit.gd",
    "tests/card_icon_fix_verify.gd",
    "tests/unit/combat/test_enemy_stat_resolver.gd",
]


def build_replacement_patterns():
    """构建所有 (旧串, 新串) 对，含前缀变体，按长度降序排列避免子串误伤。"""
    pairs = []
    # C/D/E 段：完整 id + foe_/captured_ 前缀变体（D段 foe_pool 已是完整，但 captured_ 前缀需处理）
    for old, new in FULL_MAPPING.items():
        pairs.append((old, new))
        # captured_ 前缀变体
        if not old.startswith("foe_"):
            pairs.append(("captured_" + old, "captured_" + new))
    # A/B/omega 段：裸 id + foe_/captured_foe_ 前缀变体
    for old, new in BASE_MAPPING.items():
        pairs.append((old, new))  # 裸
        pairs.append(("foe_" + old, "foe_" + new))  # foe_ 前缀
        pairs.append(("captured_foe_" + old, "captured_foe_" + new))  # captured_foe_ 前缀
    # 按旧串长度降序（长串先替换）
    pairs.sort(key=lambda p: len(p[0]), reverse=True)
    return pairs


def replace_in_text(text: str, pairs) -> tuple:
    """用单词边界替换所有模式。返回 (新文本, 替换次数)。"""
    total = 0
    for old, new in pairs:
        if old == new:
            continue
        # 用正则边界：id 字符是 [a-z0-9_]，边界为非 id 字符或串首/尾
        # (?<![a-z0-9_]) 后向否定 + (?![a-z0-9_]) 前向否定
        pattern = re.escape(old)
        # 但 id 含 _，re.escape 不影响 _
        regex = r"(?<![a-zA-Z0-9_])" + re.escape(old) + r"(?![a-zA-Z0-9_])"
        new_text, n = re.subn(regex, lambda m: new, text)
        if n > 0:
            text = new_text
            total += n
    return text, total


def main():
    dry_run = "--dry-run" in sys.argv
    pairs = build_replacement_patterns()

    print("=== 敌方单位 id 改名 ===")
    print("模式: %s" % ("DRY-RUN" if dry_run else "实际写入"))
    print("映射对数: %d（含前缀变体）" % len(pairs))
    print()

    grand_total = 0
    file_stats = []
    for rel in TARGET_FILES:
        path = os.path.join(PROJECT_ROOT, rel.replace("\\", "/"))
        if not os.path.exists(path):
            print("  [跳过] 不存在: %s" % rel)
            continue
        with open(path, "r", encoding="utf-8") as f:
            original = f.read()
        new_text, n = replace_in_text(original, pairs)
        file_stats.append((rel, n))
        grand_total += n
        if n > 0 and not dry_run:
            with open(path, "w", encoding="utf-8") as f:
                f.write(new_text)

    # 输出统计
    print("=== 替换统计 ===")
    for rel, n in sorted(file_stats, key=lambda x: -x[1]):
        marker = " ✓" if n > 0 else ""
        print("  %4d 处  %s%s" % (n, rel, marker))
    print()
    print("总替换: %d 处" % grand_total)
    if dry_run:
        print("(DRY-RUN：未写入文件)")


if __name__ == "__main__":
    main()
