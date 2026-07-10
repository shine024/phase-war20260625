import json, io, sys, re
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

with open('tools/_mycard_ids.json', encoding='utf-8') as f:
    mycards = json.load(f)
with open('tools/_icon_standard_mapping.json', encoding='utf-8') as f:
    std = json.load(f)
# 标准反向：card_id(审查表) -> name
std_names = {cid: v['display_name'] for cid,v in std.items()}

# manifest foe_ 映射（敌方 card_id -> visual_id）
FOE_PLATFORM = ["ww1_arm_rolls","ww1_arm_ft17","ww1_arty_77mm","ww1_inf_cavalry","ww1_sup_engineer","ww2_inf_hellcat","ww2_arm_sherman","ww2_arm_tiger","ww2_inf_bazooka","ww2_inf_panzerschrek","ww2_arty_m81","ww1_arty_m81","cold_inf_btr60","cold_arm_t55","cold_inf_bmp1","cold_sup_m113","cold_sup_zsu23","mod_inf_technical","mod_arm_m1a1","mod_sup_m6","mod_arty_m270","mod_inf_scout_drone","mod_arm_m1a2sep","fut_inf_scout_mech","fut_arm_hovertank","fut_arm_prism","fut_arm_heavy_mech","fut_arm_nexus"]
FOE_SPECIAL = ["fut_sup_bulwark","fut_arm_titan_mk2","fut_inf_storm_rider","fut_air_heavy_carrier","fut_air_regen_frame","mod_arm_abrams_mk2"]
CAPTURED = ["ww1_inf_mp18","ww1_inf_rifle","ww1_sup_mg_nest","ww1_arty_mortar","ww1_inf_storm_e","ww1_arm_rolls_e","ww1_boss_av7","ww2_inf_thompson","ww2_inf_garand","ww2_sup_mg42","ww2_inf_panzerschreck_e","ww2_inf_para_e","ww2_arm_panther_e","ww2_boss_kingtiger"]
FORT = ["ww1_fort_pillbox","ww1_fort_artillery","ww2_fort_bunker","ww2_fort_flak","cold_fort_missile","cold_fort_radar","mod_fort_citadel","mod_fort_phalanx","fut_fort_ion","fut_fort_shield"]
FIXED = ["ww1_inf_mp18","ww1_inf_rifle","ww1_sup_mg_nest","ww1_arty_mortar","ww1_inf_storm_e","ww1_arm_rolls_e","ww1_boss_av7","ww2_inf_thompson","ww2_inf_garand","ww2_sup_mg42","ww2_inf_panzerschreck_e","ww2_inf_para_e","ww2_arm_panther_e","ww2_boss_kingtiger","cold_inf_ak","cold_inf_m60","cold_arm_btr_e","cold_air_m113_e","cold_inf_spetsnaz_e","cold_arm_t72_e","cold_boss_mig","mod_inf_marine","mod_air_technical_e","mod_arm_stryker_e","mod_arty_mlrs_e","mod_inf_delta_e","mod_arm_abrams_e","mod_air_apache_e","mod_boss_command","fut_air_drone","fut_inf_cyborg","fut_arm_mech_e","fut_arm_hovertank_e","fut_inf_spectre_e","fut_arm_colossus_e","fut_boss_nexus"]
POOL = ["ww1_inf_enfield","ww1_arm_rolls_mk2","ww1_sup_vickers","ww1_sup_ford_ambulance","ww1_inf_mp18_x","ww2_arm_garand_para","ww2_arty_hummel","ww2_arty_pak40","ww2_sup_gmc_truck","ww2_inf_kar98k","cold_arty_bmd1","cold_sup_bmp1_x","cold_inf_metis","cold_arm_p18","cold_arty_brem1","mod_sup_m4_carbine","mod_inf_patriot","mod_arm_himars","mod_arty_rq7","mod_sup_growler","fut_inf_neural","fut_arm_hk07","fut_arty_hel30","fut_sup_nrepair","fut_inf_x9","fut_inf_c96","fut_arm_sdkfz","fut_arty_ssc1","fut_sup_ps9"]

