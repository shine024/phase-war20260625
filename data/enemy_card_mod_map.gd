extends RefCounted
class_name EnemyCardModMap
## 敌方战斗卡 → 玩家卡 + 专属改造池 映射表
##
## 用途：
##   1. IntelManual 追踪每张敌方卡的 base_progress / mod_intel_points
##   2. 情报达到阈值时，按该卡的 mod_pool 自动解锁对应改造模块
##   3. 进化面板查询低进化/高进化可用目标
##
## 结构：
##   key   = archetype_id（与 unified_card_table 中 enemy_only=true 条目一致）
##   value = {
##     "player_card_id": String,   # 对应的玩家可用卡（低进化目标；若 "" 则仅情报展示）
##     "mod_pool": Array[String],  # 该卡专属可解锁改造 ID 列表（空 = 按 combat_kind 全量）
##     "low_evo": bool,            # 50% base intel 是否允许低进化（默认 true）
##   }
##
## 覆盖 unified_card_table 全部 106 条 enemy_only 条目。
## 改造 ID 命名规范：inf_/arm_/art_/aa_/air_/rec_/eng_/for_/gen_ 前缀
## 对应兵种：步兵 / 装甲 / 炮兵 / 防空 / 航空 / 侦察 / 工程 / 堡垒 / 通用

const ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")

# ── 完整映射表 ────────────────────────────────────────────────────────────────

