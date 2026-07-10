# 模拟 card_icon_path_for 对所有我方战斗卡的取图，列出每张卡最终取的 player 图
import json, io, sys, os
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

with open('tools/_icon_standard_mapping.json', encoding='utf-8') as f:
    std = json.load(f)

# manifest 的 foe_ -> visual_id 映射（_visual_id_for_source_id 结果）
FOE_PLATFORM_CARD_IDS = ["ww1_arm_rolls","ww1_arm_ft17","ww1_arty_77mm","ww1_inf_cavalry","ww1_sup_engineer","ww2_inf_hellcat","ww2_arm_sherman","ww2_arm_tiger","ww2_inf_bazooka","ww2_inf_panzerschrek","ww2_arty_m81","ww1_arty_m81","cold_inf_btr60","cold_arm_t55","cold_inf_bmp1","cold_sup_m113","cold_sup_zsu23","mod_inf_technical","mod_arm_m1a1","mod_sup_m6","mod_arty_m270","mod_inf_scout_drone","mod_arm_m1a2sep","fut_inf_scout_mech","fut_arm_hovertank","fut_arm_prism","fut_arm_heavy_mech","fut_arm_nexus"]
FOE_SPECIAL_CARD_IDS = ["fut_sup_bulwark","fut_arm_titan_mk2","fut_inf_storm_rider","fut_air_heavy_carrier","fut_air_regen_frame","mod_arm_abrams_mk2"]
CAPTURED_ENEMY_IDS = ["ww1_inf_mp18","ww1_inf_rifle","ww1_sup_mg_nest","ww1_arty_mortar","ww1_inf_storm_e","ww1_arm_rolls_e","ww1_boss_av7","ww2_inf_thompson","ww2_inf_garand","ww2_sup_mg42","ww2_inf_panzerschreck_e","ww2_inf_para_e","ww2_arm_panther_e","ww2_boss_kingtiger"]
FORT_ENEMY_IDS = ["ww1_fort_pillbox","ww1_fort_artillery","ww2_fort_bunker","ww2_fort_flak","cold_fort_missile","cold_fort_radar","mod_fort_citadel","mod_fort_phalanx","fut_fort_ion","fut_fort_shield"]
FIXED_ENEMY_IDS = ["ww1_inf_mp18","ww1_inf_rifle","ww1_sup_mg_nest","ww1_arty_mortar","ww1_inf_storm_e","ww1_arm_rolls_e","ww1_boss_av7","ww2_inf_thompson","ww2_inf_garand","ww2_sup_mg42","ww2_inf_panzerschreck_e","ww2_inf_para_e","ww2_arm_panther_e","ww2_boss_kingtiger","cold_inf_ak","cold_inf_m60","cold_arm_btr_e","cold_air_m113_e","cold_inf_spetsnaz_e","cold_arm_t72_e","cold_boss_mig","mod_inf_marine","mod_air_technical_e","mod_arm_stryker_e","mod_arty_mlrs_e","mod_inf_delta_e","mod_arm_abrams_e","mod_air_apache_e","mod_boss_command","fut_air_drone","fut_inf_cyborg","fut_arm_mech_e","fut_arm_hovertank_e","fut_inf_spectre_e","fut_arm_colossus_e","fut_boss_nexus"]
POOL_ENEMY_IDS = ["ww1_inf_enfield","ww1_arm_rolls_mk2","ww1_sup_vickers","ww1_sup_ford_ambulance","ww1_inf_mp18_x","ww2_arm_garand_para","ww2_arty_hummel","ww2_arty_pak40","ww2_sup_gmc_truck","ww2_inf_kar98k","cold_arty_bmd1","cold_sup_bmp1_x","cold_inf_metis","cold_arm_p18","cold_arty_brem1","mod_sup_m4_carbine","mod_inf_patriot","mod_arm_himars","mod_arty_rq7","mod_sup_growler","fut_inf_neural","fut_arm_hk07","fut_arty_hel30","fut_sup_nrepair","fut_inf_x9","fut_inf_c96","fut_arm_sdkfz","fut_arty_ssc1","fut_sup_ps9"]

def visual_id_for(sid):
    for i,e in enumerate(FORT_ENEMY_IDS):
        if sid==e: return "vis_player_%03d"%(72+i)
    for i,e in enumerate(CAPTURED_ENEMY_IDS):
        if sid==e: return "vis_player_%03d"%(36+i)
    if sid in FIXED_ENEMY_IDS: return "vis_player_%03d"%(36+FIXED_ENEMY_IDS.index(sid))
    if sid in POOL_ENEMY_IDS: return sid
    if sid in FOE_SPECIAL_CARD_IDS: return "vis_player_%03d"%(30+FOE_SPECIAL_CARD_IDS.index(sid))
    if sid in FOE_PLATFORM_CARD_IDS: return "vis_player_%03d"%(1+FOE_PLATFORM_CARD_IDS.index(sid))
    return None  # manifest 查不到

# 标准编号 -> (card_id, name)
num_std = {}
for cid,v in std.items():
    if v['icon_num'] is not None:
        num_std[v['icon_num']] = (cid, v['display_name'])
    else:
        num_std[cid] = (cid, v['display_name'])

lines=[]
ok=0; manifest_ok=0; fallback=0; mismatch=[]
for cid, v in std.items():
    vid = visual_id_for(cid)
    if vid:
        manifest_ok+=1
        # 解析编号
        import re
        m = re.match(r'vis_player_(\d+)', vid)
        num = int(m.group(1)) if m else None
        std_num = v['icon_num']
        if num == std_num or vid==cid:
            ok+=1
        else:
            mismatch.append((cid, v['display_name'], std_num, num))
    else:
        fallback+=1
        mismatch.append((cid, v['display_name'], v['icon_num'], 'FALLBACK(走ERA_KIND/SHAPE_KEY)'))

lines.append("manifest 命中: %d | 走回退: %d | 编号匹配: %d" % (manifest_ok, fallback, ok))
lines.append("不一致: %d" % len(mismatch))
lines.append("")
for cid,name,sn,cn in mismatch:
    lines.append("  %-24s %-14s 标准编号=%s 实际=%s" % (cid, name, sn, cn))
with open('tools/_simulate_result.txt','w',encoding='utf-8') as f:
    f.write('\n'.join(lines))
print('\n'.join(lines[:5]))