def visual_id_for(sid):
    for i,e in enumerate(FORT):
        if sid==e: return "vis_player_%03d"%(72+i)
    for i,e in enumerate(CAPTURED):
        if sid==e: return "vis_player_%03d"%(36+i)
    if sid in FIXED: return "vis_player_%03d"%(36+FIXED.index(sid))
    if sid in POOL: return sid
    if sid in FOE_SPECIAL: return "vis_player_%03d"%(30+FOE_SPECIAL.index(sid))
    if sid in FOE_PLATFORM: return "vis_player_%03d"%(1+FOE_PLATFORM.index(sid))
    return None  # manifest 查不到

# ERA_KIND_FALLBACK_ICON (era, combat_kind) -> vis_player
ERA_KIND = {
    "0_0":"vis_player_004","0_1":"vis_player_001","0_2":"vis_player_003","0_3":"vis_player_015","0_4":"vis_player_003",
    "1_0":"vis_player_009","1_1":"vis_player_007","1_2":"vis_player_011","1_3":"vis_player_022","1_4":"vis_player_011",
    "2_0":"vis_player_018","2_1":"vis_player_014","2_2":"vis_player_016","2_3":"vis_player_015","2_4":"vis_player_016",
    "3_0":"vis_player_018","3_1":"vis_player_019","3_2":"vis_player_020","3_3":"vis_player_022","3_4":"vis_player_020",
    "4_0":"vis_player_024","4_1":"vis_player_025","4_2":"vis_player_020","4_3":"vis_player_022","4_4":"vis_player_025",
}
# combat_kind: 0=LIGHT(轻),1=ARMOR(甲),2=SUPPORT(援),3=AIR(空),4=FORT(堡)
KIND_NAME = {0:"轻装",1:"装甲",2:"支援",3:"空中",4:"堡垒"}
ERA_NAME = {0:"一战",1:"二战",2:"冷战",3:"现代",4:"近未来"}

# 需要每张我方卡的 era 和 combat_kind——从 default_cards.gd 解析
import re as _re
with open('data/default_cards.gd', encoding='utf-8') as f:
    dc = f.read()
# _unit("id","name",era,kind,...)
card_meta = {}
for m in _re.finditer(r'_unit\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*(\d+)\s*,\s*(\d+)', dc):
    card_meta[m.group(1)] = {'era':int(m.group(3)),'kind':int(m.group(4)),'name':m.group(2)}

lines=[]
hits_manifest=0; hits_era=0; hits_none=0
problem=[]
for c in mycards:
    cid = c['card_id']
    name = c['name']
    vid = visual_id_for(cid)
    era = card_meta.get(cid,{}).get('era')
    kind = card_meta.get(cid,{}).get('kind')
    if vid:
        hits_manifest+=1
        branch="manifest"
        result=vid
    elif era is not None:
        ek = "%d_%d"%(era,kind)
        result = ERA_KIND.get(ek, "")
        if result:
            hits_era+=1
            branch="ERA_KIND回退(时代+兵种)"
        else:
            hits_none+=1
            branch="无图"
            result=""
    else:
        hits_none+=1
        branch="无元数据"
        result=""
    # 标注：manifest命中说明有专属敌图；ERA回退说明用通用代表图
    flag = "" if branch=="manifest" else "  ← 通用回退(无专属图)"
    lines.append(f"{cid:26s} {name:16s} [{ERA_NAME.get(era,'?')}/{KIND_NAME.get(kind,'?')}] -> {result:18s} ({branch}){flag}")
    if branch!="manifest":
        problem.append((cid,name,era,kind,result,branch))

out=[]
out.append("===== 112 张我方卡取图模拟 =====")
out.append("manifest专属命中: %d | ERA_KIND回退: %d | 无图: %d" % (hits_manifest, hits_era, hits_none))
out.append("")
out.extend(lines)
out.append("")
out.append("===== 走回退的卡（用通用代表图，非专属）=====")
for cid,name,era,kind,r,br in problem:
    out.append(f"  {cid:26s} {name:16s} {ERA_NAME.get(era,'?')}/{KIND_NAME.get(kind,'?')} -> {r}")
with open('tools/_sim_all_player.txt','w',encoding='utf-8') as f:
    f.write('\n'.join(out))
print("manifest: %d, era回退: %d, 无图: %d" % (hits_manifest, hits_era, hits_none))
print("回退卡数:", len(problem))