const MAPPING: Dictionary = {

	# ═══════════════════════════════════════════════
	#  一战时代 (era=0) — 主条目 + D段补充池
	#  改造逻辑：冲锋枪→双弹匣/机枪化；步枪→光学镜/穿甲弹；
	#  迫击炮→膛线/增程；装甲→倾斜装甲/柴油增压；Boss→复合装甲/尾翼稳定脱壳穿甲弹
	# ═══════════════════════════════════════════════
	"ww1_inf_mp18"          = {"player_card_id": "ww1_mp18",   "mod_pool": ["inf_01_submachine_gun", "inf_09_dual_mag", "gen_01_comms"],           "low_evo": true},
	"ww1_inf_rifle"         = {"player_card_id": "ww1_mauser", "mod_pool": ["inf_02_assault_rifle", "inf_07_optical_scope", "gen_03_camouflage"], "low_evo": true},
	"ww1_sup_mg_nest"       = {"player_card_id": "ww1_mg08",   "mod_pool": ["inf_10_saw", "inf_12_body_armor", "gen_05_shield"],                  "low_evo": true},
	"ww1_arty_mortar"       = {"player_card_id": "ww1_arty_m81","mod_pool": ["art_01_rifling", "art_02_extended_range", "art_07_ammo_supply"],    "low_evo": true},
	"ww1_inf_storm_e"       = {"player_card_id": "ww1_storm",  "mod_pool": ["inf_01_submachine_gun", "inf_05_ap_ammo", "inf_13_helmet_upgrade", "inf_22_breaching"], "low_evo": true},
	"ww1_arm_rolls_e"       = {"player_card_id": "ww1_arm_rolls","mod_pool": ["arm_01_sloped_armor", "arm_10_diesel_turbo", "arm_11_fire_control"],"low_evo": true},
	"ww1_boss_av7"          = {"player_card_id": "ww1_arm_ft17","mod_pool": ["arm_02_composite_armor", "arm_06_apfsds", "arm_12_thermal_sight", "arm_16_battle_frenzy"], "low_evo": false},
	"ww1_inf_enfield"       = {"player_card_id": "ww1_enfield","mod_pool": ["inf_02_assault_rifle", "inf_07_optical_scope", "gen_03_camouflage"],  "low_evo": true},
	"ww1_arm_rolls_mk2"     = {"player_card_id": "ww1_arm_rolls","mod_pool": ["arm_01_sloped_armor", "arm_10_diesel_turbo"],                     "low_evo": true},
	"ww1_sup_vickers"       = {"player_card_id": "ww1_mg08",   "mod_pool": ["inf_10_saw", "gen_05_shield"],                                       "low_evo": true},
	"ww1_sup_ford_ambulance"= {"player_card_id": "ww1_mp18",   "mod_pool": ["inf_18_ifak", "inf_17_tourniquet", "gen_04_vest"],                   "low_evo": true},
	"ww1_inf_mp18_x"        = {"player_card_id": "ww1_mp18",   "mod_pool": ["inf_01_submachine_gun", "inf_09_dual_mag", "inf_20_night_vision"],    "low_evo": true},

	# ═══════════════════════════════════════════════
	#  二战时代 (era=1)
	#  改造逻辑：汤普森→班用机枪化；加兰德→光学瞄准/防弹背心；
	#  MG42→防弹插板/盾牌；反坦克组→穿甲弹/高倍瞄准镜；
	#  黑豹→复合装甲/滑膛炮/热成像；虎王→爆反/APS/尾翼稳定穿甲弹
	# ═══════════════════════════════════════════════
	"ww2_inf_thompson"      = {"player_card_id": "ww2_thompson",    "mod_pool": ["inf_01_submachine_gun", "inf_09_dual_mag", "inf_19_radio"],               "low_evo": true},
	"ww2_inf_garand"        = {"player_card_id": "ww2_garand",      "mod_pool": ["inf_02_assault_rifle", "inf_07_optical_scope", "inf_12_body_armor"],       "low_evo": true},
	"ww2_sup_mg42"          = {"player_card_id": "ww2_mg42",        "mod_pool": ["inf_10_saw", "inf_11_armor_insert", "gen_05_shield"],                       "low_evo": true},
	"ww2_inf_panzerschrek_e"= {"player_card_id": "ww2_inf_panzerschrek","mod_pool": ["inf_05_ap_ammo", "inf_12_body_armor", "rec_04_high_power_scope"],        "low_evo": true},
	"ww2_inf_para_e"        = {"player_card_id": "ww2_thompson",    "mod_pool": ["inf_01_submachine_gun", "inf_20_night_vision", "rec_03_suppressor"],            "low_evo": true},
	"ww2_arm_panther_e"     = {"player_card_id": "ww2_panther",     "mod_pool": ["arm_02_composite_armor", "arm_05_smoothbore", "arm_12_thermal_sight", "arm_15_data_link"], "low_evo": true},
	"ww2_boss_kingtiger"    = {"player_card_id": "ww2_arm_tiger",   "mod_pool": ["arm_02_composite_armor", "arm_04_aps", "arm_06_apfsds", "arm_08_autoloader", "arm_16_battle_frenzy"], "low_evo": false},
	"ww2_arm_garand_para"   = {"player_card_id": "ww2_thompson",    "mod_pool": ["inf_02_assault_rifle", "inf_19_radio", "gen_02_digital"],                       "low_evo": true},
	"ww2_arty_hummel"       = {"player_card_id": "ww2_arty_m81",    "mod_pool": ["art_01_rifling", "art_02_extended_range", "art_06_fire_computer"],              "low_evo": true},
	"ww2_arty_pak40"        = {"player_card_id": "ww2_inf_panzerschrek","mod_pool": ["art_01_rifling", "art_06_fire_computer", "rec_05_uav"],                      "low_evo": true},
	"ww2_sup_gmc_truck"     = {"player_card_id": "ww2_thompson",    "mod_pool": ["eng_09_supply", "gen_04_vest"],                                                "low_evo": true},
	"ww2_inf_kar98k"        = {"player_card_id": "ww2_garand",      "mod_pool": ["inf_07_optical_scope", "inf_21_thermal", "rec_04_high_power_scope"],             "low_evo": true},

	# ═══════════════════════════════════════════════
	#  冷战时代 (era=2)
	#  改造逻辑：AK→突击步枪/防弹背心/电台；M60→小口径化/全息瞄准/防弹插板；
	#  BTR/布拉德利→爆反/蛙泳/数据链；T-72→爆反/尾翼稳定穿甲弹/火控计算机/热成像；
	#  米格→涡扇发动机/超视距导弹/ECM/数据链
	# ═══════════════════════════════════════════════
	"cold_inf_ak"           = {"player_card_id": "cold_ak47",   "mod_pool": ["inf_02_assault_rifle", "inf_12_body_armor", "inf_19_radio", "gen_03_camouflage"],          "low_evo": true},
	"cold_inf_m60"          = {"player_card_id": "cold_m14",    "mod_pool": ["inf_03_small_caliber", "inf_08_holographic", "inf_11_armor_insert"],                         "low_evo": true},
	"cold_arm_btr_e"        = {"player_card_id": "cold_bradley","mod_pool": ["arm_03_reactive_armor", "arm_13_deep_wading", "arm_15_data_link"],                             "low_evo": true},
	"cold_air_m113_e"       = {"player_card_id": "cold_bradley","mod_pool": ["arm_03_reactive_armor", "arm_09_turbine"],                                           "low_evo": true},
	"cold_inf_spetsnaz_e"   = {"player_card_id": "cold_spetsnaz","mod_pool": ["inf_02_assault_rifle", "inf_20_night_vision", "inf_21_thermal", "rec_01_optical_camouflage", "rec_03_suppressor"], "low_evo": true},
	"cold_arm_t72_e"        = {"player_card_id": "cold_t72",    "mod_pool": ["arm_03_reactive_armor", "arm_06_apfsds", "arm_11_fire_control", "arm_12_thermal_sight"],         "low_evo": true},
	"cold_boss_mig"         = {"player_card_id": "cold_mig21",  "mod_pool": ["air_01_turbofan", "air_06_bvr_missile", "air_08_ecm", "air_12_data_link"],                       "low_evo": false},
	"cold_arty_bmd1"        = {"player_card_id": "cold_bradley","mod_pool": ["arm_03_reactive_armor", "arm_09_turbine", "arm_13_deep_wading"],                               "low_evo": true},
	"cold_sup_bmp1_x"       = {"player_card_id": "cold_bradley","mod_pool": ["arm_03_reactive_armor", "arm_09_turbine"],                                              "low_evo": true},
	"cold_inf_metis"        = {"player_card_id": "cold_rpg",    "mod_pool": ["inf_05_ap_ammo", "inf_12_body_armor", "inf_21_thermal"],                                   "low_evo": true},
	"cold_arm_p18"          = {"player_card_id": "cold_mig21",  "mod_pool": ["aa_01_radar", "aa_07_aesa", "aa_11_auto_fc"],                                             "low_evo": true},
	"cold_arty_brem1"       = {"player_card_id": "cold_t72",    "mod_pool": ["arm_01_sloped_armor", "eng_01_mine_sweeper"],                                              "low_evo": true},

	# ═══════════════════════════════════════════════
	#  现代时代 (era=3)
	#  改造逻辑：海军陆战队→突击步枪/小口径/光学镜/电台/数字化；
	#  武装皮卡→穿甲弹/防弹背心/电台/伪装；斯特赖克→复合装甲/爆反/火控/数据链；
	#  HIMARS→增程弹/子母弹/侦察无人机/快速火力；
	#  三角洲→突击步枪/穿甲弹/夜视/热成像/光学伪装；艾布拉姆斯→爆反/尾翼稳定穿甲弹/火控/热成像/数据链；
	#  阿帕奇→涡扇/隐身涂层/超视距导弹/格斗导弹/武器挂架
	# ═══════════════════════════════════════════════
	"mod_inf_marine"       = {"player_card_id": "mod_marine",    "mod_pool": ["inf_02_assault_rifle", "inf_03_small_caliber", "inf_07_optical_scope", "inf_19_radio", "gen_02_digital"], "low_evo": true},
	"mod_air_technical_e"  = {"player_card_id": "mod_inf_technical","mod_pool": ["inf_05_ap_ammo", "inf_12_body_armor", "inf_19_radio", "gen_03_camouflage"],                   "low_evo": true},
	"mod_arm_stryker_e"    = {"player_card_id": "mod_stryker",   "mod_pool": ["arm_02_composite_armor", "arm_04_aps", "arm_11_fire_control", "arm_15_data_link"],                 "low_evo": true},
	"mod_arty_mlrs_e"      = {"player_card_id": "mod_arty_m270", "mod_pool": ["art_02_extended_range", "art_04_cluster_munition", "art_08_uav", "art_09_rapid_fire"],             "low_evo": true},
	"mod_inf_delta_e"      = {"player_card_id": "mod_ranger",    "mod_pool": ["inf_02_assault_rifle", "inf_05_ap_ammo", "inf_20_night_vision", "inf_21_thermal", "rec_01_optical_camouflage"], "low_evo": true},
	"mod_arm_abrams_e"     = {"player_card_id": "mod_arm_m1a1",  "mod_pool": ["arm_03_reactive_armor", "arm_06_apfsds", "arm_11_fire_control", "arm_12_thermal_sight", "arm_15_data_link"], "low_evo": true},
	"mod_air_apache_e"     = {"player_card_id": "mod_ah64",      "mod_pool": ["air_01_turbofan", "air_03_stealth_coating", "air_06_bvr_missile", "air_07_dogfight_missile", "air_11_weapon_rack"], "low_evo": true},
	"mod_boss_command"     = {"player_card_id": "",              "mod_pool": ["gen_01_comms", "gen_02_digital", "gen_06_laser_designator", "gen_09_ir_jammer"],                     "low_evo": false},
	"mod_sup_m4_carbine"   = {"player_card_id": "mod_marine",    "mod_pool": ["inf_01_submachine_gun", "inf_08_holographic", "gen_03_camouflage"],                                 "low_evo": true},
	"mod_inf_patriot"      = {"player_card_id": "mod_sup_zsu23", "mod_pool": ["aa_03_missile_rail", "aa_05_proximity_fuze", "aa_11_auto_fc", "gen_06_laser_designator"],            "low_evo": true},
	"mod_arm_himars"       = {"player_card_id": "mod_arty_m270", "mod_pool": ["art_03_guided_shell", "art_06_fire_computer", "art_08_uav"],                                         "low_evo": true},
	"mod_arty_rq7"         = {"player_card_id": "mod_ah64",      "mod_pool": ["air_04_aesa", "air_12_data_link", "rec_05_uav"],                                                     "low_evo": true},
	"mod_sup_growler"      = {"player_card_id": "fut_attack_drone","mod_pool": ["air_08_ecm", "air_12_data_link", "gen_09_ir_jammer"],                                                 "low_evo": true},
	"mod_arm_abrams_mk2"   = {"player_card_id": "mod_arm_m1a1",  "mod_pool": ["arm_02_composite_armor", "arm_04_aps", "arm_06_apfsds", "arm_11_fire_control", "arm_12_thermal_sight"], "low_evo": true},

	# ═══════════════════════════════════════════════
	#  近未来时代 (era=4)
	#  改造逻辑：赛博格→突击步枪/小口径/外骨骼/热成像/连击爆发；
	#  无人机→涡扇/隐身涂层/火控雷达/数据链；机兵→复合装甲/爆反/火控/数据链/相位共鸣；
	#  悬浮坦克→倾斜装甲/燃气轮机/柴油涡轮增压/数据链；
	#  幽灵→突击步枪/夜视/热成像/光学伪装/消音器；巨像→复合装甲/爆反/尾翼稳定穿甲弹/战斗狂热/相位护盾；
	#  神经接口→突击步枪/外骨骼/热成像/连击爆发；HK-07→爆反/火控/相位共鸣；
	#  HEL-30激光→膛线强化/精确制导/火控计算机/侦察无人机；N-Repair→医疗/补给/战术背心；
	#  X-9猎杀者→穿甲弹/外骨骼/光学伪装/消音器；毛瑟C96→冲锋枪/双弹匣/伪装；
	#  Sd.Kfz.251→倾斜装甲/柴油增压/防地雷；SS-C-1→增程弹/子母弹/快速火力；
	#  PS-9相位中继→战场通讯/数字化/红外干扰
	# ═══════════════════════════════════════════════
	"fut_inf_cyborg"       = {"player_card_id": "fut_cyborg",       "mod_pool": ["inf_02_assault_rifle", "inf_03_small_caliber", "inf_16_exoskeleton", "inf_21_thermal", "inf_23_combat_stimulant"], "low_evo": true},
	"fut_air_drone"        = {"player_card_id": "fut_attack_drone",  "mod_pool": ["air_01_turbofan", "air_03_stealth_coating", "air_04_aesa", "air_12_data_link"],                                                      "low_evo": true},
	"fut_arm_mech_e"       = {"player_card_id": "fut_assault_mech",  "mod_pool": ["arm_02_composite_armor", "arm_04_aps", "arm_11_fire_control", "arm_15_data_link", "gen_11_phase_resonance"],                          "low_evo": true},
	"fut_arm_hovertank_e"  = {"player_card_id": "fut_arm_hovertank", "mod_pool": ["arm_01_sloped_armor", "arm_09_turbine", "arm_10_diesel_turbo", "arm_15_data_link"],                                                       "low_evo": true},
	"fut_inf_spectre_e"    = {"player_card_id": "fut_spectre",       "mod_pool": ["inf_02_assault_rifle", "inf_20_night_vision", "inf_21_thermal", "rec_01_optical_camouflage", "rec_03_suppressor"],                   "low_evo": true},
	"fut_arm_colossus_e"   = {"player_card_id": "fut_colossus",      "mod_pool": ["arm_02_composite_armor", "arm_03_reactive_armor", "arm_06_apfsds", "arm_16_battle_frenzy", "gen_12_phase_shielding"],                  "low_evo": true},
	"fut_boss_nexus"       = {"player_card_id": "",                  "mod_pool": ["gen_11_phase_resonance", "gen_12_phase_shielding", "gen_13_phase_overdrive"],                                                             "low_evo": false},
	"fut_sup_bulwark"      = {"player_card_id": "fut_fort_citadel",  "mod_pool": ["for_01_concrete", "for_03_auto_turret", "for_06_radar", "for_10_command"],                                                                "low_evo": true},
	"fut_arm_titan_mk2"    = {"player_card_id": "fut_arm_heavy_mech","mod_pool": ["arm_02_composite_armor", "arm_04_aps", "arm_06_apfsds", "gen_12_phase_shielding"],                                                        "low_evo": true},
	"fut_inf_storm_rider"  = {"player_card_id": "fut_spectre",       "mod_pool": ["inf_01_submachine_gun", "inf_16_exoskeleton", "inf_23_combat_stimulant", "inf_24_urban_warfare"],                                           "low_evo": true},
	"fut_air_heavy_carrier"= {"player_card_id": "fut_space_fighter", "mod_pool": ["air_01_turbofan", "air_02_vector_thrust", "air_03_stealth_coating", "air_04_aesa", "air_06_bvr_missile"],                                   "low_evo": true},
	"fut_air_regen_frame"  = {"player_card_id": "fut_attack_drone",  "mod_pool": ["air_01_turbofan", "air_08_ecm", "air_12_data_link"],                                                                                     "low_evo": true},
	"fut_inf_neural"       = {"player_card_id": "fut_cyborg",        "mod_pool": ["inf_03_small_caliber", "inf_21_thermal", "gen_14_phase_shield_gen", "gen_16_emp_pulse"],                                                  "low_evo": true},
	"fut_arm_hk07"         = {"player_card_id": "fut_assault_mech",  "mod_pool": ["arm_03_reactive_armor", "arm_11_fire_control", "gen_11_phase_resonance"],                                                                   "low_evo": true},
	"fut_arty_hel30"       = {"player_card_id": "fut_howitzer",      "mod_pool": ["art_01_rifling", "art_03_guided_shell", "art_06_fire_computer", "art_08_uav"],                                                             "low_evo": true},
	"fut_sup_nrepair"      = {"player_card_id": "fut_fort_citadel",  "mod_pool": ["eng_08_medical", "eng_09_supply", "gen_04_vest"],                                                                                         "low_evo": true},
	"fut_inf_x9"           = {"player_card_id": "fut_spectre",       "mod_pool": ["inf_05_ap_ammo", "rec_01_optical_camouflage", "rec_03_suppressor", "inf_20_night_vision"],                                                    "low_evo": true},
	"fut_inf_c96"          = {"player_card_id": "fut_cyborg",        "mod_pool": ["inf_01_submachine_gun", "inf_09_dual_mag", "gen_03_camouflage"],                                                                           "low_evo": true},
	"fut_arm_sdkfz"        = {"player_card_id": "fut_assault_mech",  "mod_pool": ["arm_01_sloped_armor", "arm_10_diesel_turbo", "gen_07_mine_resistant"],                                                                   "low_evo": true},
	"fut_arty_ssc1"        = {"player_card_id": "fut_howitzer",      "mod_pool": ["art_02_extended_range", "art_04_cluster_munition", "art_09_rapid_fire"],                                                                    "low_evo": true},
	"fut_sup_ps9"          = {"player_card_id": "fut_fort_citadel","mod_pool": ["gen_01_comms", "gen_02_digital", "gen_09_ir_jammer"],                                                                                    "low_evo": true},

	# ═══════════════════════════════════════════════
	#  A段平台卡（low_evo=false，敌方部署专用，无低进化目标）
	# ═══════════════════════════════════════════════
	# 一战平台
	"platform_ww1_light"   = {"player_card_id": "ww1_mp18",    "mod_pool": ["inf_01_submachine_gun", "gen_03_camouflage"],   "low_evo": false},
	"platform_ww1_medium"  = {"player_card_id": "ww1_arm_rolls", "mod_pool": ["arm_01_sloped_armor", "arm_10_diesel_turbo"],  "low_evo": false},
	"platform_ww1_fort"    = {"player_card_id": "ww1_mg08",    "mod_pool": ["inf_10_saw", "gen_05_shield"],                   "low_evo": false},
	"platform_ww1_radar"   = {"player_card_id": "ww1_mg08",    "mod_pool": ["aa_01_radar", "gen_01_comms"],                   "low_evo": false},
	"platform_ww1_medic"   = {"player_card_id": "ww1_mp18",    "mod_pool": ["inf_18_ifak", "gen_04_vest"],                    "low_evo": false},
	# 二战平台
	"platform_ww2_light"   = {"player_card_id": "ww2_thompson","mod_pool": ["inf_01_submachine_gun", "gen_03_camouflage"],    "low_evo": false},
	"platform_ww2_medium"  = {"player_card_id": "ww2_pz3",     "mod_pool": ["arm_01_sloped_armor", "arm_10_diesel_turbo"],     "low_evo": false},
	"platform_ww2_heavy"   = {"player_card_id": "ww2_panther", "mod_pool": ["arm_02_composite_armor", "arm_05_smoothbore"],     "low_evo": false},
	"platform_ww2_raider"  = {"player_card_id": "ww2_thompson","mod_pool": ["inf_02_assault_rifle", "inf_19_radio"],           "low_evo": false},
	"platform_ww2_artillery"= {"player_card_id": "ww2_arty_m81","mod_pool": ["art_01_rifling", "art_02_extended_range"],       "low_evo": false},
	"platform_ww2_radar"    = {"player_card_id": "ww2_thompson","mod_pool": ["aa_01_radar", "gen_01_comms"],                   "low_evo": false},
	"platform_ww2_siege"    = {"player_card_id": "ww2_arty_m81","mod_pool": ["art_01_rifling", "art_06_fire_computer"],        "low_evo": false},
	"platform_ww2_fortress" = {"player_card_id": "ww2_mg42",    "mod_pool": ["inf_10_saw", "for_01_concrete", "for_09_minefield"],"low_evo": false},
	# 冷战平台
	"platform_cold_light"  = {"player_card_id": "cold_ak47",   "mod_pool": ["inf_02_assault_rifle", "gen_03_camouflage"],      "low_evo": false},
	"platform_cold_medium" = {"player_card_id": "cold_t72",    "mod_pool": ["arm_03_reactive_armor", "arm_09_turbine"],         "low_evo": false},
	"platform_cold_heavy"  = {"player_card_id": "cold_t72",    "mod_pool": ["arm_03_reactive_armor", "arm_06_apfsds", "arm_12_thermal_sight"], "low_evo": false},
	"platform_cold_radar"  = {"player_card_id": "cold_mig21",  "mod_pool": ["aa_01_radar", "aa_11_auto_fc"],                   "low_evo": false},
	"platform_cold_medic"  = {"player_card_id": "cold_ak47",   "mod_pool": ["inf_18_ifak", "gen_04_vest"],                     "low_evo": false},
	"platform_cold_carrier"= {"player_card_id": "cold_mig21",  "mod_pool": ["air_01_turbofan", "gen_01_comms"],                "low_evo": false},
	"platform_cold_ifv"    = {"player_card_id": "cold_bradley","mod_pool": ["arm_03_reactive_armor", "arm_13_deep_wading"],      "low_evo": false},
	"platform_cold_scout"  = {"player_card_id": "cold_ak47",   "mod_pool": ["inf_02_assault_rifle", "rec_01_optical_camouflage"], "low_evo": false},
	# 现代平台
	"platform_modern_light"   = {"player_card_id": "mod_marine",   "mod_pool": ["inf_02_assault_rifle", "gen_03_camouflage"],    "low_evo": false},
	"platform_modern_medium"  = {"player_card_id": "mod_arm_m1a1", "mod_pool": ["arm_02_composite_armor", "arm_11_fire_control"], "low_evo": false},
	"platform_modern_radar"   = {"player_card_id": "mod_sup_zsu23","mod_pool": ["aa_01_radar", "gen_06_laser_designator"],        "low_evo": false},
	"platform_modern_spg"     = {"player_card_id": "mod_arty_m270","mod_pool": ["art_01_rifling", "art_06_fire_computer"],        "low_evo": false},
	"platform_modern_stealth" = {"player_card_id": "mod_ranger",   "mod_pool": ["inf_02_assault_rifle", "rec_01_optical_camouflage"], "low_evo": false},
	"platform_modern_guard_heavy" = {"player_card_id": "mod_arm_m1a1","mod_pool": ["arm_03_reactive_armor", "arm_06_apfsds", "gen_12_phase_shielding"], "low_evo": false},
	# 近未来平台
	"platform_future_light"   = {"player_card_id": "fut_cyborg",      "mod_pool": ["inf_02_assault_rifle", "inf_16_exoskeleton"],    "low_evo": false},
	"platform_future_medium"  = {"player_card_id": "fut_arm_hovertank","mod_pool": ["arm_01_sloped_armor", "arm_10_diesel_turbo"],     "low_evo": false},
	"platform_future_radar"   = {"player_card_id": "fut_howitzer",    "mod_pool": ["art_01_rifling", "gen_06_laser_designator"],        "low_evo": false},
	"platform_future_heavy"   = {"player_card_id": "fut_arm_heavy_mech","mod_pool": ["arm_02_composite_armor", "arm_04_aps", "gen_11_phase_resonance"], "low_evo": false},

	# ═══════════════════════════════════════════════
	#  精英/Boss特色掉落卡（fixed mod_pool，无低进化）
	# ═══════════════════════════════════════════════
	"drop_smg_mk2"          = {"player_card_id": "ww1_mp18",    "mod_pool": ["inf_01_submachine_gun", "inf_09_dual_mag", "inf_10_saw"],           "low_evo": false},
	"drop_phase_lance"      = {"player_card_id": "ww2_thompson","mod_pool": ["inf_02_assault_rifle", "inf_08_holographic", "inf_20_night_vision"], "low_evo": false},
	"drop_railgun"          = {"player_card_id": "fut_cyborg",  "mod_pool": ["inf_02_assault_rifle", "inf_21_thermal", "rec_04_high_power_scope"], "low_evo": false},
	"drop_mega_beam_cannon" = {"player_card_id": "mod_arty_m270","mod_pool": ["art_01_rifling", "art_03_guided_shell", "art_06_fire_computer"],   "low_evo": false},
	"drop_thunder_field"    = {"player_card_id": "mod_ranger",  "mod_pool": ["inf_02_assault_rifle", "inf_23_combat_stimulant", "inf_24_urban_warfare"], "low_evo": false},
	"drop_overclock_matrix" = {"player_card_id": "mod_ah64",    "mod_pool": ["air_01_turbofan", "air_02_vector_thrust", "air_06_bvr_missile"],    "low_evo": false},
	"drop_mega_particle_cannon" = {"player_card_id": "fut_arm_heavy_mech","mod_pool": ["arm_02_composite_armor", "arm_04_aps", "arm_16_battle_frenzy", "gen_11_phase_resonance"], "low_evo": false},
}

