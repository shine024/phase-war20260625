extends RefCounted
class_name EnemyFixedLoadouts
## v26 敌方固定配装表（137 卡全量 = 109 经典 + 8 新飞机 + v27 星冥 20）——每张敌方战斗卡的"特点定位 + 四档增量改造序列"
## v27: 星冥 xeno_* 条目改造池兼容映射近未来带（生成器 pool_era=4，era=5 查询亦走该带）。
##
## 数据结构（LOADOUTS，由 tools/gen_enemy_loadout_draft.gd 生成 + 人工核对）：
##   "<archetype_id>": {
##       "identity": "一句话定位（进战场敌方详情）",
##       "mods": [ ...9 条有序增量序列 ],      # 档位取前 N 条（同卡只增不减=养成感）
##       "cuts": {1: 5, 2: 7, 3: 9, 4: 9},    # 各档取条数（缺省用 DEFAULT_CUTS）
##   }
## 生成时已校验：conflict_group 无同组冲突 / era_band 兼容 / 效果键白名单内至少一键。
##
## 消费链：
##   enemy_unit._apply_loadout_modifications（v26 挂载，经典敌兵 B 路径）
##   master_platform_power（相位师产兵 A 路径，走 build_stats_from_card）
## 展示：card_info_panel 敌方分支"敌方配装"段。

const Tiers = preload("res://data/enemy_loadout_tiers.gd")

## 各档默认取条数（新兵 5 / 老兵 6-7 / 精英 8-9 / 传奇 9 满配；逐卡可覆写）
const DEFAULT_CUTS: Dictionary = {
	Tiers.TIER_RECRUIT: 5,
	Tiers.TIER_VETERAN: 7,
	Tiers.TIER_ELITE: 9,
	Tiers.TIER_LEGENDARY: 9,
}

## v26 敌方消费路径支持的改造效果键白名单（"宁可少接不可乱接"口径，仿 v21 词条白名单）：
## - 数值键全开（敌方 stats/伤害结算链两侧均有分支）
## - 命中侧机制键开（DOT/连锁/破甲/溅射/标记/击杀修复——bullet/module_effect_handler 敌我共用）
## - attack_interval 已开（v26.2 第二阶段）：registry 转写为 per-target 攻速轴落 stats，
##   挂载点经 _sync_mod_speed_ratio_to_weapon_slots 同步进 weapon_slots[].attack_speed
##   （敌方 timing 主路径读武器槽速度——只写 stats 会空转，敌我同构的存量缺口已补）
## - 先排除：ally_*（经典敌兵无光环组播链，只有载体半额，可读性差）、
##   受击侧机制键（爆反/拦截/怒气/急救——挂在 construct_unit.take_damage，经典敌兵空转）、
##   combo/rage/revive 类（受击/成长侧，同上）
const LOADOUT_MOD_SUPPORTED_KEYS: Array = [
	# 三维攻击/防御/HP（含 v22 四通道的 flat/pct/set 全形态，registry 统一消费）
	"attack_light", "attack_armor", "attack_air",
	"attack_light_pct", "attack_armor_pct", "attack_air_pct", "max_hp_pct",
	"attack_light_set", "attack_armor_set", "attack_air_set", "max_hp_set",
	"defense_light", "defense_armor", "defense_air",
	"defense_light_pct", "defense_armor_pct", "defense_air_pct",
	"max_hp",
	# 数值副属性
	"move_speed", "attack_range", "deploy_speed", "attack_interval",
	"crit_chance", "crit_damage_bonus", "crit_resist",
	"dodge_chance", "damage_reduction", "hp_regen",
	"armor_penetration", "armor_pen_vs_light", "armor_pen_vs_armor", "armor_pen_vs_air",
	"true_damage",
	# 命中侧机制（敌我共用链）
	"splash_damage", "splash_radius", "chain_chance",
	"kill_repair", "armor_break", "armor_break_stacks",
	"mark_chance", "mark_vuln_bonus", "mark_duration",
	"chem_chance", "chem_dps", "chem_duration",
	"burn_chance", "burn_dps", "burn_duration",
	"nano_chance", "nano_pct", "nano_duration",
	"attack_fort_bonus", "siege_bonus_pct", "urban_defense_bonus",
	# 重定向族（registry 内映射到上述白名单键：vision→crit、thermal/heat→减伤 等）
	"vision", "vision_bonus", "night_bonus", "thermal_immunity", "heat_resist",
	"accuracy_bonus", "counter_bonus", "close_accuracy",
]

