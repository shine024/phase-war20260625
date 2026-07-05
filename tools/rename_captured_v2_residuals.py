"""
captured_card_stats.gd 残留 key 补充改名
处理首轮漏掉的：
1. _v2 后缀的敌人原图 key（captured_enemy_xxx_v2 → captured_新id_v2）
2. panzerschrek 拼写变体（captured_enemy_ww2_panzerschrek，少一个 c）
"""
import os, re

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(PROJECT_ROOT, "data", "captured_card_stats.gd")

# C段 旧 id → 新 id（与主脚本一致）
C_MAPPING = {
    'enemy_ww1_infantry_basic': 'ww1_inf_mp18', 'enemy_ww1_infantry_rifle': 'ww1_inf_rifle',
    'enemy_ww1_mg_nest': 'ww1_sup_mg_nest', 'enemy_ww1_mortar': 'ww1_arty_mortar',
    'elite_ww1_storm': 'ww1_inf_storm_e', 'elite_ww1_armored': 'ww1_arm_rolls_e', 'boss_ww1_av7': 'ww1_boss_av7',
    'enemy_ww2_infantry': 'ww2_inf_thompson', 'enemy_ww2_rifleman': 'ww2_inf_garand',
    'enemy_ww2_mg42': 'ww2_sup_mg42', 'enemy_ww2_panzerschreck': 'ww2_inf_panzerschreck_e',
    'enemy_ww2_panzerschrek': 'ww2_inf_panzerschreck_e',  # 拼写变体（少c）
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
}

def build_pairs():
    pairs = []
    for old, new in C_MAPPING.items():
        # captured_ + old（无 _v2）
        pairs.append(("captured_" + old, "captured_" + new))
        # captured_ + old + _v2
        pairs.append(("captured_" + old + "_v2", "captured_" + new + "_v2"))
    # 按长度降序（panzerschreck 在 panzerschrek 前，长串先替换）
    pairs.sort(key=lambda p: len(p[0]), reverse=True)
    return pairs

with open(TARGET, "r", encoding="utf-8") as f:
    text = f.read()

pairs = build_pairs()
total = 0
for old, new in pairs:
    if old == new:
        continue
    regex = r"(?<![a-zA-Z0-9_])" + re.escape(old) + r"(?![a-zA-Z0-9_])"
    text, n = re.subn(regex, lambda m: new, text)
    total += n

with open(TARGET, "w", encoding="utf-8") as f:
    f.write(text)

print("captured_card_stats.gd 补充改名: %d 处" % total)
