import json, io, sys, re
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

with open('tools/_mycard_ids.json', encoding='utf-8') as f:
    mycards = json.load(f)
with open('tools/_icon_standard_mapping.json', encoding='utf-8') as f:
    std = json.load(f)

# 标准: enemy card_id -> (icon_num, filename, name)
FOE_PLATFORM = ["ww1_arm_rolls","ww1_arm_ft17","ww1_arty_77mm","ww1_inf_cavalry","ww1_sup_engineer","ww2_inf_hellcat","ww2_arm_sherman","ww2_arm_tiger","ww2_inf_bazooka","ww2_inf_panzerschrek","ww2_arty_m81","ww1_arty_m81","cold_inf_btr60","cold_arm_t55","cold_inf_bmp1","cold_sup_m113","cold_sup_zsu23","mod_inf_technical","mod_arm_m1a1","mod_sup_m6","mod_arty_m270","mod_inf_scout_drone","mod_arm_m1a2sep","fut_inf_scout_mech","fut_arm_hovertank","fut_arm_prism","fut_arm_heavy_mech","fut_arm_nexus"]
FOE_SPECIAL = ["fut_sup_bulwark","fut_arm_titan_mk2","fut_inf_storm_rider","fut_air_heavy_carrier","fut_air_regen_frame","mod_arm_abrams_mk2"]
CAPTURED = ["ww1_inf_mp18","ww1_inf_rifle","ww1_sup_mg_nest","ww1_arty_mortar","ww1_inf_storm_e","ww1_arm_rolls_e","ww1_boss_av7","ww2_inf_thompson","ww2_inf_garand","ww2_sup_mg42","ww2_inf_panzerschreck_e","ww2_inf_para_e","ww2_arm_panther_e","ww2_boss_kingtiger"]
FORT = ["ww1_fort_pillbox","ww1_fort_artillery","ww2_fort_bunker","ww2_fort_flak","cold_fort_missile","cold_fort_radar","mod_fort_citadel","mod_fort_phalanx","fut_fort_ion","fut_fort_shield"]
FIXED = CAPTURED + ["cold_inf_ak","cold_inf_m60","cold_arm_btr_e","cold_air_m113_e","cold_inf_spetsnaz_e","cold_arm_t72_e","cold_boss_mig","mod_inf_marine","mod_air_technical_e","mod_arm_stryker_e","mod_arty_mlrs_e","mod_inf_delta_e","mod_arm_abrams_e","mod_air_apache_e","mod_boss_command","fut_air_drone","fut_inf_cyborg","fut_arm_mech_e","fut_arm_hovertank_e","fut_inf_spectre_e","fut_arm_colossus_e","fut_boss_nexus"]
POOL = ["ww1_inf_enfield","ww1_arm_rolls_mk2","ww1_sup_vickers","ww1_sup_ford_ambulance","ww1_inf_mp18_x","ww2_arm_garand_para","ww2_arty_hummel","ww2_arty_pak40","ww2_sup_gmc_truck","ww2_inf_kar98k","cold_arty_bmd1","cold_sup_bmp1_x","cold_inf_metis","cold_arm_p18","cold_arty_brem1","mod_sup_m4_carbine","mod_inf_patriot","mod_arm_himars","mod_arty_rq7","mod_sup_growler","fut_inf_neural","fut_arm_hk07","fut_arty_hel30","fut_sup_nrepair","fut_inf_x9","fut_inf_c96","fut_arm_sdkfz","fut_arty_ssc1","fut_sup_ps9"]

def visual_id_for(sid):
    for i,e in enumerate(FORT):
        if sid==e: return (72+i)
    for i,e in enumerate(CAPTURED):
        if sid==e: return (36+i)
    if sid in FIXED: return (36+FIXED.index(sid))
    if sid in POOL: return sid
    if sid in FOE_SPECIAL: return (30+FOE_SPECIAL.index(sid))
    if sid in FOE_PLATFORM: return (1+FOE_PLATFORM.index(sid))
    return None

# 所有 enemy 图编号 -> name
en_num_name = {}
for cid,v in std.items():
    if v['icon_num'] is not None:
        en_num_name[v['icon_num']] = (cid, v['display_name'])
    else:
        en_num_name[cid] = (cid, v['display_name'])

# 我方卡 meta
with open('data/default_cards.gd', encoding='utf-8') as f:
    dc = f.read()
card_meta = {}
for m in re.finditer(r'_unit\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*(\d+)\s*,\s*(\d+)', dc):
    card_meta[m.group(1)] = {'era':int(m.group(3)),'kind':int(m.group(4)),'name':m.group(2)}

ERA_KIND = {"0_0":4,"0_1":1,"0_2":3,"0_3":15,"0_4":3,"1_0":9,"1_1":7,"1_2":11,"1_3":22,"1_4":11,"2_0":18,"2_1":14,"2_2":16,"2_3":15,"2_4":16,"3_0":18,"3_1":19,"3_2":20,"3_3":22,"3_4":20,"4_0":24,"4_1":25,"4_2":20,"4_3":22,"4_4":25}

# 统计每个 vis_player 编号被多少我方卡使用（当前）
usage = {}
fallback_cards = []
for c in mycards:
    cid=c['card_id']; meta=card_meta.get(cid)
    vid_num = visual_id_for(cid)
    if vid_num is not None:
        continue  # manifest 命中
    # 走回退
    ek = "%d_%d"%(meta['era'],meta['kind'])
    n = ERA_KIND.get(ek)
    fallback_cards.append((cid, meta['name'], meta['era'], meta['kind'], n))
    usage[n] = usage.get(n,0)+1

print("===== 当前回退图的使用密度（哪些代表图被大量复用）=====")
for n in sorted(usage, key=lambda k:-usage[k]):
    cid,name = en_num_name.get(n,('???','???'))
    print(f"  vis_player_{n:03d} [{cid}/{name}] 被 {usage[n]} 张我方卡复用")
print(f"\n回退卡总数: {len(fallback_cards)}")