## ════════════════════════════════════════════════════════════════
##  配装数据（生成器产出区——勿手改格式，identity/overrides 可人工微调）
## ════════════════════════════════════════════════════════════════
# 【GEN:LOADOUTS:START】（tools/gen_enemy_loadout_draft.gd 生成区标记）
const LOADOUTS: Dictionary = {
	"ww1_inf_mp18": {
		identity = "步兵班·MP18·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "inf_01_submachine_gun", "gen_unified_splash", "inf_06_hp_ammo", "gen_combustion_catalyst", "inf_07_optical_scope", "enh_chain", "enh_atkspd_up"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"ww1_inf_rifle": {
		identity = "步兵班·步枪·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "gen_unified_splash", "inf_06_hp_ammo", "gen_combustion_catalyst", "inf_07_optical_scope", "enh_chain", "enh_atkspd_up", "inf_09_dual_mag"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"ww1_sup_mg_nest": {
		identity = "机枪巢·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "aa_04_quad_mount", "art_09_rapid_fire", "enh_crit_dmg", "art_chem_cluster", "gen_combustion_catalyst", "aa_14_searchlight", "enh_crit"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"ww1_arty_mortar": {
		identity = "迫击炮组·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "aa_15_flak_burst", "enh_crit_dmg", "art_chem_cluster", "gen_combustion_catalyst", "aa_14_searchlight", "enh_crit", "aa_04_quad_mount"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"ww1_inf_storm_e": {
		identity = "【精英】暴风突击队·机动游击——快速穿插，先手接敌",
		mods = ["enh_speed_up", "enh_dodge", "gen_05_shield", "inf_14_knee_pads", "inf_07_optical_scope", "enh_crit", "enh_range_up", "enh_dmg_up", "inf_05_ap_ammo"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"ww1_arm_rolls_e": {
		identity = "【精英】装甲车·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "enh_crit_dmg", "gen_combustion_catalyst", "enh_crit", "arm_01_sloped_armor", "arm_14_mine_plow", "arm_18_gun_mantlet", "enh_atkspd_up"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"ww1_boss_av7": {
		identity = "【首领】圣沙蒙坦克·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "arm_18_gun_mantlet", "enh_chain", "enh_crit_dmg", "gen_combustion_catalyst", "enh_crit", "arm_01_sloped_armor", "arm_14_mine_plow"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"foe_ww1_arm_rolls": {
		identity = "罗尔斯装甲车·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "arm_18_gun_mantlet", "enh_atkspd_up", "enh_crit_dmg", "gen_combustion_catalyst", "enh_crit", "arm_01_sloped_armor", "arm_14_mine_plow"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"foe_ww1_arm_ft17": {
		identity = "【首领】FT-17轻型坦克·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "enh_chain", "enh_crit_dmg", "gen_combustion_catalyst", "enh_crit", "arm_01_sloped_armor", "arm_14_mine_plow", "arm_18_gun_mantlet"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"foe_ww1_arty_77mm": {
		identity = "77mm野战炮·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "aa_04_quad_mount", "art_09_rapid_fire", "enh_crit_dmg", "art_chem_cluster", "gen_combustion_catalyst", "aa_14_searchlight", "enh_crit"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"foe_ww1_inf_cavalry": {
		identity = "骑兵斥候·机动游击——快速穿插，先手接敌",
		mods = ["enh_speed_up", "enh_dodge", "enh_dmg_up", "gen_combustion_catalyst", "gen_05_shield", "inf_14_knee_pads", "inf_07_optical_scope", "enh_crit", "enh_range_up"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"foe_ww1_sup_engineer": {
		identity = "工兵班·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "enh_crit_dmg", "art_chem_cluster", "gen_combustion_catalyst", "aa_14_searchlight", "enh_crit", "aa_04_quad_mount", "aa_15_flak_burst"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"foe_ww1_arty_m81": {
		identity = "81mm迫击炮组·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "enh_crit_dmg", "art_chem_cluster", "gen_combustion_catalyst", "aa_14_searchlight", "enh_crit", "aa_04_quad_mount", "art_09_rapid_fire"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"ww1_inf_enfield": {
		identity = "李-恩菲尔德志愿兵排·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "inf_01_submachine_gun", "gen_unified_splash", "inf_06_hp_ammo", "gen_combustion_catalyst", "inf_07_optical_scope", "enh_chain", "enh_atkspd_up"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"ww1_arm_rolls_mk2": {
		identity = "劳斯莱斯 Mk.II 装甲车·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "arm_18_gun_mantlet", "enh_chain", "enh_crit_dmg", "gen_combustion_catalyst", "enh_crit", "arm_01_sloped_armor", "arm_14_mine_plow"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"ww1_sup_vickers": {
		identity = "维克斯 .303 机枪阵地·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "aa_04_quad_mount", "art_09_rapid_fire", "enh_crit_dmg", "art_chem_cluster", "gen_combustion_catalyst", "aa_14_searchlight", "enh_crit"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"ww1_sup_ford_ambulance": {
		identity = "福特 T 型战地救护车·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "aa_04_quad_mount", "gen_unified_splash", "art_chem_cluster", "gen_combustion_catalyst", "aa_15_flak_burst", "eng_chem_sprayer", "enh_chain"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"ww1_inf_mp18_x": {
		identity = "MP18 突击队·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "inf_09_dual_mag", "gen_unified_splash", "inf_06_hp_ammo", "gen_combustion_catalyst", "inf_07_optical_scope", "enh_chain", "enh_atkspd_up"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"ww1_fort_pillbox": {
		identity = "混凝土机枪碉堡·攻城压制——反堡垒面轰炸，摧毁阵地工事",
		mods = ["enh_dmg_up", "enh_splash", "enh_chain", "enh_crit_dmg", "gen_unified_splash", "enh_range_up", "for_05_ammo_dump", "gen_combustion_catalyst", "enh_atkspd_up"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"ww1_fort_artillery": {
		identity = "要塞炮台·攻城压制——反堡垒面轰炸，摧毁阵地工事",
		mods = ["enh_dmg_up", "enh_splash", "enh_chain", "enh_crit_dmg", "gen_unified_splash", "enh_range_up", "for_05_ammo_dump", "gen_combustion_catalyst", "enh_atkspd_up"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"ww2_inf_thompson": {
		identity = "步兵班·汤普森·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "gen_unified_splash", "inf_06_hp_ammo", "gen_combustion_catalyst", "inf_07_optical_scope", "enh_chain", "enh_atkspd_up", "inf_01_submachine_gun"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"ww2_inf_garand": {
		identity = "步枪班·加兰德·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "enh_atkspd_up", "inf_01_submachine_gun", "gen_unified_splash", "inf_06_hp_ammo", "gen_combustion_catalyst", "inf_07_optical_scope", "enh_chain"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"ww2_sup_mg42": {
		identity = "MG42机枪组·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "aa_14_searchlight", "aa_01_radar", "art_01_rifling", "enh_crit_dmg", "aa_02_iff", "art_chem_cluster", "gen_combustion_catalyst"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"ww2_inf_panzerschreck_e": {
		identity = "反坦克组·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "gen_unified_splash", "inf_06_hp_ammo", "gen_combustion_catalyst", "inf_07_optical_scope", "enh_chain", "enh_atkspd_up", "gen_01_comms"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"ww2_inf_para_e": {
		identity = "【精英】伞兵精英·机动游击——快速穿插，先手接敌",
		mods = ["enh_speed_up", "enh_dodge", "gen_05_shield", "inf_14_knee_pads", "inf_07_optical_scope", "enh_crit", "enh_range_up", "enh_dmg_up", "gen_combustion_catalyst"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"ww2_arm_panther_e": {
		identity = "【精英】黑豹坦克·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "enh_crit_dmg", "gen_combustion_catalyst", "enh_crit", "arm_01_sloped_armor", "arm_13_deep_wading", "arm_14_mine_plow", "arm_18_gun_mantlet"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"ww2_boss_kingtiger": {
		identity = "【首领】虎王坦克·重装防御——厚甲消耗战，正面接敌",
		mods = ["enh_hp_up", "enh_def_up", "arm_01_sloped_armor", "enh_def_flat", "arm_18_gun_mantlet", "enh_regen", "enh_dodge", "arm_13_deep_wading", "arm_14_mine_plow"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"foe_ww2_inf_hellcat": {
		identity = "M18地狱猫·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "enh_crit_dmg", "gen_combustion_catalyst", "enh_crit", "arm_01_sloped_armor", "arm_13_deep_wading", "arm_14_mine_plow", "enh_atkspd_up"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"foe_ww2_arm_sherman": {
		identity = "M4谢尔曼·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "enh_atkspd_up", "enh_crit_dmg", "gen_combustion_catalyst", "enh_crit", "arm_01_sloped_armor", "arm_13_deep_wading", "arm_14_mine_plow"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"foe_ww2_arm_tiger": {
		identity = "【首领】虎式坦克·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "arm_14_mine_plow", "arm_18_gun_mantlet", "enh_crit_dmg", "gen_combustion_catalyst", "enh_crit", "arm_01_sloped_armor", "arm_13_deep_wading"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"foe_ww2_inf_bazooka": {
		identity = "巴祖卡组·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "inf_01_submachine_gun", "gen_unified_splash", "inf_06_hp_ammo", "gen_combustion_catalyst", "inf_07_optical_scope", "enh_chain", "enh_atkspd_up"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"foe_ww2_inf_panzerschrek": {
		identity = "铁拳反坦克组·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "enh_atkspd_up", "gen_01_comms", "gen_unified_splash", "inf_06_hp_ammo", "gen_combustion_catalyst", "inf_07_optical_scope", "enh_chain"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"foe_ww2_arty_m81": {
		identity = "81mm迫击炮·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "aa_01_radar", "art_01_rifling", "enh_crit_dmg", "aa_02_iff", "art_chem_cluster", "gen_combustion_catalyst", "aa_14_searchlight"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"ww2_arm_garand_para": {
		identity = "M1 加兰德伞兵班·机动游击——快速穿插，先手接敌",
		mods = ["enh_speed_up", "enh_dodge", "gen_05_shield", "inf_14_knee_pads", "inf_07_optical_scope", "enh_crit", "enh_range_up", "enh_dmg_up", "inf_05_ap_ammo"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"ww2_arty_hummel": {
		identity = "黄蜂 Hummel 自行火炮·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "aa_14_searchlight", "enh_crit", "art_01_rifling", "enh_crit_dmg", "aa_02_iff", "art_chem_cluster", "gen_combustion_catalyst"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"ww2_arty_pak40": {
		identity = "PaK 40 反坦克炮组·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "aa_14_searchlight", "enh_crit", "art_01_rifling", "enh_crit_dmg", "aa_02_iff", "art_chem_cluster", "gen_combustion_catalyst"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"ww2_sup_gmc_truck": {
		identity = "GMC 2.5t 补给卡车·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "aa_15_flak_burst", "eng_chem_sprayer", "art_01_rifling", "gen_unified_splash", "aa_02_iff", "art_chem_cluster", "gen_combustion_catalyst"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"ww2_inf_kar98k": {
		identity = "毛瑟 Kar98k 狙击组·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "gen_unified_splash", "inf_06_hp_ammo", "gen_combustion_catalyst", "inf_07_optical_scope", "enh_chain", "enh_atkspd_up", "gen_01_comms"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"ww2_air_bomber": {
		identity = "B-17 空中堡垒·对地轰炸——地毯式轰炸，覆盖地面目标",
		mods = ["enh_dmg_up", "enh_splash", "air_18_heavy_rack", "enh_chain", "gen_unified_splash", "gen_combustion_catalyst", "air_17_bombsight", "enh_crit_dmg", "enh_range_up"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"ww2_air_dive_bomber": {
		identity = "Ju 87 斯图卡·对地轰炸——地毯式轰炸，覆盖地面目标",
		mods = ["enh_dmg_up", "enh_splash", "air_18_heavy_rack", "enh_atkspd_up", "gen_unified_splash", "gen_combustion_catalyst", "air_17_bombsight", "enh_crit_dmg", "enh_range_up"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"ww2_fort_bunker": {
		identity = "混凝土碉堡·攻城压制——反堡垒面轰炸，摧毁阵地工事",
		mods = ["enh_dmg_up", "enh_splash", "enh_chain", "enh_crit_dmg", "gen_unified_splash", "enh_range_up", "for_05_ammo_dump", "gen_combustion_catalyst", "enh_atkspd_up"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"ww2_fort_flak": {
		identity = "88mm防空塔·防空特化——制空拦截，猎杀飞行单位",
		mods = ["enh_dmg_up", "enh_crit", "enh_atkspd_up", "enh_range_up", "for_05_ammo_dump", "gen_combustion_catalyst", "enh_dodge", "enh_crit_dmg", "enh_chain"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"cold_inf_ak": {
		identity = "苏军步兵·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "inf_10_saw", "enh_atkspd_up", "gen_unified_splash", "inf_03_small_caliber", "inf_06_hp_ammo", "gen_combustion_catalyst", "inf_07_optical_scope"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"cold_inf_m60": {
		identity = "美军步兵·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "gen_unified_splash", "inf_03_small_caliber", "inf_06_hp_ammo", "gen_combustion_catalyst", "inf_07_optical_scope", "inf_10_saw", "enh_chain"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"cold_arm_btr_e": {
		identity = "BTR装甲车·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "arm_06_apfsds", "arm_07_gun_missile", "enh_crit_dmg", "gen_combustion_catalyst", "arm_11_fire_control", "arm_12_thermal_sight", "enh_crit"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"cold_air_m113_e": {
		identity = "M113装甲车·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "arm_06_apfsds", "arm_07_gun_missile", "enh_crit_dmg", "gen_combustion_catalyst", "arm_11_fire_control", "arm_12_thermal_sight", "arm_01_sloped_armor"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"cold_inf_spetsnaz_e": {
		identity = "【精英】特种部队·机动游击——快速穿插，先手接敌",
		mods = ["enh_speed_up", "enh_dodge", "inf_10_saw", "gen_05_shield", "inf_14_knee_pads", "gen_stealth_coating", "inf_07_optical_scope", "enh_crit", "enh_range_up"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"cold_arm_t72_e": {
		identity = "【精英】T-72坦克·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "arm_01_sloped_armor", "arm_06_apfsds", "arm_07_gun_missile", "enh_crit_dmg", "gen_combustion_catalyst", "arm_11_fire_control", "arm_12_thermal_sight"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"cold_boss_mig": {
		identity = "【首领】米格-29·制空战机——空优格斗，先夺制空权",
		mods = ["enh_dmg_up", "enh_crit", "air_17_bombsight", "air_14_swing_wing", "air_21_terrain_radar", "air_22_countermeasure", "enh_dodge", "gen_stealth_coating", "gen_combustion_catalyst"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"foe_cold_inf_btr60": {
		identity = "BTR-60装甲车·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "arm_06_apfsds", "arm_07_gun_missile", "enh_crit_dmg", "gen_combustion_catalyst", "arm_11_fire_control", "arm_12_thermal_sight", "arm_01_sloped_armor"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"foe_cold_arm_t55": {
		identity = "【首领】T-55坦克·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "arm_12_thermal_sight", "arm_01_sloped_armor", "arm_06_apfsds", "arm_07_gun_missile", "enh_crit_dmg", "gen_combustion_catalyst", "arm_11_fire_control"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"foe_cold_inf_bmp1": {
		identity = "BMP-1步战车·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "arm_12_thermal_sight", "arm_01_sloped_armor", "arm_06_apfsds", "arm_07_gun_missile", "enh_crit_dmg", "gen_combustion_catalyst", "arm_11_fire_control"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"foe_cold_sup_m113": {
		identity = "M113装甲车·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "arm_06_apfsds", "arm_07_gun_missile", "enh_crit_dmg", "gen_combustion_catalyst", "arm_11_fire_control", "arm_12_thermal_sight", "enh_crit"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"foe_cold_sup_zsu23": {
		identity = "ZSU-23-4自行高炮·防空特化——制空拦截，猎杀飞行单位",
		mods = ["enh_dmg_up", "enh_crit", "art_09_rapid_fire", "aa_03_missile_rail", "aa_acid_warhead", "art_01_rifling", "art_02_extended_range", "aa_01_radar", "aa_04_quad_mount"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"cold_arty_bmd1": {
		identity = "BMD-1 空降战车·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "arm_06_apfsds", "arm_07_gun_missile", "enh_crit_dmg", "gen_combustion_catalyst", "arm_11_fire_control", "arm_12_thermal_sight", "arm_01_sloped_armor"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"cold_sup_bmp1_x": {
		identity = "BMP-1 步兵战车·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "arm_01_sloped_armor", "arm_06_apfsds", "arm_07_gun_missile", "enh_crit_dmg", "gen_combustion_catalyst", "arm_11_fire_control", "arm_12_thermal_sight"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"cold_inf_metis": {
		identity = "9K111 法特导弹组·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "gen_unified_splash", "inf_03_small_caliber", "inf_06_hp_ammo", "gen_combustion_catalyst", "inf_07_optical_scope", "inf_10_saw", "enh_chain"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"cold_arm_p18": {
		identity = "P-18 雷达警戒车·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "gen_combustion_catalyst", "enh_crit", "art_01_rifling", "art_02_extended_range", "enh_crit_dmg", "aa_02_iff", "art_chem_cluster"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"cold_arty_brem1": {
		identity = "BREM-1 装甲抢修车·重装防御——厚甲消耗战，正面接敌",
		mods = ["enh_hp_up", "enh_def_up", "gen_stealth_coating", "arm_01_sloped_armor", "enh_def_flat", "arm_18_gun_mantlet", "arm_10_diesel_turbo", "enh_regen", "enh_dodge"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"cold_air_strike_fighter": {
		identity = "F-111 土豚·对地轰炸——地毯式轰炸，覆盖地面目标",
		mods = ["enh_dmg_up", "enh_splash", "air_19_cluster_dispenser", "gen_unified_splash", "gen_combustion_catalyst", "air_17_bombsight", "enh_crit_dmg", "enh_range_up", "air_18_heavy_rack"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"cold_air_bomber": {
		identity = "图-95 熊式·对地轰炸——地毯式轰炸，覆盖地面目标",
		mods = ["enh_dmg_up", "enh_splash", "air_19_cluster_dispenser", "gen_unified_splash", "gen_combustion_catalyst", "air_17_bombsight", "enh_crit_dmg", "enh_range_up", "air_14_swing_wing"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"cold_fort_missile": {
		identity = "导弹发射井·攻城压制——反堡垒面轰炸，摧毁阵地工事",
		mods = ["enh_dmg_up", "enh_splash", "enh_crit_dmg", "gen_unified_splash", "enh_range_up", "for_05_ammo_dump", "gen_combustion_catalyst", "enh_atkspd_up", "enh_chain"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"cold_fort_radar": {
		identity = "雷达站·攻城压制——反堡垒面轰炸，摧毁阵地工事",
		mods = ["enh_dmg_up", "enh_splash", "gen_unified_splash", "enh_range_up", "for_05_ammo_dump", "gen_combustion_catalyst", "enh_atkspd_up", "enh_chain", "enh_crit"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"mod_inf_marine": {
		identity = "海军陆战队·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "enh_atkspd_up", "gen_unified_splash", "inf_03_small_caliber", "inf_06_hp_ammo", "gen_combustion_catalyst", "inf_07_optical_scope", "inf_10_saw"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"mod_air_technical_e": {
		identity = "皮卡武装·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "gen_unified_splash", "inf_03_small_caliber", "inf_06_hp_ammo", "gen_combustion_catalyst", "inf_07_optical_scope", "inf_10_saw", "enh_chain"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"mod_arm_stryker_e": {
		identity = "斯特赖克装甲车·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "arm_11_fire_control", "enh_crit", "arm_06_apfsds", "arm_07_gun_missile", "enh_crit_dmg", "gen_weakpoint_analyzer", "gen_combustion_catalyst"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"mod_arty_mlrs_e": {
		identity = "火箭炮车·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "eng_optical_fiber", "art_01_rifling", "art_02_extended_range", "enh_crit_dmg", "gen_weakpoint_analyzer", "aa_02_iff", "art_chem_cluster"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"mod_inf_delta_e": {
		identity = "【精英】三角洲部队·机动游击——快速穿插，先手接敌",
		mods = ["enh_speed_up", "enh_dodge", "inf_07_optical_scope", "inf_16_exoskeleton", "inf_10_saw", "gen_05_shield", "inf_04_bullpup", "inf_14_knee_pads", "rec_07_gps"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"mod_arm_abrams_e": {
		identity = "【精英】M1A2坦克·重装防御——厚甲消耗战，正面接敌",
		mods = ["enh_hp_up", "enh_def_up", "enh_def_flat", "arm_02_composite_armor", "arm_10_diesel_turbo", "enh_regen", "enh_dodge", "gen_stealth_coating", "arm_06_apfsds"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"mod_air_apache_e": {
		identity = "【精英】阿帕奇直升机·对地轰炸——地毯式轰炸，覆盖地面目标",
		mods = ["enh_dmg_up", "enh_splash", "air_06_bvr_missile", "air_04_aesa", "air_19_cluster_dispenser", "gen_unified_splash", "gen_combustion_catalyst", "air_17_bombsight", "enh_crit_dmg"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"mod_boss_command": {
		identity = "【首领】指挥中枢·攻城压制——反堡垒面轰炸，摧毁阵地工事",
		mods = ["enh_dmg_up", "enh_splash", "enh_crit", "gen_unified_splash", "enh_range_up", "for_05_ammo_dump", "gen_combustion_catalyst", "enh_atkspd_up", "enh_chain"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"foe_mod_inf_technical": {
		identity = "皮卡武装·机动游击——快速穿插，先手接敌",
		mods = ["enh_speed_up", "enh_dodge", "rec_07_gps", "inf_07_optical_scope", "inf_16_exoskeleton", "inf_10_saw", "gen_05_shield", "inf_04_bullpup", "inf_14_knee_pads"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"foe_mod_arm_m1a1": {
		identity = "M1A1主战坦克·重装防御——厚甲消耗战，正面接敌",
		mods = ["enh_hp_up", "enh_def_up", "enh_def_flat", "arm_02_composite_armor", "arm_10_diesel_turbo", "enh_regen", "enh_dodge", "gen_stealth_coating", "arm_06_apfsds"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"foe_mod_sup_m6": {
		identity = "自行高炮M6·防空特化——制空拦截，猎杀飞行单位",
		mods = ["enh_dmg_up", "enh_crit", "sup_targeting_drone", "aa_04_quad_mount", "aa_03_missile_rail", "aa_acid_warhead", "art_01_rifling", "art_02_extended_range", "art_03_guided_shell"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"foe_mod_arty_m270": {
		identity = "M270火箭炮·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "eng_optical_fiber", "art_01_rifling", "art_02_extended_range", "enh_crit_dmg", "gen_weakpoint_analyzer", "aa_02_iff", "art_chem_cluster"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"foe_mod_inf_scout_drone": {
		identity = "侦察无人机·制空战机——空优格斗，先夺制空权",
		mods = ["enh_dmg_up", "enh_crit", "enh_dodge", "air_antiradiation_missile", "air_17_bombsight", "air_targeting_laser", "air_02_vector_thrust", "air_14_swing_wing", "air_21_terrain_radar"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"foe_mod_arm_m1a2sep": {
		identity = "【首领】M1A2 SEP主战坦克·重装防御——厚甲消耗战，正面接敌",
		mods = ["enh_hp_up", "enh_def_up", "gen_stealth_coating", "arm_06_apfsds", "enh_def_flat", "arm_02_composite_armor", "arm_10_diesel_turbo", "enh_regen", "enh_dodge"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"foe_mod_arm_abrams_mk2": {
		identity = "艾布拉姆斯Mk.II·重装防御——厚甲消耗战，正面接敌",
		mods = ["enh_hp_up", "enh_def_up", "enh_def_flat", "arm_02_composite_armor", "arm_10_diesel_turbo", "enh_regen", "enh_dodge", "gen_stealth_coating", "arm_05_smoothbore"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"mod_sup_m4_carbine": {
		identity = "M4 卡宾特遣班·机动游击——快速穿插，先手接敌",
		mods = ["enh_speed_up", "enh_dodge", "inf_16_exoskeleton", "inf_10_saw", "gen_05_shield", "inf_04_bullpup", "inf_14_knee_pads", "rec_07_gps", "inf_07_optical_scope"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"mod_inf_patriot": {
		identity = "爱国者 PAC-3 发射车·防空特化——制空拦截，猎杀飞行单位",
		mods = ["enh_dmg_up", "enh_crit", "sup_targeting_drone", "aa_04_quad_mount", "aa_03_missile_rail", "aa_acid_warhead", "art_01_rifling", "art_02_extended_range", "art_03_guided_shell"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"mod_arm_himars": {
		identity = "HIMARS 火箭炮组·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "art_chem_cluster", "gen_combustion_catalyst", "art_01_rifling", "art_02_extended_range", "enh_crit_dmg", "gen_weakpoint_analyzer", "aa_02_iff"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"mod_arty_rq7": {
		identity = "RQ-7 影子无人机班·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "aa_07_aesa", "art_01_rifling", "art_02_extended_range", "gen_unified_splash", "aa_02_iff", "art_chem_cluster", "gen_combustion_catalyst"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"mod_sup_growler": {
		identity = "EA-18G 电子战小组·对地轰炸——地毯式轰炸，覆盖地面目标",
		mods = ["enh_dmg_up", "enh_splash", "gen_weakpoint_analyzer", "air_04_aesa", "air_19_cluster_dispenser", "gen_unified_splash", "gen_combustion_catalyst", "air_17_bombsight", "enh_crit_dmg"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"mod_air_multirole": {
		identity = "F-15E 攻击鹰·制空战机——空优格斗，先夺制空权",
		mods = ["enh_dmg_up", "enh_crit", "air_21_terrain_radar", "air_22_countermeasure", "air_antiradiation_missile", "air_17_bombsight", "air_targeting_laser", "air_02_vector_thrust", "air_14_swing_wing"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"mod_air_bomber": {
		identity = "B-52 同温层堡垒·对地轰炸——地毯式轰炸，覆盖地面目标",
		mods = ["enh_dmg_up", "enh_splash", "air_04_aesa", "air_19_cluster_dispenser", "gen_unified_splash", "gen_combustion_catalyst", "air_17_bombsight", "enh_crit_dmg", "air_06_bvr_missile"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"mod_fort_citadel": {
		identity = "要塞核心·攻城压制——反堡垒面轰炸，摧毁阵地工事",
		mods = ["enh_dmg_up", "enh_splash", "enh_chain", "enh_crit_dmg", "gen_unified_splash", "enh_range_up", "for_05_ammo_dump", "gen_combustion_catalyst", "enh_atkspd_up"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"mod_fort_phalanx": {
		identity = "近防炮系统·防空特化——制空拦截，猎杀飞行单位",
		mods = ["enh_dmg_up", "enh_crit", "enh_atkspd_up", "for_03_auto_turret", "enh_range_up", "for_05_ammo_dump", "gen_combustion_catalyst", "enh_dodge", "gen_weakpoint_analyzer"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"fut_air_drone": {
		identity = "无人机群·对地轰炸——地毯式轰炸，覆盖地面目标",
		mods = ["enh_dmg_up", "enh_splash", "gen_11_phase_resonance", "air_04_aesa", "air_19_cluster_dispenser", "gen_unified_splash", "gen_beam_splitter", "gen_combustion_catalyst", "gen_weakpoint_analyzer"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"fut_inf_cyborg": {
		identity = "机械步兵·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "gen_combustion_catalyst", "enh_chain", "gen_unified_splash", "inf_03_small_caliber", "gen_11_phase_resonance", "inf_06_hp_ammo", "gen_beam_splitter"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"fut_arm_mech_e": {
		identity = "机甲步兵·重装防御——厚甲消耗战，正面接敌",
		mods = ["enh_hp_up", "enh_def_up", "enh_def_flat", "gen_12_phase_shielding", "arm_02_composite_armor", "arm_10_diesel_turbo", "enh_regen", "enh_dodge", "gen_stealth_coating"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"fut_arm_hovertank_e": {
		identity = "悬浮坦克·重装防御——厚甲消耗战，正面接敌",
		mods = ["enh_hp_up", "enh_def_up", "arm_05_smoothbore", "enh_def_flat", "gen_12_phase_shielding", "arm_02_composite_armor", "arm_10_diesel_turbo", "enh_regen", "enh_dodge"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"fut_inf_spectre_e": {
		identity = "【精英】幽灵特工·机动游击——快速穿插，先手接敌",
		mods = ["enh_speed_up", "enh_dodge", "inf_16_exoskeleton", "inf_10_saw", "gen_05_shield", "inf_04_bullpup", "inf_14_knee_pads", "rec_07_gps", "inf_08_holographic"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"fut_arm_colossus_e": {
		identity = "【精英】巨神机甲·重装防御——厚甲消耗战，正面接敌",
		mods = ["enh_hp_up", "enh_def_up", "gen_stealth_coating", "enh_def_flat", "gen_12_phase_shielding", "arm_02_composite_armor", "arm_10_diesel_turbo", "enh_regen", "enh_dodge"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"fut_boss_nexus": {
		identity = "【首领】风暴核心·重装防御——厚甲消耗战，正面接敌",
		mods = ["enh_hp_up", "enh_def_up", "enh_dodge", "arm_05_smoothbore", "enh_def_flat", "gen_12_phase_shielding", "arm_02_composite_armor", "arm_10_diesel_turbo", "enh_regen"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"foe_fut_inf_scout_mech": {
		identity = "侦察机甲·机动游击——快速穿插，先手接敌",
		mods = ["enh_speed_up", "enh_dodge", "rec_07_gps", "gen_stealth_coating", "inf_16_exoskeleton", "inf_10_saw", "gen_05_shield", "inf_04_bullpup", "inf_14_knee_pads"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"foe_fut_arm_hovertank": {
		identity = "悬浮坦克·重装防御——厚甲消耗战，正面接敌",
		mods = ["enh_hp_up", "enh_def_up", "gen_stealth_coating", "enh_def_flat", "gen_12_phase_shielding", "arm_02_composite_armor", "arm_10_diesel_turbo", "enh_regen", "enh_dodge"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"foe_fut_arm_prism": {
		identity = "光棱坦克·重装防御——厚甲消耗战，正面接敌",
		mods = ["enh_hp_up", "enh_def_up", "gen_stealth_coating", "enh_def_flat", "gen_12_phase_shielding", "arm_02_composite_armor", "arm_10_diesel_turbo", "enh_regen", "enh_dodge"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"foe_fut_arm_heavy_mech": {
		identity = "【首领】重装机甲·重装防御——厚甲消耗战，正面接敌",
		mods = ["enh_hp_up", "enh_def_up", "gen_stealth_coating", "enh_def_flat", "gen_12_phase_shielding", "arm_02_composite_armor", "arm_10_diesel_turbo", "enh_regen", "enh_dodge"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"foe_fut_arm_nexus": {
		identity = "【首领】虚空领主·重装防御——厚甲消耗战，正面接敌",
		mods = ["enh_hp_up", "enh_def_up", "enh_def_flat", "gen_12_phase_shielding", "arm_02_composite_armor", "arm_10_diesel_turbo", "enh_regen", "enh_dodge", "gen_stealth_coating"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"foe_fut_sup_bulwark": {
		identity = "壁垒·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "aa_02_iff", "art_chem_cluster", "gen_11_phase_resonance", "art_01_rifling", "art_02_extended_range", "enh_crit_dmg", "gen_weakpoint_analyzer"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"foe_fut_arm_titan_mk2": {
		identity = "泰坦Mk.II·重装防御——厚甲消耗战，正面接敌",
		mods = ["enh_hp_up", "enh_def_up", "enh_def_flat", "gen_12_phase_shielding", "arm_02_composite_armor", "arm_10_diesel_turbo", "enh_regen", "enh_dodge", "arm_05_smoothbore"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"foe_fut_inf_storm_rider": {
		identity = "暴风骑士·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "gen_unified_splash", "inf_03_small_caliber", "gen_11_phase_resonance", "inf_06_hp_ammo", "gen_beam_splitter", "gen_combustion_catalyst", "inf_10_saw"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"foe_fut_air_heavy_carrier": {
		identity = "重装母舰·制空战机——空优格斗，先夺制空权",
		mods = ["enh_dmg_up", "enh_crit", "gen_11_phase_resonance", "air_antiradiation_missile", "air_targeting_laser", "gen_reflector_array", "air_02_vector_thrust", "air_14_swing_wing", "air_21_terrain_radar"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"foe_fut_air_regen_frame": {
		identity = "再生骨架·对地轰炸——地毯式轰炸，覆盖地面目标",
		mods = ["enh_dmg_up", "enh_splash", "gen_weakpoint_analyzer", "gen_11_phase_resonance", "air_04_aesa", "air_19_cluster_dispenser", "gen_unified_splash", "gen_beam_splitter", "gen_combustion_catalyst"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"fut_inf_neural": {
		identity = "神经接口突击兵·机动游击——快速穿插，先手接敌",
		mods = ["enh_speed_up", "enh_dodge", "inf_16_exoskeleton", "inf_10_saw", "gen_05_shield", "inf_04_bullpup", "inf_14_knee_pads", "rec_07_gps", "gen_stealth_coating"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"fut_arm_hk07": {
		identity = "HK-07 量产机兵·重装防御——厚甲消耗战，正面接敌",
		mods = ["enh_hp_up", "enh_def_up", "arm_05_smoothbore", "enh_def_flat", "gen_12_phase_shielding", "arm_02_composite_armor", "arm_10_diesel_turbo", "enh_regen", "enh_dodge"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"fut_arty_hel30": {
		identity = "HEL-30 激光炮阵列·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "gen_11_phase_resonance", "art_01_rifling", "art_02_extended_range", "enh_crit_dmg", "gen_weakpoint_analyzer", "aa_02_iff", "eng_optical_fiber"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"fut_sup_nrepair": {
		identity = "N-Repair 纳米工程车·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "gen_11_phase_resonance", "art_01_rifling", "art_02_extended_range", "enh_crit_dmg", "gen_weakpoint_analyzer", "aa_02_iff", "eng_optical_fiber"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"fut_inf_x9": {
		identity = "X-9 猎杀者渗透组·机动游击——快速穿插，先手接敌",
		mods = ["enh_speed_up", "enh_dodge", "inf_08_holographic", "inf_16_exoskeleton", "inf_10_saw", "gen_05_shield", "inf_04_bullpup", "inf_14_knee_pads", "rec_07_gps"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"fut_inf_c96": {
		identity = "毛瑟 C96 征召兵排·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "gen_unified_splash", "inf_03_small_caliber", "gen_11_phase_resonance", "inf_06_hp_ammo", "gen_beam_splitter", "gen_combustion_catalyst", "enh_chain"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"fut_arm_sdkfz": {
		identity = "Sd.Kfz.251/1 半履带车·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "gen_beam_splitter", "gen_combustion_catalyst", "arm_06_apfsds", "gen_11_phase_resonance", "arm_07_gun_missile", "enh_crit_dmg", "gen_weakpoint_analyzer"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"fut_arty_ssc1": {
		identity = "SS-C-1 岸防导弹组·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "aa_02_iff", "eng_optical_fiber", "gen_11_phase_resonance", "art_01_rifling", "art_02_extended_range", "enh_crit_dmg", "gen_weakpoint_analyzer"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"fut_sup_ps9": {
		identity = "PS-9 相位中继站·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "gen_11_phase_resonance", "art_01_rifling", "art_02_extended_range", "enh_crit_dmg", "gen_weakpoint_analyzer", "aa_02_iff", "art_chem_cluster"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"fut_air_stealth_multirole": {
		identity = "六代机制空型·制空战机——空优格斗，先夺制空权",
		mods = ["enh_dmg_up", "enh_crit", "air_14_swing_wing", "air_21_terrain_radar", "gen_11_phase_resonance", "air_antiradiation_missile", "air_targeting_laser", "gen_reflector_array", "air_02_vector_thrust"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"fut_air_stealth_bomber": {
		identity = "B-21 突袭者·对地轰炸——地毯式轰炸，覆盖地面目标",
		mods = ["enh_dmg_up", "enh_splash", "gen_combustion_catalyst", "enh_crit_dmg", "gen_11_phase_resonance", "air_04_aesa", "air_19_cluster_dispenser", "gen_unified_splash", "gen_beam_splitter"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"fut_fort_ion": {
		identity = "离子炮台·攻城压制——反堡垒面轰炸，摧毁阵地工事",
		mods = ["enh_dmg_up", "enh_splash", "enh_chain", "gen_unified_splash", "gen_11_phase_resonance", "enh_range_up", "for_05_ammo_dump", "gen_beam_splitter", "gen_combustion_catalyst"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"fut_fort_shield": {
		identity = "能量护盾发生器·攻城压制——反堡垒面轰炸，摧毁阵地工事",
		mods = ["enh_dmg_up", "enh_splash", "gen_combustion_catalyst", "enh_atkspd_up", "gen_unified_splash", "gen_11_phase_resonance", "enh_range_up", "for_05_ammo_dump", "gen_beam_splitter"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"xeno_swarmling": {
		identity = "蚀群幼体·机动游击——快速穿插，先手接敌",
		mods = ["enh_speed_up", "enh_dodge", "inf_16_exoskeleton", "inf_10_saw", "gen_05_shield", "inf_04_bullpup", "inf_14_knee_pads", "rec_07_gps", "inf_08_holographic"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"xeno_probe": {
		identity = "晶工探测器·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "aa_07_aesa", "art_01_rifling", "art_02_extended_range", "gen_unified_splash", "gen_11_phase_resonance", "aa_02_iff", "eng_optical_fiber"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"xeno_zealot": {
		identity = "渡暮狂战士·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "enh_chain", "gen_unified_splash", "inf_03_small_caliber", "gen_11_phase_resonance", "inf_06_hp_ammo", "gen_beam_splitter", "gen_combustion_catalyst"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"xeno_stalker": {
		identity = "影跃猎者·机动游击——快速穿插，先手接敌",
		mods = ["enh_speed_up", "enh_dodge", "rec_07_gps", "gen_stealth_coating", "inf_16_exoskeleton", "inf_10_saw", "gen_05_shield", "inf_04_bullpup", "inf_14_knee_pads"],
		cuts = {1: 5, 2: 6, 3: 8, 4: 9},
	},
	"xeno_adept": {
		identity = "灵裔侍从·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "gen_combustion_catalyst", "enh_chain", "gen_unified_splash", "inf_03_small_caliber", "gen_11_phase_resonance", "inf_06_hp_ammo", "gen_beam_splitter"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"xeno_sentinel": {
		identity = "哨兵浮棱·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "aa_02_iff", "eng_optical_fiber", "aa_07_aesa", "art_01_rifling", "art_02_extended_range", "gen_unified_splash", "gen_11_phase_resonance"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"xeno_dragoon": {
		identity = "龙骑残躯·重装防御——厚甲消耗战，正面接敌",
		mods = ["enh_hp_up", "enh_def_up", "enh_def_flat", "gen_12_phase_shielding", "arm_02_composite_armor", "arm_10_diesel_turbo", "enh_regen", "enh_dodge", "gen_stealth_coating"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"xeno_plasma_bug": {
		identity = "等离囊虫·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "art_chem_cluster", "gen_11_phase_resonance", "art_01_rifling", "art_02_extended_range", "enh_crit_dmg", "gen_weakpoint_analyzer", "aa_02_iff"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"xeno_tripod": {
		identity = "【精英】三足行者·重装防御——厚甲消耗战，正面接敌",
		mods = ["enh_hp_up", "enh_def_up", "gen_stealth_coating", "enh_def_flat", "gen_12_phase_shielding", "arm_02_composite_armor", "arm_10_diesel_turbo", "enh_regen", "enh_dodge"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"xeno_hunter": {
		identity = "【精英】隐面猎手·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "enh_chain", "gen_unified_splash", "inf_03_small_caliber", "gen_11_phase_resonance", "inf_06_hp_ammo", "gen_beam_splitter", "gen_combustion_catalyst"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"xeno_mimic": {
		identity = "【精英】拟时者·机动游击——快速穿插，先手接敌",
		mods = ["enh_speed_up", "enh_dodge", "inf_16_exoskeleton", "inf_10_saw", "gen_05_shield", "inf_04_bullpup", "inf_14_knee_pads", "rec_07_gps", "gen_stealth_coating"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"xeno_biomorph": {
		identity = "【精英】异变体·机动游击——快速穿插，先手接敌",
		mods = ["enh_speed_up", "enh_dodge", "inf_16_exoskeleton", "inf_10_saw", "gen_05_shield", "inf_04_bullpup", "inf_14_knee_pads", "rec_07_gps", "gen_stealth_coating"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"xeno_dark_templar": {
		identity = "【精英】暗影执刃·火力压制——持续面杀伤，压制步兵集群",
		mods = ["enh_dmg_up", "enh_splash", "enh_chain", "gen_unified_splash", "inf_03_small_caliber", "gen_11_phase_resonance", "inf_06_hp_ammo", "gen_beam_splitter", "gen_combustion_catalyst"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"xeno_reaver": {
		identity = "【精英】蚀甲虫·重装防御——厚甲消耗战，正面接敌",
		mods = ["enh_hp_up", "enh_def_up", "enh_def_flat", "gen_12_phase_shielding", "arm_02_composite_armor", "arm_10_diesel_turbo", "enh_regen", "enh_dodge", "arm_05_smoothbore"],
		cuts = {1: 5, 2: 6, 3: 9, 4: 9},
	},
	"xeno_interceptor": {
		identity = "【精英】拦截机群·对地轰炸——地毯式轰炸，覆盖地面目标",
		mods = ["enh_dmg_up", "enh_splash", "gen_combustion_catalyst", "gen_weakpoint_analyzer", "gen_11_phase_resonance", "air_04_aesa", "air_19_cluster_dispenser", "gen_unified_splash", "gen_beam_splitter"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"xeno_carrier": {
		identity = "【精英】蚀空母舰·对地轰炸——地毯式轰炸，覆盖地面目标",
		mods = ["enh_dmg_up", "enh_splash", "gen_11_phase_resonance", "air_04_aesa", "air_19_cluster_dispenser", "gen_unified_splash", "gen_beam_splitter", "gen_combustion_catalyst", "gen_weakpoint_analyzer"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"xeno_saucer": {
		identity = "【精英】猎能碟·制空战机——空优格斗，先夺制空权",
		mods = ["enh_dmg_up", "enh_crit", "air_22_countermeasure", "gen_11_phase_resonance", "air_antiradiation_missile", "air_targeting_laser", "gen_reflector_array", "air_02_vector_thrust", "air_14_swing_wing"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"xeno_templar": {
		identity = "【首领】渡师·风暴·破甲攻坚——反装甲火力特化，专破硬目标",
		mods = ["enh_dmg_up", "enh_penetration", "eng_optical_fiber", "gen_11_phase_resonance", "art_01_rifling", "art_02_extended_range", "enh_crit_dmg", "gen_weakpoint_analyzer", "aa_02_iff"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
	"xeno_thing": {
		identity = "【首领】拟形之惧·重装防御——厚甲消耗战，正面接敌",
		mods = ["enh_hp_up", "enh_def_up", "enh_dodge", "arm_05_smoothbore", "enh_def_flat", "gen_12_phase_shielding", "arm_02_composite_armor", "arm_10_diesel_turbo", "enh_regen"],
		cuts = {1: 5, 2: 7, 3: 9, 4: 9},
	},
	"xeno_mothership": {
		identity = "【首领】蚀冕方舟·制空战机——空优格斗，先夺制空权",
		mods = ["enh_dmg_up", "enh_crit", "air_14_swing_wing", "air_21_terrain_radar", "gen_11_phase_resonance", "air_antiradiation_missile", "air_targeting_laser", "gen_reflector_array", "air_02_vector_thrust"],
		cuts = {1: 5, 2: 7, 3: 8, 4: 9},
	},
}
# 【GEN:LOADOUTS:END】

## 取某敌方卡的配装（未配置返回 {}，调用方走模板兜底/跳过）
static func get_loadout(archetype_id: String) -> Dictionary:
	return LOADOUTS.get(archetype_id, {}) as Dictionary

## 取一句话定位（未配置返回空串）
static func get_identity(archetype_id: String) -> String:
	return String((LOADOUTS.get(archetype_id, {}) as Dictionary).get("identity", ""))

## 取某档的改造 id 列表（未配置返回 []——调用方按兵种模板兜底或跳过）
static func get_mods_for_tier(archetype_id: String, tier: int) -> Array:
	var lo: Dictionary = LOADOUTS.get(archetype_id, {}) as Dictionary
	if lo.is_empty():
		return []
	var mods: Array = lo.get("mods", []) as Array
	if mods.is_empty():
		return []
	var cuts: Dictionary = lo.get("cuts", DEFAULT_CUTS) as Dictionary
	var n: int = int(cuts.get(tier, DEFAULT_CUTS.get(tier, 5)))
	return mods.slice(0, clampi(n, 0, mods.size()))