# ── 工具函数 ────────────────────────────────────────────────────────────────

## 获取某敌方卡的配置（空字典 = 未配置）
static func get_config(archetype_id: String) -> Dictionary:
	return MAPPING.get(archetype_id, {})

## 获取对应的玩家卡 ID（"" = 无对应玩家卡）
static func get_player_card_id(archetype_id: String) -> String:
	var cfg: Dictionary = get_config(archetype_id)
	var pid: Variant = cfg.get("player_card_id")
	if pid == null:
		return ""
	return String(pid)

## 获取该敌方卡专属可解锁改造列表（空 pool 时按 combat_kind 全量）
## 注意：必须逐元素构建 Array[String]——直接 return pool.duplicate() 返回未类型化
## Array，运行时触发 "Trying to return an array of type Array where expected return
## type is Array[String]" 报错并按空处理（2026-08-28 v21 smoke 首跑踩坑，此前未被执行过）。
static func get_unlockable_mods(archetype_id: String) -> Array[String]:
	var cfg: Dictionary = get_config(archetype_id)
	var out: Array[String] = []
	var pool: Array = cfg.get("mod_pool", [])
	if not pool.is_empty():
		for m in pool:
			if m is String and not out.has(m):
				out.append(m)
		return out
	# 空 pool = 按 player_card_id 取全量
	var player_id: String = get_player_card_id(archetype_id)
	if player_id.is_empty():
		return out
	var mods: Array = ModificationRegistry.get_mods_for_card(player_id)
	for m in mods:
		if m is String and not out.has(m):
			out.append(m)
	return out

## 检查该卡是否允许低进化（50% base intel 触发）
static func can_low_evolve(archetype_id: String) -> bool:
	var cfg: Dictionary = get_config(archetype_id)
	return bool(cfg.get("low_evo", false))

## 获取所有已配置的 archetype_id 列表
static func get_all_archetype_ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(MAPPING.keys())
	return out

## 检查 archetype_id 是否已配置
static func has_entry(archetype_id: String) -> bool:
	return MAPPING.has(archetype_id)
